#!/bin/bash

LOG_DIR="/home/kali/Desktop/project/usb_ids/USB-IDS/logs"
LOG_FILE="$LOG_DIR/usb_activity.log"

mkdir -p "$LOG_DIR"

echo "========== USB MONITORING SESSION STARTED: $(date) ==========" >> "$LOG_FILE"

echo "[INFO] Starting USB activity monitoring..."
echo "Logs are being written to: $LOG_FILE"

# Trap for cleanup on script termination
trap "echo '[INFO] Stopping USB monitor...' | tee -a \"$LOG_FILE\"; pkill -P $$; exit 0" SIGINT SIGTERM

# Print initial system info to log
{
   # echo "========== USB MONITORING STARTED: $(date) =========="
    echo "===== SYSTEM INFO ====="
    uname -a
    echo ""
    echo "===== CONNECTED USB DEVICES (lsusb) ====="
    lsusb
    echo ""
    echo "===== USB DEVICE DETAILS (lshw) ====="
    lshw 2>/dev/null | grep -i "usb"
    echo ""
    echo "======================================="
} >> "$LOG_FILE"

# Start monitors only after the above finishes

# 1. Monitor USB insert/remove using udevadm
udevadm monitor --kernel --subsystem-match=usb |
while read -r line; do
    echo "$(date) [UDEV] $line" | tee -a "$LOG_FILE"
    if [[ "$line" == *"add"* ]]; then
        echo "$(date) [UDEV] Connected USB Snapshot:" | tee -a "$LOG_FILE"
        lsusb | tee -a "$LOG_FILE"
    fi
done &

# 2. Monitor kernel messages via journalctl
journalctl -f -n 0 -o short-iso -k |
grep --line-buffered -i usb |
while read -r line; do
    echo "$(date) [JOURNALCTL] $line" | tee -a "$LOG_FILE"
done &

# 3. Monitor audit logs for USB-related activity  "usb"
tail -F /var/log/audit/audit.log |
grep --line-buffered -E "mount|avc|USER_AUTH|USER_LOGIN|usb_keys|usb-badusb|usb_sensitive_access" |
while read -r line; do
    echo "$(date) [AUDITD] $line" | tee -a "$LOG_FILE"
done &

# Keep everything running
wait

