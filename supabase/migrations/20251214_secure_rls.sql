-- 1. Explicitly Enable RLS on all tables (Safety First)
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

-- 2. Drop legacy/insecure policies
DROP POLICY IF EXISTS "Enable all for auth users" ON public.projects;
DROP POLICY IF EXISTS "Enable all for auth users" ON public.workers;
DROP POLICY IF EXISTS "Enable all for auth users" ON public.project_workers;
DROP POLICY IF EXISTS "Enable all for auth users" ON public.daily_reports;
DROP POLICY IF EXISTS "Enable all for auth users" ON public.organizations;

DROP POLICY IF EXISTS "Org Policy Projects" ON public.projects;
DROP POLICY IF EXISTS "Org Policy Workers" ON public.workers;
DROP POLICY IF EXISTS "Org Policy ProjWorkers" ON public.project_workers;
DROP POLICY IF EXISTS "Org Policy Reports" ON public.daily_reports;

-- Also Drop the NEW policies if they exist (to allow re-run)
DROP POLICY IF EXISTS "Strict Org Policy Projects" ON public.projects;
DROP POLICY IF EXISTS "Strict Org Policy Workers" ON public.workers;
DROP POLICY IF EXISTS "Strict Org Policy ProjWorkers" ON public.project_workers;
DROP POLICY IF EXISTS "Strict Org Policy Reports" ON public.daily_reports;
DROP POLICY IF EXISTS "Strict Org Policy Organizations" ON public.organizations;
DROP POLICY IF EXISTS "Orgs Isolation" ON public.organizations;

-- 3. Define the Match Logic (As a helper function if needed, or inline)
-- Logic: Table.org_id (Slug) MUST MATCH Normalized(User.Metadata.org_name)
-- Normalized = UPPER(REGEXP_REPLACE(org_name, '[^a-zA-Z0-9]', '', 'g'))

-- PROJECTS
-- 1. Organizations Policy (Own Org)
CREATE POLICY "Orgs Isolation" ON public.organizations
FOR ALL TO authenticated
USING (
  code = (auth.jwt()->'user_metadata'->>'org_code')::text 
  OR 
  code = UPPER(REGEXP_REPLACE((auth.jwt()->'user_metadata'->>'org_name')::text, '[^a-zA-Z0-9]', '', 'g'))
);

-- 2. Projects Policy
CREATE POLICY "Strict Org Policy Projects" ON public.projects
FOR ALL TO authenticated
USING (
  org_id = (auth.jwt()->'user_metadata'->>'org_code')::text
  OR
  org_id = UPPER(REGEXP_REPLACE((auth.jwt()->'user_metadata'->>'org_name')::text, '[^a-zA-Z0-9]', '', 'g'))
);

-- 3. Workers Policy
CREATE POLICY "Strict Org Policy Workers" ON public.workers
FOR ALL TO authenticated
USING (
  org_id = (auth.jwt()->'user_metadata'->>'org_code')::text
  OR
  org_id = UPPER(REGEXP_REPLACE((auth.jwt()->'user_metadata'->>'org_name')::text, '[^a-zA-Z0-9]', '', 'g'))
);

-- 4. Project Workers Policy (The one failing in Sync)
CREATE POLICY "Strict Org Policy ProjWorkers" ON public.project_workers
FOR ALL TO authenticated
USING (
  org_id = (auth.jwt()->'user_metadata'->>'org_code')::text
  OR
  org_id = UPPER(REGEXP_REPLACE((auth.jwt()->'user_metadata'->>'org_name')::text, '[^a-zA-Z0-9]', '', 'g'))
);

-- 5. Reports Policy
CREATE POLICY "Strict Org Policy Reports" ON public.daily_reports
FOR ALL TO authenticated
USING (
  org_id = (auth.jwt()->'user_metadata'->>'org_code')::text
  OR
  org_id = UPPER(REGEXP_REPLACE((auth.jwt()->'user_metadata'->>'org_name')::text, '[^a-zA-Z0-9]', '', 'g'))
);

-- ORGANIZATIONS
-- Users can see their own organization
CREATE POLICY "Strict Org Policy Organizations" ON public.organizations
FOR ALL TO authenticated
USING (
  code = UPPER(REGEXP_REPLACE(
      (auth.jwt()->'user_metadata'->>'org_name')::text, 
      '[^a-zA-Z0-9]', '', 'g'
  ))
  OR
  id::text = (auth.jwt()->'user_metadata'->>'org_id')::text -- Fallback if we start using IDs
);
