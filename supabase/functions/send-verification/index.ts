import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0";

const RESEND_API_KEY = "re_4VgGie2R_MQhQRjFMZ7XV8buHywagiCqF";
const PROJECT_REF = "zfptxccotqqehgkpysbq"; 

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Helper to resolve OR CREATE UUID from Name if needed
async function resolveOrCreateOrgId(supabase: any, orgIdInput: string, email: string): Promise<string> {
  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(orgIdInput);
  if (isUuid) return orgIdInput;

  const { data } = await supabase
    .from('organizations')
    .select('id')
    .eq('name', orgIdInput)
    .maybeSingle();

  if (data?.id) return data.id;

  console.log(`Org ${orgIdInput} not found. Auto-creating...`);
  const { data: newOrg, error } = await supabase
    .from('organizations')
    .insert({
      name: orgIdInput,
      code: orgIdInput,
      billing_email: email,
      created_at: new Date().toISOString(),
    })
    .select('id')
    .single();

  if (error) {
    console.error("Auto-create failed:", error);
    throw new Error(`Organizasyon olusturulamadi: ${error.message}`);
  }
  return newOrg.id;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const url = new URL(req.url);
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // 1. GET Request (Verification Click)
  if (req.method === 'GET') {
    const orgIdInput = url.searchParams.get('orgId');
    const email = url.searchParams.get('email');

    if (!orgIdInput || !email) {
      return new Response("<h3>Hata: Gecersiz baglanti.</h3>", { 
        headers: { "Content-Type": "text/html; charset=utf-8" } 
      });
    }

    try {
      const realOrgId = await resolveOrCreateOrgId(supabase, orgIdInput, email);

      const { error } = await supabase
        .from('organizations')
        .update({ billing_email_verified: true })
        .eq('id', realOrgId)
        .eq('billing_email', email);

      if (error) throw error;

      return new Response(`<!DOCTYPE html>
<html lang="tr">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Doğrulama Başarılı</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; text-align: center; padding: 40px 20px; background: #f9f9f9; }
      .card { background: white; padding: 40px; border-radius: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); max-width: 400px; margin: 0 auto; }
      h1 { color: #2e7d32; margin-bottom: 10px; }
      p { color: #555; line-height: 1.5; }
      .icon { font-size: 48px; margin-bottom: 20px; display: block; }
    </style>
  </head>
  <body>
    <div class="card">
      <span class="icon">✅</span>
      <h1>Doğrulandı!</h1>
      <p><b>${email}</b> adresi başarıyla doğrulandı.</p>
      <p>Bu pencereyi kapatıp uygulamaya dönebilirsiniz.</p>
    </div>
  </body>
</html>`, { 
        headers: { "Content-Type": "text/html; charset=utf-8" } 
      });

    } catch (e) {
      return new Response(`<h3>Hata: ${e.message}</h3>`, { headers: { "Content-Type": "text/html; charset=utf-8" } });
    }
  }

  // 2. POST Request (Send Email)
  try {
    const { email, orgId } = await req.json(); 
    if (!email || !orgId) throw new Error("Missing email or orgId");

    const realOrgId = await resolveOrCreateOrgId(supabase, orgId, email);
    const verifyUrl = `https://${PROJECT_REF}.supabase.co/functions/v1/send-verification?orgId=${realOrgId}&email=${email}`;

    const html = `
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            body { font-family: sans-serif; color: #333; }
            .container { padding: 30px; border: 1px solid #eee; border-radius: 12px; max-width: 600px; margin: 0 auto; background-color: #ffffff; }
            .btn { background-color: #000000; color: #ffffff !important; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: bold; display: inline-block;}
            .footer { margin-top: 30px; font-size: 12px; color: #888; border-top: 1px solid #eee; padding-top: 20px; }
          </style>
        </head>
        <body style="background-color: #f5f5f5; padding: 20px;">
          <div class="container">
            <h2>PuantajX Fatura Doğrulama</h2>
            <p>Merhaba,</p>
            <p>Organizasyonunuzun <b>(${email})</b> fatura e-posta adresini doğrulamak için lütfen aşağıdaki butona tıklayın:</p>
            <p style="text-align: center; margin: 40px 0;">
              <a href="${verifyUrl}" class="btn">E-postayı Doğrula</a>
            </p>
            <p>Eğer butona tıklayamıyorsanız, aşağıdaki linki tarayıcınıza yapıştırın:</p>
            <p style="font-size: 12px; color: #007bff; word-break: break-all;">${verifyUrl}</p>
            <div class="footer">
              <p>Bu işlemi siz talep etmediyseniz lütfen bu e-postayı dikkate almayın.</p>
              <p>PuantajX Ekibi</p>
            </div>
          </div>
        </body>
      </html>
    `;

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "PuantajX <onboarding@resend.dev>", 
        to: email, 
        subject: "Fatura E-postanızı Doğrulayın",
        html: html,
      }),
    });

    const data = await res.json();
    if (!res.ok) throw new Error(data.message || 'Resend API Failed');

    return new Response(JSON.stringify({ success: true, data }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
