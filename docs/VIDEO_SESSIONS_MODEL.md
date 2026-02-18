# Video Sessions Working Model (Zoom OAuth + External Video)

## STEP 1 — Repo Scan Summary

### Existing Video Session Files

| File | Purpose |
|------|---------|
| `lib/pages/video_sessions/video_sessions_page.dart` | Main list page – tabs (Ongoing/Upcoming/Links), uses `MeetingStorageService` (in-memory mock) |
| `lib/pages/video_sessions/create_meeting_page.dart` | Create meeting – generates ID/code client-side, saves to `MeetingStorageService` |
| `lib/pages/video_sessions/join_meeting_page.dart` | Join by ID+code – navigates to `/video/room/:shareKey` |
| `lib/pages/video_sessions/meeting_room_page.dart` | Meeting room UI – WebRTC mockup only, no real video |
| `lib/models/video_session_models.dart` | `Meeting`, `Participant`, `Role`, `MeetingStatus`, `MeetingPrivacy` |
| `lib/services/meeting_storage_service.dart` | In-memory singleton – `ongoingMeetings`, `upcomingMeetings`, `recentMeetings` |

### Routes (`lib/router/app_router.dart`)

| Path | Page | Notes |
|------|------|-------|
| `/video` | VideoSessionsPage | Role from query `?role=client|trainer|nutritionist` (stripped by redirect) |
| `/video/create` | CreateMeetingPage | Role from query |
| `/video/join` | JoinMeetingPage | Client-only flow |
| `/video/room/:meetingId` | MeetingRoomPage | Uses shareKey (meetingId-code) |

### Entry Points

- **Quick Access** (`lib/widgets/home_v3/quick_access_v3.dart`): VIDEO SESSIONS tile → `/video?role=client|trainer|nutritionist`
- **Trainer dashboard** (`lib/pages/trainer/client_detail_page.dart`): Video call button → `/video/create?role=trainer`
- **Nutritionist** (`lib/pages/nutritionist/nutritionist_client_detail_page.dart`): Video call → `/video/create?role=nutritionist`
- **Nutritionist home** (`lib/pages/nutritionist/nutritionist_home_page.dart`): Video sessions → `/video?role=nutritionist`

### Existing Supabase Schema

- `video_sessions` table exists (20250127 migrations): `host_id`, `lead_id`, `conversation_id`, `status`, `room_id`, `token` – different design, no Zoom fields.
- No `user_integrations_zoom` or Zoom OAuth tables.
- No Edge functions for Zoom.

---

## Architecture Overview

### Connection States (Trainer)

1. **Not connected** – Connect Zoom CTA, Create Session disabled
2. **Connected** – Create enabled, show connected email, Disconnect option
3. **Expired** – Reconnect CTA

### Data Flow

1. Trainer connects Zoom via OAuth → Edge stores tokens in `user_integrations_zoom`
2. Trainer creates session → Edge calls Zoom API, inserts `video_sessions` + `video_session_host_meta` (host_start_url)
3. Client/participant taps Join → `url_launcher` opens `join_url` (Zoom app/browser)
4. Return to app → refresh session status

### Security

- **host_start_url** stored in `video_session_host_meta` with RLS: only host can SELECT
- Participants never see host_start_url
- Zoom client secret never in Flutter; all Zoom API calls via Edge functions

---

## Schema (Migration)

### Tables

- `video_sessions` – join_url, provider, scheduled_start, duration_minutes, max_participants, status (no host_start_url)
- `video_session_host_meta` – session_id, host_id, host_start_url (RLS: host only)
- `video_session_participants` – session_id, user_id, role (optional MVP)
- `user_integrations_zoom` – user_id, zoom_account_email, access_token, refresh_token, expires_at

---

## Setup (Zoom OAuth)

1. Create a Zoom OAuth app at https://marketplace.zoom.us/
2. Add redirect URI: `https://<project-ref>.supabase.co/functions/v1/zoom-oauth-callback`
3. Set Supabase secrets: `ZOOM_CLIENT_ID`, `ZOOM_CLIENT_SECRET`, `ZOOM_REDIRECT_URI`, `APP_REDIRECT_URI` (e.g. `cotrainr://video/zoom-connected`)
4. Deep link `cotrainr://video/zoom-connected` is configured in AndroidManifest and AppLinkHandler

## Test Checklist (Manual)

- [ ] Connect Zoom: tap Connect → OAuth flow → returns with connected state
- [ ] Reconnect: expire token (or mock) → Reconnect CTA → re-auth works
- [ ] Disconnect: tap Disconnect → tokens cleared, Create disabled
- [ ] Create session: title, date/time, duration 30/45/60, max 5 → success, invite link copied
- [ ] Join link: tap Join → opens Zoom app/browser with join_url
- [ ] Participants cannot see host_start_url (verify RLS / API response)
- [ ] RLS: host CRUD own sessions; participants SELECT only sessions they’re in
- [ ] Return to app: after Zoom, app resumes and refreshes session list
