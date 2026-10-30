#!/usr/bin/env bash
# download_counts.sh — how many people downloaded Desi Dictation, by route,
# summed across every release. No tracking: GitHub counts each release file,
# and each route fetches its own copy of the same DMG (release.sh):
#   DesiDictation-mac.dmg   the website's Download button   (from v0.7.0)
#   DesiDictation.dmg       the one-line installer (Terminal)
#   DesiDictation-<v>.dmg   the GitHub releases page
#   DesiDictation-update.dmg  the app's one-click update (existing users;
#                           not in the total, which counts new downloads)
# Before v0.7.0 the website button also fetched DesiDictation.dmg, so for
# older releases "Terminal" includes website clicks.
#
# Usage: ./scripts/download_counts.sh            (needs `gh`, logged in)
set -euo pipefail
REPO="${REPO:-s-samarth/desi-dictation}"

rows="$(gh api "repos/$REPO/releases" --paginate --jq '
  .[] | .tag_name as $tag | .assets[]
  | select(.name | endswith(".dmg"))
  | [$tag,
     (if .name == "DesiDictation-mac.dmg" then "website"
      elif .name == "DesiDictation.dmg" then "terminal"
      elif .name == "DesiDictation-update.dmg" then "update"
      else "releases-page" end),
     .download_count] | @tsv')"

printf "%-12s %8s %9s %14s %7s %8s\n" release website terminal releases-page total updates
per_release="$(echo "$rows" | awk -F'\t' '
  { n[$1, $2] += $3; tags[$1] = 1 }
  END {
    for (t in tags) {
      w = n[t, "website"] + 0; s = n[t, "terminal"] + 0; p = n[t, "releases-page"] + 0
      u = n[t, "update"] + 0
      printf "%-12s %8d %9d %14d %7d %8d\n", t, w, s, p, w + s + p, u
    }
  }' | sort -V)"
echo "$per_release"
echo "$per_release" | awk '{ w += $2; s += $3; p += $4; t += $5; u += $6 }
  END { printf "%-12s %8d %9d %14d %7d %8d\n", "ALL", w, s, p, t, u }'
echo
echo "Counts include our own test downloads. Installs that finished set-up are"
echo "fewer: everyone needs at least one model from the Models page next."
