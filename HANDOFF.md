# Turtle Nest Log — Handoff Context

_Last verified 2026-07-28._

## What This Is
A mobile-first sea turtle nest tracking web app for volunteer monitors on the beach stretch from Al Weeks Park to Verona Lookout Tower in Ormond by the Sea, FL.

## Backend status — restored 2026-07-28
Earlier on 2026-07-28 `limdyowwnlleyyswwkeo.supabase.co` returned **NXDOMAIN** — the free-tier project had been **paused after ~7 days of inactivity**, which drops the subdomain from DNS. The app still loaded and drew the map but showed **zero nests**.

It is now **back up**: 27 nests (25 loggerhead, 1 green, 1 false crawl), date range 2026-05-01 → 2026-06-29, all with coordinates, 22 photos.

**If it happens again:** https://supabase.com/dashboard → project `turtle-tracker` → **Restore**. Check with `dig +short limdyowwnlleyyswwkeo.supabase.co` — empty output means the host is gone. If it was deleted rather than paused, recreate it, run `supabase-setup.sql`, then update `SUPABASE_URL` / `SUPABASE_ANON_KEY` in `index.html` (~line 660) and `make_nest_report.py`.

**It should not happen again** — the twice-weekly `backup.sh` job now keeps the inactivity clock reset (deploy-checklist §C).

## Live URL
**https://turtle-tracker-obs.netlify.app/**

⚠️ **Netlify is NOT connected to the GitHub repo.** `git push` does **not** update the live site — that's how production silently fell 3 commits behind between 2026-06-29 and 2026-07-28.

The Netlify CLI is now installed and logged in, so `./deploy.sh "what changed"` commits, pushes and publishes in one step. **Deployed 2026-07-28** — the live site is current as of commit `b93ce0b`. Note `deploy.sh` publishes a temp dir holding only `index.html`; deploying `--dir .` would expose the xlsx, the report script and these docs publicly.

## Architecture
Single self-contained HTML file — no build step, no framework, nothing to install.
- **Map:** Leaflet 1.9.4 + ESRI satellite tiles
- **Database + Storage:** Supabase (Postgres + Storage)
- **Frontend:** vanilla JS
- **Also loaded from CDN:** `exifr` (GPS from photo EXIF), `heic2any` (iPhone HEIC → JPEG), `exceljs` (report export)

## Supabase Project
- **Project name:** turtle-tracker
- **URL:** `https://limdyowwnlleyyswwkeo.supabase.co` ← currently NXDOMAIN
- **Dashboard:** https://supabase.com/dashboard/project/limdyowwnlleyyswwkeo
- **Anon key:** the live key is the `eyJ…` JWT hardcoded in `index.html`. An `sb_publishable_GMO9je…` key is also floating around in old notes — both are for this same dead project. Whichever survives the restore, make sure `index.html` and `make_nest_report.py` agree.

### Database schema
```sql
public.turtle_nests (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  nest_number          TEXT        NOT NULL,
  species              TEXT        NOT NULL CHECK (species IN ('loggerhead','leatherback','green')),
  date_found           DATE        NOT NULL,
  latitude             DOUBLE PRECISION NOT NULL,
  longitude            DOUBLE PRECISION NOT NULL,
  photo_url            TEXT,
  notes                TEXT,
  hatch_date_min       DATE,
  hatch_date_max       DATE,
  hatch_date           DATE,        -- actual observed hatch
  num_hatchlings       INT,
  whole_eggs_remaining INT,
  created_at           TIMESTAMPTZ DEFAULT NOW() NOT NULL
)
```
- RLS enabled with public SELECT / INSERT / UPDATE / DELETE policies
- Storage bucket: `nest-photos` (public)
- ⚠️ `supabase-setup.sql` predates the last three columns — if you recreate the project from it, add `hatch_date`, `num_hatchlings`, `whole_eggs_remaining` by hand.

## Hatch Windows (UF/IFAS)
| Species     | Min days | Max days |
|-------------|----------|----------|
| Loggerhead  | 55       | 65       |
| Leatherback | 60       | 70       |
| Green       | 52       | 56       |

## Features Implemented
- Satellite map pre-fitted to the beach, auto-fits to nest bounds on load
- Street-name labels along the shore (Al Weeks → Verona)
- **GPS-first pin drop** — tap ＋ FAB → device geolocation, zooms in, drops a blue preview dot; falls back to tap-on-map if GPS is denied
- **GPS pulled from photo EXIF** via `exifr.gps()`, with a toast when a photo carries no GPS
- Add nest: nest number (auto-formatted), species picker, date, photo (camera capture, HEIC auto-converted), notes
- Hatch window auto-calculated from species + date found
- **Urgency-colored label markers** showing nest # and days remaining
- Tap a marker → **nest detail card** (not a bare popup)
- **Edit nest** — number, dates, notes, observed hatch date, hatchling count, whole eggs remaining, **and add/replace the photo**
- Delete nest, from either the list card or the edit form
- Nest list with days-remaining badge, sortable by number or due date
- **Report tab** — generates an Excel workbook with per-nest photo + map thumbnail
- **`?view` mode** — read-only public link (hides add/edit/report)
- Share card for Facebook neighborhood groups
- **Offline banner** — if the database can't be reached, a persistent red bar says so and disables adding, so an unreachable backend is never mistaken for "no nests"

## Companion scripts
| Script | What it does |
|---|---|
| `backup.sh` | Twice-weekly launchd job — dumps the table to `~/turtle-nest-backups/`, pulls down photos, and keeps the project from idling into a pause. Deploy-checklist §C. |
| `restore.sh` | Reverses it into a fresh project — re-uploads photos, repoints `photo_url`, reinserts nests with original ids. Dry run by default. Deploy-checklist §B. |
| `deploy.sh` | Commit + push + publish `index.html` to Netlify. |
| `make_nest_report.py` | Builds `Turtle_Nest_Log.xlsx` (photos, map thumbnails, nearest-street lookup). |

The committed `Turtle_Nest_Log.xlsx` is a **snapshot of 14 nests as of 2026-06-16** — a partial reference only. It holds no coordinates, species, or notes, so it is **not** a restore source; use a `backup.sh` snapshot.

## Known Issues / To-Do
- ~~The live DB is missing `hatch_date`, `num_hatchlings`, `whole_eggs_remaining`.~~ **Fixed 2026-07-29** — `migration-add-hatch-outcome-columns.sql` was run in the SQL Editor. Verified end to end afterwards: opened a real nest in the edit form, set all three fields, hit Save → "✅ Nest updated!", values confirmed persisted via the REST API, then restored to their original state (row byte-identical to the pre-test snapshot). Photo upload to the `nest-photos` bucket verified separately. The edit form now works; it never had against this project before.
- ~~No backup of the nest data.~~ **Solved 2026-07-28** — `backup.sh` on a launchd schedule (Sun + Wed) dumps the table to `~/turtle-nest-backups/` and pulls down photos, and the same request keeps the project from pausing. See deploy-checklist §C.
- Storage RLS on `nest-photos` allows public INSERT/DELETE — fine for trusted community use, worth tightening if it goes wider
- No authentication (intentional — all monitors share one view)
- Hatch-date columns are nullable (added after the initial table) — could be tightened with a migration
- `deploy-checklist.md` is a from-scratch setup guide, not a routine deploy doc — see the Live URL section above for day-to-day deploys

## Suggested Next Features
- Automatic weekly data export / backup (see above)
- Filter list by species or status (hatched / active / critical)
- Notification when a nest enters its hatch window
- Season stats summary (total nests, species breakdown, % hatched)
- CSV export for FWC reporting
