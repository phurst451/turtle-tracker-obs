# Turtle Nest Log — Ormond by the Sea

Mobile-first sea turtle nest tracker for volunteer monitors on the beach from Al Weeks Park to Verona Lookout Tower.

## ⚠️ Read first
**`HANDOFF.md` is the source of truth** — architecture, schema, full feature list, known issues. **`deploy-checklist.md`** is the operational runbook: deploying, recovering a paused project, the backup job, and the post-deploy smoke test. Read those before acting.

**This is a separate repo from `personal-tools`,** even though it sits inside that folder. Its own remote: `github.com/phurst451/turtle-tracker-obs`. Nothing here belongs to the Home Assistant work next door.

## What it is
One self-contained `index.html` — no build step, no framework, no install. Leaflet + ESRI satellite tiles, Supabase (Postgres + Storage), vanilla JS. CDN: `exifr` (GPS from photo EXIF), `heic2any` (iPhone HEIC→JPEG), `exceljs` (report export).

| Thing | Value |
|---|---|
| Live site | https://turtle-tracker-obs.netlify.app/ |
| Read-only link | same URL + `?view` (hides add/edit/report) |
| Supabase | `limdyowwnlleyyswwkeo.supabase.co` · [dashboard](https://supabase.com/dashboard/project/limdyowwnlleyyswwkeo) |
| Netlify | [project](https://app.netlify.com/projects/turtle-tracker-obs) — CLI installed and logged in |
| Backups | `~/turtle-nest-backups/` (JSON + photos) |

The Supabase URL and anon key are hardcoded near the top of the `<script>` block in `index.html` (~line 660). **`backup.sh` and `restore.sh` both read them from there** — it is the single source of truth. Update it after any project change and the scripts follow.

## Hard rules
- **Never enter Phillip's passwords or API keys anywhere.** Anything needing a real Supabase/Netlify login is his to do. The anon key is public and already ships in the deployed HTML — that one is fine to use.
- **Never run `netlify deploy` by hand — always `./deploy.sh "msg"`.** Any deploy that doesn't pass an explicit `--dir` publishes the whole repo: `Turtle_Nest_Log.xlsx` (the entire nest dataset, exact GPS of protected nests), `make_nest_report.py`, the launchd plist and these docs. `deploy.sh` stages a temp dir holding only `index.html`. Verify with a 404 check after every deploy.
- **This app is used by real volunteers mid-season.** Deploying a half-working feature is visible immediately. Smoke-test per deploy-checklist §D.

## Scripts
| Script | Does |
|---|---|
| `./deploy.sh "msg"` | commit + push + publish `index.html` to Netlify |
| `./backup.sh` | dump table + photos to `~/turtle-nest-backups/`; also resets the inactivity timer |
| `./restore.sh` | rebuild a project from a snapshot (dry run by default) |
| `make_nest_report.py` | build `Turtle_Nest_Log.xlsx` (photos, map thumbnails, nearest street) |

## Top gotchas (each of these actually bit)
- **`git push` does NOT deploy.** Netlify is not connected to the repo. Production sat 3 commits stale for a month because `deploy.sh` printed "✅ Deployed" after only pushing. Always confirm the live file matches local.
- **The dangerous form is the *omitted* `--dir`, not `--dir .`.** The Netlify site's publish directory is set to this repo's root, in the Netlify UI (`publishOrigin = "ui"`) — it appears locally in `.netlify/netlify.toml`, which is gitignored and therefore invisible from a fresh clone. So a bare `netlify deploy --prod` silently picks up the repo root and publishes everything. That happened on 2026-07-31: a deploy made outside `deploy.sh` put the xlsx, both `.sql` files, every script and all internal docs on the public site until a clean redeploy evicted them. Changing the publish directory in the Netlify UI is the durable fix and needs Phillip's login.
- **Free Supabase projects pause after ~7 days idle** and the subdomain stops resolving (NXDOMAIN). The app then shows an empty map, which looks exactly like "no nests." `backup.sh` runs Sun + Wed to keep it awake — if that job stops, the project will pause again.
- **macOS TCC blocks launchd agents from writing to `~/Documents`, `~/Desktop`, `~/Downloads`.** The job "succeeds" and writes nothing. That's why backups live in `~/`. Applies to any scheduled job on this Mac.
- **Supabase Storage public URLs are CDN-cached** — a deleted or replaced photo keeps serving the old bytes. Check the bucket listing, not the URL.
- **Schema drift is invisible until it fails.** The edit form shipped writing three columns that didn't exist, so Save never worked (`42703`), and `supabase-setup.sql` omitted `false_crawl` from the species CHECK. When adding a field to the form, add it to the table *and* to `supabase-setup.sql`.
- **`species` has four values** — `loggerhead`, `leatherback`, `green`, and `false_crawl` (came ashore, laid nothing). False crawls have no hatch window and render as "FC".

## Current state (2026-07-31)
27 nests (25 loggerhead, 1 green, 1 false crawl), 2026-05-01 → 06-29, all with coordinates; 22 photos. Live site current. Backup job verified running unattended. Edit form works (fixed 07-29 — it never had before). Publish surface verified clean 07-31: every repo file 404s, only `index.html` serves.

**Open / next up**
- `2035 TV time`-style polish aside, the app is feature-complete for the season. Remaining ideas in `HANDOFF.md` → Suggested Next Features: filter by species/status, hatch-window notification, season stats, CSV export for FWC.
- `restore.sh --execute --force` has never been run start-to-finish (every step verified individually; the forced overwrite was blocked as destructive).
- Storage RLS allows public INSERT/DELETE on `nest-photos` — fine for a trusted group, worth tightening if the app goes wider.
- **Netlify publish directory still points at the repo root.** The 07-31 leak is cleaned up, but the setting that caused it is unchanged, so the next hand-run `netlify deploy` re-exposes everything. Phillip to change it in the Netlify UI (Build & deploy → Publish directory).
