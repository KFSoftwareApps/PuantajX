-- Add org_id to all tables
alter table public.projects add column if not exists org_id text;
alter table public.workers add column if not exists org_id text;
alter table public.project_workers add column if not exists org_id text;
alter table public.daily_reports add column if not exists org_id text;

-- Update RLS Policies to be stricter
-- Drop existing lax policies
drop policy if exists "Enable all for auth users" on "public"."projects";
drop policy if exists "Enable all for auth users" on "public"."workers";
drop policy if exists "Enable all for auth users" on "public"."project_workers";
drop policy if exists "Enable all for auth users" on "public"."daily_reports";

-- Create new policies based on Org Match
-- Note: This assumes the user's 'org_name' in metadata matches the record's 'org_id'
-- Since we store 'org_name' (code) in metadata during register.

create policy "Org Policy Projects" on "public"."projects"
for all using (
  auth.uid() is not null 
  and 
  (org_id = (select raw_user_meta_data->>'org_name' from auth.users where id = auth.uid()))
);

create policy "Org Policy Workers" on "public"."workers"
for all using (
  auth.uid() is not null 
  and 
  (org_id = (select raw_user_meta_data->>'org_name' from auth.users where id = auth.uid()))
);

create policy "Org Policy ProjWorkers" on "public"."project_workers"
for all using (
  auth.uid() is not null 
  and 
  (org_id = (select raw_user_meta_data->>'org_name' from auth.users where id = auth.uid()))
);

create policy "Org Policy Reports" on "public"."daily_reports"
for all using (
  auth.uid() is not null 
  and 
  (org_id = (select raw_user_meta_data->>'org_name' from auth.users where id = auth.uid()))
);
