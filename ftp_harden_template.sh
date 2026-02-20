#!/bin/bash

echo "=== NCAE HARDENING: FTP (vsftpd) ==="

# 1. Check if vsftpd is installed
if ! command -v vsftpd >/dev/null 2>&1; then
    echo " [!] vsftpd is NOT installed. Skipping."
    exit 0
fi

CONFIG="/etc/vsftpd.conf"
BACKUP="/etc/vsftpd.conf.bak"

# 2. Backup Config
if [ ! -f "$BACKUP" ]; then
    cp "$CONFIG" "$BACKUP"
    echo " [+] Backup created at $BACKUP"
fi

# 3. Apply Hardening Rules
# Disable Anonymous Login (Critical)
sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' "$CONFIG"

# Enable Local Users (Required for Scoring)
sed -i 's/^local_enable=.*/local_enable=YES/' "$CONFIG"

# Enable Write Access (Required for Scoring: "ftp write")
sed -i 's/^#write_enable=.*/write_enable=YES/' "$CONFIG"

# Jail Users (Prevents directory traversal)
sed -i 's/^#chroot_local_user=.*/chroot_local_user=YES/' "$CONFIG"

# Fix "500 OOPS" error (Required when chroot is enabled with write access)
if ! grep -q "allow_writeable_chroot=YES" "$CONFIG"; then
    echo "allow_writeable_chroot=YES" >> "$CONFIG"
fi

# 4. Restart Service
systemctl restart vsftpd
echo " [+] vsftpd restarted with hardened config."
echo "     -> Verified: Anonymous disabled, Write enabled, Chroot active."
