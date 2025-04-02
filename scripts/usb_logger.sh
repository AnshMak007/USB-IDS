#!/bin/bash

LOG_FILE="/home/kali/Desktop/project/usb_ids/logs/usb_activity.log"

echo "[INFO] Starting USB activity monitoring..."
echo "Logs are being written to: $LOG_FILE"

# Start logging USB events
{
    echo "========== USB MONITORING STARTED: $(date) =========="
    
    # Real-time monitoring for USB insert/remove events
    udevadm monitor --kernel --subsystem-match=usb |
    while read -r line; do
        echo "$(date) [UDEV] $line" | tee -a "$LOG_FILE"
    done &

    # Monitor system logs for USB-related activity
    journalctl -f -n 0 -o short-iso -k | grep --line-buffered -i usb |
    while read -r line; do
        echo "$(date) [JOURNALCTL] $line" | tee -a "$LOG_FILE"
    done &

    # Monitor audit logs for suspicious USB-related activity
    tail -F /var/log/audit/audit.log |
    grep --line-buffered -E "usb|mount|avc|USER_AUTH|USER_LOGIN" |
    while read -r line; do
        echo "$(date) [AUDITD] $line" | tee -a "$LOG_FILE"
    done &

    # Keep script running
    while true; do
        sleep 5
    done
} &

