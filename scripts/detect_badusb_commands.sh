#!/bin/bash

LOG_FILE="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_activity.log"
ALERT_LOG="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_command_alerts.log"
ALERT_SCRIPT="/usr/local/bin/usb_alert.sh"

START_TIME=$(date +%s)  # Record start time

echo "[INFO] Starting USB command execution monitor..."
echo "[INFO] Logs will be read from: $LOG_FILE"
echo "[INFO] Alerts will be saved in: $ALERT_LOG"

# Monitor log file for new entries
tail -Fn0 "$LOG_FILE" | while read -r line; do
    # Extract timestamp and log message
    TIMESTAMP=$(echo "$line" | awk '{print $1, $2, $3, $4, $5, $6, $7}')
    LOG_ENTRY=$(echo "$line" | awk '{$1=$2=$3=$4=$5=$6=$7=""; print $0}' | sed 's/^ //')

    # Convert timestamp to UNIX format
    LOG_TIME=$(date -d "$TIMESTAMP" +%s 2>/dev/null)

    # Ensure we only process logs **after** script start time
    if [[ -n "$LOG_TIME" && "$LOG_TIME" -lt "$START_TIME" ]]; then
        continue  # Skip older logs
    fi

    # Check for suspicious commands
    if echo "$LOG_ENTRY" | grep -E 'sudo|wget|curl|nc|netcat|chmod|xdotool' >/dev/null; then
        ALERT_MESSAGE="[ALERT] Suspicious USB command detected: $LOG_ENTRY"
        echo "$(date) $ALERT_MESSAGE" | tee -a "$ALERT_LOG"

        # Trigger alert script
        bash "$ALERT_SCRIPT" "$LOG_ENTRY"
    fi
done

