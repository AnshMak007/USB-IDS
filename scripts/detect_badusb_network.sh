#!/bin/bash

LOG_FILE="/home/kali/Desktop/project/usb_ids/logs/usb_activity.log"
NETWORK_LOG="/home/kali/Desktop/project/usb_ids/logs/usb_network_activity.log"
SUSPICIOUS_LOG="/home/kali/Desktop/project/usb_ids/logs/suspicious_activity.log"

echo "[INFO] Monitoring USB logs for network adapter and BadUSB attack detection..."
echo "Logs are being written to: $NETWORK_LOG and $SUSPICIOUS_LOG"

detect_suspicious_activity() {
    echo "[INFO] Scanning for suspicious activities..."
    
    # Check for active network connections by unknown processes
    ss -tunlp | grep -E ":(21|22|80|443|8080)" | tee -a "$SUSPICIOUS_LOG"
    
    # Check for packet sniffing tools running
    if pgrep -x "tcpdump|wireshark|bettercap" > /dev/null; then
        echo "$(date) [ALERT] Possible Packet Sniffing Detected!" | tee -a "$SUSPICIOUS_LOG"
    fi
    
    # Check for data exfiltration commands running
    if pgrep -x "curl|wget|scp|nc" > /dev/null; then
        echo "$(date) [ALERT] Possible Data Exfiltration Attempt!" | tee -a "$SUSPICIOUS_LOG"
    fi
}

# Start monitoring usb_activity.log for USB network adapters
tail -Fn0 "$LOG_FILE" | while read -r line; do
    if echo "$line" | grep -qE "usb[0-9]+|eth[0-9]+|wlan[0-9]+"; then
        echo "$(date) [ALERT] Possible USB Network Adapter Detected: $line" | tee -a "$NETWORK_LOG"
        
        # Run additional checks for BadUSB behavior
        detect_suspicious_activity
    fi
done

