#!/bin/bash

PASSWD_FILE="/etc/passwd"
SHADOW_FILE="/etc/shadow"
MIN_UID=1000

echo "=== Starting Audit of $PASSWD_FILE and $SHADOW_FILE ==="

# 1. Check for UID 0 
echo "[*] Checking for non-root users with UID 0..."
awk -F: '($3 == 0 && $1 != "root") {print " [!] CRITICAL: " $1 " has UID 0!"}' $PASSWD_FILE

#  Check System Accounts with Login Shells
echo "[*] Checking system accounts (UID < $MIN_UID) for valid shells..."
# Check system accounts for nologin
awk -F: -v min="$MIN_UID" \
'($3 < min && $3 != 0 && $7 !~ /(nologin|false)/) {print " [!] WARNING: System user " $1 " (UID " $3 ") has shell: " $7}' $PASSWD_FILE

#Check shadow for empty passwords and unlocked system accounts
echo "[*] Checking shadow file anomalies..."
# Requires root privileges to read /etc/shadow
if [ -r $SHADOW_FILE ]; then
    # Check field 2 for empty password field
    awk -F: '($2 == "") {print " [!] CRITICAL: Account " $1 " has NO password!"}' $SHADOW_FILE

    # Check for system users (from passwd list) that are unlocked in shadow
    
    for user in $(awk -F: -v min="$MIN_UID" '$3 < min && $3 != 0 {print $1}' $PASSWD_FILE); do
        grep "^$user:" $SHADOW_FILE | awk -F: '$2 ~ /^\$/ {print " [!] WARNING: System account " $1 " has a valid password hash (is unlocked)."}'
    done
else
    echo " [X] ERROR: Cannot read $SHADOW_FILE. Run as root."
fi

echo "=== Audit Complete ==="
