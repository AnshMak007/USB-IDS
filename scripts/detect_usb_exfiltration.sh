#!/bin/bash

# === Configuration ===
LOG_DIR="/home/kali/usb_ids_logs"  # Not inside watched dirs
EXFIL_LOG="$LOG_DIR/usb_exfil_alerts.log"
WATCH_DIRS=("/home/kali/Documents")  # Directories to monitor
EXFIL_SIZE_THRESHOLD=10120  # Size in KB (e.g., 10MB)

mkdir -p "$LOG_DIR"

echo "[INFO] USB Data Exfiltration Detection (Size-Based) Started at: $(date)" | tee -a "$EXFIL_LOG"

# === Helper: Get mounted removable USB device paths ===
get_usb_mounts() {
    lsblk -o NAME,MOUNTPOINT,RM | awk '$3 == 1 && $2 != "" {print $2}'
}

# === Helper: Calculate total size (in KB) of files in USB mount ===
calculate_total_size() {
    du -sk "$1" 2>/dev/null | awk '{print $1}'
}

# === Main Monitoring Loop ===
while true; do
    MOUNTS=$(get_usb_mounts)
    for mount in $MOUNTS; do
        echo "[INFO] Monitoring mount point: $mount" | tee -a "$EXFIL_LOG"

        for src_dir in "${WATCH_DIRS[@]}"; do
            echo "[INFO] Watching for file copy from $src_dir to $mount" | tee -a "$EXFIL_LOG"

            inotifywait -r -e close_write,create,move "$src_dir" --format '%w%f' |
            while read -r file; do
                sleep 2  # Give time for write to complete

                PRE_SIZE=$(calculate_total_size "$mount")
                sleep 1
                POST_SIZE=$(calculate_total_size "$mount")
                DIFF_SIZE=$((POST_SIZE - PRE_SIZE))

                if [[ $DIFF_SIZE -gt $EXFIL_SIZE_THRESHOLD ]]; then
                    ALERT_MSG="[ALERT] Potential USB data exfiltration detected!"
                    FILE_MSG="[DETAIL] File: $file | To: $mount | ΔSize: ${DIFF_SIZE}KB"

                    echo "$(date) $ALERT_MSG" | tee -a "$EXFIL_LOG"
                    echo "$FILE_MSG" | tee -a "$EXFIL_LOG"

                    notify-send -u critical "USB Exfiltration Detected" "$FILE_MSG"
                    break
                fi
            done &
        done
    done
    sleep 5
done

