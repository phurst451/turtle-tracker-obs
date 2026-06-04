#!/bin/bash
msg=${1:-"update"}
git add index.html
git commit -m "$msg"
git push
echo "✅ Deployed — Netlify will go live in ~30 seconds"
