#!/usr/bin/env bash
# Live-sync themes/jtech to a LOCAL development forum on every save (the
# discourse_theme CLI). Same variables as upload.rb; never points at a
# non-local forum, since discourse_theme would otherwise upload to whatever URL
# it remembers.
set -euo pipefail
cd "$(dirname "$0")/../../themes/jtech"

url="${JTECH_THEME_URL:-http://localhost:3000}"
case "$url" in
  http://localhost* | http://127.0.0.1*) ;;
  *) echo "refusing: $url is not a local forum" >&2; exit 1 ;;
esac

key="${JTECH_THEME_API_KEY:-}"
if [ -z "$key" ] && [ -n "${JTECH_THEME_API_KEY_FILE:-}" ]; then
  key="$(cat "$JTECH_THEME_API_KEY_FILE")"
fi
[ -n "$key" ] || { echo "set JTECH_THEME_API_KEY or JTECH_THEME_API_KEY_FILE" >&2; exit 1; }

export DISCOURSE_URL="$url" DISCOURSE_API_KEY="$key"
exec discourse_theme watch . "$@"
