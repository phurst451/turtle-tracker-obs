#!/bin/bash
# Turtle Nest Log — publish the app.
#
# HOW THIS SITE DEPLOYS (this changed, and the old comment here was wrong):
# the Netlify project is wired to the GitHub repo and builds on every push to
# main. So `git push` IS the deploy. There is no drag-and-drop step and no
# `netlify deploy --dir` — a manual deploy only creates a second deploy that
# the next CD build overwrites. That race is exactly what leaked the repo on
# 2026-07-31: deploy.sh ran a clean --dir deploy at 16:00, its own git push
# triggered a repo-root CD build at 16:03, and the 404 check in between passed.
#
# What is published is pinned by netlify.toml -> publish = "site", which
# overrides the repo-root setting in the Netlify UI. site/ holds only
# index.html.
#
# This script pushes, waits for the CD build for THIS commit to go live, and
# then verifies both that the live app matches local and that repo files 404.
set -euo pipefail
cd "$(dirname "$0")"

SITE_ID=5036bbed-6da7-4417-9a27-1636d9925184   # not read from .netlify/, which is gitignored
SITE_URL=https://turtle-tracker-obs.netlify.app
APP=site/index.html

msg=${1:-"update"}

if [[ -n "$(git status --porcelain "$APP")" ]]; then
  git add "$APP"
  git commit -m "$msg"
else
  echo "· $APP unchanged — nothing to commit"
fi

git push
sha=$(git rev-parse HEAD)
echo "✅ Pushed $sha — Netlify builds from this push"

# ── Wait for the CD build for this exact commit ──────────────────
echo -n "· waiting for the build"
live=""
for _ in $(seq 1 60); do
  sleep 5; echo -n "."
  state=$(netlify api listSiteDeploys --data "{\"site_id\":\"$SITE_ID\"}" 2>/dev/null \
    | jq -r --arg sha "$sha" '.[] | select(.commit_ref == $sha) | .state' | head -1)
  case "$state" in
    ready)  live=yes; break ;;
    error)  echo; echo "❌ the build for $sha FAILED — the live site is still the old version"; exit 1 ;;
  esac
done
echo
[[ -n "$live" ]] || { echo "❌ timed out waiting for the build. Check $SITE_URL/../deploys"; exit 1; }

# ── Verify: right app live, and nothing else published ───────────
tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT
curl -fsS -m 30 "$SITE_URL/" -o "$tmp"
if cmp -s "$tmp" "$APP"; then
  echo "✅ live app matches $APP"
else
  echo "❌ live app does NOT match $APP — deploy did not take"; exit 1
fi

fail=0
for f in Turtle_Nest_Log.xlsx backup.sh deploy.sh restore.sh CLAUDE.md HANDOFF.md \
         deploy-checklist.md make_nest_report.py supabase-setup.sql; do
  code=$(curl -sS -m 15 -o /dev/null -w '%{http_code}' "$SITE_URL/$f")
  if [[ "$code" != "404" ]]; then
    echo "❌ LEAK: /$f is serving $code — it must be 404"
    fail=1
  fi
done
if (( fail )); then
  echo "❌ the publish surface is leaking. Check netlify.toml -> publish."
  exit 1
fi
echo "✅ publish surface clean — only index.html is served"
