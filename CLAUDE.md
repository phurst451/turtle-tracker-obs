# Turtle Nest Log — Ormond by the Sea

Mobile-first sea turtle nest tracker for volunteer monitors on the beach from Al Weeks Park to Verona Lookout Tower.

## ⚠️ Read first
**`HANDOFF.md` is the source of truth** — architecture, schema, full feature list, known issues. **`deploy-checklist.md`** is the operational runbook: deploying, recovering a paused project, the backup job, and the post-deploy smoke test. Read those before acting.

**This is a separate repo from `personal-tools`,** even though it sits inside that folder. Its own remote: `github.com/phurst451/turtle-tracker-obs`. Nothing here belongs to the Home Assistant work next door.

## What it is
One self-contained `site/index.html` — no build step, no framework, no install. It lives in `site/` because that directory is the **entire publish surface** (pinned by `netlify.toml`); nothing outside it can reach the live site. Leaflet + ESRI satellite tiles, Supabase (Postgres + Storage), vanilla JS. CDN: `exifr` (GPS from photo EXIF), `heic2any` (iPhone HEIC→JPEG), `exceljs` (report export).

| Thing | Value |
|---|---|
| Live site | https://turtle-tracker-obs.netlify.app/ |
| Read-only link | same URL + `?view` (hides add/edit/report) |
| Supabase | `limdyowwnlleyyswwkeo.supabase.co` · [dashboard](https://supabase.com/dashboard/project/limdyowwnlleyyswwkeo) |
| Netlify | [project](https://app.netlify.com/projects/turtle-tracker-obs) — CLI installed and logged in |
| Backups | `~/turtle-nest-backups/` (JSON + photos) |

The Supabase URL and anon key are hardcoded near the top of the `<script>` block in `site/index.html` (~line 660). **`backup.sh` and `restore.sh` both read them from there** (as `$APP`) — it is the single source of truth. Update it after any project change and the scripts follow.

## Hard rules
- **Never enter Phillip's passwords or API keys anywhere.** Anything needing a real Supabase/Netlify login is his to do. The anon key is public and already ships in the deployed HTML — that one is fine to use.
- **`git push` deploys. The site builds from GitHub on every push to `main`.** What gets published is pinned by the committed `netlify.toml` → `publish = "site"`, which overrides the repo-root publish directory still set in the Netlify UI. **Never put anything in `site/` that isn't meant to be public**, and never hand-run `netlify deploy` — a manual deploy is just a second deploy the next CD build overwrites. Use `./deploy.sh "msg"`; it pushes, waits for that commit's build, then verifies the live app and 404-checks every repo file.
- **This app is used by real volunteers mid-season.** Deploying a half-working feature is visible immediately. Smoke-test per deploy-checklist §D.

## Scripts
| Script | Does |
|---|---|
| `./deploy.sh "msg"` | commit + push `site/index.html`, wait for the CD build, verify the publish surface |
| `./backup.sh` | dump table + photos to `~/turtle-nest-backups/`. **Does _not_ keep the project awake** — see gotchas |
| `./restore.sh` | rebuild a project from a snapshot (dry run by default) |
| `make_nest_report.py` | build `Turtle_Nest_Log.xlsx` (photos, map thumbnails, nearest street) |

## Top gotchas (each of these actually bit)
- **`git push` DOES deploy — this was the inverse of what these docs said, and it leaked the repo for 18 days.** The site is wired to GitHub CD (`build_settings.provider = github`, `repo_branch = main`). The old note here claimed the opposite, so `deploy.sh` ran a clean `--dir` deploy and then pushed — and the push triggered a repo-root CD build that republished everything ~3 minutes later, *after* the 404 check had passed. Found 2026-08-18. Always verify the live surface **after** the CD build lands, not after the CLI deploy.
- **The publish directory is pinned in a committed `netlify.toml`, not in the Netlify UI.** The UI setting still says repo root, and it is invisible from a fresh clone (it appears only in gitignored `.netlify/netlify.toml`) — which is why it went unnoticed twice. `netlify.toml` overrides it and travels with the repo. **Do not delete `netlify.toml`**, and if you ever change the publish dir, change it there.
- **Free Supabase projects pause and the subdomain stops resolving (NXDOMAIN).** The app then shows an empty map, which looks exactly like "no nests." **`backup.sh`'s REST reads do NOT count as activity.** The job ran Jul 29, 31, Aug 2, 5, 9, 12 and 16 — never a gap over 4 days — and Supabase still paused the project on 07-27 *and* 08-16 for ">7 days of inactivity". The keep-alive premise in `backup.sh`'s header is wrong. Treat pausing as a recurring certainty: back up on a schedule (that part works), and expect to un-pause from the dashboard. Supabase emails a warning ~1 day ahead — **those notices are currently going to Trash unread.**
- **macOS TCC blocks launchd agents from writing to `~/Documents`, `~/Desktop`, `~/Downloads`.** The job "succeeds" and writes nothing. That's why backups live in `~/`. Applies to any scheduled job on this Mac.
- **Supabase Storage public URLs are CDN-cached** — a deleted or replaced photo keeps serving the old bytes. Check the bucket listing, not the URL.
- **Schema drift is invisible until it fails.** The edit form shipped writing three columns that didn't exist, so Save never worked (`42703`), and `supabase-setup.sql` omitted `false_crawl` from the species CHECK. When adding a field to the form, add it to the table *and* to `supabase-setup.sql`.
- **`species` has four values** — `loggerhead`, `leatherback`, `green`, and `false_crawl` (came ashore, laid nothing). False crawls have no hatch window and render as "FC".

## Current state (2026-08-18)

*Last reconciled: 2026-10-21.*
**Just done:** Supabase confirmed back up after the 08-16 pause: all 27 nests present, fresh backup snapshot (08-18).
**Next step:** none recorded as pending in this file; read the dated notes below before starting.
**Blocker:** none

27 nests (25 loggerhead, 1 green, 1 false crawl), 2026-05-01 → 06-29, all with coordinates; 22 photos. Edit form works (fixed 07-29). Backup job runs unattended and its snapshots are good.

Supabase was paused 2026-08-16 15:10 UTC (that's the "can't reach the nest database" symptom) and is **back up as of 08-18** — verified reachable, 200, all 27 nests present, nothing lost. Fresh snapshot: `~/turtle-nest-backups/nests-2026-08-18.json`.

Publish surface: repo restructured 08-18 so only `site/index.html` is publishable, and `Turtle_Nest_Log.xlsx` is no longer tracked in git.

**Open / next up**
- `2035 TV time`-style polish aside, the app is feature-complete for the season. Remaining ideas in `HANDOFF.md` → Suggested Next Features: filter by species/status, hatch-window notification, season stats, CSV export for FWC.
- `restore.sh --execute --force` has never been run start-to-finish (every step verified individually; the forced overwrite was blocked as destructive).
- Storage RLS allows public INSERT/DELETE on `nest-photos` — fine for a trusted group, worth tightening if the app goes wider.
- **The keep-alive doesn't work.** `backup.sh` reads the table twice a week and the project still paused twice. Either accept manual un-pausing as routine, or move off the free tier. Do not trust the "any request resets the timer" claim.
- **Supabase mail is going to Trash unread** — including the "going to be paused" warning that arrives ~1 day ahead, and repeated "security vulnerabilities detected in your projects" notices (Jul 21, Aug 11, Aug 18). Worth a filter that keeps them in the inbox, and worth actually reading the security ones.
- **The Netlify UI publish directory still says repo root.** It is now overridden by the committed `netlify.toml`, so it is no longer live-dangerous — but correcting it in the UI (Build & deploy → Publish directory → `site`) would remove the last copy of the setting that caused two leaks. Needs Phillip's login.
- `Turtle_Nest_Log.xlsx` is untracked as of 08-18 but **still present in git history**, and the GitHub repo is public. Purging it needs a history rewrite + force-push — not done.
