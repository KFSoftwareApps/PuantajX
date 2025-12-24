import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { Client } from "https://deno.land/x/postgres@v0.17.0/mod.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email } = await req.json()
    if (!email) throw new Error('Email is required')

    // Connection String from Env
    const dbUrl = Deno.env.get('SUPABASE_DB_URL')
    if (!dbUrl) throw new Error('Missing SUPABASE_DB_URL')

    // Connect to DB directly
    const client = new Client(dbUrl)
    await client.connect()

    try {
      // Query identities table directly
      const result = await client.queryObject`
        SELECT provider 
        FROM auth.identities 
        WHERE identity_data->>'email' = ${email}
      `
      
      const identities = result.rows
      const hasGoogle = identities.some((r: any) => r.provider === 'google')
      
      return new Response(
        JSON.stringify({ 
          exists: identities.length > 0, 
          hasGoogle: hasGoogle,
          providers: identities.map((r: any) => r.provider)
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    } finally {
      await client.end()
    }

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
