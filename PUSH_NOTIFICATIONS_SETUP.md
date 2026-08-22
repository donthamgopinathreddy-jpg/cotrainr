# Push Notifications Setup

**App package:** `com.cotrainr.app`

## Push delivery authority (encoded in DB + code)

```
EVENT → notifications INSERT → webhook send-push-notification → deliverNotificationPush → FCM
```

- Edge Functions (`create-video-session`, `respond-video-session`, `dispatch-video-session-reminders`) **only INSERT** notification rows.
- They **must not** call `deliverNotificationRows()` (removed in release pass).
- Migration `20260824_notifications_release.sql` stores policy in `system_config`.

## Reminder dispatch authority

```
schedule_video_session_notification_jobs()  ← on session create/reschedule (SQL)
dispatch_video_session_notification_jobs() ← polled ONLY by Edge Function every minute
```

- **pg_cron** job `cotrainr-video-session-reminders` is **unscheduled** by migration.
- Schedule Supabase cron HTTP → `dispatch-video-session-reminders` with `VIDEO_SESSION_CRON_SECRET`.

## Quick checklist

1. Replace `android/app/google-services.json` from Firebase
2. `supabase db push` (includes `20260824_notifications_release.sql`)
3. Set Firebase secrets on Edge Functions
4. Deploy:
   ```bash
   supabase functions deploy send-push-notification
   supabase functions deploy dispatch-video-session-reminders
   supabase functions deploy create-video-session
   supabase functions deploy respond-video-session
   ```
5. **Database Webhook**: table `notifications`, event **Insert** → `send-push-notification`
6. **Scheduled function**: `dispatch-video-session-reminders` every 1 minute with `x-cron-secret` header

## App version config

Table `app_version_config` + RPC `get_app_version_config()`.

Update minimum/recommended versions via Supabase Dashboard (service role) — not from the client.

## iOS (separate readiness)

iOS push requires `GoogleService-Info.plist`, APNs, and foreground actionable handling.
Not required for Android-only release. See §18 in notifications audit.

## Test

1. Sign in on device
2. Insert a row into `notifications` for your user
3. Receive exactly **one** push (not two)
