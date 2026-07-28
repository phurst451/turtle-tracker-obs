#!/bin/bash
# Commit + push index.html, then publish it to Netlify.
#
# NOTE: this site is a Netlify *drag-and-drop* site — it is NOT wired to the
# GitHub repo. Pushing to git does not update the live site. (This script used
# to claim it did, which is how the live site silently fell 3 commits behind.)
set -euo pipefail
cd "$(dirname "$0")"

msg=${1:-"update"}

if [[ -n "$(git status --porcelain index.html)" ]]; then
  git add index.html
  git commit -m "$msg"
else
  echo "· index.html unchanged — nothing to commit"
fi
git push
echo "✅ Pushed to GitHub"

if command -v netlify >/dev/null 2>&1; then
  netlify deploy --prod --dir .
  echo "✅ Deployed to Netlify"
else
  echo
  echo "⚠️  NOT deployed yet — the live site is still the old version."
  echo "    Netlify CLI isn't installed, so this has to be done by hand:"
  echo
  echo "      1. A Finder window is opening with index.html selected"
  echo "      2. Drag it onto the Deploys tab at:"
  echo "         https://app.netlify.com/sites/turtle-tracker-obs/deploys"
  echo
  echo "    To automate this in future:  npm i -g netlify-cli && netlify link"
  echo
  open -R index.html 2>/dev/null || true
fi
