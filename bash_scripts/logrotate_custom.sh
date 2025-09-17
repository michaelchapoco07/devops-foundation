#!/usr/bin/env bash
set -Eeuo pipefail
PATH=/usr/sbin:/usr/bin:/sbin:/bin

usage() { echo "Usage: $0 <file> [keep=N]"; }

[[ $# -lt 1 ]] && {
  usage
  exit 64
}
FILE="$1"
KEEP="${2:-7}"

[[ -f "$FILE" ]] || {
  echo "No such file: $FILE"
  exit 66
}
[[ "$KEEP" =~ ^[0-9]+$ ]] || {
  echo "keep must be a number"
  exit 64
}
((KEEP >= 1)) || {
  echo "keep must be >= 1"
  exit 64
}

# Shift old rotations up (file.N -> file.N+1)
for ((i = KEEP - 1; i >= 1; i--)); do
  [[ -f "${FILE}.${i}" ]] && mv -f "${FILE}.${i}" "${FILE}.$((i + 1))"
done

# Always rotate current to .1, then truncate original
cp -p -- "$FILE" "${FILE}.1" 2>/dev/null || : # ok if empty
: >"$FILE"

# Remove the oldest if it exists
[[ -f "${FILE}.${KEEP}" ]] && rm -f -- "${FILE}.${KEEP}"

echo "Rotated $FILE (kept $KEEP copies). Now have:"
ls -1 "${FILE}".* 2>/dev/null || echo "  (no prior rotations yet)"
