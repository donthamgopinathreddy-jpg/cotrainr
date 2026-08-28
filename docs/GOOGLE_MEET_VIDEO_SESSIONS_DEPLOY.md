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

If automated migrations fail due to duplicate version history, run manually in SQL editor:

1. `supabase/migrations/20260816_video_sessions_mvp_hardening.sql` (if not applied)
2. `supabase/migrations/20260817_google_meet_integration.sql`
3. `supabase/migrations/20260818_video_sessions_rls_no_recursion.sql`
4. `supabase/migrations/20260819_video_sessions_drop_client_id_refs.sql`
5. `supabase/migrations/20260820_video_session_notifications.sql` (optional if 20260821 applied)
6. **`supabase/migrations/20260821_video_session_names_and_push.sql` (required)**

## Video session notifications / reminders

Server-side jobs live in `video_session_notification_jobs`. Created/reschedule/cancel rows go into existing `public.notifications`. Push uses existing `device_tokens` + `send-push-notification`, reached **only** through the Supabase Database Webhook on `public.notifications` INSERT.

Dispatch SQL:

`SELECT public.dispatch_video_session_notification_jobs();`

pg_cron is scheduled in the migration when the extension exists (`* * * * *`). If pg_cron is unavailable, deploy and schedule the Edge Function every minute:

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
