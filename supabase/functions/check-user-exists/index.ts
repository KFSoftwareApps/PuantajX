import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { email } = await req.json()

    if (!email) {
      throw new Error('Email is required')
    }

    // Use Admin API to list users. 
    // Ideally we'd use direct DB access or exact filter, but listUsers is the standard API way.
    // Note: listUsers() without query params lists all users.
    // However, recent Supabase versions allow filtering? No, documentation says no.
    // BUT! We can use `rpc` if we had a function.
    // Since we don't want to force migrations, let's try a clever trick:
    // Create a dummy user. If it fails with "User already registered", we know they exist.
    // BUT checking PROVIDER is the goal.
    
    // Attempt 2: Use `admin.listUsers()` logic might be slow if many users.
    // Let's use the PostgreSQL connection via usage of `supabase.rpc`? No function.
    // Let's try `admin.getUserById`? No ID.
    
    // FALLBACK: Since we are in an Edge Function, we are trusted.
    // We can't easily use 'deno-postgres' without connection string which might not be exposed as env var by default in all setups (SUPABASE_DB_URL).
    
    // LET'S TRY `supabaseClient` with a SPECIAL query?
    // Actually, `supabase-js` v2 `auth.admin.listUsers` does not support email filter.
    // BUT! The Supabase Management API does (v1/projects/{ref}/users). That requires different token.
    
    // OK, the cleanest way that works for sure without external deps is iterating if user count is small, OR
    // using `delete-account` pattern if we had the ID.
    
    // WAIT! I recall `supabase.auth.admin.createUser({ email, password, email_confirm: false })`. 
    // If it returns error "User already registered", we know existence.
    // But we don't know if it's Google or Email.
    
    // RE-EVALUATION: The user provided screenshot shows "E-Posta Doğrulama" dialog. 
    // This dialog appears because the CLIENT throws an error/message.
    // If I can intercept the client flow...
    
    // Let's go with the DATABASE FUNCTION (RPC) approach.
    // It's the only performant and correct way.
    // I will write the SQL file and ask the user to run it via Dashboard or CLI.
    // AND I will update the Edge Function to CALL it.
    // ACTUALLY, if I have the function, I don't need Edge Function.
    
    // LET'S WRITE THE EDGE FUNCTION TO CONNECT TO POSTGRES DIRECTLY IF POSSIBLE.
    // Deno connection string is usually not available.
    
    // OK, `supabase-js` `admin` actually DOES have `listUsers` which returns `users`.
    // We can fetch page 1 (50 users). If user is not there... hard luck?
    // This is bad.
    
    throw new Error("Strategy Correction: Please execute the provided SQL in Supabase Dashboard SQL Editor.");

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
