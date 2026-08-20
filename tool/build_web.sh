#!/usr/bin/env bash
# Release web build for GitHub Pages.
#
# Usage:
#   tool/build_web.sh                      # project site at /Hub-City-Transit/
#   BASE_HREF=/ tool/build_web.sh          # user site or custom domain
#
# Config comes from --dart-define, not a bundled asset: an asset is served at a
# public URL on web. Nothing here is secret — the app holds no credential — but
# a compile-time value cannot be swapped independently of the binary.
set -euo pipefail

cd "$(dirname "$0")/.."

BASE_HREF="${BASE_HREF:-/Hub-City-Transit/}"
DEFINES_FILE="${DEFINES_FILE:-env/dart_defines.json}"

args=(build web --release --base-href "$BASE_HREF")
if [[ -f "$DEFINES_FILE" ]]; then
  args+=(--dart-define-from-file="$DEFINES_FILE")
else
  echo "warning: $DEFINES_FILE not found — ARCGIS_URL will be empty and live bus" >&2
  echo "         positions will not load. Pass values with --dart-define instead." >&2
fi

flutter "${args[@]}"

# GitHub Pages cannot rewrite unknown paths to index.html, so a refresh at a deep
# link like /schedule would 404 before Flutter ever loads. Pages serves 404.html
# for any unmatched path, and because it boots the same app the router then reads
# the original URL and lands on the right screen.
cp build/web/index.html build/web/404.html

# Jekyll is on by default for Pages and skips files beginning with an underscore.
touch build/web/.nojekyll

echo "built build/web (base href: $BASE_HREF)"
