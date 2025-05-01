#!/bin/bash

# === Configuration ===
USBMON_IFACE_BASE="/sys/kernel/debug/usb/usbmon"
LOG_DIR="/home/kali/Desktop/project/usb_ids/USB-IDS/logs"
ALERT_FILE="$LOG_DIR/usb_cmd_alerts.log"
AUDIT_LOG="/var/log/audit/audit.log"

mkdir -p "$LOG_DIR"
echo "[INFO] USB command injection monitoring started..."

# === Step 1: Detect newly attached USB device using diff ===
echo "[INFO] Waiting for USB device connection..."

before_lsusb=$(lsusb)
new_device_bus=""

udevadm monitor --udev --subsystem-match=usb | while read -r line; do
    if [[ "$line" == *"add"* ]]; then
        echo "[INFO] USB add event detected. Determining new device..."

        sleep 1  # slight delay to let the device register

        after_lsusb=$(lsusb)
        new_device=$(diff <(echo "$before_lsusb") <(echo "$after_lsusb") | grep '^>' | sed 's/^> //')

        if [[ -n "$new_device" ]]; then
            echo "[INFO] New USB device: $new_device"
            new_device_bus=$(echo "$new_device" | awk '{print $2}' | sed 's/^0*//')
            new_device_dev=$(echo "$new_device" | awk '{print $4}' | sed 's/://')
            echo "[INFO] Monitoring Bus: $new_device_bus, Device: $new_device_dev"
        else
            echo "[WARNING] Could not determine new device."
            exit 1
        fi

        break
    fi
done

# === Step 2: Monitor usbmon for malicious command patterns ===
MON_IFACE="$USBMON_IFACE_BASE/${new_device_bus}u"
echo "[INFO] Using usbmon interface: $MON_IFACE"

tail -n 0 -F "$MON_IFACE" | while read -r line; do
    if [[ "$line" =~ ^[0-9]+:.*C ]]; then
        # Extract hex payload
        hex_payload=$(echo "$line" | grep -oE '[0-9A-Fa-f]{2}(\s|$)' | tr -d ' ')

        # Convert hex to ASCII
        ascii_payload=$(echo "$hex_payload" | xxd -r -p 2>/dev/null)

        # Try base64 decoding
        decoded_b64=$(echo "$ascii_payload" | base64 -d 2>/dev/null)

        # Detect suspicious command content
        if echo "$ascii_payload $decoded_b64" | grep -Eiq '(curl|wget|bash|nc|chmod|/bin/sh|eval|exec)'; then
            echo "$(date) [ALERT] Suspicious USB command-like payload detected: $ascii_payload" | tee -a "$ALERT_FILE"

            # === Step 3: Correlate with audit logs ===
            echo "[INFO] Correlating with audit logs..." | tee -a "$ALERT_FILE"
            grep -iE "$(echo $ascii_payload | grep -oE '\w+')" "$AUDIT_LOG" | tail -n 5 | tee -a "$ALERT_FILE"
        fi
    fi
done

