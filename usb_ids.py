import subprocess
import time
import os

LOG_FILE = "logs/usb_activity.log"
ALERT_FILE = "logs/badusb_alerts.log"

def log_event(event):
    """Write event to log file."""
    with open(LOG_FILE, "a") as f:
        f.write(event + "\n")

def trigger_alert(alert_message):
    """Log and trigger an alert."""
    print(f"[ALERT] {alert_message}")
    with open(ALERT_FILE, "a") as f:
        f.write(alert_message + "\n")
    subprocess.run(["scripts/alert.sh", alert_message])

def run_detection_scripts():
    """Run all detection scripts and collect results."""
    print("[INFO] Running detection scripts...")
    
    # Check USB roles
    roles_output = subprocess.run(["scripts/check_roles.sh"], capture_output=True, text=True).stdout
    if "SUSPICIOUS" in roles_output:
        trigger_alert("Suspicious USB role detected!")

    # Check keystroke speed
    keystroke_output = subprocess.run(["python3", "scripts/detect_keystrokes.py"], capture_output=True, text=True).stdout
    if "BADUSB DETECTED" in keystroke_output:
        trigger_alert("Keystroke injection detected!")

    # Check executed commands
    audit_output = subprocess.run(["scripts/detect_cmds.sh"], capture_output=True, text=True).stdout
    if "SUSPICIOUS CMD" in audit_output:
        trigger_alert("Suspicious command execution detected!")

    log_event(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] USB monitoring cycle completed.")

def main():
    print("[INFO] Starting USB Intrusion Detection System (USB IDS)...")
    while True:
        run_detection_scripts()
        time.sleep(5)  # Adjust frequency as needed

if __name__ == "__main__":
    main()

