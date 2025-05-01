#!/bin/bash

LOG_DIR="/home/kali/Desktop/project/usb_ids/USB-IDS/logs"
ALERT_LOG="$LOG_DIR/usb_keystroke_alerts.log"
mkdir -p "$LOG_DIR"

echo "[INFO] USB Keystroke Injection Detection Started at: $(date)"
echo "[INFO] Logs will be saved to: $ALERT_LOG"

# === Step 1: Detect new USB device using udevadm and lsusb diff ===
echo "[INFO] Waiting for USB device connection..."
before_lsusb=$(lsusb)
new_device_bus="1"

udevadm monitor --udev --subsystem-match=usb --property | while read -r line; do
    if [[ "$line" == *"add"* ]]; then
        echo "[INFO] USB device add event detected..."
        sleep 1  # Let the system finish registering the device
        break
    fi
done
after_lsusb=$(lsusb)
new_device=$(comm -13 <(echo "$before_lsusb" | sort) <(echo "$after_lsusb" | sort))

if [[ -n "$new_device" ]]; then
    echo "[INFO] New USB device detected: $new_device"
    new_device_bus=$(echo "$new_device" | awk '{print $2}' | sed 's/^0*//')

    if [[ -z "$new_device_bus" ]]; then
        echo "[ERROR] Failed to extract bus number from device info: $new_device"
        exit 1
    fi

    echo "[DEBUG] Extracted bus number: $new_device_bus"
    echo "[DEBUG] Device diff output: $(diff <(echo "$before_lsusb") <(echo "$after_lsusb"))"
else
    echo "[WARNING] Could not identify new USB device."
    exit 1
fi

# === Step 2: Monitor usbmon for suspicious activity ===
USBMON_INTERFACE="/sys/kernel/debug/usb/usbmon/${new_device_bus}u"
if [[ ! -f "$USBMON_INTERFACE" ]]; then
    echo "[ERROR] usbmon interface $USBMON_INTERFACE not found!" | tee -a "$ALERT_LOG"
    exit 1
fi

echo "[INFO] Monitoring USB Interface: $USBMON_INTERFACE" | tee -a "$ALERT_LOG"

LAST_TIME=0
LAST_PAYLOAD=""
REPEAT_COUNT=0
REPEAT_THRESHOLD=5
INJECTION_TIME_THRESHOLD=10000  # 10 ms

cat "$USBMON_INTERFACE" | while read -r line; do
    TYPE=$(echo "$line" | awk '{print $5}')
    ENDPOINT=$(echo "$line" | awk '{print $6}')
    DATA_LEN=$(echo "$line" | awk '{print $7}')
    TIMESTAMP=$(echo "$line" | awk '{print $2}')
    PAYLOAD=$(echo "$line" | grep -oP '=\s+\K(.+)$')

    
    # === Heuristic 1: Normal keystroke injection detection ===
    if [[ "$TYPE" == "C" && "$ENDPOINT" == "81" && "$DATA_LEN" -eq 8 && -n "$PAYLOAD" ]]; then
        CURRENT_TIME=$(echo "$TIMESTAMP" | awk -F'.' '{print ($1 * 1000000) + $2}')
        if [[ $LAST_TIME -ne 0 ]]; then
            TIME_DIFF=$((CURRENT_TIME - LAST_TIME))
            if [[ $TIME_DIFF -lt $INJECTION_TIME_THRESHOLD ]]; then
                echo "[ALERT] Fast keystroke timing detected! Delay=${TIME_DIFF}μs | Data=$PAYLOAD | Time=$(date)" | tee -a "$ALERT_LOG"
            fi
        fi
        LAST_TIME=$CURRENT_TIME

        if [[ "$PAYLOAD" == "$LAST_PAYLOAD" ]]; then
            REPEAT_COUNT=$((REPEAT_COUNT + 1))
            if [[ $REPEAT_COUNT -ge $REPEAT_THRESHOLD ]]; then
                echo "[ALERT] Repeated keystroke payload detected $REPEAT_COUNT times | Data=$PAYLOAD | Time=$(date)" | tee -a "$ALERT_LOG"
                REPEAT_COUNT=0
            fi
        else
            REPEAT_COUNT=1
            LAST_PAYLOAD="$PAYLOAD"
        fi
    fi

    # === Heuristic 2: Suspicious large payload detection ===
    if [[ "$TYPE" == "C" && "$ENDPOINT" == "81" && "$DATA_LEN" -gt 64 && -n "$PAYLOAD" ]]; then
        # Count nulls
        null_count=$(echo "$PAYLOAD" | grep -o "00" | wc -l)
        total_bytes=$(echo "$PAYLOAD" | wc -w)
        null_ratio=$(echo "scale=2; $null_count / $total_bytes" | bc)

        # Check for ASCII sequences
        ascii_pattern=$(echo "$PAYLOAD" | grep -oE '([2-7][0-9]|6[1-9]|7[0-9]|4[1-6])' | wc -l)

        if [[ $(echo "$null_ratio > 0.5" | bc) -eq 1 || "$ascii_pattern" -gt 10 ]]; then
            echo "[ALERT] Suspicious bulk USB payload detected! Null Ratio: $null_ratio, ASCII-like bytes: $ascii_pattern | Time: $(date)" | tee -a "$ALERT_LOG"
            echo "[DEBUG] Payload: $PAYLOAD" >> "$ALERT_LOG"
        fi
    fi


done
