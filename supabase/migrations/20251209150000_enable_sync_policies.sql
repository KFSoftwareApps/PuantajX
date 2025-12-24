-- Enable RLS and add policies for all tables

-- Projects
alter table "public"."projects" enable row level security;

create policy "Users can view own projects" on "public"."projects"
for select to authenticated using (true);

create policy "Users can insert own projects" on "public"."projects"
for insert to authenticated with check (true);

create policy "Users can update own projects" on "public"."projects"
for update to authenticated using (true);

-- Workers
alter table "public"."workers" enable row level security;

create policy "Users can view own workers" on "public"."workers"
for select to authenticated using (true);

create policy "Users can insert own workers" on "public"."workers"
for insert to authenticated with check (true);

create policy "Users can update own workers" on "public"."workers"
for update to authenticated using (true);

-- Project Workers
alter table "public"."project_workers" enable row level security;

create policy "Users can view own project_workers" on "public"."project_workers"
for select to authenticated using (true);

create policy "Users can insert own project_workers" on "public"."project_workers"
for insert to authenticated with check (true);

create policy "Users can update own project_workers" on "public"."project_workers"
for update to authenticated using (true);

-- Daily Reports
alter table "public"."daily_reports" enable row level security;

create policy "Users can view own daily_reports" on "public"."daily_reports"
for select to authenticated using (true);

create policy "Users can insert own daily_reports" on "public"."daily_reports"
for insert to authenticated with check (true);

create policy "Users can update own daily_reports" on "public"."daily_reports"
for update to authenticated using (true);
