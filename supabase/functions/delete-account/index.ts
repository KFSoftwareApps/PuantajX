import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Create Supabase Client with Admin Key (Service Role)
    // We need service role to delete users. 
    // Deno Env should have SUPABASE_SERVICE_ROLE_KEY.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 2. Verified User from Header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Missing Authorization Header');
    }

    // Robust token extraction (handle Bearer case-insensitively)
    const token = authHeader.replace(/^Bearer\s+/i, '');
    
    // Verify using Admin client (Service Role)
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      console.error('User verification failed:', userError);
      throw new Error(`User verification failed: ${userError?.message || 'Unknown error'}`);
    }

    // 4. Cleanup Data (Projects, Workers, etc.)
    // Strategy: Derive Org Code from Metadata -> Find UUID -> Cascade Delete
    let orgUuid = null;
    let orgCode = null; // Defined in outer scope
    
    // Get Org Name from Metadata
    const orgName = user.user_metadata?.org_name;
    
    if (orgName) {
      // Derive Code (Slug) - Match Dart & SQL Logic
      orgCode = orgName.toUpperCase().replace(/[^A-Z0-9]/g, '');
      
      console.log(`Deriving Org Code: ${orgCode} from Name: ${orgName}`);

      const { data: orgData } = await supabaseAdmin
        .from('organizations')
        .select('id')
        .eq('code', orgCode)
        .maybeSingle(); 
      
      if (orgData) {
        orgUuid = orgData.id;
        console.log(`Found Org UUID: ${orgUuid} for code: ${orgCode}`);
      } else {
         console.warn(`No organization found with code: ${orgCode}`);
      }
    } else {
       console.warn('User has no org_name in metadata.');
    }

    if (orgUuid && orgCode) { // Check both
       try {
           console.log(`Starting cascade delete for Org: ${orgCode} (UUID: ${orgUuid})`);
           
           // 1. Delete Child Tables (Foreign Keys use CODE/SLUG, not UUID based on screenshot)
           // The app stores "KALPAKTALHA" in projects.org_id, not the UUID.
           try {
               await supabaseAdmin.from('daily_reports').delete().eq('org_id', orgCode);
           } catch (e) { console.error('Failed to delete reports:', e); }

           try {
               await supabaseAdmin.from('project_workers').delete().eq('org_id', orgCode);
           } catch (e) { console.error('Failed to delete project_workers:', e); }

           try {
               await supabaseAdmin.from('workers').delete().eq('org_id', orgCode);
           } catch (e) { console.error('Failed to delete workers:', e); }
           
           try {
               await supabaseAdmin.from('projects').delete().eq('org_id', orgCode);
           } catch (e) { console.error('Failed to delete projects:', e); }

           try {
               await supabaseAdmin.from('teams').delete().eq('org_id', orgCode);
           } catch (e) { console.error('Failed to delete teams:', e); }
           
           // 2. Delete Organization (Primary Key is UUID)
           console.log(`Deleting organization: ${orgUuid}`);
           const { error: orgError } = await supabaseAdmin
              .from('organizations')
              .delete()
              .eq('id', orgUuid);
           
           if (orgError) {
             console.error('Org delete error:', orgError);
             // If org delete fails, we might still want to proceed to delete user? 
             // Ideally yes, but data remains orphaned. 
             // We log critical error but proceed.
           }
       } catch (err) {
           console.error('Data cleanup error:', err);
       }
    } else {
      console.warn('No Organization found for this user. Skipping data cleanup.');
    }

    // 4. Delete the User
    console.log(`Attempting to delete user: ${user.id}`);
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(
      user.id
    );

    if (deleteError) {
      console.error('Delete User Error:', deleteError);
      throw deleteError;
    }

    // 5. Verification: Check if user still exists
    const { data: { user: checkUser } } = await supabaseAdmin.auth.admin.getUserById(user.id);
    if (checkUser) {
       console.error('CRITICAL: User still exists after deletion!');
       throw new Error('Hesap silinemedi (Sunucu hatası). Lütfen desteğe başvurun.');
    }

    return new Response(JSON.stringify({ message: 'Account deleted successfully' }), {
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
