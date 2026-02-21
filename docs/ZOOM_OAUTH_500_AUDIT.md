# Zoom OAuth Edge Functions – 500 Error Audit

## Root Cause Analysis

### Primary cause: **Malformed redirect URL fallback** (zoom-oauth-start L39)

**Original code:**
```typescript
const redirectUri = Deno.env.get("ZOOM_REDIRECT_URI") ?? 
  `${Deno.env.get("SUPABASE_URL")!.replace(".supabase.co", "")}/functions/v1/zoom-oauth-callback`
```

**Bug:** `replace(".supabase.co", "")` turns `https://xyz.supabase.co` into `https://xyz`, producing:
`https://xyz/functions/v1/zoom-oauth-callback` — invalid host (no TLD).

**Correct format:** `https://<project-ref>.supabase.co/functions/v1/zoom-oauth-callback`

**Fix:** Use `${supabaseUrl.replace(/\/$/, "")}/functions/v1/zoom-oauth-callback` (only strip trailing slash).

---

### Secondary causes

| Issue | Location | Impact |
|-------|----------|--------|
| `Deno.env.get("SUPABASE_URL")!` throws if null | zoom-oauth-start L26, L40; zoom-oauth-callback L66 | 500 before any response |
| No validation of SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY | Both | createClient can throw |
| No check for upsert error | zoom-oauth-callback L70 | Silent failure or unhandled DB error |
| No validation of tokenData shape | zoom-oauth-callback L51 | access_token/refresh_token could be undefined → DB constraint violation |
| `process.env` not used (correct) | Both | ✓ Uses Deno.env.get() |

---

## Line numbers where crashes could occur

### zoom-oauth-start
- **L26–27:** `createClient(Deno.env.get("SUPABASE_URL")!, ...)` — throws if SUPABASE_URL is null
- **L39:** `Deno.env.get("SUPABASE_URL")!.replace(...)` — throws if null; produces invalid URL
- **L30:** `supabase.auth.getUser()` — network/parsing errors could throw (caught by try/catch)

### zoom-oauth-callback
- **L66–67:** `createClient(Deno.env.get("SUPABASE_URL")!, ...)` — throws if null
- **L51–52:** `tokenData.access_token` / `tokenData.refresh_token` — if malformed, undefined → DB NOT NULL violation
- **L70:** `upsert()` — error not checked; constraint violation could surface as throw

---

## Flutter call site verification

**Repository:** `lib/repositories/video_sessions_repository.dart`

```dart
final res = await _supabase.functions.invoke('zoom-oauth-start');
```

- ✓ Function name: `zoom-oauth-start` (matches deployed name)
- ✓ Supabase client automatically sends `Authorization: Bearer <session_token>` when user is logged in
- ✓ No body required for zoom-oauth-start

**Auth requirement:** User must be logged in. If session is expired or missing, `getUser()` returns error → 401 (not 500).

---

## Supabase secrets checklist

| Secret | Required | Purpose |
|--------|----------|---------|
| `ZOOM_CLIENT_ID` | Yes | Zoom OAuth app client ID |
| `ZOOM_CLIENT_SECRET` | Yes | Zoom OAuth app client secret |
| `ZOOM_REDIRECT_URI` | Yes (recommended) | Must match Zoom app config: `https://<project-ref>.supabase.co/functions/v1/zoom-oauth-callback` |
| `APP_REDIRECT_URI` | No | Deep link after OAuth; default `cotrainr://video/zoom-connected` |

**Set via Dashboard:** Project Settings → Edge Functions → Secrets

**Set via CLI:**
```bash
supabase secrets set ZOOM_CLIENT_ID=your_client_id
supabase secrets set ZOOM_CLIENT_SECRET=your_client_secret
supabase secrets set ZOOM_REDIRECT_URI=https://YOUR_PROJECT_REF.supabase.co/functions/v1/zoom-oauth-callback
```

---

## curl test commands

### 1. Test zoom-oauth-start (requires valid JWT)

```bash
# Replace YOUR_SUPABASE_URL and YOUR_ANON_KEY
export SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co"
export ANON_KEY="your_anon_key"

# Get a JWT: sign in via Flutter/app, then copy from Supabase Auth or use:
# supabase auth get-session (if using Supabase CLI with linked project)

curl -X POST "$SUPABASE_URL/functions/v1/zoom-oauth-start" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

**Expected 200:** `{"auth_url":"https://zoom.us/oauth/authorize?..."}`  
**Expected 401:** `{"error":"Missing Authorization header"}` or `{"error":"Unauthorized"}`  
**Expected 500:** `{"error":"Zoom OAuth not configured..."}` or `{"error":"..."}`

### 2. Test without auth (expect 401)

```bash
curl -X POST "https://YOUR_PROJECT_REF.supabase.co/functions/v1/zoom-oauth-start" \
  -H "Content-Type: application/json"
```

### 3. Test zoom-oauth-callback (browser only)

Callback is invoked by Zoom redirect. Test by completing OAuth in browser; check Supabase Edge Function logs for `[zoom-oauth-callback]` entries.

---

## Patched functions summary

Both functions now include:

1. **Safe env access** — No `!`; explicit null checks with JSON error responses
2. **Correct redirect URL** — `supabaseUrl + "/functions/v1/zoom-oauth-callback"` (no `.supabase.co` removal)
3. **Structured logging** — `[zoom-oauth-start]` / `[zoom-oauth-callback]` prefix for all logs
4. **Defensive validation** — access_token, refresh_token, DB upsert errors
5. **No unhandled throws** — All code paths return a Response
