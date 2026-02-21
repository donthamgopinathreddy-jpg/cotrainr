# Zoom OAuth Integration — Audit Report

**Project ref:** nvtozwtuyhwqkqvftpyi  
**Callback endpoint:** `https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback`

---

## Section A: Findings (bulleted, with file + line references)

### A1. zoom-oauth-start/index.ts

- **OAuth authorize URL construction (L70):**
  ```
  https://zoom.us/oauth/authorize?response_type=code&client_id=${encodeURIComponent(clientId)}&redirect_uri=${encodeURIComponent(redirectUri)}&state=${encodeURIComponent(state)}
  ```
  - Uses `https://zoom.us/oauth/authorize` ✓ (not marketplace.zoom.us)
  - Single encoding: `encodeURIComponent()` applied once to each param ✓

- **redirect_uri source (L60–67):** `Deno.env.get("ZOOM_REDIRECT_URI")?.trim()`. No fallback; returns 500 if unset or not `https://`.

- **state generation (L69):** `state = user.id` (Supabase auth user UUID). Not stored server-side; passed through OAuth and used as `user_id` in callback upsert (zoom-oauth-callback L106). No explicit validation of state beyond presence check.

- **Authorization header (L24–28):** Required. Returns 401 if missing.

- **Mismatch conditions for redirect_uri:**
  - `ZOOM_REDIRECT_URI` differs from Zoom app config (trailing slash, http vs https, path typo)
  - Secret has leading/trailing whitespace (`.trim()` mitigates)
  - Zoom app config uses different URL (e.g. wrong project ref)

### A2. zoom-oauth-callback/index.ts

- **Auth / JWT:** Function code does **not** check `Authorization` header. It processes any GET request.

- **Code and state (L15–17):** `url.searchParams.get("code")` and `url.searchParams.get("state")`. Correct for Zoom GET redirect.

- **Token exchange (L48–59):**
  - `POST https://zoom.us/oauth/token` ✓
  - `Authorization: "Basic " + btoa(clientId + ":" + clientSecret)` ✓
  - Body: `grant_type=authorization_code`, `code`, `redirect_uri` ✓
  - `redirect_uri` uses same `ZOOM_REDIRECT_URI` env var (L40–44) ✓

- **401 cause:** Supabase gateway enforces JWT by default and returns 401 before the function runs. Zoom redirects the browser with no JWT; the request never reaches the function code.

- **500 causes:** Missing env vars (ZOOM_CLIENT_ID, ZOOM_CLIENT_SECRET, ZOOM_REDIRECT_URI, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY); Zoom token exchange failure; DB upsert failure.

- **Redirect loops:** Not in code. All paths return a single 302 to `appRedirect` (success or error). No loop in callback logic.

- **DB upsert (L105–115):** `user_integrations_zoom` upsert with `onConflict: "user_id"`. Errors handled; redirect to app with `?error=db_save_failed`.

### A3. Supabase Edge Function configuration

- **zoom-oauth-start:** Expects `Authorization: Bearer <jwt>` (L24–28). Used by Flutter via `supabase.functions.invoke()` which sends the session.

- **zoom-oauth-callback:** Must be invoked by Zoom without a JWT. Supabase gateway JWT verification is enabled by default for all functions.

- **zoom-oauth-callback must be PUBLIC:** Yes. Zoom redirects the browser to the callback URL. The browser does not send a Supabase JWT. If JWT verification is on, the gateway returns 401 before the function runs.

- **"Verify JWT with legacy secret" ON:** If this applies to the callback, it would reject the Zoom redirect because the request has no JWT. Result: 401.

- **Config location:** No `config.toml` or `verify_jwt` found in the repo. Supabase Dashboard → Edge Functions → per-function settings, or deploy with `--no-verify-jwt` for zoom-oauth-callback.

### A4. Redirect flow back to app (deep link)

- **Success (zoom-oauth-callback L121):** `Response.redirect(\`${appRedirect}?success=1\`, 302)` → `cotrainr://video/zoom-connected?success=1`

- **Error (L9–12, 24, 29, 37, 43, 64, 67, 72, 76, 99, 119, 125):** `redirectWithError(appRedirect, errorCode)` → `cotrainr://video/zoom-connected?error=<code>`

- **AppLinkHandler (app_link_handler.dart L40–48):** Handles `cotrainr://video/zoom-connected` and navigates to `/video?zoom-connected=1` (or with `zoom_error`). Single navigation; no loop in code.

- **ERR_TOO_MANY_REDIRECTS:** Not caused by the callback. Possible causes:
  - Mobile browser failing to open `cotrainr://` and falling back to HTTP, which redirects again
  - App not configured for deep link; browser keeps trying to load
  - UNKNOWN: Would need to inspect browser network trace or device logs

---

## Section B: Confirmed Root Causes (ranked by likelihood)

1. **zoom-oauth-callback returns 401 (Supabase gateway JWT)**  
   - Zoom redirects without JWT; Supabase gateway rejects before the function runs.  
   - Evidence: "zoom-oauth-callback invocation as GET 401".

2. **Zoom 4700 "Invalid redirect url"**  
   - `redirect_uri` in the authorize request does not exactly match the Redirect URL in the Zoom app.  
   - Evidence: "zoom-oauth-start" constructs the URL; Zoom validates it on the authorize page.

3. **"Application not found"**  
   - Wrong `client_id`, app in wrong Zoom account, or wrong app type (e.g. Event Subscription instead of OAuth).  
   - Evidence: Zoom app config.

4. **ERR_TOO_MANY_REDIRECTS**  
   - Likely device/browser handling of `cotrainr://` and fallbacks.  
   - Evidence: UNKNOWN; no app code that could cause this.

---

## Section C: Minimal Fix List (only smallest changes)

1. **Make zoom-oauth-callback public (no JWT):**
   - Deploy: `supabase functions deploy zoom-oauth-callback --no-verify-jwt`
   - Or: Supabase Dashboard → Edge Functions → zoom-oauth-callback → Settings → disable JWT verification.

2. **Verify ZOOM_REDIRECT_URI:**
   - Supabase secrets: `ZOOM_REDIRECT_URI=https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback` (exact match, no trailing slash).

3. **Verify Zoom app config:**
   - OAuth app type (not Event Subscription).
   - Redirect URL: `https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback` (exact match).

4. **If ERR_TOO_MANY_REDIRECTS persists:**
   - Confirm Android `AndroidManifest.xml` and iOS `Info.plist` have correct intent filters for `cotrainr://video/zoom-connected`.
   - UNKNOWN: May need device logs.

---

## Section D: Verification Steps (exact curl/browser steps)

### D1. zoom-oauth-start (expect 401 without JWT)

```bash
curl -s -o /dev/null -w "%{http_code}" -X POST \
  "https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-start" \
  -H "Content-Type: application/json"
```

Expected: `401`

### D2. zoom-oauth-callback (expect 302 without JWT if public)

```bash
curl -s -o /dev/null -w "%{http_code}" -L -X GET \
  "https://nvtozwtuyhwqkqvftpyi.supabase.co/functions/v1/zoom-oauth-callback?error=test"
```

- If JWT verified: `401`
- If public: `302` redirect to `cotrainr://video/zoom-connected?error=test`

### D3. Full OAuth flow (browser)

1. Log in to app as trainer.
2. Tap Connect Zoom.
3. Browser opens Zoom authorize page.
4. Complete Zoom login.
5. Zoom redirects to callback; app should open with deep link.

### D4. Check Supabase logs

- Edge Functions → zoom-oauth-start: look for `[zoom-oauth-start] redirect_uri=...`
- Edge Functions → zoom-oauth-callback: if 401, no logs; if public, look for `[zoom-oauth-callback]` entries.
