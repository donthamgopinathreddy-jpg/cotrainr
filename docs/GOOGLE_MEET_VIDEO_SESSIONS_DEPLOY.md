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
