#!/bin/bash

LOG_DIR="/home/kali/Desktop/project/usb_ids/USB-IDS/logs"
ALERT_LOG="$LOG_DIR/usb_exfil_alerts.log"
AUDIT_LOG="/var/log/audit/audit.log"
AUDIT_TAG="usb_sensitive_access"

mkdir -p "$LOG_DIR"

echo "[INFO] USB Data Exfiltration Detection Started: $(date)" | tee -a "$ALERT_LOG"

# === Function: Get USB mount points ===
get_usb_mounts() {
    lsblk -o NAME,MOUNTPOINT,RM | awk '$3 == 1 && $2 != "" {print $2}'
}

# === Function: Monitor write to USB mount ===
monitor_usb_write() {
    local mount_point="$1"
    echo "[INFO] Monitoring writes to USB mount: $mount_point" | tee -a "$ALERT_LOG"

    inotifywait -mrq -e create -e moved_to -e close_write "$mount_point" --format '%w%f' |
    while read -r file; do
        echo "$(date) [ALERT] File written to USB!" | tee -a "$ALERT_LOG"
        echo "[DETAIL] File: $file | Mount: $mount_point" | tee -a "$ALERT_LOG"
    done
}

# === Function: Monitor audit logs for sensitive file access ===
monitor_audit_logs() {
    echo "[INFO] Monitoring audit logs for sensitive file access..." | tee -a "$ALERT_LOG"
    tail -Fn0 "$AUDIT_LOG" | grep --line-buffered "$AUDIT_TAG" |
    while read -r log_line; do
        echo "$(date) [ALERT] Sensitive file accessed! (Tagged: $AUDIT_TAG)" | tee -a "$ALERT_LOG"
        echo "[DETAIL] $log_line" | tee -a "$ALERT_LOG"

        # Now start USB mount monitoring after confirming sensitive access
        USB_MOUNTS=$(get_usb_mounts)
        for mount in $USB_MOUNTS; do
            monitor_usb_write "$mount" &
        done
    done
}

# === Main: Watch for USB connection using udevadm ===
udevadm monitor --udev --subsystem-match=block | while read -r line; do
    if echo "$line" | grep -q "add"; then
        echo "[INFO] USB device detected. Verifying..." | tee -a "$ALERT_LOG"

        sleep 2  # Give the system time to mount
        USB_MOUNTS=$(get_usb_mounts)

        if [ -n "$USB_MOUNTS" ]; then
            echo "[INFO] USB mounted at: $USB_MOUNTS" | tee -a "$ALERT_LOG"
            monitor_audit_logs &
        fi
    fi
done

