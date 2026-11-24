# VSIT Complaint Box — Testing Notes

## Automated tests (25 tests, all passing)

Run with `flutter test`. Run `flutter analyze` for lint (0 issues).

| File | What it covers |
|---|---|
| `test/utils_test.dart` (13 tests) | Tracking-ID generation (first, increment, year rollover), PIN generation/hash/verify, duplicate detection (match / wrong category / unrelated), SLA breach math, status-machine transitions, reopen window (within 7 days / after 7 days). |
| `test/local_repository_test.dart` (10 tests) | Demo seed (8 departments, demo accounts), wrong-password rejection, student registration + login, staff registration pending until approved, **full complaint lifecycle** (submit → acknowledge → under review → action taken → resolved, illegal jump rejected, timeline, feedback, reopen), anonymous submit + tracking with correct PIN and wrong PIN, rejection requires a reason, stats + duplicate detection, notifications mark-all-read. |
| `test/widget_test.dart` (2 tests) | App starts on the login screen; logging in as the demo student opens the student dashboard with the Submit button. |

## Manual checklist (verified by hand during development)

- [x] Student registration (all fields validated) and login
- [x] Staff registration shows "awaiting admin approval"; login blocked until approved
- [x] Wrong password / unknown email show clear errors
- [x] Complaint submission: validation, category/department/priority pickers, anonymous toggle + PIN shown once, emergency flag forces Critical
- [x] Duplicate warning appears for a similar complaint; submission still allowed
- [x] Success screen shows the tracking ID (`VSIT-YYYY-NNNN`)
- [x] My Complaints: filters (status, category) + search by ID/title
- [x] Complaint detail: timeline, attachments, messages, feedback stars, reopen within 7 days
- [x] Anonymous tracking: correct ID+PIN shows status; wrong PIN shows nothing
- [x] Notifications: unread badge, mark-all-read
- [x] Admin dashboard numbers, SLA-breach alert card
- [x] Admin complaints table: all filters + date range + search (desktop table, mobile cards)
- [x] Admin complaint detail: status change (illegal transitions blocked), priority change, department/officer assignment, internal note (hidden from students), public update, reject with mandatory reason, escalate, messaging
- [x] Departments: add + deactivate
- [x] Users: search, approve pending staff, deactivate/activate
- [x] Analytics charts render (category, department, monthly, priority, resolution rate)
- [x] Reports: CSV and PDF export files are created with the selected filters
- [x] Settings: SLA hours editable, suggestions list, audit log
- [x] Role redirects: admin users land on `/admin`, students on `/home`; logged-out users land on `/login`
- [x] Responsive: admin sidebar on desktop (width >= 900), bottom nav on mobile

## Not tested in this environment

- Real-device Android run (APK built here; install and smoke-test on a phone).
- Web file attachments (not supported on web by design — see README).
- Supabase SQL in `supabase/` is reference only and was not executed against a live project.
