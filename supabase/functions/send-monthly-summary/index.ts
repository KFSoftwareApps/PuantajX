import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0";

const RESEND_API_KEY = "re_4VgGie2R_MQhQRjFMZ7XV8buHywagiCqF";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Fetch eligible organizations
    // notify_monthly_summary = true AND billing_email_verified = true
    const { data: orgs, error: orgError } = await supabase
      .from('organizations')
      .select('id, name, billing_email')
      .eq('notify_monthly_summary', true)
      .eq('billing_email_verified', true);

    if (orgError) throw orgError;

    const results = [];

    // 2. Loop and Send (For MVP linear processing is fine)
    if (orgs) {
      for (const org of orgs) {
        if (!org.billing_email) continue;
        
        // Mocking statistics for now (or could fetch real counts)
        // Ideally we would run complex queries here provided by a Postgres function
        // For efficiency, let's just send a generic "Check your report" email
        
        const html = `
          <div style="font-family: sans-serif; color: #333;">
            <h2>📊 Aylık Faaliyet Raporu</h2>
            <p>Sayın <b>${org.name}</b> yetkilisi,</p>
            <p>Geçtiğimiz aya ait hesap özetiniz hazırdır.</p>
            
            <p>Detaylı raporları ve personel hakedişlerini görüntülemek için panele giriş yapın.</p>
            
            <a href="https://puantajx.app/dashboard" style="display: inline-block; background: #2e7d32; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;">Panele Git</a>
            
            <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
            <small style="color: #777;">Bu e-posta ${org.billing_email} adresine gönderilmiştir. Tercihlerinizi <a href="https://puantajx.app/settings">Ayarlar</a>'dan değiştirebilirsiniz.</small>
          </div>
        `;

        try {
          const res = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${RESEND_API_KEY}`,
            },
            body: JSON.stringify({
              from: "PuantajX <onboarding@resend.dev>",
              to: [org.billing_email],
              subject: `📅 ${new Date().toLocaleString('tr-TR', { month: 'long' })} Ayı Faaliyet Raporu`,
              html: html,
            }),
          });
          
          if (res.ok) {
            results.push({ org: org.name, status: 'sent' });
          } else {
             const err = await res.text();
             results.push({ org: org.name, status: 'failed', error: err });
          }
        } catch (e) {
          results.push({ org: org.name, status: 'error', error: e.message });
        }
      }
    }

    return new Response(JSON.stringify({ success: true, processed: results.length, details: results }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
