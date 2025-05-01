#!/bin/bash

LOG_DIR="/home/kali/Desktop/project/usb_ids/USB-IDS/logs"
ALERT_LOG="$LOG_DIR/usb_nic_alerts.log"
mkdir -p "$LOG_DIR"

echo "[INFO] USB NIC Detection & Monitoring Script Started at: $(date)"
echo "[INFO] Logs will be saved to: $ALERT_LOG"

# Wait for a USB NIC connection
echo "[INFO] Waiting for new USB NIC device connection..."
udevadm monitor --udev --subsystem-match=net | while read -r line; do
    if [[ "$line" == *"add"* ]]; then
        sleep 2  # Wait for interface to initialize
        new_iface=$(ip -o link show | tail -n1 | awk -F': ' '{print $2}')
        echo "[INFO] New network interface detected: $new_iface" | tee -a "$ALERT_LOG"

        # Get vendor and product info
        vendor=$(cat /sys/class/net/$new_iface/device/vendor 2>/dev/null)
        product=$(cat /sys/class/net/$new_iface/device/device 2>/dev/null)

        echo "[INFO] Vendor: $vendor | Product: $product" | tee -a "$ALERT_LOG"

        # === DHCP Server Detection ===
        echo "[INFO] Checking for rogue DHCP server on interface $new_iface..." | tee -a "$ALERT_LOG"
        dhcp_check=$(netstat -uln | grep ":67")
        if [[ ! -z "$dhcp_check" ]]; then
            echo "[ALERT] DHCP Server detected on interface $new_iface!" | tee -a "$ALERT_LOG"
        fi

        # === Passive DNS/HTTP Traffic Inspection ===
        echo "[INFO] Running passive DNS and HTTP inspection..." | tee -a "$ALERT_LOG"
        suspicious_domains=$(timeout 15 tcpdump -nn -i "$new_iface" udp port 53 -c 50 2>/dev/null | grep "A " | grep -Ev "trusted.com|local" | awk '{print $NF}' | sort | uniq)
        if [[ ! -z "$suspicious_domains" ]]; then
            echo "[ALERT] Suspicious DNS responses detected:" | tee -a "$ALERT_LOG"
            echo "$suspicious_domains" | tee -a "$ALERT_LOG"
        fi

        http_check=$(timeout 15 tcpdump -A -nn -i "$new_iface" tcp port 80 -c 30 2>/dev/null | grep -Ei 'HTTP/1.1 30[123]|Location:' | sort | uniq)
        if [[ ! -z "$http_check" ]]; then
            echo "[ALERT] Possible HTTP redirect or tampering detected:" | tee -a "$ALERT_LOG"
            echo "$http_check" | tee -a "$ALERT_LOG"
        fi

        # === Auto-Isolation if multiple issues detected ===
        if [[ ! -z "$dhcp_check" && ( ! -z "$suspicious_domains" || ! -z "$http_check" ) ]]; then
            echo "[CRITICAL] Multiple indicators of compromise found. Disabling interface $new_iface..." | tee -a "$ALERT_LOG"
            sudo ifconfig "$new_iface" down
            echo "[INFO] Interface $new_iface has been brought down for safety." | tee -a "$ALERT_LOG"
        fi
    fi
done

