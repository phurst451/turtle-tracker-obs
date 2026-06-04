# Deploy Checklist — Ormond Turtle Nest Log

## Step 1 — Rotate your Supabase service role key (DO THIS FIRST)
1. Go to https://supabase.com → your project
2. Settings → API
3. Under "Service role key" → click Reveal → click "Generate new key"
4. Copy and store the new key somewhere safe (you won't need it in the app)

---

## Step 2 — Get your anon key
1. Same page: Settings → API
2. Copy the **anon / public** key (starts with `eyJ...`)

---

## Step 3 — Paste the anon key into the HTML
Open `turtle-nest-log.html` and find this line near the top of the `<script>` block:

```js
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY_HERE';  // ← replace this
```

Replace `YOUR_ANON_KEY_HERE` with your actual anon key.

---

## Step 4 — Run the Supabase SQL
1. Go to your Supabase project → **SQL Editor** → **New query**
2. Open `supabase-setup.sql` and paste the entire contents
3. Click **Run**
4. You should see "Success" with no errors

---

## Step 5 — Create the photo storage bucket (if SQL didn't do it)
If the storage INSERT in the SQL errored (it sometimes requires the UI):
1. Go to **Storage** → **New bucket**
2. Name: `nest-photos`
3. Toggle **Public** to ON
4. Click **Create bucket**
5. Then go to **Policies** → add policies for SELECT, INSERT, DELETE using the "All users" / anon template

---

## Step 6 — Deploy to Vercel
Vercel handles a single HTML file with zero config.

### Option A: Drag-and-drop (easiest)
1. Go to https://vercel.com → Log in (or sign up free)
2. Click **Add New → Project**
3. Choose **"Deploy from file upload"** (or drag the HTML file)
4. Drop `turtle-nest-log.html` into the upload zone
5. Click **Deploy** — you'll get a URL like `turtle-nest-log.vercel.app`

### Option B: GitHub (recommended for updates)
1. Create a free GitHub account if you don't have one
2. Create a new repo called `turtle-nest-log`
3. Upload `turtle-nest-log.html` to the repo
4. Go to https://vercel.com → **Add New → Project** → **Import Git Repository**
5. Select your repo → click **Deploy**
6. Future updates: just edit the file on GitHub → Vercel auto-redeploys in ~30 seconds

---

## Step 7 — Test it
1. Open your Vercel URL on your phone
2. Tap the **+** FAB on the map
3. Tap somewhere on the beach to place a pin
4. Fill in the form and save
5. The nest should appear on the map with a countdown and in the Nests list
6. Tap "Share Card" to generate the Facebook-ready card

---

## Sharing tip
The Share Card is designed for screenshots. When you tap "📸 Screenshot to share":
- On iPhone: press Side Button + Volume Up
- On Android: press Power + Volume Down
Then share the screenshot to your neighborhood Facebook group!

---

## Troubleshooting
| Problem | Fix |
|---|---|
| "Could not load nests" toast | Check the anon key is pasted correctly in the HTML |
| Photo upload fails | Confirm the `nest-photos` bucket exists and is set to Public |
| Map is blank | Check internet connection — map tiles load from ESRI |
| Nest doesn't save | Open browser DevTools → Console for the error message |
