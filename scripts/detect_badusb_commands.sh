#!/bin/bash

AUDIT_LOG="/var/log/audit/audit.log"
ALERT_LOG="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_command_alerts.log"
PID_FILE="/tmp/usb_audit_monitor.pid"

USERNAME="kali"  # Change if needed
USER_HOME="/home/$USERNAME"
DISPLAY_NUM=":0"

echo "[INFO] USB Command Execution Monitor Started"
echo "[INFO] Monitoring will start only when USB is connected."

send_gui_alert() {
    ALERT_TEXT="$1"
    export DISPLAY=$DISPLAY_NUM
    export XAUTHORITY="$USER_HOME/.Xauthority"

    DBUS_PID=$(pgrep -u "$USERNAME" -f "gnome-session|xfce4-session|plasmashell" | head -n 1)
    if [[ -z "$DBUS_PID" ]]; then
        echo "[WARN] GUI session for user $USERNAME not detected."
        return
    fi

    DBUS_ENV=$(tr '\0' '\n' < /proc/"$DBUS_PID"/environ | grep DBUS_SESSION_BUS_ADDRESS)
    if [[ -n "$DBUS_ENV" ]]; then
        sudo -u "$USERNAME" DBUS_SESSION_BUS_ADDRESS="${DBUS_ENV#*=}" \
        notify-send "⚠️ USB IDS Alert" "$ALERT_TEXT"
    else
        echo "[ERROR] Could not retrieve DBUS_SESSION_BUS_ADDRESS"
    fi
}

start_monitoring() {
    if [[ -f "$PID_FILE" ]]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            echo "[INFO] Audit monitor already running (PID $OLD_PID), skipping start."
            return
        else
            echo "[WARN] Stale PID file found. Removing and restarting monitor."
            rm -f "$PID_FILE"
        fi
    fi

    echo "[INFO] USB connected. Starting audit log monitoring..."

    declare -A SEEN_COMMANDS
    (
    tail -Fn0 "$AUDIT_LOG" | while read -r line; do
        if echo "$line" | grep -q "usb-badusb"; then
            USER=$(echo "$line" | grep -oP 'EUID="\K[^"]+')
            COMMAND=$(echo "$line" | grep -oP 'exe="[^"]+"' | cut -d'"' -f2)
            [[ -z "$COMMAND" ]] && COMMAND=$(echo "$line" | grep -oP 'comm="\K[^"]+')

            if [[ -n "$COMMAND" && -z "${SEEN_COMMANDS["$COMMAND"]}" ]]; then
                TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
                ALERT_MSG="[ALERT] $TIMESTAMP Suspicious Command Executed by user '$USER': $COMMAND"
                echo "$ALERT_MSG" | tee -a "$ALERT_LOG"
                send_gui_alert "$ALERT_MSG"
                SEEN_COMMANDS["$COMMAND"]=1
            fi
        fi
    done
    ) &

    MON_PID=$!
    echo "$MON_PID" > "$PID_FILE"
    echo "[INFO] Audit monitor started with PID $MON_PID"
}

stop_monitoring() {
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        echo "[INFO] USB disconnected. Stopping audit monitor (PID $PID)..."
        kill "$PID" 2>/dev/null && echo "[INFO] Audit monitor stopped."
        rm -f "$PID_FILE"
    else
        echo "[WARN] PID file not found. Attempting to find and stop audit monitor manually..."
        PGID=$(pgrep -f "tail -Fn0 $AUDIT_LOG")
        if [[ -n "$PGID" ]]; then
            kill "$PGID" && echo "[INFO] Killed orphaned audit monitor (PID $PGID)."
        else
            echo "[INFO] No orphaned audit monitor found."
        fi
    fi
}

# Watch for USB add/remove
udevadm monitor --udev --subsystem-match=usb | while read -r line; do
    if echo "$line" | grep -q "add"; then
        start_monitoring
    elif echo "$line" | grep -q "remove"; then
        stop_monitoring
    fi
done

