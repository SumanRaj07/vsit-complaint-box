-- ============================================================================
-- VSIT Complaint Box — seed data (0002_seed.sql)
-- Run AFTER 0001_init.sql, in the same Supabase SQL Editor.
-- Departments + FAQs + app defaults. Demo accounts are created in
-- Supabase Auth (Dashboard -> Authentication -> Users) — see supabase/README.md
-- for the exact demo accounts, then run the "demo profiles" block below with
-- the real user UUIDs copied from the Auth dashboard.
-- ============================================================================

-- ---------------------------------------------------------------- departments
insert into public.departments (name, description) values
  ('Information Technology', 'BSc IT programmes, IT labs and IT faculty matters'),
  ('Computer Science', 'BSc Computer Science programmes and CS labs'),
  ('Administration', 'General administration, admissions and student services'),
  ('Examination Cell', 'Examinations, results, hall tickets and revaluation'),
  ('Library', 'Central library, reading room and book bank'),
  ('Accounts', 'Fees, receipts, scholarships and refunds'),
  ('Infrastructure and Maintenance', 'Classrooms, washrooms, electricity, water and repairs'),
  ('Student Welfare', 'Student support, counselling, anti-ragging and grievances')
on conflict (name) do nothing;

-- ---------------------------------------------------------------- FAQs
insert into public.faqs (question, answer, sort_order) values
  ('How do I track my complaint?',
   'Open My Complaints and tap your complaint to see its full timeline. Anonymous complaints can be tracked from the Track Complaint screen using the tracking ID (for example VSIT-2026-0001) and the 6-digit PIN you chose while submitting.',
   1),
  ('Is my identity safe if I submit anonymously?',
   'Yes. Anonymous complaints hide your name, email and roll number from department officers. Only the Super Admin can see that a complaint is anonymous, never who submitted it. Do not put your name inside the complaint text or inside attached files if you want to stay anonymous.',
   2),
  ('How long does a complaint take to resolve?',
   'Target times are: Critical — 24 hours, High — 3 days, Medium — 5 days, Low — 10 days. If a complaint crosses its target time it is automatically escalated to the HOD.',
   3),
  ('Can I reopen a resolved complaint?',
   'Yes, within 7 days of resolution, if the issue is not actually resolved. Open the complaint and tap Reopen, then explain what is still pending.',
   4),
  ('What can I attach as evidence?',
   'Photos (JPG/PNG), PDF documents and short videos (MP4), up to 25 MB per file. Make sure photos do not show other students'' personal details unless needed.',
   5),
  ('Is this an emergency service?',
   'No. The Complaint Box is for college grievances. For fire, medical or safety emergencies, contact college security and the local emergency services immediately.',
   6)
on conflict do nothing;

-- ---------------------------------------------------------------- demo profiles (OPTIONAL)
-- 1. Create the demo users in Supabase Auth first (see supabase/README.md).
-- 2. Copy each user's UUID from Authentication -> Users.
-- 3. Replace the placeholder UUIDs below and run this block.
--
-- insert into public.profiles (id, full_name, college_id, email, role, department_id, class_year, account_status)
-- values
--   ('<STUDENT_UUID>', 'Aarav Sharma', 'VSIT2026001', 'student@demo.vsit.edu', 'student',
--    (select id from public.departments where name = 'Information Technology'), 'SYBSc IT', 'active'),
--   ('<STAFF_UUID>', 'Prof. Meera Nair', 'EMP1001', 'staff@demo.vsit.edu', 'staff',
--    (select id from public.departments where name = 'Information Technology'), null, 'active'),
--   ('<OFFICER_UUID>', 'Mr. Rajesh Patil', 'EMP2001', 'officer@demo.vsit.edu', 'dept_officer',
--    (select id from public.departments where name = 'Infrastructure and Maintenance'), null, 'active'),
--   ('<ADMIN_UUID>', 'Dr. S. Kulkarni', 'EMP9001', 'admin@demo.vsit.edu', 'super_admin',
--    (select id from public.departments where name = 'Administration'), null, 'active');

-- ---------------------------------------------------------------- sample complaints (OPTIONAL)
-- Run after the demo profiles block, replacing <STUDENT_UUID> and
-- <OFFICER_UUID> with the same UUIDs. Tracking IDs use the current year.
--
-- insert into public.complaints
--   (tracking_id, user_id, title, description, category, department_id, location, priority, status, is_anonymous, assigned_officer_id)
-- values
--   ('VSIT-2026-0001', '<STUDENT_UUID>', 'Projector not working in Lab 3',
--    'The projector in Computer Lab 3 has not worked for two weeks. Lectures are delayed every day.',
--    'Computer Laboratory',
--    (select id from public.departments where name = 'Information Technology'),
--    'Computer Lab 3, 2nd floor', 'high', 'under_review', false, '<OFFICER_UUID>'),
--   ('VSIT-2026-0002', '<STUDENT_UUID>', 'Wi-Fi disconnects frequently in library',
--    'The library Wi-Fi disconnects every 10–15 minutes, making it impossible to study online.',
--    'Wi-Fi and Internet',
--    (select id from public.departments where name = 'Library'),
--    'Central Library', 'medium', 'submitted', false, null),
--   ('VSIT-2026-0003', null, 'Unhygienic washrooms on 3rd floor',
--    'The washrooms on the 3rd floor are not cleaned regularly and there is no water supply in the afternoon.',
--    'Cleanliness and Hygiene',
--    (select id from public.departments where name = 'Infrastructure and Maintenance'),
--    '3rd floor washrooms', 'high', 'acknowledged', true, '<OFFICER_UUID>');
