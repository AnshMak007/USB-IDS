#!/usr/bin/env python3

import tkinter as tk
from tkinter import messagebox
import random
import sys

# Generate a random 4-digit code
CODE = str(random.randint(1000, 9999))

def verify_code():
    user_input = entry.get()
    if user_input == CODE:
        messagebox.showinfo("Authorization", "✅ Keyboard/HID authorized successfully!")
        sys.exit(0)  # Exit with success code
    else:
        messagebox.showwarning("Authorization", "❌ Unauthorized keyboard/HID detected! Possible BadUSB attack!")
        sys.exit(1)  # Exit with failure code

# Create the GUI window
root = tk.Tk()
root.title("USB Keyboard/HID Authorization")
root.geometry("350x150")
root.resizable(False, False)

# Instruction Label
label = tk.Label(root, text=f"A new keyboard/HID has been detected!\nEnter this code to authorize: {CODE}", font=("Arial", 12))
label.pack(pady=10)

# Entry Box
entry = tk.Entry(root, font=("Arial", 14), justify="center")
entry.pack()

# Submit Button
submit_button = tk.Button(root, text="Authorize", command=verify_code, font=("Arial", 12))
submit_button.pack(pady=10)

# Timeout: Auto-close after 10 seconds if no input
# Replace old root.after line with this:
def timeout():
    messagebox.showwarning("Timeout", "Authorization timed out! Device not authorized.")
    sys.exit(1)

root.after(10000, timeout)

root.mainloop()

