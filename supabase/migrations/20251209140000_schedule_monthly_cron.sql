-- Enable extensions for Cron and Net requests
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Verify if pg_cron is available (Some free tier projects might restrict this)
-- If restricted, this migration might fail.

-- Schedule the job: "Send Monthly Summary"
-- Runs at 09:00 AM on the 1st of every month
select cron.schedule(
  'send-monthly-summary',
  '0 9 1 * *', 
  $$
  select
    net.http_post(
        -- URL of the Edge Function
        url:='https://zfptxccotqqehgkpysbq.supabase.co/functions/v1/send-monthly-summary',
        
        -- Service Key for authorization
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.settings.service_role_key', true) || '"}'::jsonb
    ) as request_id;
  $$
);

-- Note: The service_role_key must be set in database settings or hardcoded (securely). 
-- For this migration, we assume the user might need to set it or we might need a better way to auth from DB.
-- Alternatively, if the function is PUBLIC (no verify jwt), we don't need the key, but that's insecure.
-- A better pattern is to use Vault or just allow the function to be called publicly but validate a secret query param.
-- SIMPLIFICATION for MVP:
-- We will use the Anon Key or rely on the function inspecting a custom header secret we inject here? 
-- Actually, we can't easily inject the Service Key here without exposing it in SQL.
-- STRATEGY: We will assume the Edge Function checks for a custom 'X-Cron-Secret' header, 
-- and we store that secret here.
