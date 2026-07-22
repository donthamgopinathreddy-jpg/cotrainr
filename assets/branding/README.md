# Cotrainr branding assets

Bundled locally — never required from Supabase at cold start.

## Vector masters (preferred)

| File | Use |
|------|-----|
| `vector/cotrainr_logo.svg` | **Master logo** — white symbol + orange blade. Render with `SvgPicture` / `CotrainrLogo`. |
| `vector/cotrainr_logo_white.svg` | All-white symbol for orange / photo backgrounds |
| `vector/orange_*.svg`, `light_glow.svg`, `abstract_lines.svg`, `corner_overlay.svg` | Splash atmosphere layers |

Never upscale PNG logos. Always render the mark from `cotrainr_logo.svg`.

## PNG ladder (from master)

`png/cotrainr_logo_{16…1024}.png` and `png/color/` — Lanczos downscales only.

## Photographic / raster

| File | Use |
|------|-----|
| `cotrainr_runner_athlete.png` | Splash athlete photo (no baked logo) |
| `cotrainr_runner_splash_clean.png` | Fallback full splash art |
| `cotrainr_auth_background.png` | Login / Create Account background |
| `cotrainr_orange_full_logo.png` | Pattern wash reference only |
| `icons/*` | App icon + favicons (orange bg + white symbol) |
| `references/*` | Design references only (not UI) |

Brand orange: `DesignTokens.accentOrange` (`#FF8A00`).

Rebuild vectors: `python tools/build_vector_branding.py`
