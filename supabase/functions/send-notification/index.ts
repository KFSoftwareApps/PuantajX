import { serve } from "https://deno.land/std@0.192.0/http/server.ts";

const RESEND_API_KEY = "re_4VgGie2R_MQhQRjFMZ7XV8buHywagiCqF";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface NotificationRequest {
  type: 'limit_warning' | 'billing_update';
  email: string;
  orgName: string;
  data: any; // Flexible data payload
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const payload: NotificationRequest = await req.json();
    const { type, email, orgName, data } = payload;

    if (!email) throw new Error("Email is required");

    let subject = "";
    let html = "";

    if (type === 'limit_warning') {
      const { resource, current, limit } = data;
      const percent = Math.round((current / limit) * 100);
      subject = `⚠️ Limit Uyarısı: ${resource} Kotanız Doluyor (%${percent})`;
      html = `
        <div style="font-family: sans-serif; color: #333;">
          <h2>Limit Uyarısı</h2>
          <p>Sayın <b>${orgName}</b> yetkilisi,</p>
          <p>Organizasyonunuzun <b>${resource}</b> kullanım limiti kritik seviyeye ulaştı.</p>
          
          <div style="background: #fff3cd; padding: 15px; border-radius: 8px; border: 1px solid #ffeeba; margin: 20px 0;">
            <p style="margin: 0; font-size: 16px;">
              <strong>Kullanım:</strong> ${current} / ${limit} (${percent}%)
            </p>
          </div>

          <p>İşlerinizin aksamaması için planınızı yükseltmenizi öneririz.</p>
          <a href="https://puantajx.app/settings" style="display: inline-block; background: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Planı Yükselt</a>
        </div>
      `;
    } else {
        throw new Error("Unknown notification type");
    }

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "PuantajX <onboarding@resend.dev>", // Or verified domain
        to: [email],
        subject: subject,
        html: html,
      }),
    });

    const dataRes = await res.json();
    return new Response(JSON.stringify(dataRes), {
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
