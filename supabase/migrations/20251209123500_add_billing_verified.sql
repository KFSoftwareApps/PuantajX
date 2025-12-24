alter table "public"."organizations" add column if not exists "billing_email_verified" boolean default false;
