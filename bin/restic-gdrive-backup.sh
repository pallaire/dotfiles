#!/usr/bin/env bash
# Restic backup of Google Drive (Insync) folder to /mnt/BackupDrive.
#
# Usage:
#   restic-gdrive-backup.sh nightly   # incremental snapshot + apply retention
#   restic-gdrive-backup.sh full      # re-read every file (--force) + verify repo data
#
# Retention: snapshots older than 6 months are removed and their data pruned.

set -euo pipefail

# cron has no desktop session: point notify-send at the user's D-Bus.
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

MODE="${1:-nightly}"
SOURCE="/home/pallaire/Insync/pallaire@gmail.com/Google Drive"
MOUNTPOINT="/mnt/BackupDrive"

export RESTIC_REPOSITORY="$MOUNTPOINT/restic"
export RESTIC_PASSWORD_FILE="$HOME/.config/restic/gdrive.pass"

LOG_DIR="$HOME/.local/state/restic"
LOG="$LOG_DIR/gdrive-backup.log"
LOCK="$LOG_DIR/gdrive-backup.lock"
mkdir -p "$LOG_DIR"

exec >>"$LOG" 2>&1
echo "===== $(date '+%F %T') starting $MODE backup ====="

# Only one run at a time; wait up to 1 hour for a run that's still going.
exec 9>"$LOCK"
if ! flock -w 3600 9; then
    echo "Another backup is still running; giving up."
		notify-send -u critical "restic-gdrive-backup.sh" "Another backup is still running; giving up." || true
    exit 1
fi

# Don't write to the empty mount-point directory if the USB drive is unplugged.
if ! mountpoint -q "$MOUNTPOINT"; then
    echo "ERROR: $MOUNTPOINT is not mounted; skipping."
		notify-send -u critical "restic-gdrive-backup.sh" "ERROR: $MOUNTPOINT is not mounted; skipping." || true
    exit 1
fi

if [[ ! -f "$RESTIC_PASSWORD_FILE" ]]; then
    echo "ERROR: password file $RESTIC_PASSWORD_FILE not found."
		notify-send -u critical "restic-gdrive-backup.sh" "ERROR: password file $RESTIC_PASSWORD_FILE not found." || true
    exit 1
fi

# Create the repository on the first run.
if ! restic cat config >/dev/null 2>&1; then
    echo "Repository not found, initializing $RESTIC_REPOSITORY"
		notify-send -u critical "restic-gdrive-backup.sh" "Repository not found, initializing $RESTIC_REPOSITORY" || true
    restic init
fi

case "$MODE" in
    nightly)
        restic backup --tag nightly "$SOURCE"
        ;;
    full)
        # --force re-reads every file instead of trusting the mtime/size cache.
        restic backup --force --tag full "$SOURCE"
        # Read back 10% of the stored data to catch corruption on the drive.
        restic check --read-data-subset=10%
        ;;
    *)
        echo "Unknown mode '$MODE' (use 'nightly' or 'full')"
        exit 2
        ;;
esac

# Keep 6 months of snapshots, delete older ones and free their space.
restic forget --keep-within 6m --prune

echo "===== $(date '+%F %T') $MODE backup finished OK ====="
notify-send -u critical "restic-gdrive-backup.sh" "===== $(date '+%F %T') $MODE backup finished OK =====" || true
