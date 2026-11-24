# VSIT Complaint Box — Student Grievance Redressal System

**Your Voice Matters. Your Campus Improves.**

A complete, fully working grievance redressal system for **Vidyalankar School of Information Technology (VSIT)** — built with Flutter and Dart for Android, Flutter Web, and a responsive desktop admin dashboard.

## Runs 100% locally — no backend, no account, no internet

Everything is stored **on the device** (SharedPreferences + the app's documents folder). There is no server, no Supabase project, no API key and no setup step. Install the APK (or open the web build) and it just works.

> The `supabase/` folder in this project contains optional reference SQL (tables + RLS policies) if the college ever wants a cloud backend. **The app never uses it.**

## What is included

**Roles**
- **Student** — register, submit complaints (including anonymous), upload evidence, track status on a timeline, message officers, give feedback after resolution, reopen within 7 days.
- **Teaching Staff** — register (needs admin approval), submit and track complaints.
- **Department / Admin Officer** — see only their department's complaints, investigate, change status, add internal notes (never shown to students), send public updates, request more information, assign, resolve, reject (reason mandatory).
- **Super Admin / HOD** — everything: all complaints, users, departments, analytics, reports, settings, audit log, escalations.

**Complaints**
- 14 categories (Academic, Faculty, Exams, Administration, Infrastructure, Computer Lab, Library, Canteen, Cleanliness, Wi-Fi, Fees, Harassment/Misconduct, Transport, Other), 4 priorities (Low / Medium / High / Critical), emergency flag.
- Tracking IDs like `VSIT-2026-0001`, generated sequentially per year.
- Evidence: JPG/PNG/PDF/MP4 up to 25 MB per file. On Android the files are copied into the app's own folder so they survive cache clears.
- **Anonymous complaints**: identity hidden from officers; tracked with the tracking ID + a 6-digit PIN (only its SHA-256 hash is stored; the PIN is shown once and cannot be recovered).
- **Duplicate detection**: warns when a similar complaint (same category + department, similar title/description) already exists — never auto-rejects.
- **SLA monitoring**: Critical 24 h, High 72 h, Medium 120 h, Low 240 h. Overdue complaints are flagged on the admin dashboard and can be escalated to the HOD.
- Full status timeline: Submitted → Acknowledged → Under Review → Investigation → Action Taken → Resolved / Closed / Reopened / Rejected (with reason) / Info Required.
- Per-complaint messaging between student and officer; internal notes stay internal.
- Feedback: 1–5 star rating, "was it actually resolved?", comments.
- Notifications centre with unread counts and mark-as-read.
- FAQs and improvement suggestions (not formal complaints).

**Admin**
- Dashboard: totals, new/pending/investigation/resolved/critical, average resolution time, resolution %, SLA-breach alerts, recent complaints.
- Complaint management table (desktop) / cards (mobile) with filters: status, category, priority, department, date range, anonymous/verified + search by ID/title.
- Department management (add / deactivate), user management (approve staff, activate / deactivate accounts).
- Analytics: by category, by department, monthly trend (6 months), priority distribution, department resolution rates.
- Reports: date/status filters + **CSV and PDF export**.
- Settings: SLA targets per priority, reopen window, improvement suggestions, audit log.

## Demo accounts (password: `Demo@1234` for all)

| Role | Email |
|---|---|
| Student | student@demo.vsit.edu |
| Teaching Staff | staff@demo.vsit.edu |
| Department Officer | officer@demo.vsit.edu |
| Super Admin / HOD | admin@demo.vsit.edu |

Sample data is seeded on first run: 8 departments, 4 sample complaints (including one anonymous — track it with ID `VSIT-<year>-0003` and PIN `123456`), FAQs, notifications.

Passwords are stored as salted SHA-256 hashes on the device — never plain text.

> **Build note (Nov 2026):** Kotlin is pinned to **2.2.20** in
> `android/settings.gradle.kts` (the Flutter default 2.4.0 could not be
> downloaded — the network hangs on its artifacts). 2.2.20 is fully cached
> and builds cleanly; no app code is affected. If you build on a machine
> with normal internet, you can raise it back to 2.4.0. The APK here was
> built with Gradle in offline mode for the same reason.

## Run it

### Android (APK already built — see `VSIT-Complaint-Box.apk`)
1. Copy the APK to your phone and install it (allow "Install unknown apps" if asked).
2. Open the app and log in with a demo account above, or register a new student account.

### From source (Android Studio / VS Code)
```bash
flutter pub get
flutter run            # Android device / emulator
flutter run -d chrome  # web
```

### Web build
The production web build is in `build/web/` — serve it with any static host:
```bash
cd build/web
python -m http.server 8000
# open http://localhost:8000
```

## Project structure

```
lib/
  main.dart                 App entry (local repository, Riverpod, GoRouter)
  core/
    config.dart             App constants, SLA targets, limits
    models.dart             All data models (fromJson/toJson)
    theme.dart              Navy/white Material 3 theme
    utils.dart              Tracking IDs, PIN hashing, duplicate detection,
                            SLA math, status machine
    router.dart             GoRouter + role-based redirects
    providers.dart          Riverpod providers (repository, session)
  data/
    repository.dart         Data-layer interface (screens only use this)
    local_repository.dart   The only backend: on-device storage + seed data
    file_store.dart         Evidence-file persistence (io / web variants)
  features/
    auth/                   Login, register (student/staff), forgot password
    student/                Dashboard, submit, my complaints, detail,
                            anonymous tracking, notifications, profile
    admin/                  Dashboard, complaints table, complaint detail,
                            departments, users, analytics, reports, settings
    common/                 Shared widgets, FAQ, suggestions
supabase/                   OPTIONAL reference SQL only (not used by the app)
docs/TESTING.md             What was tested and how
test/                       25 tests (utils, repository flow, widget smoke)
```

## Testing

```bash
flutter analyze   # 0 issues
flutter test      # 25 tests pass
```

See `docs/TESTING.md` for the full checklist (registration, staff approval, anonymous tracking, status machine, rejection rules, feedback, notifications, exports, responsiveness).

## Honest limits (local version)

- **Data lives on one device only.** No cross-device sync and no cloud backup. Export CSV/PDF reports regularly from the admin Reports screen.
- **No email.** Password reset links cannot be sent; the Super Admin resets passwords from User Management (activate/deactivate).
- **Attachments on web:** the web build cannot attach files (browser file picks have no persistent path). Evidence upload works in the Android app.
- **No push notifications.** In-app notifications only.
- If the app is uninstalled, all local data is deleted with it.
