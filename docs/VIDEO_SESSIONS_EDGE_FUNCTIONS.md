# Video Sessions Edge Functions

The Android MVP uses **Google Meet**. Zoom is gone: the source, the runbook
examples and the secrets have all been removed.

The live source is the only reference — read it in `supabase/functions/`
rather than copying from a document. Deploy commands and required secrets are
in [GOOGLE_MEET_VIDEO_SESSIONS_DEPLOY.md](GOOGLE_MEET_VIDEO_SESSIONS_DEPLOY.md).

## Current functions

| Function | Purpose | `verify_jwt` | How the caller is authenticated |
|---|---|---|---|
| `google-oauth-start` | Returns the Google consent URL and records a single-use state row | true | Supabase JWT |
| `google-oauth-callback` | Exchanges the code, stores tokens, redirects to the app deep link | **false** | Single-use random state row in `oauth_pending_states` + PKCE `code_verifier` + expiry. Google cannot present a Supabase JWT, which is why the exception exists. |
| `google-integration-status` | Reports connect / reconnect-required state. Never returns tokens. | true | Supabase JWT |
| `google-disconnect` | Deletes the caller's Google credentials | true | Supabase JWT |
| `create-video-session` | Creates the Meet space and the session + participant rows | true | Supabase JWT, then re-checks trainer/nutritionist from the database (client-supplied role is ignored) |
| `respond-video-session` | Records an attendance response | true | Supabase JWT; the row is keyed on `auth.uid()` |
| `dispatch-video-session-reminders` | Runs the reminder/start job queue | **false** | Mandatory `x-cron-secret`. Missing env secret returns 503; wrong or missing caller secret returns 401. It cannot fail open. |
| `send-push-notification` | Sole FCM sender, triggered by the `public.notifications` INSERT dispatcher | **false** | Mandatory `x-notification-webhook-secret`, same fail-closed rules |

## Reminder scheduling authority

`dispatch-video-session-reminders`, invoked by its scheduled trigger every
minute, is the authority. `20260822` also schedules pg_cron when the extension
is available; both call the same idempotent
`public.dispatch_video_session_notification_jobs()`, and
`video_session_notification_log` dedupes, so overlap cannot double-send. Do not
introduce a second push producer — every push must originate from a
`public.notifications` INSERT.

## Token handling

Google access and refresh tokens live in `public.user_integrations_google` and
are read only by Edge Functions using the service role. They are never selected
by the Flutter client and never returned in any function response.
`supabase/manual/20260829_video_session_privilege_hardening.sql` removes the
remaining `anon` / `authenticated` table privileges as defence in depth.

## Zoom: DECOMMISSIONED (2026-08-28) — DO NOT DEPLOY

`zoom-oauth-start`, `zoom-oauth-callback` and `zoom-disconnect` are
**DECOMMISSIONED**. Their source has been deleted from `supabase/functions/`
and they must not be recreated. Their OAuth flow bound the `state` parameter
directly to the Supabase user id with no nonce, no single-use check and no
PKCE, so a forged callback could attach an attacker's Zoom account to another
user. If they are still deployed, delete them:

```bash
supabase functions delete zoom-oauth-start
supabase functions delete zoom-oauth-callback
supabase functions delete zoom-disconnect
```

The Zoom secrets (`ZOOM_CLIENT_ID`, `ZOOM_CLIENT_SECRET`, `ZOOM_REDIRECT_URI`,
`APP_REDIRECT_URI`) are no longer used and should be unset.
