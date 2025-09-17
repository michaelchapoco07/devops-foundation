#!/usr/bin/env bash
# snapshot_backup.sh — create a timestamped tar.gz of a directory with retention
# Usage:
#   snapshot_backup.sh -s <src_dir> [-d <dest_dir>] [-k <keep_count>] [-D <days>] [--exclude PATTERN ...]
# Examples:
#   snapshot_backup.sh -s ~/demo_dir -d ~/backups -k 7
#   snapshot_backup.sh -s /etc -d ~/backups -k 14 --exclude "*.conf.bak" --exclude "ssl/*"

set -Eeuo pipefail
PATH=/usr/sbin:/usr/bin:/sbin:/bin

# ---------- defaults ----------
SRC=""
DEST="$HOME/backups"
KEEP=7      # keep newest N archives
DAYS=0      # additionally delete archives older than N days (0 = off)
LABEL=""    # optional prefix for archive names
EXCLUDES=() # repeated --exclude patterns

# ---------- helpers ----------
ts() { date '+%Y%m%d-%H%M%S'; }
die() {
  echo "ERROR: $*" >&2
  exit 1
}
info() { echo "[ $(date '+%F %T') ] $*"; }

# choose fastest available compressor
if command -v pigz >/dev/null 2>&1; then
  COMPRESSOR="pigz -9"
else
  COMPRESSOR="gzip -9"
fi

# ---------- args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
  -s | --src)
    SRC="${2:-}"
    shift 2
    ;;
  -d | --dest)
    DEST="${2:-}"
    shift 2
    ;;
  -k | --keep)
    KEEP="${2:-}"
    shift 2
    ;;
  -D | --days)
    DAYS="${2:-}"
    shift 2
    ;;
  -l | --label)
    LABEL="${2:-}"
    shift 2
    ;;
  --exclude)
    EXCLUDES+=("$2")
    shift 2
    ;;
  -h | --help)
    sed -n '2,40p' "$0"
    exit 0
    ;;
  *) die "Unknown argument: $1" ;;
  esac
done

[[ -n "${SRC:-}" ]] || die "Missing -s <src_dir>"
[[ -d "$SRC" ]] || die "No such directory: $SRC"
[[ "$KEEP" =~ ^[0-9]+$ ]] || die "--keep must be a number"
[[ "$DAYS" =~ ^[0-9]+$ ]] || die "--days must be a number"
((KEEP >= 1)) || die "--keep must be >= 1"

SRC="$(readlink -f "$SRC")"
DEST="$(readlink -f "$DEST")"
mkdir -p "$DEST"

BASE="$(basename "$SRC")"
PREFIX="${LABEL:+$LABEL-}${BASE}"
ARCHIVE="$DEST/${PREFIX}-$(ts).tar.gz"

# prevent concurrent runs on same src+dest
LOCK="/tmp/snapshot.$(echo -n "${SRC}|${DEST}|${LABEL}" | sha256sum | cut -d' ' -f1).lock"
exec 9>"$LOCK" || die "Cannot open lock $LOCK"
flock -n 9 || die "Another snapshot is running (lock: $LOCK)"

# cleanup partial file on error
cleanup() { [[ -f "$ARCHIVE.part" ]] && rm -f -- "$ARCHIVE.part"; }
trap cleanup ERR INT TERM

# basic free space check (approx)
SRC_BYTES=$(du -sB1 "$SRC" | awk '{print $1}')
DEST_FREE=$(df -PB1 "$DEST" | awk 'NR==2{print $4}')
# need ~ size of SRC (compressed) + 10%
NEEDED=$((SRC_BYTES - SRC_BYTES / 3)) # rough 67% compression guess
((DEST_FREE > NEEDED)) || info "Warning: low free space in $DEST (may still succeed)"

# build tar command
TAR_ARGS=(-I "$COMPRESSOR" -cpf "$ARCHIVE.part" -C "$(dirname "$SRC")")
for pat in "${EXCLUDES[@]:-}"; do TAR_ARGS+=(--exclude="$pat"); done
TAR_ARGS+=("$(basename "$SRC")")

info "Creating $ARCHIVE ..."
tar "${TAR_ARGS[@]}" 2>/dev/null
mv -f -- "$ARCHIVE.part" "$ARCHIVE"
info "Created $ARCHIVE"

# retention by count (newest first)
mapfile -t files < <(ls -1t "$DEST/${PREFIX}-"*.tar.gz 2>/dev/null || true)
if ((${#files[@]} > KEEP)); then
  for ((i = KEEP; i < ${#files[@]}; i++)); do
    info "Prune old: ${files[$i]}"
    rm -f -- "${files[$i]}"
  done
fi

# optional retention by age
if ((DAYS > 0)); then
  info "Prune > ${DAYS}d: $DEST/${PREFIX}-*.tar.gz"
  find "$DEST" -maxdepth 1 -type f -name "${PREFIX}-*.tar.gz" -mtime +"$DAYS" -print -delete
fi

# basic verification: list archive contents (fast check)
if tar -tzf "$ARCHIVE" >/dev/null 2>&1; then
  info "Verified archive integrity."
else
  die "Archive verification failed for $ARCHIVE"
fi

info "Done."
