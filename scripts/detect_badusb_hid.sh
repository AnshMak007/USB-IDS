#!/bin/bash

LOG_FILE="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_activity.log"
ALERT_FILE="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_alerts.log"
TEMP_AUTH_DIR="/home/kali/Desktop/project/usb_ids/USB-IDS/authorized_hid"

mkdir -p "$TEMP_AUTH_DIR"

echo "[INFO] Monitoring for new USB HID devices..."

detect_hid_device() {
    local line="$1"
    echo "[DEBUG] New log line received: $line"

    if echo "$line" | grep -qiE "Nano|HID|keyboard|input device|Mouse"; then
        echo "[DEBUG] Line matched HID pattern"

        local vid=$(echo "$line" | grep -oP 'idVendor=\K[0-9a-fA-F]{4}')
        local pid=$(echo "$line" | grep -oP 'idProduct=\K[0-9a-fA-F]{4}')
        local device_id=""

        if [[ -z "$vid" || -z "$pid" ]]; then
            echo "[DEBUG] Missing VID or PID. Trying fallback via lsusb..."
            local lsusb_line=$(lsusb | grep -iE 'keyboard|input|nano|mouse' | tail -n 1)
            if [[ -n "$lsusb_line" ]]; then
                local raw_id=$(echo "$lsusb_line" | awk '{print $6}')
                if [[ "$raw_id" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]]; then
                    vid=$(echo "$raw_id" | cut -d: -f1)
                    pid=$(echo "$raw_id" | cut -d: -f2)
                    echo "[DEBUG] Fallback lsusb VID=$vid PID=$pid"
                else
                    echo "[DEBUG] Fallback VID:PID not in expected format."
                    return
                fi
            else
                echo "[DEBUG] No matching lsusb output found."
                return
            fi
        fi

        if [[ -n "$vid" && -n "$pid" ]]; then
            device_id="${vid}:${pid}"
            echo "[DEBUG] Final Device ID: $device_id"
        else
            echo "[DEBUG] Still missing VID or PID. Cannot verify or authorize."
            return
        fi

        if [[ -f "$TEMP_AUTH_DIR/$device_id" ]]; then
            echo "$(date) [INFO] Already authorized device detected again: $device_id" >> "$ALERT_FILE"
            return
        fi
        echo "$(date) [ALERT] New HID device found - $line" | tee -a "$ALERT_FILE"

        # Launch GUI auth and get return code
        python3 /home/kali/Desktop/project/usb_ids/USB-IDS/authorize_keyboard.py &
        local auth_pid=$!
        timeout 15s tail --pid=$auth_pid -f /dev/null
        wait $auth_pid
        local auth_exit=$?

        if [[ $auth_exit -eq 0 ]]; then
            echo "$(date) [INFO] Keyboard successfully authorized: $device_id" | tee -a "$ALERT_FILE"
            touch "$TEMP_AUTH_DIR/$device_id"
        else
            echo "$(date) [ALERT] Unauthorized keyboard detected! Not authorized: $device_id" | tee -a "$ALERT_FILE"
        fi
    else
        echo "[DEBUG] Line did not match HID pattern"
    fi
}

# Open file descriptor to avoid subshell from `tail | while`
exec 3< <(tail -Fn0 "$LOG_FILE")
while read -r line <&3; do
    detect_hid_device "$line"
done
