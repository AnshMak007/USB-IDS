#!/bin/bash
LOG_FILE="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_activity.log"
ALERT_FILE="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_alerts.log"
THRESHOLD=20  # Max allowed keystrokes per second

echo "[INFO] Monitoring keystroke speed..." | tee -a "$ALERT_FILE"

send_gui_alert() {
    local gui_user="kali"  # Change this if your username is different
    local display=":0"
    local dbus_address="/run/user/1000/bus"

    if [[ -n "$gui_user" && -n "$display" && -n "$dbus_address" ]]; then
        sudo -u "$gui_user" DISPLAY="$display" DBUS_SESSION_BUS_ADDRESS="unix:path=$dbus_address" \
        notify-send -u critical -a "USB IDS Alert" "⚠ BadUSB Keystroke Injection Detected" "$1"
    else
        echo "[WARN] GUI alert not sent: Hardcoded environment incomplete." | tee -a "$ALERT_FILE"
    fi
}

detect_fast_keystrokes() {
    local timestamp
    timestamp=$(date +%s)
    local count=0
    local last_alert_time=0

    tail -Fn0 "$LOG_FILE" | grep --line-buffered "usb_keys" | while read -r line; do
        local current_time
        current_time=$(date +%s)

        # Reset counter every second
        if [ "$current_time" -gt "$timestamp" ]; then
            count=0
            timestamp=$current_time
        fi

        ((count++))

        if [ "$count" -gt "$THRESHOLD" ]; then
            if [ $((current_time - last_alert_time)) -ge 5 ]; then
                local alert_msg="[ALERT] Possible BadUSB detected! Unusual keystroke speed ($count keystrokes/sec)"
                echo "$(date) $alert_msg" | tee -a "$ALERT_FILE"
                send_gui_alert "$alert_msg"
                last_alert_time=$current_time
            fi
        fi
    done
}

detect_fast_keystrokes
