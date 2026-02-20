#!/bin/bash

LOG_FILE="hunter_report.txt"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 

echo -e "${YELLOW}=== NCAE PERSISTENCE HUNTER v2 ===${NC}"
echo "Scanning for threats..." > "$LOG_FILE"

# --- 1. SUID SCAN (The Noisy Part) ---
echo -e "\n${YELLOW}[*] Scanning SUID Binaries...${NC}"
echo "=== SUID BINARIES ===" >> "$LOG_FILE"

# A list of "Known Good" SUID binaries on standard Linux
# These are SAFE. We will ignore them.
KNOWN_GOOD=(
    "/usr/bin/sudo"
    "/usr/bin/passwd"
    "/usr/bin/chsh"
    "/usr/bin/chfn"
    "/usr/bin/gpasswd"
    "/usr/bin/newgrp"
    "/usr/bin/mount"
    "/usr/bin/umount"
    "/usr/bin/su"
    "/usr/bin/pkexec"
    "/usr/bin/crontab"
    "/usr/lib/openssh/ssh-keysign"
    "/usr/lib/dbus-1.0/dbus-daemon-launch-helper"
    "/usr/lib/polkit-1/polkit-agent-helper-1"
    "/usr/lib/xorg/Xorg.wrap"
    "/usr/lib/snapd/snap-confine"
    "/usr/sbin/pppd"
    "/bin/mount"
    "/bin/umount"
    "/bin/su"
    "/bin/ping"
)

# Find SUID files, BUT skip /timeshift, /proc, /sys, /snap, and /dev directories
# This stops the infinite backup loop.
find / -path "/timeshift" -prune -o \
       -path "/proc" -prune -o \
       -path "/sys" -prune -o \
       -path "/snap" -prune -o \
       -path "/dev" -prune -o \
       -user root -perm -4000 -type f -print 2>/dev/null | while read -r binary; do
    
    IS_SAFE=false
    for good in "${KNOWN_GOOD[@]}"; do
        if [[ "$binary" == "$good" ]]; then
            IS_SAFE=true
            break
        fi
    done

    if [ "$IS_SAFE" = true ]; then
        echo " [OK] $binary" >> "$LOG_FILE"
    else
        # IF IT IS NOT ON THE LIST, HIGHLIGHT IT
        echo -e "${RED} [!!!] SUSPICIOUS: $binary ${NC}" | tee -a "$LOG_FILE"
    fi
done

# --- 2. CRON JOBS (Simplified) ---
echo -e "\n${YELLOW}[*] Scanning Cron...${NC}"
echo "=== CRON JOBS ===" >> "$LOG_FILE"
# Only show lines that are NOT comments (#) and NOT empty
grep -rE "^[^#]" /etc/cron.d /etc/cron.daily /etc/cron.hourly /var/spool/cron 2>/dev/null | grep -v "placeholder" >> "$LOG_FILE"

# --- 3. SSH KEYS (Critical) ---
echo -e "\n${YELLOW}[*] Scanning SSH Keys...${NC}"
grep -E ":/home/|:/root" /etc/passwd | cut -d: -f6 | while read -r home; do
    if [ -f "$home/.ssh/authorized_keys" ]; then
        echo -e "${RED} [!] KEYS FOUND IN: $home ${NC}" | tee -a "$LOG_FILE"
        cat "$home/.ssh/authorized_keys" | tee -a "$LOG_FILE"
    fi
done

echo -e "\n${GREEN}=== SCAN COMPLETE ===${NC}"
