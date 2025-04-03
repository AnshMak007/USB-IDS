#!/bin/bash

LOG_FILE="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_activity.log"
ALERT_FILE="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_alerts.log"

echo "[INFO] Monitoring for new USB HID devices..."

detect_hid_device() {
    local line="$1"

    if echo "$line" | grep -qiE "HID|keyboard|input device"; then
        echo "$(date) [ALERT] New HID device found - $line" | tee -a "$ALERT_FILE"

        # Call the Python-based keyboard authorization GUI
        python3 /home/kali/Desktop/project/usb_ids/authorize_keyboard.py

        # Check the exit code of the Python script
        if [[ $? -ne 0 ]]; then
            echo "$(date) [ALERT] Unauthorized keyboard detected! Blocking it..." | tee -a "$ALERT_FILE"
            # Add additional steps here if needed (e.g., disable the keyboard)
        else
            echo "$(date) [INFO] Keyboard successfully authorized." | tee -a "$ALERT_FILE"
        fi
    fi
}

tail -Fn0 "$LOG_FILE" | while read -r line; do
    detect_hid_device "$line"
done

