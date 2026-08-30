# Google Meet Video Sessions — secrets & deploy notes

## Required Supabase secrets

```bash
supabase secrets set GOOGLE_OAUTH_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
supabase secrets set GOOGLE_OAUTH_CLIENT_SECRET=<web-client-secret>
supabase secrets set GOOGLE_OAUTH_REDIRECT_URI=https://<PROJECT_REF>.supabase.co/functions/v1/google-oauth-callback
supabase secrets set GOOGLE_APP_REDIRECT_URI=cotrainr://video/google-connected
```

Also ensure existing:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

## Google Cloud Console

1. Enable **Google Meet API**.
2. Configure OAuth consent screen (External or Internal).
3. Create **OAuth 2.0 Client ID** (Web application).
4. Authorized redirect URI must exactly match `GOOGLE_OAUTH_REDIRECT_URI`.
5. Scope used: `https://www.googleapis.com/auth/meetings.space.created` only.

## Deploy Edge Functions

```bash
supabase functions deploy google-oauth-start
supabase functions deploy google-oauth-callback
supabase functions deploy google-disconnect
supabase functions deploy google-integration-status
supabase functions deploy create-video-session
```

## SQL

> **Do not run `supabase db push`.** The migration history has duplicate
> version prefixes, so a push can replay historical migrations. Apply SQL by
> hand in the SQL Editor, in order.
>
> **Never run `supabase/migrations/20250215_video_sessions_zoom.sql` against
> production.** Its first statements are
> `DROP TABLE IF EXISTS public.video_session_participants CASCADE;`,
> `... video_session_host_meta CASCADE;` and `... video_sessions CASCADE;`,
> and it then recreates the obsolete Zoom shape (`user_integrations_zoom`).
> Replaying it destroys every live session, participant row, attendance
> response and dependent policy. The same applies to
> `20250127_complete_wipe_and_recreate.sql`.

Apply in this order if not already applied:

1. `supabase/migrations/20260816_video_sessions_mvp_hardening.sql`
2. `supabase/migrations/20260817_google_meet_integration.sql`
3. `supabase/migrations/20260818_video_sessions_rls_no_recursion.sql`
4. `supabase/migrations/20260819_video_sessions_drop_client_id_refs.sql`
5. `supabase/migrations/20260820_video_session_notifications.sql` (superseded by 20260821; skip if 20260821 is applied)
6. **`supabase/migrations/20260821_video_session_names_and_push.sql` (required)**
7. **`supabase/migrations/20260822_video_session_attendance_reminders.sql` (required)** — attendance responses (`response_status`, `respond_to_video_session`), the reminder jobs, and the current `list_my_video_sessions` / `get_my_video_session` / `list_my_video_session_people` read RPCs.
8. **`supabase/migrations/20260824_notifications_release.sql` (required)** — notification release state that the video-session producers depend on.

Optional hardening, manual only:

- `supabase/manual/20260829_video_session_privilege_hardening.sql` — revokes
  client privileges on `profile_display_name` and on the Google
  credential/OAuth-state tables. Revokes and read-only checks only.

## Video session notifications / reminders

Server-side jobs live in `video_session_notification_jobs`. Created / reschedule / cancel rows go into `public.notifications`. Push uses `device_tokens` + `send-push-notification`, reached **only** through the notifications INSERT dispatcher, so there is exactly one push producer.

**Scheduling authority: the `dispatch-video-session-reminders` Edge Function.**
`20260822` schedules pg_cron (`* * * * *`) only when the extension is present,
and production does not rely on it — the Edge Function's scheduled trigger is
the authority, and `dispatch_video_session_notification_jobs()` is idempotent
(`video_session_notification_log` dedupes), so a stray cron run cannot double
send. Run the dispatch manually with:

`SELECT public.dispatch_video_session_notification_jobs();`

If you enable pg_cron as well, keep both pointed at the same function; do not
add a second producer.

```bash
supabase functions deploy create-video-session
supabase functions deploy send-push-notification
supabase functions deploy dispatch-video-session-reminders --no-verify-jwt
supabase secrets set VIDEO_SESSION_CRON_SECRET=<random>
supabase secrets set NOTIFICATION_WEBHOOK_SECRET=<random>
```

Both secrets are **mandatory**. `dispatch-video-session-reminders` and `send-push-notification` return `503 configuration_error` when their secret is unset and `401` on a missing or wrong caller secret, so neither can fail open.

Also required for FCM (existing send-push secrets):

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

Dashboard → Edge Functions → `dispatch-video-session-reminders` → add a scheduled trigger (every 1 minute) with header `x-cron-secret: <VIDEO_SESSION_CRON_SECRET>`.

Dashboard → Database → Webhooks → the `public.notifications` INSERT webhook → add header `x-notification-webhook-secret: <NOTIFICATION_WEBHOOK_SECRET>`.

Android reminder/start notifications include Join and Dismiss actions in the foreground local notification. iOS has no custom action buttons in this MVP (tap opens session detail).
