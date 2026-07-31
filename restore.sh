#!/bin/bash
# Turtle Nest Log — restore a backup into a Supabase project.
#
# Reverses backup.sh: re-uploads the nest photos to the nest-photos bucket,
# rewrites every photo_url to point at the target project, and inserts the
# rows with their original ids and created_at timestamps preserved.
#
# Reads the TARGET project from index.html, same as backup.sh — so the
# intended order after losing a project is:
#   1. create the new project, run supabase-setup.sql
#   2. update SUPABASE_URL / SUPABASE_ANON_KEY in index.html
#   3. ./restore.sh --execute
#
# Dry run by default. Nothing is written until you pass --execute.
#
#   ./restore.sh                          # plan only, newest snapshot
#   ./restore.sh --snapshot FILE          # plan a specific snapshot
#   ./restore.sh --execute                # actually restore
#   ./restore.sh --execute --force        # ...even if the table isn't empty

set -uo pipefail
cd "$(dirname "$0")" || exit 1

CURL=/usr/bin/curl
JQ=/usr/bin/jq
BUCKET=nest-photos

BACKUP_DIR="${TURTLE_BACKUP_DIR:-$HOME/turtle-nest-backups}"
SNAPSHOT=""
EXECUTE=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute)  EXECUTE=1; shift ;;
    --force)    FORCE=1; shift ;;
    --snapshot) SNAPSHOT="${2:-}"; shift 2 ;;
    -h|--help)  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

die() { echo "✗ $*" >&2; exit 1; }

# ── Locate the snapshot ──────────────────────────────────────────
[[ -z "$SNAPSHOT" ]] && SNAPSHOT=$(ls -t "$BACKUP_DIR"/nests-*.json 2>/dev/null | head -1)
[[ -n "$SNAPSHOT" && -f "$SNAPSHOT" ]] || die "no snapshot found in $BACKUP_DIR (pass --snapshot FILE)"
"$JQ" -e 'type == "array"' "$SNAPSHOT" >/dev/null 2>&1 || die "$SNAPSHOT is not a JSON array"

PHOTO_DIR="$(dirname "$SNAPSHOT")/photos"
ROWS=$("$JQ" 'length' "$SNAPSHOT")

# ── Target project, read from the app ────────────────────────────
URL=$(sed -n "s/.*const SUPABASE_URL[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" index.html | head -1)
KEY=$(sed -n "s/.*const SUPABASE_ANON_KEY[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" index.html | head -1)
[[ -n "$URL" && -n "$KEY" ]] || die "could not read SUPABASE_URL / SUPABASE_ANON_KEY from index.html"

AUTH=(-H "apikey: $KEY" -H "Authorization: Bearer $KEY")

echo "snapshot : $SNAPSHOT  ($ROWS nests)"
echo "photos   : $PHOTO_DIR"
echo "target   : $URL"
echo

# ── Preflight ────────────────────────────────────────────────────
EXISTING=$("$CURL" -sS -m 30 "${AUTH[@]}" "$URL/rest/v1/turtle_nests?select=id" 2>/dev/null | "$JQ" 'length' 2>/dev/null)
[[ -z "$EXISTING" || "$EXISTING" == "null" ]] && die "target unreachable, or turtle_nests missing — run supabase-setup.sql first"

echo "target already holds $EXISTING nest(s)"
if [[ "$EXISTING" -gt 0 && $FORCE -eq 0 ]]; then
  echo
  echo "  Refusing to restore into a non-empty table. Rows are upserted by id,"
  echo "  so a restore would overwrite any row sharing an id with the snapshot."
  echo "  If that is what you want, re-run with --force."
  [[ $EXECUTE -eq 1 ]] && exit 1
fi

# ── Work out what needs doing ────────────────────────────────────
WITH_PHOTO=$("$JQ" '[.[] | select(.photo_url != null)] | length' "$SNAPSHOT")
MISSING=0; PRESENT=0
while IFS= read -r u; do
  n=$(basename "${u%%\?*}")
  if [[ -f "$PHOTO_DIR/$n" ]]; then PRESENT=$((PRESENT+1)); else MISSING=$((MISSING+1)); echo "  ! photo not in backup: $n"; fi
done < <("$JQ" -r '.[].photo_url // empty' "$SNAPSHOT")

echo "photos to upload: $PRESENT of $WITH_PHOTO referenced"
[[ $MISSING -gt 0 ]] && echo "  $MISSING referenced photo(s) are missing locally — those nests will restore with photo_url = null"

if [[ $EXECUTE -eq 0 ]]; then
  echo
  echo "DRY RUN — nothing written. Re-run with --execute to restore."
  exit 0
fi

# ── 1. Upload photos ─────────────────────────────────────────────
echo
echo "uploading photos…"
UP_OK=0; UP_FAIL=0
while IFS= read -r u; do
  n=$(basename "${u%%\?*}")
  f="$PHOTO_DIR/$n"
  [[ -f "$f" ]] || continue
  mime=$(file --mime-type -b "$f")
  code=$("$CURL" -sS -m 300 -o /dev/null -w '%{http_code}' -X POST \
    "${AUTH[@]}" -H "Content-Type: $mime" -H "x-upsert: true" \
    --data-binary "@$f" "$URL/storage/v1/object/$BUCKET/$n")
  if [[ "$code" == "200" ]]; then UP_OK=$((UP_OK+1)); else UP_FAIL=$((UP_FAIL+1)); echo "  ✗ $n → HTTP $code"; fi
done < <("$JQ" -r '.[].photo_url // empty' "$SNAPSHOT")
echo "  uploaded $UP_OK, failed $UP_FAIL"

# ── 2. Rewrite photo_url onto the target, then insert ────────────
# Photos are stored flat under their basename, so the basename from the old
# URL is also the new object path — only the origin changes. A nest whose
# photo is missing from the backup gets null rather than a dead link.
PAYLOAD=$(mktemp -t turtle-restore) || exit 1
trap 'rm -f "$PAYLOAD"' EXIT

AVAILABLE=$(cd "$PHOTO_DIR" 2>/dev/null && ls | "$JQ" -R . | "$JQ" -s .) || AVAILABLE='[]'
"$JQ" --arg base "$URL/storage/v1/object/public/$BUCKET/" --argjson have "$AVAILABLE" '
  map(
    if .photo_url == null then .
    else
      (.photo_url | split("?")[0] | split("/") | last) as $n
      | if ($have | index($n)) then .photo_url = $base + $n else .photo_url = null end
    end
  )
' "$SNAPSHOT" > "$PAYLOAD" || die "failed to rewrite photo URLs"

echo "inserting $ROWS nests…"
RESP=$("$CURL" -sS -m 120 -w '\n%{http_code}' -X POST \
  "${AUTH[@]}" -H "Content-Type: application/json" \
  -H "Prefer: return=minimal,resolution=merge-duplicates" \
  --data-binary "@$PAYLOAD" "$URL/rest/v1/turtle_nests?on_conflict=id")
CODE=$(tail -1 <<<"$RESP"); BODY=$(sed '$d' <<<"$RESP")

if [[ "$CODE" != "201" && "$CODE" != "200" && "$CODE" != "204" ]]; then
  die "insert failed — HTTP $CODE: $(head -c 400 <<<"$BODY")"
fi

FINAL=$("$CURL" -sS -m 30 "${AUTH[@]}" "$URL/rest/v1/turtle_nests?select=id" | "$JQ" 'length')
echo
echo "✓ restore complete — target now holds $FINAL nest(s)"
echo "  photos uploaded: $UP_OK   failed: $UP_FAIL   missing from backup: $MISSING"
[[ "$FINAL" -lt "$ROWS" ]] && echo "  ⚠ expected at least $ROWS — check the output above"
exit 0
