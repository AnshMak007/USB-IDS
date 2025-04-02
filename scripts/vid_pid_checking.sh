#!/bin/bash

BLACKLIST="badusb_blacklist.txt"
LOGFILE="usb_detection.log"

# Extract all connected USB devices
lsusb | while read line; do
    VID=$(echo $line | awk '{print $6}' | cut -d: -f1)
    PID=$(echo $line | awk '{print $6}' | cut -d: -f2)

    # Check against blacklist
    if grep -q "${VID}:${PID}" "$BLACKLIST"; then
        echo "[ALERT] Malicious USB detected! VID:PID=$VID:$PID" | tee -a "$LOGFILE"
    fi
done

