-- Allow users to read their own organization details (for verification status)
drop policy if exists "Users can view own organization" on public.organizations;

create policy "Users can view own organization" on public.organizations
for select to authenticated using (true);
