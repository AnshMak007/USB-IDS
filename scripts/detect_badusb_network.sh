#!/bin/bash

LOG_FILE="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_activity.log"
ALERT_FILE="/home/kali/Desktop/project/usb_ids/USB-IDS/logs/usb_alerts.log"

echo "[INFO] Monitoring for USB network adapters..."

# Get the initial list of network interfaces
BASE_INTERFACES=$(ip -o link show | awk -F': ' '{print $2}')

detect_suspicious_activity() {
    local interface="$1"
    MAC_ADDR=$(cat /sys/class/net/"$interface"/address 2>/dev/null)

    echo "[INFO] New network interface found: $interface ($MAC_ADDR)"

    # Check if it's actively transmitting data
    if ip -s link show "$interface" | awk '$1=="RX:" {rx=$2} $1=="TX:" {tx=$2} END {if (rx>0 || tx>0) print "active"}' | grep -q "active"; then
        echo "$(date) [ALERT] Suspicious USB network activity detected on $interface!" | tee -a "$ALERT_FILE"
    fi

    detect_mitm_attack
    detect_rogue_dhcp
    detect_dns_changes
    detect_suspicious_connections
    detect_rogue_ports "$interface"
    detect_suspicious_processes "$interface"
    monitor_traffic_spikes "$interface"
}

detect_rogue_ports() {		#Scan for listening ports not typically expected on USB adapters.
    local interface="$1"

    # Get all listening ports (exclude known safe ports like 53, 80, 443)
    BAD_PORTS=$(ss -tuln | awk '{print $5}' | grep -E ':[2-9][0-9][0-9][0-9]$')

    if [[ -n "$BAD_PORTS" ]]; then
        echo "$(date) [ALERT] Unauthorized listening port detected on $interface: $BAD_PORTS" | tee -a "$ALERT_FILE"
    fi
}

detect_suspicious_processes() {		# Check for new processes bound to the suspicious network interface.
    local interface="$1"

    # Get active processes using the network adapter
    NET_PROCS=$(lsof -i | grep "$interface")

    if [[ -n "$NET_PROCS" ]]; then
        echo "$(date) [ALERT] Suspicious process using $interface detected!" | tee -a "$ALERT_FILE"
        echo "$NET_PROCS" | tee -a "$ALERT_FILE"
    fi
}

detect_new_network_interface() {	# Add a loop with retries to check for interfaces appearing shortly after USB connection.
    for i in {1..5}; do  # Retry for 5 seconds
        CURRENT_INTERFACES=$(ip -o link show | awk -F': ' '{print $2}')
        NEW_INTERFACE=$(comm -13 <(echo "$BASE_INTERFACES" | sort) <(echo "$CURRENT_INTERFACES" | sort))

        if [[ -n "$NEW_INTERFACE" ]]; then
            echo "[ALERT] New network interface detected: $NEW_INTERFACE" | tee -a "$ALERT_FILE"
            detect_suspicious_activity "$NEW_INTERFACE"
            break
        fi

        sleep 1  # Small delay before rechecking
    done
}


monitor_traffic_spikes() {		# Log sudden spikes in TX/RX traffic for the USB network interface.
    local interface="$1"

    # Get RX/TX stats
    RX_BEFORE=$(cat /sys/class/net/"$interface"/statistics/rx_bytes)
    TX_BEFORE=$(cat /sys/class/net/"$interface"/statistics/tx_bytes)
    
    sleep 5  # Check after 5 seconds
    
    RX_AFTER=$(cat /sys/class/net/"$interface"/statistics/rx_bytes)
    TX_AFTER=$(cat /sys/class/net/"$interface"/statistics/tx_bytes)
    
    RX_DIFF=$((RX_AFTER - RX_BEFORE))
    TX_DIFF=$((TX_AFTER - TX_BEFORE))

    if [[ "$RX_DIFF" -gt 500000 || "$TX_DIFF" -gt 500000 ]]; then  # 500 KB threshold
        echo "$(date) [ALERT] Unusual high traffic detected on $interface (RX: $RX_DIFF bytes, TX: $TX_DIFF bytes)" | tee -a "$ALERT_FILE"
    fi
}



detect_mitm_attack() {
    GATEWAY_IP=$(ip route | awk '/default/ {print $3}')
    ARP_ENTRIES=$(arp -an | grep "$GATEWAY_IP" | awk '{print $4}' | sort -u | wc -l)

    if [[ "$ARP_ENTRIES" -gt 1 ]]; then
        echo "$(date) [ALERT] Possible ARP spoofing detected! Multiple MACs for gateway $GATEWAY_IP" | tee -a "$ALERT_FILE"
    fi
}

detect_rogue_dhcp() {
    if journalctl -u systemd-networkd --since "5 minutes ago" | grep -q "DHCPACK.*$interface"; then
        echo "$(date) [ALERT] Possible rogue DHCP server detected on $interface!" | tee -a "$ALERT_FILE"
    fi
}

detect_dns_changes() {
    KNOWN_DNS="8.8.8.8 1.1.1.1"
    CURRENT_DNS=$(nmcli dev show | grep "IP4.DNS" | awk '{print $2}')

    for dns in $CURRENT_DNS; do
        if ! echo "$KNOWN_DNS" | grep -q "$dns"; then
            echo "$(date) [ALERT] Suspicious DNS server detected: $dns" | tee -a "$ALERT_FILE"
        fi
    done
}

detect_suspicious_connections() {
    NET_CONNECTIONS=$(ss -tunp | grep -E 'ESTAB|SYN-SENT' | awk '{print $5}' | cut -d: -f1 | sort -u)

    for ip in $NET_CONNECTIONS; do
        if ! grep -q "$ip" /etc/hosts; then
            echo "$(date) [ALERT] Suspicious outbound connection detected to $ip" | tee -a "$ALERT_FILE"
        fi
    done
}

tail -Fn0 "$LOG_FILE" | while read -r line; do
    if echo "$line" | grep -qi "USB device added"; then
        echo "[INFO] USB device inserted. Checking for new network interfaces..."
        sleep 5
        detect_new_network_interface
    fi
done

