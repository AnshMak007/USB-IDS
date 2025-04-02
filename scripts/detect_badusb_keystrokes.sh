#!/bin/bash

LOG_FILE="/home/kali/Desktop/project/usb_ids/logs/audit/audit.log"
ALERT_FILE="/home/kali/Desktop/project/usb_ids/logs/usb_alerts.log"
THRESHOLD=20  # Max allowed keystrokes per second

echo "[INFO] Monitoring keystroke speed..."

detect_fast_keystrokes() {
    local timestamp=$(date +%s)
    local count=0

    # Monitor keystroke events in audit log
    tail -Fn0 "$LOG_FILE" | grep --line-buffered "usb_keys" | while read -r line; do
        local current_time=$(date +%s)

        # Reset count every second
        if [ "$current_time" -gt "$timestamp" ]; then
            count=0
            timestamp=$current_time
        fi

        ((count++))

        # If keystrokes exceed threshold, trigger alert
        if [ "$count" -gt "$THRESHOLD" ]; then
            echo "$(date) [ALERT] Possible BadUSB detected! Unusual keystroke speed ($count keystrokes/sec)" | tee -a "$ALERT_FILE"
        fi
    done
}

detect_fast_keystrokes

