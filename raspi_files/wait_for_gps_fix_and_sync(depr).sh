#!/bin/bash

SCRIPT="/usr/local/bin/sync_rtc_from_gps.py"
LOG="/var/log/gps_rtc_sync.log"
MAX_WAIT=300    # Total timeout in seconds
INTERVAL=15     # Seconds between GPS fix checks
TRIES=$((MAX_WAIT / INTERVAL))

log() {
    local now
    now=$(date -u "+%Y-%m-%d %H:%M:%S")
    echo "[GPS-RTC SYNC] $now - $1" | tee -a "$LOG"
}

log "Starting GPS-to-RTC synchronization process."
log "Using sync script: $SCRIPT"
log "Checking for GPS fix every $INTERVAL seconds (max $MAX_WAIT seconds)..."

SECONDS_WAITED=0
FIX_FOUND=0

while [ "$SECONDS_WAITED" -lt "$MAX_WAIT" ]; do
    if gpspipe -w -n 10 2>/dev/null | grep -q '"mode":[23]'; then
        log "[INFO] GPS fix acquired after $SECONDS_WAITED seconds. Proceeding with sync."
        FIX_FOUND=1
        break
    fi

    log "[INFO] No GPS fix yet. Waiting $INTERVAL seconds..."
    sleep "$INTERVAL"
    SECONDS_WAITED=$((SECONDS_WAITED + INTERVAL))
done

if [ "$FIX_FOUND" -ne 1 ]; then
    log "[WARNING] GPS fix not acquired after $MAX_WAIT seconds. RTC sync skipped."
    log "[INFO] Attempting fallback: restore system time from RTC..."
    if hwclock --hctosys 2>/dev/null; then
        log "[INFO] System time restored from RTC as fallback."
        exit 0
    else
        log "[ERROR] Failed to read RTC. System time may be inaccurate."
        exit 1
    fi
fi

log "[INFO] Running RTC sync script..."

if /usr/bin/python3 "$SCRIPT"; then
    log "[INFO] SUCCESS: RTC successfully synced from GPS."
    exit 0
else
    log "[ERROR] RTC sync script failed to execute properly."
    exit 2
fi