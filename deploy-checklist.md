# Deploy & Recovery Checklist — Ormond Turtle Nest Log

_Rewritten 2026-07-28. The previous version described a Vercel deploy of `turtle-nest-log.html` with a placeholder anon key — none of that matches how this app is actually hosted._

---

## A. Routine deploy (the normal case)

The live site is **https://turtle-tracker-obs.netlify.app/**, a Netlify **drag-and-drop** site. It is **not** connected to the GitHub repo.

> **`git push` does not deploy.** Pushing only updates GitHub. This is how the live site sat 3 commits behind for a month.

### ✅ The Netlify CLI is installed and logged in as `phurst451` (as of 2026-07-28)
So a deploy is now one command:
```bash
./deploy.sh "what changed"
```
That commits, pushes, **and** publishes. Hard-refresh the live URL afterwards and confirm the change is actually there.

> **`deploy.sh` publishes a temp dir containing only `index.html` — never `--dir .`.** Deploying the repo root would put `Turtle_Nest_Log.xlsx` (all the nest data), `make_nest_report.py` and these internal docs on the public site.

### Fallback — manual drag
If the CLI is unavailable, drag `index.html` onto the Deploys tab: https://app.netlify.com/sites/turtle-tracker-obs/deploys

---

## B. Recovering a paused / deleted Supabase project

Free-tier Supabase projects pause after ~7 days of inactivity, and a paused project's subdomain stops resolving (NXDOMAIN). Symptom: the app loads, the map draws, and there are **zero nests**, with a red "Can't reach the nest database" banner.

**Check which case you're in:**
```bash
dig +short limdyowwnlleyyswwkeo.supabase.co
```
Empty output = the host is gone.

### If it's only paused
1. https://supabase.com/dashboard → project `turtle-tracker` → **Restore**
2. Wait for it to come up, then re-run the `dig` above until it returns an address
3. Reload the app — the banner should clear on its own

### If it was deleted — rebuild
1. Create a new Supabase project
2. **SQL Editor → New query** → paste all of `supabase-setup.sql` → **Run**
   - This now includes `hatch_date`, `num_hatchlings`, `whole_eggs_remaining` and the **UPDATE** policy the edit form needs
3. **Storage** → confirm a public bucket named `nest-photos` exists (the SQL creates it; the UI sometimes needs to do it instead)
4. **Settings → API** → copy the **anon / public** key
5. Update both places that hardcode the project:
   - `index.html`, near the top of the `<script>` block (~line 660): `SUPABASE_URL`, `SUPABASE_ANON_KEY`
   - `make_nest_report.py` (~line 10): `SUPABASE_URL`, `ANON_KEY`
6. Deploy per section A
7. Re-enter the nests. `Turtle_Nest_Log.xlsx` lists 14 nests as of 2026-06-16 with nest #, nearest street, date found and hatch window — but **no coordinates, species, or notes**, so pins have to be re-placed by hand.

---

## C. Automatic backup + keep-alive — **installed 2026-07-28**

`backup.sh` runs on a launchd schedule and does both jobs at once: it dumps `turtle_nests` to a dated JSON file and downloads any new nest photos, and the request itself resets Supabase's ~7-day inactivity timer.

| | |
|---|---|
| Script | `backup.sh` (reads the Supabase URL + anon key straight out of `index.html`, so there's one source of truth) |
| Schedule | **Sunday and Wednesday, 11:00** — see note below |
| Backups | `~/turtle-nest-backups/` — `nests-YYYY-MM-DD.json` + `photos/` |
| Log | `~/turtle-nest-backups/backup.log` |
| Job | `~/Library/LaunchAgents/com.phillip.turtle-backup.plist` (copy kept in this repo) |

**Why twice a week and not weekly:** the pause threshold is ~7 days, so a 7-day job has zero margin — one run missed because the Mac was off is enough to let the project pause. Two runs 3–4 days apart survive a missed one. For a true weekly job, delete the second `<dict>` from the plist.

**⚠️ Do not point the backups at `~/Documents`, `~/Desktop` or `~/Downloads`.** macOS TCC blocks launchd agents from writing there. The job still "succeeds" as far as launchd is concerned and writes nothing — this bit us during setup. `~/` itself is unprotected, which is why backups live there.

### Useful commands
```bash
./backup.sh                                                    # run it now
tail -20 ~/turtle-nest-backups/backup.log                      # what happened last
launchctl list | grep turtle                                   # middle column is the last exit code; 0 is good
launchctl kickstart -p gui/$(id -u)/com.phillip.turtle-backup  # force a scheduled run
```

### Reinstalling the job
```bash
cp com.phillip.turtle-backup.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.phillip.turtle-backup.plist
```

### Restoring from a backup
The JSON is the full table — every column, including coordinates. To reload it into a fresh project after running `supabase-setup.sql`:
```bash
URL=$(sed -n "s/.*const SUPABASE_URL[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" index.html | head -1)
KEY=$(sed -n "s/.*const SUPABASE_ANON_KEY[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" index.html | head -1)
curl -X POST "$URL/rest/v1/turtle_nests" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  --data-binary @~/turtle-nest-backups/nests-YYYY-MM-DD.json
```
Photos would need re-uploading to the `nest-photos` bucket and the `photo_url` values rewritten to the new project's domain.

---

## D. Smoke test after any deploy

1. Open the live URL on a phone
2. Confirm **no** red banner and that existing nests appear on the map
3. Tap **＋** → allow location → pin drops at your spot
4. Save a test nest with a photo → appears on map and in the Nests list
5. Tap its marker → detail card → **Edit** → change the notes, replace the photo → **Save Changes** → confirm it sticks after a reload
   _(If edits silently do nothing, the UPDATE RLS policy is missing — section B step 2.)_
6. Delete the test nest from the edit form → confirm it disappears
7. Open `?view` on the URL → add/edit/report controls should be hidden

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Red "Can't reach the nest database" banner | Section B — project is paused or deleted |
| Live site missing a change you made | You pushed but never dragged to Netlify — section A |
| Edits appear to save but revert on reload | Missing UPDATE policy on `turtle_nests` |
| Photo upload fails | `nest-photos` bucket missing, not public, or missing INSERT policy |
| Map blank but UI fine | ESRI tile fetch failed — check connectivity |
| Nest won't save | DevTools → Console for the Supabase error |
