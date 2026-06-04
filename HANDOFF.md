# Turtle Nest Log — Handoff Context

## What This Is
A mobile-first sea turtle nest tracking web app for volunteer monitors on the beach stretch from Al Weeks Park to Verona Lookout Tower in Ormond by the Sea, FL.

## Live URL
**https://turtle-tracker-obs.netlify.app/**
Hosted on Netlify (free tier, drag-and-drop deploys). To update: drag a new `index.html` to the Deploys tab.

## Architecture
Single self-contained HTML file — no build step, no framework, no dependencies to install.
- **Map:** Leaflet.js + ESRI satellite tiles
- **Database + Storage:** Supabase (Postgres + Storage)
- **Frontend:** Vanilla JS

## Supabase Project
- **Project name:** turtle-tracker
- **URL:** `https://limdyowwnlleyyswwkeo.supabase.co`
- **Anon/publishable key:** `sb_publishable_GMO9je7DtCsdQsivWcRklA_4Yzpz3ke`
- **Dashboard:** https://supabase.com/dashboard/project/limdyowwnlleyyswwkeo

### Database schema
```sql
public.turtle_nests (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  nest_number     TEXT        NOT NULL,
  species         TEXT        NOT NULL CHECK (species IN ('loggerhead','leatherback','green')),
  date_found      DATE        NOT NULL,
  latitude        DOUBLE PRECISION NOT NULL,
  longitude       DOUBLE PRECISION NOT NULL,
  photo_url       TEXT,
  notes           TEXT,
  hatch_date_min  DATE,
  hatch_date_max  DATE,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
)
```
- RLS enabled with public SELECT / INSERT / DELETE policies
- Storage bucket: `nest-photos` (public)

## Hatch Windows (UF/IFAS)
| Species     | Min days | Max days |
|-------------|----------|----------|
| Loggerhead  | 55       | 65       |
| Leatherback | 60       | 70       |
| Green       | 52       | 56       |

## Features Implemented
- Satellite map pre-fitted to beach (29.355–29.393°N)
- **GPS-first pin drop** — tap ＋ FAB → uses device geolocation, zooms to spot, drops blue preview dot; falls back to tap-on-map if GPS denied
- Add nest form: nest number, species picker, date, photo (camera capture), notes
- Hatch date auto-calculated on species + date selection
- Species-colored map markers (orange=loggerhead, blue=leatherback, green=green)
- Popup with hatch countdown on each marker
- Scrollable nest list with days-remaining badge (turns red when ≤7 days, hatched state)
- Tap list card → flies to marker on map
- Share card — screenshot-ready for Facebook neighborhood groups
- Delete nest (removes from DB + map)
- Supabase persistence + photo storage
- Toast notifications, loading overlay

## File Location
The single deployable file is `index.html`. Keep it as one file — no bundler needed.

## Known Issues / To-Do
- Storage RLS policies for `nest-photos` bucket allow public INSERT/DELETE — fine for trusted community use but worth tightening if the app goes wider
- No user authentication (intentional for simplicity — all monitors share the same view)
- No edit-nest functionality (delete and re-add is the current workaround)
- Share card uses screenshot; could upgrade to Web Share API or canvas-based image export
- Hatch date fields are nullable in DB (were added after initial table creation) — consider making NOT NULL with a migration

## Suggested Next Features
- Edit nest (update species, notes, photo)
- Filter list by species or status (hatched / active / critical)
- Push/email notification when nest enters hatch window
- Season stats summary (total nests, species breakdown, % hatched)
- Export to CSV for FWC reporting
