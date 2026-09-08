# Cotrainr Full Pre-Release Audit

Audit branch: `security/pre-release-hardening`

Production Supabase project: `nvtozwtuyhwqkqvftpyi`

Audit started: 2026-09-08

## Release rule

This is the master end-to-end release audit. Live Supabase is production truth. Historical migrations are never replayed into production. Every production database change is applied as a new forward migration, verified live, and then recorded in this branch. Release is not READY while a P0/P1 correctness, privacy, security, or release-integrity issue remains open.

## Audit matrix

| Area | Scope | Status |
|---|---|---|
| Product/MVP scope | Reachable Android v1 surfaces, hidden feature flags, role-specific experiences | IN PROGRESS |
| UI/UX | Layout, overflow, hierarchy, empty/error/loading states, touch targets | IN PROGRESS |
| Light/Dark | Theme tokens, contrast, system bars, surfaces, text, modals | FIXED SOURCE / DEVICE VERIFY PENDING |
| Interactions | Tap/pressed/selected/disabled/loading, switches, chips, segmented controls, destructive actions | IN PROGRESS |
| Accessibility | Semantics, text scale, contrast, touch targets, labels | PENDING |
| Navigation | GoRouter guards, auth redirects, deep links, back behavior, unreachable routes | IN PROGRESS |
| Auth/Onboarding | Email/social/reset, role authority, completion, restricted accounts | IN PROGRESS |
| Provider verification | Verification upload, admin boundary, verified-only authority | HARDENED / E2E PENDING |
| Discover/Profile | Public data minimization, filters, location, provider cards | IN PROGRESS |
| Connections/Entitlements | Request/accept/decline/cancel/end/reconnect, Model B allowance | IN PROGRESS |
| Messaging | Conversation authorization, send/read/delete, media/voice, reconnect behavior | IN PROGRESS |
| Meals/Hydration | CRUD, goals, reminders, ownership/RLS, no fabricated data | IN PROGRESS |
| Health | Health Connect source, permissions, sync, failure states, duplication | HARDENED / DEVICE VERIFY PENDING |
| Video Sessions | Meet OAuth, create/list/detail/respond/join/cancel/reminders | IN PROGRESS |
| Notifications | FCM, local notifications, preferences, scheduler/webhook auth | IN PROGRESS |
| Partner Centres/Pass | Discover, offers, pass ID, partner/admin boundaries | IN PROGRESS |
| Community Events | Listing/detail/registration and authorization | IN PROGRESS |
| Supabase RLS/Grants | Exposed tables/views/functions/storage | IN PROGRESS |
| SECURITY DEFINER | anon/authenticated callable RPCs and caller binding/IDOR | IN PROGRESS |
| Edge Functions | JWT/shared-secret/state authorization, error/log hygiene | IN PROGRESS |
| Storage | Buckets, object path ownership, signed URLs, delete/update policies | PENDING |
| Secrets/Logging | privileged keys, OAuth/Firebase/signing secrets, sensitive logs | IN PROGRESS |
| Data integrity | FK/unique/check constraints, races, deterministic queries | IN PROGRESS |
| Performance | indexes, RLS init-plan, duplicate policies/indexes, app rebuild/network churn | TRIAGE PENDING |
| Android config | package, target/min SDK, manifest, exported components, signing | SOURCE HARDENED / BUILD PENDING |
| Privacy/Delete | account deletion, retention, device tokens, integrations, storage | PENDING |
| Play compliance | Data Safety, Health Apps, deletion, permissions, legal URLs | PENDING |
| Dependency/build | pub lock, analyze/tests, release AAB, Play internal test | LOCAL VERIFICATION PENDING |
| Dead/legacy cleanup | obsolete UI/routes/services/assets/Zoom/DB objects | PENDING AFTER RELEASE BLOCKERS |

## Findings and fixes

### RPC-03 — Internal composite relationship helper exposed to authenticated clients — CLOSED

Live function `public.conversation_has_accepted_lead(public.conversations)` is `SECURITY DEFINER` and accepted a caller-supplied composite conversation row without binding the supplied client/provider pair to `auth.uid()`. A signed-in caller could therefore use the function as a relationship-existence probe even though the function is intended as an internal helper.

Dependency inspection found no RLS policy using this overload and no live function dependency on this composite overload. Messaging uses the separate `conversation_has_accepted_lead(uuid, uuid)` overload, which requires `auth.uid()` to equal one of the supplied participants.

Production fix applied and verified:
- live migration: `20260908210455_pre_release_restrict_internal_connection_helper`
- `anon`: EXECUTE false
- `authenticated`: EXECUTE false
- `service_role`: EXECUTE true
- safer two-UUID overload remains authenticated-callable

GitHub forward migration:
`supabase/migrations/20260908210455_pre_release_restrict_internal_connection_helper.sql`

### Edge Function authentication baseline — REVIEWED, CONTINUING

Active Edge Functions were inventoried. The three functions with `verify_jwt=false` have non-user-JWT callers and currently implement alternative fail-closed authorization:
- `google-oauth-callback`: one-time OAuth state + expiry + PKCE owner binding
- `send-push-notification`: mandatory webhook shared secret before privileged work
- `dispatch-video-session-reminders`: mandatory cron shared secret before privileged work

Do not set these to `verify_jwt=true` merely to clear a checklist item; that would break their legitimate browser/webhook/scheduler callers. Continue reviewing payload validation, logs and least privilege.

### Security advisor baseline — REVIEWED, CONTINUING

Current review priorities:
- leaked-password protection remains disabled and must be enabled before release if the project plan supports it
- authenticated-callable `SECURITY DEFINER` functions require caller-binding review; this audit is in progress
- PostGIS-owned extension warnings are not modified blindly
- RLS-enabled/no-policy service tables are assessed by intended access, not mechanically given permissive policies

### Performance advisor baseline — TRIAGE, NOT AUTOMATIC RELEASE BLOCKERS

The advisor reports unindexed foreign keys, RLS init-plan opportunities, unused/duplicate indexes and multiple permissive policies. These are triaged by production impact. We will not destabilize authorization or schema simply to produce a clean advisor screen.

## Already completed before this master pass

- privileged admin/verification RPC execution hardened
- partner operational tables locked down
- notification preference RPC hardened
- provider reviews view converted to security invoker
- mutable function search paths pinned
- provider verification authority enforced at DB and video Edge boundary
- create-video-session live v41 verifies provider before Meet creation
- Health Connect read-only least privilege and source correctness hardened
- fabricated Insights fallback series removed
- Android debug signing fallback removed
- compile/target SDK 36 recorded
- light/dark Material contrast and legacy theme-token bugs fixed
- global switch ON/OFF/disabled states made visually explicit

## Known release blockers / mandatory gates

1. Complete authenticated `SECURITY DEFINER`/IDOR review.
2. Complete storage bucket/object-policy review.
3. Complete repository + production secret/logging review.
4. Verify account deletion and retention end-to-end.
5. Enable leaked-password protection where supported.
6. Finish reachable custom interaction-state UI audit.
7. Verify every MVP feature wiring against its live DB/Edge boundary.
8. Generate the real Android upload keystore locally and keep it off Git.
9. Run `flutter analyze` and tests locally.
10. Build signed AAB and install through Play Internal Testing.
11. Run fresh Member, Trainer and Nutritionist E2E on the Play-installed build.
12. Match Play Data Safety, Health Apps declaration, permission disclosures, legal pages and deletion behavior to the audited runtime.

## Cursor/local reconciliation

Cursor should pull `security/pre-release-hardening` and treat this branch as the implementation record. Production migrations listed here have already been applied to live Supabase; Cursor must not rerun old already-applied migrations against production. The migration files exist so local/dev schema history can reproduce the intended state.

Local-only verification remains responsible for Flutter analyzer/tests, real Android keystore configuration, release AAB construction and device/Play-installed visual/E2E testing.
