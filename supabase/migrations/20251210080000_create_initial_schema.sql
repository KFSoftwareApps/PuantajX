-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Projects Table
create table if not exists public.projects (
    id uuid not null default uuid_generate_v4() primary key,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    name text,
    status text,
    location text,
    project_code text,
    settings jsonb -- for finance multipliers etc
);

-- Workers Table
create table if not exists public.workers (
    id uuid not null default uuid_generate_v4() primary key,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    name text,
    active boolean default true,
    pay_type text,
    daily_rate numeric,
    hourly_rate numeric,
    currency text default 'TRY',
    phone text,
    iban text
);

-- Project Workers (Junction)
create table if not exists public.project_workers (
    id uuid not null default uuid_generate_v4() primary key,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    project_id uuid references public.projects(id) on delete cascade,
    worker_id uuid references public.workers(id) on delete cascade,
    crew_id uuid references public.workers(id) on delete set null,
    is_active boolean default true,
    assigned_at timestamptz default now()
);

-- Daily Reports
create table if not exists public.daily_reports (
    id uuid not null default uuid_generate_v4() primary key,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    project_id uuid references public.projects(id) on delete cascade,
    date timestamptz not null,
    weather text,
    shift text,
    general_note text,
    status text,
    created_by text,
    approved_by text,
    
    -- JSONB Columns for embedded lists
    items jsonb default '[]'::jsonb, 
    attachments jsonb default '[]'::jsonb
);

-- RLS Policies (Included here for convenience in one-shot)
alter table public.projects enable row level security;
alter table public.workers enable row level security;
alter table public.project_workers enable row level security;
alter table public.daily_reports enable row level security;

create policy "Enable all for auth users" on "public"."projects" for all to authenticated using (true) with check (true);
create policy "Enable all for auth users" on "public"."workers" for all to authenticated using (true) with check (true);
create policy "Enable all for auth users" on "public"."project_workers" for all to authenticated using (true) with check (true);
create policy "Enable all for auth users" on "public"."daily_reports" for all to authenticated using (true) with check (true);
