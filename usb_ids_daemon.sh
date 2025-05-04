#!/bin/bash

### === Configuration ===
SCRIPTS_DIR="/home/kali/Desktop/project/usb_ids/USB-IDS/scripts"
LOG_DIR="/home/kali/Desktop/project/usb_ids/USB-IDS/logs"
PID_FILE="/var/run/usb_ids_daemon.pid"

mkdir -p "$LOG_DIR"

### === Background Tasks to Run ===
SCRIPTS=(
    "usb_logger.sh"
    "detect_badusb_commands.sh"
    "detect_badusb_hid.sh"
    "detect_badusb_keystrokes.sh"
)

### === Cleanup function on exit ===
cleanup() {
    echo "[INFO] Stopping USB IDS Daemon..." | tee -a "$LOG_DIR/usb_ids_daemon.log"
    rm -f "$PID_FILE"
    pkill -P $$  # Kill all child processes started by this script
    exit 0
}

trap cleanup SIGINT SIGTERM

### === Start Function ===
start_services() {
    echo "[INFO] Starting USB IDS Daemon..." | tee -a "$LOG_DIR/usb_ids_daemon.log"
    
    # Start each script in the background
    for script in "${SCRIPTS[@]}"; do
        SCRIPT_PATH="$SCRIPTS_DIR/$script"
        if [[ -x "$SCRIPT_PATH" ]]; then
            "$SCRIPT_PATH" >> "$LOG_DIR/${script%.sh}.log" 2>&1 &
            echo "[INFO] Started: $script (PID=$!)" | tee -a "$LOG_DIR/usb_ids_daemon.log"
        else
            echo "[WARN] Script not found or not executable: $SCRIPT_PATH" | tee -a "$LOG_DIR/usb_ids_daemon.log"
        fi
    done

    # Wait for all child processes (background scripts) to finish
    wait
}

### === Main ===
if [[ -f "$PID_FILE" ]]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "[ERROR] USB IDS Daemon is already running (PID=$OLD_PID)." | tee -a "$LOG_DIR/usb_ids_daemon.log"
        exit 1
    else
        echo "[WARN] Stale PID file found. Removing..." | tee -a "$LOG_DIR/usb_ids_daemon.log"
        rm -f "$PID_FILE"
    fi
fi

echo $$ > "$PID_FILE"

start_services

# Keep script alive to satisfy systemd, and wait for background jobs
wait

