# Zoom OAuth + Video Sessions Exact Failure Audit

**Project ref:** `nvtozwtuyhwqkqvftpyi`  
**Required redirect URI:** `https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback`

---

## Root Cause (Most Likely)

**Zoom error 4700 "Invalid redirect url"** — The `redirect_uri` sent in the OAuth authorize request does not **exactly** match the Redirect URL configured in the Zoom App Marketplace.

**Evidence:**
- [Zoom Community: Invalid Redirect Uri error code 4700](https://community.zoom.com/marketplace-10/invalid-redirect-uri-error-code-4700-60101)
- [Zoom Dev Forum: Invalid Redirect 4700](https://devforum.zoom.us/t/invalid-redirect-4700/98051)

**Exact failure step:** Step 2 — User authorizes on Zoom → Zoom validates `redirect_uri` against app config → mismatch → 4700.

**Code locations:**
- `zoom-oauth-start/index.ts` L60–70: constructs `redirectUri`
- `zoom-oauth-start/index.ts` L70: builds auth URL with `encodeURIComponent(redirectUri)`

**Generated URL params (from zoom-oauth-start):**
```
response_type=code
client_id=<ZOOM_CLIENT_ID>
redirect_uri=<ZOOM_REDIRECT_URI or fallback>
state=<user.id>
```

**Fallback bug (fixed in prior patch):** Original used `replace(".supabase.co","")` producing invalid `https://xyz/functions/...`. Current code uses `supabaseUrl + "/functions/v1/zoom-oauth-callback"` — correct.

**Remaining risk:** If `ZOOM_REDIRECT_URI` is unset, fallback uses `SUPABASE_URL`. Supabase may inject a URL with trailing slash or different format. **Require explicit `ZOOM_REDIRECT_URI`** to eliminate mismatch.

---

## Secondary Issues

| Issue | Location | Impact |
|-------|----------|--------|
| No logging of constructed redirect_uri | zoom-oauth-start | Cannot debug 4700 in Supabase logs |
| Deep link drops error param | app_link_handler.dart L45 | User sees "Connect Zoom" again with no error message when callback fails |
| zoom-oauth-callback uses `baseUrl` when ZOOM_REDIRECT_URI unset | zoom-oauth-callback L39–40 | Token exchange `redirect_uri` must match authorize; `baseUrl` from request could differ in edge cases |
| "Application not found" | — | Wrong `client_id`, app in wrong account, or app type (must be OAuth, not Event Subscription) |

---

## Step 1 — Flutter Connect Flow (Evidence)

| Action | File | Lines |
|--------|------|-------|
| Connect button handler | `lib/pages/video_sessions/video_sessions_page_v2.dart` | 116–158 `_connectZoom()` |
| Function invoke | `lib/repositories/video_sessions_repository.dart` | 106–107 `getZoomOAuthUrl()` → `_supabase.functions.invoke('zoom-oauth-start')` |
| URL launch | `video_sessions_page_v2.dart` | 119–122 `Uri.parse(url)` → `launchUrl(uri, mode: LaunchMode.externalApplication)` |
| Deep link handler | `lib/widgets/app_link_handler.dart` | 31–33 `_isVideoZoomConnectedUri`, 42–46 `_handleUri` → `context.go('/video?zoom-connected=1')` |

**Auth header:** `supabase.functions.invoke()` automatically sends `Authorization: Bearer <session_access_token>` when user is logged in. No raw HTTP.

**Edge function return:** JSON `{ auth_url: "https://zoom.us/oauth/authorize?..." }`. Flutter extracts and opens it.

**Deep link:** `cotrainr://video/zoom-connected` (with optional `?success=1` or `?error=xxx`) → AppLinkHandler navigates to `/video?zoom-connected=1` (currently drops `error`).

---

## Step 2 — zoom-oauth-start (Evidence)

| Check | Status |
|-------|--------|
| redirect_uri construction | L60–67: Uses `ZOOM_REDIRECT_URI` or fallback `supabaseUrl + "/functions/v1/zoom-oauth-callback"` |
| No `.replace(".supabase.co","")` | ✓ Fixed in prior patch |
| ZOOM_CLIENT_ID | L51–58: Validated |
| ZOOM_REDIRECT_URI | Optional; fallback used if unset |
| Auth URL format | L70: `https://zoom.us/oauth/authorize?response_type=code&client_id=...&redirect_uri=...&state=...` ✓ |
| Logging | L26, 34, 43, 47, 53, 64, 77: Present but no log of final `redirectUri` or `authUrl` (masked) |

**Exact redirect_uri when ZOOM_REDIRECT_URI set:**
```
https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback
```

**Zoom app requirement:** This exact string must appear in Zoom App → OAuth → Redirect URL for OAuth (whitelist).

---

## Step 3 — zoom-oauth-callback (Evidence)

| Check | Status |
|-------|--------|
| Reads code, state | L15–17 ✓ |
| Token exchange | L42–53: POST to `https://zoom.us/oauth/token` |
| redirect_uri for token | L40: `ZOOM_REDIRECT_URI` or `baseUrl` (request origin + path) |
| DB upsert | L99–109: `user_integrations_zoom`; error checked |
| App redirect | L115: `cotrainr://video/zoom-connected?success=1` or `?error=xxx` |
| Env validation | L32–37: clientId, clientSecret |

**On error:** 302 redirect to `cotrainr://video/zoom-connected?error=<code>`.

**On success:** 302 redirect to `cotrainr://video/zoom-connected?success=1`.

---

## Step 4 — Supabase Secrets & Zoom Marketplace

### Supabase Edge Function Secrets (Required)

| Secret | Value (copy/paste) |
|--------|--------------------|
| `ZOOM_CLIENT_ID` | Your Zoom app Client ID |
| `ZOOM_CLIENT_SECRET` | Your Zoom app Client Secret |
| `ZOOM_REDIRECT_URI` | `https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback` |
| `APP_REDIRECT_URI` | `cotrainr://video/zoom-connected` (optional, default) |

### Zoom Marketplace Settings

| Setting | Required | Value |
|---------|----------|-------|
| App type | Yes | **OAuth** (not Event Subscription, not Server-to-Server) |
| Redirect URL for OAuth | Yes | `https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback` |
| Domain Allow List / Home URL | No | Not required for server-side OAuth redirect |
| Development vs Production | — | In Development, redirect URL works immediately. In Production, URL changes require app resubmission. |

**Exact checklist:**
1. Zoom App Marketplace → Your app (Cotrainr)
2. OAuth tab → Redirect URL for OAuth → Add: `https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback`
3. No trailing slash. HTTPS only. Exact match.

---

## Step 5 — Proving with Logs

**Supabase Dashboard → Edge Functions → Logs**

Filter: `zoom-oauth-start`, `zoom-oauth-callback`

**Look for:**
- `[zoom-oauth-start]` — request id, status, and (after patch) `redirect_uri=` (masked)
- `[zoom-oauth-callback]` — token exchange status, DB upsert errors

**If 4700:** Compare logged `redirect_uri` with Zoom app config. They must match character-for-character.

---

## Step 6 — Why "Connect Zoom" Keeps Showing

| Component | File | Logic |
|-----------|------|-------|
| Status source | `video_sessions_repository.dart` L72–101 | `getZoomStatus()` queries `user_integrations_zoom` where `user_id = currentUser.id` |
| RLS | `20250215_video_sessions_zoom.sql` L69–70 | `USING (auth.uid() = user_id)` — user can read own row ✓ |
| Page load | `video_sessions_page_v2.dart` L82–104 | `_load()` calls `getZoomStatus()` and sets `_zoomStatus` |
| Refresh on return | L52–55, 63–65 | `zoom-connected=1` → `_refreshZoomStatus()` |

**Exact reason UI stays disconnected:**

1. **Callback never succeeds** — Zoom 4700 or token exchange fails → no DB upsert → `user_integrations_zoom` has no row for user.
2. **Callback succeeds but app doesn't refresh** — Deep link opens app; AppLinkHandler does `context.go('/video?zoom-connected=1')`. VideoSessionsPageV2's `didChangeDependencies` or `_handleQueryParams` runs and calls `_refreshZoomStatus()`. If the route doesn't re-build with new uri (e.g. already on /video), `didChangeDependencies` might not run again. **Potential gap:** When navigating from background via deep link, GoRouter may replace the route; the page should rebuild. Verify `state.uri` includes `zoom-connected=1` when coming from deep link.
3. **RLS blocks read** — Unlikely; policy allows `auth.uid() = user_id`.

**Most likely:** (1) — OAuth fails at Zoom (4700) or token exchange, so no row is ever written.

---

## Minimal Patch

1. **Require ZOOM_REDIRECT_URI** in zoom-oauth-start (no fallback).
2. **Use same ZOOM_REDIRECT_URI** in zoom-oauth-callback for token exchange (no baseUrl fallback).
3. **Add logging** of redirect_uri (mask project ref for security) and auth URL (mask client_id).
4. **Pass zoom_error** through deep link → `/video?zoom-connected=1&zoom_error=xxx` → show snackbar.

---

## Verification Steps

1. Set secrets (required; no fallback):
   ```bash
   supabase secrets set ZOOM_CLIENT_ID=<your_client_id>
   supabase secrets set ZOOM_CLIENT_SECRET=<your_client_secret>
   supabase secrets set ZOOM_REDIRECT_URI=https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback
   ```

2. Zoom App: Add exact redirect URL (no trailing slash):
   ```
   https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback
   ```

3. Deploy:
   ```bash
   supabase functions deploy zoom-oauth-start
   supabase functions deploy zoom-oauth-callback
   ```

4. Test: Tap Connect Zoom → complete Zoom login → check Supabase logs for `[zoom-oauth-start]` and `[zoom-oauth-callback]`.

5. If 4700: Copy `redirect_uri` from logs and compare with Zoom app config.

6. Curl test (expect 401 without JWT):
   ```bash
   curl -s -o /dev/null -w "%{http_code}" -X POST \
     "https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-start" \
     -H "Content-Type: application/json"
   # Expected: 401
   ```

---

## Regression Checks

- [ ] Trainer: Connect Zoom → success → Create Session (Zoom) works
- [ ] Nutritionist: Same flow
- [ ] Client: No Connect Zoom card; sessions list works
- [ ] Disconnect Zoom: Tokens removed; Connect card shows again
