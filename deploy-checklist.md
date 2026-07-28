# Deploy & Recovery Checklist — Ormond Turtle Nest Log

_Rewritten 2026-07-28. The previous version described a Vercel deploy of `turtle-nest-log.html` with a placeholder anon key — none of that matches how this app is actually hosted._

---

## A. Routine deploy (the normal case)

The live site is **https://turtle-tracker-obs.netlify.app/**, a Netlify **drag-and-drop** site. It is **not** connected to the GitHub repo.

> **`git push` does not deploy.** Pushing only updates GitHub. This is how the live site sat 3 commits behind for a month.

### Option 1 — manual (works today)
1. `./deploy.sh "what changed"` — commits, pushes, and opens Finder with `index.html` selected
2. Drag `index.html` onto the Deploys tab: https://app.netlify.com/sites/turtle-tracker-obs/deploys
3. Hard-refresh the live URL and confirm the change is actually there

### Option 2 — one-time setup, then it's automatic
```bash
npm i -g netlify-cli && netlify link
```
After that `./deploy.sh "what changed"` commits, pushes, **and** publishes in one step.

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

## C. Keeping it from pausing again

Any DB request resets the 7-day inactivity timer. A weekly cron is enough:
```bash
curl -s -o /dev/null -H "apikey: $TURTLE_ANON_KEY" \
  "https://YOUR-PROJECT.supabase.co/rest/v1/turtle_nests?select=id&limit=1"
```
Better still, make that same job dump the table to a dated JSON file — right now the nest data has **no backup anywhere**.

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
