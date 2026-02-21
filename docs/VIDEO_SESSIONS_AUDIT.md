# Video Sessions End-to-End Audit

**Date:** 2025-02-15  
**Scope:** Flutter UI + Supabase backend + Zoom integration  
**Goal:** Identify wired vs placeholder, recommend production-ready path for external Zoom

---

## 1) Executive Summary

| Aspect | Status | Notes |
|--------|--------|-------|
| **UI** | Mixed | Two parallel flows: (1) VideoSessionsPageV2 + CreateSessionSheet = **wired** to Supabase/Zoom; (2) VideoSessionsPage, CreateMeetingPage, JoinMeetingPage, MeetingRoomPage = **UI-only** (in-memory mock) |
| **Backend** | Exists | `video_sessions`, `user_integrations_zoom`, `video_session_participants`, `video_session_host_meta` (20250215_video_sessions_zoom.sql) |
| **Zoom** | OAuth wired | Edge Functions: `create-video-session`, `zoom-oauth-start`, `zoom-oauth-callback`, `zoom-disconnect` |
| **Join flow** | External Zoom | SessionDetailPage uses `url_launcher` → opens Zoom externally |
| **Meeting room** | Placeholder | MeetingRoomPage = 3,500+ line UI mock, no WebRTC, uses in-memory MeetingStorageService |
| **Client visibility** | Broken | create-video-session only adds host to participants; clients never see sessions in list |
| **Invite via chat** | Missing | No integration with conversations/messages or notifications |

---

## 2) Flutter UI + Navigation

### 2.1 Routes (app_router.dart)

| Route | Page | Used By |
|-------|------|---------|
| `/video` | VideoSessionsPageV2 | Main entry (Quick Access, trainer/nutritionist dashboards) |
| `/video/session/:id` | SessionDetailPage | Session list tap |
| `/video/create` | CreateMeetingPage | **Legacy** – not used by V2; uses in-memory mock |
| `/video/join` | JoinMeetingPage | **Legacy** – Meeting ID + Join Code (in-memory) |
| `/video/room/:meetingId` | MeetingRoomPage | **Legacy** – in-app "room" UI mock (no real call) |

**Note:** Router strips `?role=` from video URLs (security).

### 2.2 Active Flow (VideoSessionsPageV2)

| Screen | Fields | Button Action | Data Source |
|--------|--------|---------------|-------------|
| **VideoSessionsPageV2** | – | Create Session (FAB) | Opens CreateSessionSheet |
| | | Join with link (client) | `_showJoinWithLinkSheet` → paste Zoom URL → `launchUrl` |
| | | Session tile tap | `context.push('/video/session/${s.id}')` |
| **CreateSessionSheet** | Title, Date, Time, Duration, Max participants | Create Session | `VideoSessionsRepository.createSession()` → Edge Function → Supabase |
| **SessionDetailPage** | Title, date, duration | Join Session | `launchUrl(session.joinUrl)` → external Zoom |
| | | Copy Invite Link | Clipboard |
| | | Cancel Session (host) | `VideoSessionsRepository.cancelSession()` |

### 2.3 Legacy / Unused Flow (UI-only)

| Screen | Fields | Button Action | Data Source |
|--------|--------|---------------|-------------|
| **CreateMeetingPage** | Title, Privacy, Instant/Schedule, Date, Time, Duration, Allowed Roles | Create Meeting | `MeetingStorageService.addMeeting()` (in-memory) |
| **JoinMeetingPage** | Meeting ID (6 digits), Join Code (6 chars), Name | Join Meeting | `context.push('/video/room/$shareKey')` → MeetingRoomPage |
| **MeetingRoomPage** | – | Mute, Video, Leave, etc. | `MeetingStorageService` (in-memory); mock participants; **no real call** |
| **VideoSessionsPage** | – | Create/Join/Schedule | Uses MeetingStorageService; **not in router** (V2 is used) |

### 2.4 Entry Points

| Location | Action |
|----------|--------|
| `quick_access_v3.dart` | `context.push('/video?role=trainer|nutritionist|client')` |
| `trainer_home_page.dart` | Video tile → `/video` |
| `nutritionist_home_page.dart` | `context.push('/video?role=nutritionist')` |
| `client_detail_page.dart` | "Start Video Call" → `/video/create?role=trainer` |
| `nutritionist_client_detail_page.dart` | Video button → `/video/create?role=nutritionist` |
| `app_link_handler.dart` | Deep link → `context.go('/video')` |

**Gap:** Client detail pages push `/video/create` which uses CreateMeetingPage (in-memory). They should use CreateSessionSheet or a Supabase-backed create flow.

---

## 3) Data & Supabase

### 3.1 Existing Tables (20250215_video_sessions_zoom.sql)

| Table | Purpose |
|-------|---------|
| **user_integrations_zoom** | Zoom OAuth tokens (user_id, access_token, refresh_token, expires_at, zoom_account_email) |
| **video_sessions** | id, host_id, provider, title, description, scheduled_start, duration_minutes, max_participants, status, join_url, provider_meeting_id |
| **video_session_host_meta** | session_id, host_id, host_start_url (host-only; never exposed) |
| **video_session_participants** | session_id, user_id, role (host/participant) |

**Status enum:** `scheduled`, `cancelled`, `ended`  
**Provider:** `zoom`, `meet`, `jitsi`

### 3.2 RLS Summary

- **user_integrations_zoom:** User can SELECT own row only.
- **video_sessions:** Host CRUD own; participants SELECT if in `video_session_participants`.
- **video_session_host_meta:** Host SELECT only; no client INSERT/UPDATE.
- **video_session_participants:** Host manages; participants SELECT.

### 3.3 Critical Gap: Client Visibility

`create-video-session` Edge Function inserts only the **host** into `video_session_participants`. Clients never appear. RLS blocks them from seeing sessions. `listSessions()` returns empty for clients.

**Fix:** Add client(s) to `video_session_participants` when creating a session, or add `client_id` to `video_sessions` and adjust RLS.

### 3.4 Trainer–Client Relationships

| Table | Purpose |
|-------|---------|
| **leads** | client_id, provider_id, status (requested/accepted/declined) |
| **conversations** | lead_id, client_id, provider_id (created when lead accepted) |
| **messages** | conversation_id, sender_id, content |

**20250215_video_sessions_zoom.sql:** Drops and recreates `video_sessions` **without** `conversation_id` or `client_id`. No link between sessions and leads/conversations.

### 3.5 Messaging Integration

- **conversations** + **messages** exist.
- **NotificationService** (in-memory) has `meetingId` but no Supabase-backed notifications for video sessions.
- No Edge Function or trigger to send session invite via messages or push.

---

## 4) Services / Repositories

### 4.1 VideoSessionsRepository

| Method | Wired? | Notes |
|--------|--------|------|
| `getZoomStatus()` | Yes | Reads `user_integrations_zoom` |
| `getZoomOAuthUrl()` | Yes | Invokes `zoom-oauth-start` |
| `disconnectZoom()` | Yes | Invokes `zoom-disconnect` |
| `listSessions()` | Yes | Selects from `video_sessions` (RLS filters) |
| `createSession()` | Yes | Invokes `create-video-session` |
| `cancelSession()` | Yes | Updates `video_sessions.status` |
| `getSession()` | Yes | Select by id |

**Gap:** No `addParticipant()` or `inviteClient()`.

### 4.2 MeetingStorageService

- In-memory singleton. Used by legacy CreateMeetingPage, MeetingRoomPage. **Not used** by VideoSessionsPageV2.

---

## 5) Edge Functions

| Function | Purpose |
|----------|---------|
| **zoom-oauth-start** | Returns Zoom OAuth URL |
| **zoom-oauth-callback** | Exchanges code; stores tokens; redirects to `cotrainr://video/zoom-connected` |
| **zoom-disconnect** | Deletes Zoom tokens |
| **create-video-session** | Trainer only; creates Zoom meeting; inserts session + host meta + host as participant |

---

## 6) Zoom Integration Options

| Option | Effort | Recommendation |
|--------|--------|-----------------|
| **1. Manual paste** | Low | **Fastest MVP** – add "Or paste Zoom link" field; store in DB; no OAuth |
| **2. OAuth connect** | Medium | **Current** – already built; needs client visibility + invite flow |
| **3. Platform account** | High | Not recommended |

**Recommendation:** Add Option 1 as fallback when Zoom not connected. Keep Option 2 for trainers who connect Zoom.

---

## 7) Security Gaps

| Gap | Fix |
|-----|-----|
| Clients cannot see sessions | Add client to `video_session_participants` or add `client_id` + RLS |
| CreateMeetingPage still in router | Remove or redirect to CreateSessionSheet |
| Nutritionist cannot create | Edge function restricts to trainer; decide policy |

---

## 8) Recommended MVP Design (External Zoom)

1. Trainer creates session (CreateSessionSheet) → Zoom API or paste link.
2. Session stored in `video_sessions` with `join_url`.
3. Trainer adds client to participants (or session linked to conversation).
4. Client sees session in list (or receives invite via chat).
5. Client taps Join → `launchUrl(join_url)` → opens Zoom externally.
6. Client returns to app manually (deep link later).

**No in-app meeting room.** MeetingRoomPage is deprecated for production.

---

## 9) Patch Plan (Deployable Steps)

### Step 1: Add manual Zoom link (MVP fallback)
- Migration: Allow `provider='manual'`; `join_url` without Zoom API.
- Edge Function: Accept optional `join_url`; skip Zoom API when provided.
- Flutter: CreateSessionSheet – add "Paste Zoom link" optional field.

### Step 2: Client visibility
- Migration: Add `client_id` to `video_sessions` (nullable).
- Edge Function: Accept `client_id`; insert into `video_session_participants`.
- Flutter: CreateSessionSheet – client picker from leads.

### Step 3: Invite via chat
- After create, send message to conversation with join link.

### Step 4: Remove/deprecate legacy UI
- Redirect `/video/create` → CreateSessionSheet.
- Redirect `/video/join` → "Join with link" sheet.
- Deprecate `/video/room/:id` for Zoom.

### Step 5: Deep link return (later)
- Document: `cotrainr://video/session/:id`. Implement in app_link_handler when ready.

---

## 10) Exact Files to Change

| Step | File | Change |
|------|------|--------|
| 1 | New migration | Allow `provider='manual'` |
| 1 | `create-video-session/index.ts` | Accept optional `join_url`; skip Zoom API when provided |
| 1 | `create_session_sheet.dart` | Add "Paste Zoom link" optional field |
| 2 | New migration | Add `client_id` to `video_sessions` |
| 2 | `create-video-session/index.ts` | Accept `client_id`; insert participant |
| 2 | `create_session_sheet.dart` | Client picker from leads |
| 3 | `messages_repository.dart` | `sendSessionInvite()` |
| 3 | `create_session_sheet.dart` | Call sendSessionInvite after create |
| 4 | `app_router.dart` | Redirect `/video/create`, `/video/join` |
| 4 | `client_detail_page.dart` | Use CreateSessionSheet with client context |

---

## 11) Proposed Migration: 20250215_video_sessions_mvp_enhancement.sql

**File:** `supabase/migrations/20250215_video_sessions_mvp_enhancement.sql`

**Adds:**
- `client_id` (nullable) – links session to specific client for RLS
- `provider IN ('zoom','meet','jitsi','manual')` – allows manual paste
- Updated RLS – clients can SELECT where `client_id = auth.uid()` or in participants

**Idempotent:** Safe to run if columns/constraints already exist.

---

## 12) Flutter Wiring Plan

| Button | Current | Target |
|--------|---------|--------|
| Create Session (FAB) | CreateSessionSheet → createSession() | Same; add manual link option |
| Join Session (SessionDetailPage) | launchUrl(joinUrl) | Same |
| Copy Invite | Clipboard | Same |
| Join with link (client) | Paste URL → launchUrl | Same |
| Start Video Call (client detail) | `/video/create` (CreateMeetingPage) | CreateSessionSheet with client pre-selected |

**url_launcher:** Already used. No change.

**Deep link return:** Document `cotrainr://video/session/:id`; implement later.

---

## 13) Related Files Reference

| Category | Path |
|----------|------|
| Audit report | `docs/VIDEO_SESSIONS_AUDIT.md` |
| RTC audit (WebRTC) | `VIDEO_SESSIONS_RTC_AUDIT.md` |
| Model doc | `docs/VIDEO_SESSIONS_MODEL.md` |
| Base schema | `supabase/migrations/20250215_video_sessions_zoom.sql` |
| MVP enhancement | `supabase/migrations/20250215_video_sessions_mvp_enhancement.sql` |
| Edge Function | `supabase/functions/create-video-session/index.ts` |
| Repository | `lib/repositories/video_sessions_repository.dart` |
| Active page | `lib/pages/video_sessions/video_sessions_page_v2.dart` |
| Create sheet | `lib/pages/video_sessions/create_session_sheet.dart` |
| Session detail | `lib/pages/video_sessions/session_detail_page.dart` |
