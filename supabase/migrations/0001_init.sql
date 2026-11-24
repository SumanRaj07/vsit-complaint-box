-- ============================================================================
-- VSIT Complaint Box — Supabase migration 0001
-- Student Grievance Redressal System, Vidyalankar School of Information Technology
-- Run this file ONCE in the Supabase SQL Editor (Dashboard -> SQL Editor ->
-- New query -> paste the whole file -> Run). It is idempotent for enums/tables
-- only on a fresh project; on an existing project, check for name clashes.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- enums
do $$ begin
  create type user_role as enum ('student', 'staff', 'dept_officer', 'super_admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type account_status as enum ('active', 'pending_approval', 'deactivated');
exception when duplicate_object then null; end $$;

do $$ begin
  create type complaint_status as enum (
    'submitted', 'acknowledged', 'under_review', 'investigation',
    'info_required', 'action_taken', 'resolved', 'reopened', 'closed', 'rejected'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type complaint_priority as enum ('low', 'medium', 'high', 'critical');
exception when duplicate_object then null; end $$;

do $$ begin
  create type update_visibility as enum ('public', 'internal');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------- helpers
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- Sequential tracking id: VSIT-2026-0001 (resets every calendar year)
create or replace function public.next_tracking_id()
returns text language plpgsql as $$
declare
  y int := extract(year from now());
  n int;
begin
  select coalesce(max(
    nullif(substring(tracking_id from '[0-9]+$'), '')::int), 0) + 1
    into n
    from public.complaints
   where tracking_id like 'VSIT-' || y || '-%';
  return format('VSIT-%s-%s', y, lpad(n::text, 4, '0'));
end $$;

-- ---------------------------------------------------------------- departments
create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text default '',
  head_officer_id uuid,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- profiles (1:1 with auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  college_id text not null unique,
  email text not null unique,
  role user_role not null default 'student',
  department_id uuid references public.departments (id),
  class_year text,
  designation text,
  account_status account_status not null default 'active',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- complaints
create table if not exists public.complaints (
  id uuid primary key default gen_random_uuid(),
  tracking_id text not null unique,
  user_id uuid references public.profiles (id) on delete set null,
  title text not null,
  description text not null,
  category text not null check (category in (
    'Academic Issues','Faculty-Related Issues','Examination and Results',
    'College Administration','Infrastructure','Computer Laboratory','Library',
    'Canteen','Cleanliness and Hygiene','Wi-Fi and Internet','Fees and Accounts',
    'Harassment or Misconduct','Transportation','Other')),
  department_id uuid references public.departments (id),
  location text default '',
  priority complaint_priority not null default 'medium',
  status complaint_status not null default 'submitted',
  is_anonymous boolean not null default false,
  -- SHA-256 hex of the 6-digit tracking PIN (anonymous complaints only)
  tracking_pin_hash text,
  assigned_officer_id uuid references public.profiles (id) on delete set null,
  is_emergency boolean not null default false,
  rejection_reason text,
  resolved_at timestamptz,
  escalated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists complaints_user_idx on public.complaints (user_id);
create index if not exists complaints_dept_idx on public.complaints (department_id);
create index if not exists complaints_status_idx on public.complaints (status);
create index if not exists complaints_created_idx on public.complaints (created_at desc);
drop trigger if exists complaints_updated_at on public.complaints;
create trigger complaints_updated_at
  before update on public.complaints
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------- attachments
create table if not exists public.complaint_attachments (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references public.complaints (id) on delete cascade,
  file_name text not null,
  file_path text not null,
  file_type text not null,
  file_size_bytes bigint not null default 0,
  uploaded_at timestamptz not null default now()
);
create index if not exists attachments_complaint_idx
  on public.complaint_attachments (complaint_id);

-- ---------------------------------------------------------------- status updates (timeline)
create table if not exists public.complaint_updates (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references public.complaints (id) on delete cascade,
  updated_by uuid references public.profiles (id) on delete set null,
  old_status complaint_status,
  new_status complaint_status not null,
  update_message text not null default '',
  visibility update_visibility not null default 'public',
  created_at timestamptz not null default now()
);
create index if not exists updates_complaint_idx
  on public.complaint_updates (complaint_id, created_at);

-- ---------------------------------------------------------------- messages (complaint chat)
create table if not exists public.complaint_messages (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references public.complaints (id) on delete cascade,
  sender_id uuid references public.profiles (id) on delete set null,
  sender_role user_role not null default 'student',
  message text not null,
  created_at timestamptz not null default now()
);
create index if not exists messages_complaint_idx
  on public.complaint_messages (complaint_id, created_at);

-- ---------------------------------------------------------------- notifications
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  complaint_id uuid references public.complaints (id) on delete set null,
  title text not null,
  message text not null default '',
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

-- ---------------------------------------------------------------- feedback
create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references public.complaints (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  rating int not null check (rating between 1 and 5),
  actually_resolved boolean not null default true,
  comments text default '',
  created_at timestamptz not null default now(),
  unique (complaint_id, user_id)
);

-- ---------------------------------------------------------------- audit logs
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.profiles (id) on delete set null,
  action text not null,
  complaint_id uuid references public.complaints (id) on delete set null,
  details text default '',
  created_at timestamptz not null default now()
);
create index if not exists audit_created_idx on public.audit_logs (created_at desc);

-- ---------------------------------------------------------------- app settings (SLA hours per priority, reopen window)
create table if not exists public.app_settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);
insert into public.app_settings (key, value) values
  ('sla_hours_critical', '24'),
  ('sla_hours_high', '72'),
  ('sla_hours_medium', '120'),
  ('sla_hours_low', '240'),
  ('reopen_window_days', '7'),
  ('max_attachment_mb', '25')
on conflict (key) do nothing;

-- ---------------------------------------------------------------- FAQs
create table if not exists public.faqs (
  id uuid primary key default gen_random_uuid(),
  question text not null,
  answer text not null,
  sort_order int not null default 0
);

-- ---------------------------------------------------------------- improvement suggestions (not formal complaints)
create table if not exists public.suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete set null,
  title text not null,
  description text not null,
  is_anonymous boolean not null default false,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- anonymous tracking (security definer)
-- Verifies tracking id + PIN without exposing who submitted the complaint.
-- Returns only the public timeline fields; never returns user_id or identity.
create or replace function public.track_anonymous(p_tracking_id text, p_pin_hash text)
returns table (
  tracking_id text, title text, category text, priority text,
  status text, created_at timestamptz, updated_at timestamptz,
  resolved_at timestamptz
)
language sql security definer stable as $$
  select c.tracking_id, c.title, c.category, c.priority::text,
         c.status::text, c.created_at, c.updated_at, c.resolved_at
    from public.complaints c
   where c.tracking_id = p_tracking_id
     and c.is_anonymous = true
     and c.tracking_pin_hash = p_pin_hash;
$$;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
alter table public.profiles enable row level security;
alter table public.departments enable row level security;
alter table public.complaints enable row level security;
alter table public.complaint_attachments enable row level security;
alter table public.complaint_updates enable row level security;
alter table public.complaint_messages enable row level security;
alter table public.notifications enable row level security;
alter table public.feedback enable row level security;
alter table public.audit_logs enable row level security;
alter table public.app_settings enable row level security;
alter table public.faqs enable row level security;
alter table public.suggestions enable row level security;

-- helper: current user's role / department
create or replace function public.my_role() returns user_role
language sql stable as $$
  select role from public.profiles where id = auth.uid();
$$;
create or replace function public.my_department() returns uuid
language sql stable as $$
  select department_id from public.profiles where id = auth.uid();
$$;
create or replace function public.is_super_admin() returns boolean
language sql stable as $$
  select exists (select 1 from public.profiles
                  where id = auth.uid() and role = 'super_admin');
$$;

-- profiles: anyone can read their own; super admin reads all; insert own row on signup
drop policy if exists profiles_self on public.profiles;
create policy profiles_self on public.profiles
  for all using (id = auth.uid() or public.is_super_admin())
  with check (id = auth.uid() or public.is_super_admin());

-- departments: readable by all logged-in users; writable by super admin
drop policy if exists departments_read on public.departments;
create policy departments_read on public.departments
  for select using (auth.uid() is not null);
drop policy if exists departments_write on public.departments;
create policy departments_write on public.departments
  for all using (public.is_super_admin())
  with check (public.is_super_admin());

-- complaints:
--  * students/staff: own complaints only (anonymous rows hide identity in the app,
--    not in the table — the app never shows user_id for anonymous complaints)
--  * dept officers: complaints of their department
--  * super admin: everything
drop policy if exists complaints_select on public.complaints;
create policy complaints_select on public.complaints
  for select using (
    user_id = auth.uid()
    or public.is_super_admin()
    or (public.my_role() = 'dept_officer' and department_id = public.my_department())
  );
drop policy if exists complaints_insert on public.complaints;
create policy complaints_insert on public.complaints
  for insert with check (auth.uid() is not null);
drop policy if exists complaints_update on public.complaints;
create policy complaints_update on public.complaints
  for update using (
    public.is_super_admin()
    or (public.my_role() = 'dept_officer' and department_id = public.my_department())
    or (user_id = auth.uid() and status in ('submitted','info_required'))
  );

-- attachments / updates / messages: visible to whoever can see the complaint
drop policy if exists attachments_all on public.complaint_attachments;
create policy attachments_all on public.complaint_attachments
  for all using (exists (select 1 from public.complaints c
                         where c.id = complaint_id
                           and (c.user_id = auth.uid()
                                or public.is_super_admin()
                                or (public.my_role() = 'dept_officer'
                                    and c.department_id = public.my_department()))))
  with check (auth.uid() is not null);

drop policy if exists updates_read on public.complaint_updates;
create policy updates_read on public.complaint_updates
  for select using (
    visibility = 'public'
    and exists (select 1 from public.complaints c
                 where c.id = complaint_id
                   and (c.user_id = auth.uid()
                        or public.is_super_admin()
                        or (public.my_role() = 'dept_officer'
                            and c.department_id = public.my_department())))
    or (visibility = 'internal'
        and (public.is_super_admin()
             or (public.my_role() = 'dept_officer'
                 and exists (select 1 from public.complaints c
                              where c.id = complaint_id
                                and c.department_id = public.my_department()))))
  );
drop policy if exists updates_insert on public.complaint_updates;
create policy updates_insert on public.complaint_updates
  for insert with check (auth.uid() is not null);

drop policy if exists messages_all on public.complaint_messages;
create policy messages_all on public.complaint_messages
  for all using (exists (select 1 from public.complaints c
                         where c.id = complaint_id
                           and (c.user_id = auth.uid()
                                or public.is_super_admin()
                                or (public.my_role() = 'dept_officer'
                                    and c.department_id = public.my_department()))))
  with check (auth.uid() is not null);

-- notifications: own only
drop policy if exists notifications_self on public.notifications;
create policy notifications_self on public.notifications
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- feedback: own complaints only; super admin reads all
drop policy if exists feedback_all on public.feedback;
create policy feedback_all on public.feedback
  for all using (user_id = auth.uid() or public.is_super_admin())
  with check (user_id = auth.uid());

-- audit logs: super admin only
drop policy if exists audit_admin on public.audit_logs;
create policy audit_admin on public.audit_logs
  for all using (public.is_super_admin())
  with check (public.is_super_admin());

-- settings: read all, write super admin
drop policy if exists settings_read on public.app_settings;
create policy settings_read on public.app_settings
  for select using (auth.uid() is not null);
drop policy if exists settings_write on public.app_settings;
create policy settings_write on public.app_settings
  for all using (public.is_super_admin())
  with check (public.is_super_admin());

-- faqs: read all, write super admin
drop policy if exists faqs_read on public.faqs;
create policy faqs_read on public.faqs
  for select using (true);
drop policy if exists faqs_write on public.faqs;
create policy faqs_write on public.faqs
  for all using (public.is_super_admin())
  with check (public.is_super_admin());

-- suggestions: own + super admin
drop policy if exists suggestions_all on public.suggestions;
create policy suggestions_all on public.suggestions
  for all using (user_id = auth.uid() or public.is_super_admin())
  with check (user_id = auth.uid() or public.is_super_admin());

-- ---------------------------------------------------------------- storage bucket for evidence
insert into storage.buckets (id, name, public)
values ('complaint-evidence', 'complaint-evidence', false)
on conflict (id) do nothing;

drop policy if exists evidence_read on storage.objects;
create policy evidence_read on storage.objects
  for select using (
    bucket_id = 'complaint-evidence' and auth.uid() is not null);
drop policy if exists evidence_write on storage.objects;
create policy evidence_write on storage.objects
  for insert with check (
    bucket_id = 'complaint-evidence' and auth.uid() is not null);
drop policy if exists evidence_delete on storage.objects;
create policy evidence_delete on storage.objects
  for delete using (
    bucket_id = 'complaint-evidence' and public.is_super_admin());
