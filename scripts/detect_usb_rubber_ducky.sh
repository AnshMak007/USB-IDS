#!/bin/bash

LOG_FILE="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_activity.log"
ALERT_FILE="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_alerts.log"

echo "[INFO] Rubber Ducky Detection Started..."

# List of known suspicious commands
SUSPICIOUS_CMDS=("wget" "curl" "nc" "ncat" "bash" "sh" "chmod" "chown" "python" "perl" "powershell" "whoami" "scp" "nmap")

monitor_rubber_ducky() {
    tail -Fn0 "$LOG_FILE" | while read -r line; do
        # 1. Check if a HID keyboard is detected
        if echo "$line" | grep -qi "HID" && echo "$line" | grep -qi "keyboard"; then
            echo "[ALERT] HID Keyboard Device Detected: $line" | tee -a "$ALERT_FILE"
            TIMESTAMP=$(date +%s)

            # 2. Start a short window to monitor commands
            echo "[INFO] Monitoring for suspicious activity for 10 seconds..."
            end_time=$((TIMESTAMP + 10))
            while [ "$(date +%s)" -le "$end_time" ]; do
                for cmd in "${SUSPICIOUS_CMDS[@]}"; do
                    if grep -qi "$cmd" "$LOG_FILE"; then
                        echo "[DETECTED] Suspicious command '$cmd' shortly after USB device insertion." | tee -a "$ALERT_FILE"
                        echo "[RUBBER_DUCKY ALERT] Potential Rubber Ducky Attack - Command '$cmd' triggered!" | tee -a "$ALERT_FILE"
                    fi
                done
                sleep 1
            done
        fi
    done
}

monitor_rubber_ducky
