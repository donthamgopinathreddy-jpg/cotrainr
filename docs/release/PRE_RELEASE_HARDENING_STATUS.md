# Cotrainr Android Pre-Release Hardening Status

Canonical audit branch: `security/pre-release-hardening`

## Rules
- Live Supabase is production truth.
- Never replay old historical migrations into production.
- Every production DB fix is recorded as a new forward migration.
- P0/P1 closes only after inspection, fix, verification, and GitHub recording where applicable.
- Product behaviour must not be changed unless required for correctness, privacy, security, or Play compliance.

## Status legend
- OPEN
- FIXED LIVE
- RECORDED IN GITHUB
- VERIFIED
- CLOSED

## Ground-level release audit

| ID | Severity | Area | Status | Notes |
|---|---|---|---|---|
| P0-01 | P0 | Privileged admin/verification RPC execution | CLOSED | anon/authenticated EXECUTE removed; service_role retained; live verified; forward migration recorded. |
| P0-02 | P0 | Partner operational tables exposed without RLS | CLOSED | RLS enabled; anon/authenticated DML revoked; service_role retained; live verified; forward migration recorded. |
| REL-01 | P0 | Android release used debug signing | RECORDED IN GITHUB | Debug signing fallback removed. Release signing now uses uncommitted `android/key.properties`; real upload keystore still must be generated/configured on the release machine before AAB. |
| REL-02 | P0 | Google Play target API | RECORDED IN GITHUB | Android compile/target SDK set to API 36 for current Play submission requirements. Build verification still required locally. |
| REL-03 | P1 | Signing secret hygiene | CLOSED | `.gitignore` protects key.properties/JKS/keystore files; safe template added. |
| REL-04 | P1 | Generic Flutter package metadata | CLOSED | Cotrainr package description recorded; version remains `1.0.0+1` until final release build sequencing. |
| HEALTH-01 | P0 | Android 13 fallback/product health-source correctness | OPEN | Current service is Health Connect/HealthKit only and has no Android sensor fallback. Audit later in Health phase. |
| HEALTH-02 | P1 | Health Connect least-privilege permissions | CLOSED | Current health service requests READ only; manifest write permissions removed and read permissions retained. |
| ROUTE-01 | P1 | Legacy Zoom deep-link/router residue | RECORDED IN GITHUB | Android external Zoom callback intent removed. Router compatibility redirect/source residue remains for later code cleanup after confirming no caller depends on it. |
| DATA-01 | P0 | Fake Insights fallback series | OPEN | Router contains hard-coded sample metric arrays. Must never display invented health values in production. |
| AUTH-01 | P0 | Signup/onboarding role authority and provider verification integrity | VERIFIED | Live signup metadata can create trainer/nutritionist rows, but discovery requires verified=true. Critical write bypasses were closed live: profile updates are owner-only; provider insert/update is owner-only; authenticated provider writes are limited to professional fields and cannot write verified/rating/review-count/identity fields. Forward migration recorded. Remaining downstream role-specific RPC checks continue under RPC audit. |
| RPC-01 | P1 | Remaining anonymous SECURITY DEFINER functions | OPEN | Classify by body and caller before changing ACLs. |
| RPC-02 | P1 | `get_notification_push` arbitrary user preference read | CLOSED | Live RPC now service_role-only; anon/authenticated EXECUTE removed; verified and forward migration recorded. |
| VIEW-01 | P0/P1 | `provider_reviews` SECURITY DEFINER view | CLOSED | View now `security_invoker=true`; anon SELECT removed; authenticated/service_role SELECT retained; live verified and migration recorded. |
| DB-01 | P1 | Mutable function search_path warnings | OPEN | Prioritize SECURITY DEFINER/privileged functions. |
| AUTH-02 | P1 | Leaked-password protection | OPEN | Enable in Supabase Auth if supported and verify. |

## Current release constants
- Android application ID: `com.cotrainr.app`
- Flutter release name: `1.0.0`
- Flutter build number: `1`
- Minimum Android SDK: 26
- Target Android SDK: 36
- Production track target: Android first

## Release-only local secret files
The following must never be committed:
- `android/key.properties`
- upload keystore (`*.jks` / `*.keystore`)
- local `.env*` except `.env.example`

## Final closure gates
Before Play production submission:
1. Zero unresolved P0/P1 security or correctness issues.
2. Real upload keystore configured and backed up securely.
3. Signed release AAB builds and installs through Play internal testing.
4. Fresh Member, Trainer, and Nutritionist E2E passes.
5. Privacy Policy, Terms, account deletion, Data Safety, Health Apps declaration, and permission disclosures match audited runtime behaviour.
6. Notification, messaging, video, health, partner, events, and restricted-account flows pass real-device tests.
