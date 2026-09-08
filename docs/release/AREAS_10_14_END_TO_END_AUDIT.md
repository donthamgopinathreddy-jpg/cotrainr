# Areas 10–14 End-to-End Release Audit

Date: 2026-09-09
Branch: `security/pre-release-hardening`
Production Supabase: `nvtozwtuyhwqkqvftpyi`
Scope: Flutter UI -> state/repository -> Edge Functions/RPC -> RLS/grants -> DB/storage/jobs -> release/device verification.

## 10 — Video Sessions / Google Meet

### PASS / verified
- Live `create-video-session` is JWT-protected and server-resolves the authenticated host.
- Host must be trainer/nutritionist and `providers.verified=true`.
- Participant IDs are deduped, must be clients, and each must have an accepted relationship with the host.
- Google Meet creation is server-side; integration tokens are service-owned.
- OAuth start/status/disconnect are JWT protected; callback is intentionally public but state/PKCE controlled.
- Session list/detail RPCs scope results to the current host/participant.
- Normalized `video_session_participants` is live; 17 sessions / 39 participant rows at audit time; no duplicate participant pairs, no orphan participants, no sessions missing host participant.
- Reschedule/cancel trigger exists and reminder jobs exist.
- Reminder dispatcher is live and scheduled every minute.
- Direct client INSERT into `video_sessions` is now removed; creation is forced through the vetted Edge Function.
- Direct participant/provider-meta mutation grants are removed.

### FIXED BY ME
Production migrations:
- `20260908233014_pre_release_lock_video_sessions_and_device_tokens`
- `20260908233028_pre_release_force_video_creation_through_vetted_edge`

These remove permissive `is_account_active()` policies that previously OR-ed around host ownership and remove direct session creation.

### CURSOR / LOCAL REQUIRED
1. `lib/pages/video_sessions/video_sessions_page_v2.dart`: load error currently renders red text plus normal empty Upcoming/Past content. Replace with a dedicated error state containing Retry; do not render fake empty sections while `_error != null` and `_sessions` is empty.
2. Disable/guard Schedule Session while the authoritative list is in an unrecovered error state to reduce accidental duplicate scheduling.
3. Physical Android E2E: Google OAuth cold/warm return, create, group participant selection, reschedule, cancel, join, reject reason, rejected participant behavior, expired/revoked Google integration, offline/slow network, app killed/backgrounded.
4. Verify Google OAuth production redirect configuration and Android deep-link ownership on signed release build.

## 11 — Notifications / Reminders

### PASS / verified
- FCM + flutter_local_notifications are wired.
- Background/foreground video reminders support actionable Join/Reject.
- 5-minute and session-start jobs are generated server-side.
- Server-side video notification preference helper is present.
- Settings UI has Video session notifications and Session reminders toggles.
- Live reminder Edge Function requires a cron secret; live push Edge Function requires its internal secret.
- `notifications` RLS scopes SELECT/UPDATE to owner.
- Device-token ownership is now active-account + user scoped.

### FIXED BY ME
- Found duplicate FCM token ownership across accounts (1 duplicate token group). Cleaned duplicates and added a global unique token index plus single-owner claim trigger. Verification after migration: 0 duplicate token groups.
- Added owner-scoped notification DELETE policy so the UI's permanent delete actually reaches DB.
- Found notification settings repository was attempting direct `profiles` UPDATE even though direct profile UPDATE is intentionally revoked. Added `update_my_notification_preferences(...)` SECURITY DEFINER RPC, current-user/active-account scoped, and rewired Flutter repository to it.
- Fixed invalid import in `lib/services/video_session_notification_prefs.dart` (`../../../repositories/...` -> `../repositories/...`).

Production migrations:
- `20260908233145_pre_release_make_device_token_single_owner`
- `20260908233218_pre_release_notification_delete_and_internal_grants`
- `20260908233501_pre_release_notification_preferences_rpc`

Flutter commits include `02b9c611...` and `930e5534...`.

### MAJOR — CURSOR / LOCAL REQUIRED
1. Notification delete still presents an Undo that only restores local UI after permanent DB deletion. Remove Undo, or implement true server soft-delete/restore. Do not ship misleading Undo.
2. Notification-page load failure is swallowed and can look like a legitimate empty list. Add explicit error + Retry state and preserve cached rows when possible.
3. Replace production `print(...)` logging with debug/controlled logging.
4. Physical Android notification matrix: permission denied/granted/settings return, token refresh, account switch, foreground/background/killed, reminder 5m/start, Join, Reject, cold-start action, duplicate delivery, preference OFF, master push OFF.

### SECURITY / DASHBOARD REQUIRED
The active pg_cron command currently embeds the reminder dispatcher secret directly in the cron command text. Rotate the cron secret and store/use it through a secret-management path (Supabase Vault or equivalent) rather than plaintext cron SQL. The Edge Function secret must be rotated to the same new value. Do not commit the secret or migration containing it.

## 12 — Partner Centres / Pass / Offers

### PASS / verified
- Discover uses `list_partner_centers_for_discover()` and only active centres/offers are returned.
- Cotrainr Pass is generated server-side from `auth.uid()`, checks active account, format `CT########`, and is protected by a unique partial index.
- Current Pass UI displays the full pass ID and provides copy behavior.
- Partner application submission uses a server-authoritative SECURITY DEFINER RPC with active-account, required-field, email, and duplicate-open-application validation.
- `partner_member_claims` and `partner_offer_redemptions` are service/admin operational tables and now have Data API grants revoked from anon/authenticated.

### FIXED BY ME
Found permissive partner application INSERT/UPDATE policies using only `is_account_active()`, which OR-ed around owner policies. Removed them and recreated owner + active-account policies.

Production migration:
- `20260908233303_pre_release_lock_partner_application_writes`

### CURSOR / LOCAL REQUIRED
- Partner centre fetch failure in Discover must not render as genuine `No Partner Centres yet`; show degraded/error + Retry.
- Device test full Pass ID/copy on narrow + large-text screens.
- Partner-admin end-to-end verification: member claim lookup, offer redemption, duplicate redemption behavior, invalid/unknown pass, inactive account, audit log.

## 13 — Backend / Database

### PASS / verified
- Production PostgreSQL 17.6; DB timezone UTC.
- All public base tables inspected have primary keys.
- Key video integrity checks: 0 duplicate participant pairs, 0 orphan participants, 0 missing host participant.
- 0 notification rows orphaned from profiles at audit time.
- Cotrainr Pass duplicate IDs: 0.
- Device-token duplicate ownership: fixed to 0.
- Internal/service tables have direct anon/authenticated grants revoked where appropriate.
- Production-forward migrations are mirrored into Git; historical migrations are not replayed.

### FIXED BY ME — indexes
Added covering indexes for active unindexed foreign keys across partner, OAuth, video-session, and entitlement paths:
`20260908233654_pre_release_index_active_foreign_keys`.

### REMAINING
Supabase performance advisor still reports legacy/archive and other public unindexed FKs, many RLS init-plan warnings, duplicate indexes, and unused indexes. Do not blindly delete indexes. Address active MVP hot paths first, then cleanup in Area 17.

## 14 — RLS / Security Hardening

### FIXED / verified in this batch
- Removed cross-user permissive video-session mutation policies.
- Removed direct client video-session creation.
- Removed direct participant/provider-meta write grants.
- Locked device-token ownership and account switching.
- Revoked Data API grants on internal OAuth/video job/partner operational/admin/archive-message tables.
- Locked partner application writes to owner + active account.
- Notification deletion owner scoped.
- Notification preference writes moved to auth-bound RPC.
- Re-ran Supabase security advisor after DDL changes.

### SECURITY ADVISOR — OPEN / CLASSIFIED
- 13 `rls_enabled_no_policy` INFO items remain. Most are intentionally service-only/internal and now additionally have direct grants revoked. Continue caller-by-caller classification; no blanket policy creation.
- `public.spatial_ref_sys` RLS-disabled ERROR and PostGIS-in-public WARN are extension-owned; do not blindly modify during app hardening.
- SECURITY DEFINER advisor flags include both intended user-facing auth-bound RPCs and internal helpers. Each must be classified by caller/arguments; do not blanket revoke app RPCs.
- `is_username_available(text)` anonymous SECURITY DEFINER execution is intentional for pre-auth signup, subject to abuse/rate-limit review.
- Supabase Auth leaked-password protection remains disabled and must be enabled in Auth settings if available for the plan.

### MAJOR OPEN
- Broad legacy table grants/policies remain outside the active MVP path. Area 17 cleanup must prove callers before deletion/revocation.
- RLS performance warnings (`auth.uid()` init-plan) remain numerous. Correct active high-volume policies first; these are primarily performance rather than demonstrated authorization bypasses.
- Physical adversarial E2E still required with two real accounts/roles: attempt cross-user reads/writes for profile, provider, lead, conversation/message, meal, metric, video session, notification, partner application, and storage objects.

## Current batch verdict
Areas 10–14 are materially safer but are NOT 100% release-signed yet. The highest remaining release blockers are physical notification/video E2E, notification error/Undo UX, cron-secret rotation, active SECURITY DEFINER classification, leaked-password protection, and remaining local compile/analyze/test verification.
