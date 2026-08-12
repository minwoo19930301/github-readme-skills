#!/usr/bin/env bash
# Confirm a markdown file will actually render an embedded video as a
# <video> player, instead of trusting eyeballs or hoping the URL shape is right.
#
# Usage: check_video_render.sh <host> <owner/repo> <path/to/file.md> [ref]
#
#   host        github.com, or a GitHub Enterprise Server hostname
#                (e.g. github.gmarket.com)
#   owner/repo  the repository, e.g. org-labs/gmws-cli
#   path        path to the markdown file inside the repo, e.g. README.md
#   ref         optional branch/commit (defaults to the repo's default branch)
#
# Requires: gh (authenticated for <host>), python3.

set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <host> <owner/repo> <path/to/file.md> [ref]" >&2
  exit 2
fi

HOST="$1"
REPO="$2"
FILE_PATH="$3"
REF="${4:-}"

TMP_MD="$(mktemp)"
TMP_REQ="$(mktemp)"
TMP_HTML="$(mktemp)"
trap 'rm -f "$TMP_MD" "$TMP_REQ" "$TMP_HTML"' EXIT

CONTENTS_URL="repos/${REPO}/contents/${FILE_PATH}"
if [ -n "$REF" ]; then
  CONTENTS_URL="${CONTENTS_URL}?ref=${REF}"
fi

GH_HOST="$HOST" gh api "$CONTENTS_URL" --jq '.content' | base64 -d > "$TMP_MD"

python3 -c "
import json, sys
with open('$TMP_MD') as f:
    text = f.read()
print(json.dumps({'text': text, 'mode': 'gfm', 'context': '$REPO'}))
" > "$TMP_REQ"

GH_HOST="$HOST" gh api -X POST /markdown --input "$TMP_REQ" > "$TMP_HTML"

if grep -qi '<video' "$TMP_HTML"; then
  echo "OK: ${FILE_PATH} on ${REPO} (${HOST}) renders at least one <video> player."
  grep -oi '<video[^>]*src="[^"]*"' "$TMP_HTML" | sed 's/^/  /'
  exit 0
else
  echo "NOT RENDERING: ${FILE_PATH} on ${REPO} (${HOST}) has no <video> element." >&2
  echo "Any video-looking URLs found (these will just be plain links):" >&2
  grep -oiE 'https?://[^"< ]+\.(mp4|mov|webm)[^"< ]*' "$TMP_MD" | sed 's/^/  /' >&2 || true
  exit 1
fi
