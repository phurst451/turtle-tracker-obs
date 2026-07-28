#!/bin/bash
# Turtle Nest Log — data backup + keep-alive.
#
# Does two jobs at once:
#   1. Dumps public.turtle_nests to a dated JSON file, and downloads any nest
#      photos not already saved. Until now this data existed in exactly one
#      free-tier Supabase project and nowhere else.
#   2. Any request resets Supabase's ~7-day free-tier inactivity timer. That
#      timer is what paused the project and took the app down in July 2026.
#
# Credentials are read out of index.html so there is a single source of truth:
# restore or recreate the Supabase project, update the app, and this follows.
#
# Run by ~/Library/LaunchAgents/com.phillip.turtle-backup.plist.
# Manual run:  ./backup.sh

set -uo pipefail
cd "$(dirname "$0")" || exit 1

# launchd gives us a minimal PATH, so call these by absolute path.
CURL=/usr/bin/curl
JQ=/usr/bin/jq

# NOT ~/Documents. macOS TCC blocks launchd agents from writing to Documents,
# Desktop and Downloads — the job runs, reports success to launchd, and writes
# nothing. ~/ itself is unprotected. Override with TURTLE_BACKUP_DIR only if
# the new location is outside those protected folders too.
DEST="${TURTLE_BACKUP_DIR:-$HOME/turtle-nest-backups}"
KEEP_DAYS=400          # prune JSON snapshots older than this; photos are kept
LOG="$DEST/backup.log"

mkdir -p "$DEST/photos" || exit 1

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }
say() { printf '%s\n' "$*"; log "$*"; }

say "── backup run starting ──"

# ── Read Supabase config from the app ────────────────────────────
URL=$(sed -n "s/.*const SUPABASE_URL[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" index.html | head -1)
KEY=$(sed -n "s/.*const SUPABASE_ANON_KEY[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" index.html | head -1)

if [[ -z "$URL" || -z "$KEY" ]]; then
  say "FAIL: could not read SUPABASE_URL / SUPABASE_ANON_KEY from index.html"
  exit 1
fi

# ── Fetch the table ──────────────────────────────────────────────
STAMP=$(date '+%Y-%m-%d')
TMP=$(mktemp -t turtle-backup) || exit 1
trap 'rm -f "$TMP"' EXIT

CODE=$("$CURL" -sS -m 60 -w '%{http_code}' -o "$TMP" \
  -H "apikey: $KEY" \
  -H "Authorization: Bearer $KEY" \
  "$URL/rest/v1/turtle_nests?select=*&order=created_at.asc" 2>>"$LOG")
RC=$?

if [[ $RC -ne 0 ]]; then
  # rc 6 = host not resolved, which is what a paused/deleted project looks like.
  if [[ $RC -eq 6 ]]; then
    say "FAIL: $URL does not resolve — the Supabase project is paused or deleted."
    say "      Restore it at https://supabase.com/dashboard, then rerun."
  else
    say "FAIL: curl exited $RC — no backup written, previous snapshots untouched."
  fi
  exit 1
fi

if [[ "$CODE" != "200" ]]; then
  say "FAIL: HTTP $CODE from Supabase — $(head -c 200 "$TMP")"
  exit 1
fi

# Never let a truncated or error response overwrite a good backup.
if ! "$JQ" -e 'type == "array"' "$TMP" >/dev/null 2>&1; then
  say "FAIL: response was not a JSON array — $(head -c 200 "$TMP")"
  exit 1
fi

COUNT=$("$JQ" 'length' "$TMP")
OUT="$DEST/nests-$STAMP.json"
"$JQ" '.' "$TMP" > "$OUT" || { say "FAIL: could not write $OUT"; exit 1; }
say "saved $COUNT nests → $OUT"

if [[ "$COUNT" -eq 0 ]]; then
  say "WARNING: the table returned zero rows. Keeping the snapshot, but check"
  say "         the app before trusting this as the current state."
fi

# ── Download any photos we don't already have ────────────────────
NEW=0; MISS=0
while IFS= read -r photo_url; do
  [[ -z "$photo_url" || "$photo_url" == "null" ]] && continue
  name=$(basename "${photo_url%%\?*}")
  [[ -z "$name" ]] && continue
  target="$DEST/photos/$name"
  [[ -f "$target" ]] && continue
  if "$CURL" -sS -m 120 -f -o "$target" "$photo_url" 2>>"$LOG"; then
    NEW=$((NEW + 1))
  else
    rm -f "$target"
    MISS=$((MISS + 1))
    log "photo download failed: $photo_url"
  fi
done < <("$JQ" -r '.[].photo_url // empty' "$TMP")

TOTAL=$(find "$DEST/photos" -type f ! -name '.*' | wc -l | tr -d ' ')
say "photos: $NEW new, $MISS failed, $TOTAL held locally"

# ── Prune old snapshots (photos are never pruned) ────────────────
PRUNED=$(find "$DEST" -maxdepth 1 -name 'nests-*.json' -type f -mtime +$KEEP_DAYS -print -delete | wc -l | tr -d ' ')
[[ "$PRUNED" -gt 0 ]] && say "pruned $PRUNED snapshot(s) older than $KEEP_DAYS days"

say "── backup run OK ──"
