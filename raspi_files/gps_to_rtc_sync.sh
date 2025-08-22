#!/usr/bin/env bash
set -euo pipefail

LOG="/var/log/gps_rtc_sync.log"
MAX_WAIT=600
INTERVAL=20
GPS_TIMEOUT_REACHED=1

log() {
  local now
  now=$(date -u "+%Y-%m-%d %H:%M:%S")
  echo "[GPS-RTC SYNC] $now - $*" | tee -a "$LOG"
}

log "[INFO] Starting GPS-to-RTC synchronization..."

SECONDS_WAITED=0
GPS_TIME=""

while [ "$SECONDS_WAITED" -lt "$MAX_WAIT" ]; do
    # Run a Python one-liner to extract time from GPSD
    GPS_TIME=$(python3 -c '
import sys
import gps
import time

session = gps.gps(mode=gps.WATCH_ENABLE)
timeout = time.time() + 15
while time.time() < timeout:
    report = session.next()
    if report["class"] == "TPV" and hasattr(report, "time") and report.mode >= 2:
        print(report.time)
        break
' 2>/dev/null || true)

    if [ -n "$GPS_TIME" ]; then
        log "[INFO] GPS fix acquired after $SECONDS_WAITED seconds."

        # Check discrepancy between GPS and RTC
        RTC_LINE=$(hwclock --utc --show 2>/dev/null)
        if [[ -n "$RTC_LINE" ]]; then
            RTC_TIME=$(echo "$RTC_LINE" | awk '{print $1" "$2}')
            RTC_UNIX=$(date -u -d "$RTC_TIME" +%s 2>/dev/null || echo "")
            GPS_UNIX=$(date -u -d "$GPS_TIME" +%s 2>/dev/null || echo "")
            if [[ -n "$RTC_UNIX" && -n "$GPS_UNIX" ]]; then
                DISCREPANCY=$((GPS_UNIX - RTC_UNIX))
                log "[INFO] Time discrepancy between GPS and RTC: ${DISCREPANCY} seconds"
            else
                log "[WARNING] Failed to parse GPS or RTC time for discrepancy check."
            fi
        else
            log "[WARNING] Failed to read RTC for discrepancy check."
        fi

        GPS_TIMEOUT_REACHED=0
        break
    fi

    log "[INFO] No GPS fix yet. Retrying in $INTERVAL seconds..."
    sleep "$INTERVAL"
    SECONDS_WAITED=$((SECONDS_WAITED + INTERVAL))
done

if [ "$GPS_TIMEOUT_REACHED" -eq 1 ]; then
    log "[WARNING] No GPS fix within timeout. Restoring system time from RTC..."
    if hwclock --hctosys 2>/dev/null; then
        log "[INFO] System time restored from RTC."
        exit 0
    else
        log "[ERROR] Failed to read RTC."
        exit 1
    fi
fi

# Set system time from GPS
if date -u -s "$GPS_TIME"; then
    log "[INFO] System time set to UTC $GPS_TIME"
    if hwclock -w; then
        log "[INFO] RTC updated from GPS time."
        exit 0
    else
        log "[ERROR] Failed to update RTC."
        exit 2
    fi
else
    log "[ERROR] Failed to set system time."
    exit 3
fi
