#!/bin/bash

# ============================================================================
# nuke_and_seal.sh : The "Scorched Earth" Baseline (Fixed & Integrated)
# ============================================================================

if [ "$(id -u)" != "0" ]; then echo "Root required."; exit 1; fi

echo "[*] STARTING SYSTEM BASELINING..."

# --- 1. THE NUKE LIST (Binaries) ---
echo "[*] Phase 1: Nuking Binaries..."

# Network & Shells
rm -f /usr/bin/nc /usr/bin/netcat /usr/bin/ncat /usr/bin/socat
rm -f /usr/bin/telnet /usr/bin/rsh /usr/bin/rlogin /usr/bin/rcp /usr/bin/xinetd /usr/bin/rsh-server /usr/bin/rsh-client

# Scanners
rm -f /usr/bin/nmap /usr/bin/zenmap /usr/bin/masscan
rm -f /usr/bin/tcpdump /usr/bin/wireshark /usr/bin/tshark
rm -f /usr/bin/hping3 /usr/bin/fping

# Hack Tools
rm -f /usr/bin/hydra /usr/bin/john /usr/bin/sqlmap /usr/bin/medusa /usr/bin/nikto
rm -f /usr/bin/hashcat /usr/bin/mimikatz

# Compilers
rm -f /usr/bin/gcc* /usr/bin/g++* /usr/bin/cc /usr/bin/c++
rm -f /usr/bin/make /usr/bin/cmake /usr/bin/automake /usr/bin/autoconf
rm -f /usr/bin/as /usr/bin/nasm /usr/bin/yasm
rm -f /usr/bin/byacc /usr/bin/yacc /usr/bin/flex /usr/bin/bison

# Clients
rm -f /usr/bin/ftp /usr/bin/lftp /usr/bin/tftp
# rm -f /usr/bin/wget /usr/bin/curl

# Obfuscation
rm -f /usr/bin/uuencode /usr/bin/uudecode


echo "    -> Binaries destroyed."

# --- 2. THE PERMISSION SEAL (Programmatic Fix) ---
echo "[*] Phase 2: Applying Safe Permissions..."


# 1. Fix Root Permissions (Standard Security)
echo "    -> Securing /etc and /usr..."
find /etc /usr/bin /usr/sbin -type d -exec chmod 755 {} + 2>/dev/null
find /etc /usr/bin /usr/sbin -type f -exec chmod go-w {} + 2>/dev/null

# 2. Lock down Shadow/Passwd
echo "    -> Locking User Credentials..."
chown root:root /etc/passwd /etc/group /etc/shadow /etc/gshadow
chmod 644 /etc/passwd /etc/group
chmod 600 /etc/shadow /etc/gshadow


# 3. Secure Binaries (Prevent modification, preserve SUID)
echo "    -> Securing Binaries..."
chmod 755 /bin /sbin /usr/bin /usr/sbin

find /bin /sbin /usr/bin /usr/sbin -type f -exec chmod go-w {} +

# 4. Critical Tmp Permissions (Sticky Bit)
echo "    -> Fixing /tmp Sticky Bit..."
chmod 1777 /tmp /var/tmp
chown root:root /tmp /var/tmp

# --- 3. THE SAFETY NET (Fix Broken Services) ---
echo "[*] Phase 3: Checking Service Health..."

# FTP Rescue
if [ -d "/srv/ftp" ]; then
    echo "    -> Fixing FTP Root (/srv/ftp)..."
    chown root:root /srv/ftp
    chmod 755 /srv/ftp
    
    if [ -d "/srv/ftp/upload" ]; then
        chown ftp:ftp /srv/ftp/upload
    fi
fi

if [ -d "/var/ftp" ]; then
    echo "    -> Fixing FTP Root (/var/ftp)..."
    chown root:root /var/ftp
    chmod 755 /var/ftp

    if [ -d "/var/ftp/upload" ]; then
        chown ftp:ftp /var/ftp/upload
    fi
fi

# Web Server (Sessions must be writable by www-data)
if [ -d "/var/lib/php/sessions" ]; then
    echo "    -> Fixing PHP Sessions..."
    chmod 1733 /var/lib/php/sessions
    chown root:www-data /var/lib/php/sessions
fi


# MySQL Data
if [ -d "/var/lib/mysql" ]; then
    echo "    -> Fixing MySQL..."
    chown -R mysql:mysql /var/lib/mysql
    chmod 700 /var/lib/mysql
fi

# Postgres Data
if [ -d "/var/lib/postgresql" ]; then
    echo "    -> Fixing Postgres..."
    chown -R postgres:postgres /var/lib/postgresql
    chmod 700 /var/lib/postgresql
fi

# Bind DNS
if [ -d "/var/cache/bind" ]; then
    echo "    -> Fixing Bind DNS..."
    chown -R bind:bind /var/cache/bind
fi

# --- 4. SHARED MEMORY HARDENING ---
echo "[*] Phase 4: Hardening Shared Memory (/dev/shm)..."

# Backup fstab
cp -a /etc/fstab /etc/fstab.bak

# Remove old entries (using '#' delimiter to avoid syntax errors)
sed -i '\#/dev/shm#d' /etc/fstab
sed -i '\#/run/shm#d' /etc/fstab

# Add hardened entries
echo "tmpfs /dev/shm tmpfs defaults,nodev,nosuid,noexec 0 0" | tee -a /etc/fstab >/dev/null
echo "tmpfs /run/shm tmpfs defaults,nodev,nosuid,noexec 0 0" | tee -a /etc/fstab >/dev/null

# Apply Changes Immediately
mount -o remount,defaults,nodev,nosuid,noexec /dev/shm 2>/dev/null || true

echo "    -> Shared memory hardened."
echo "DONE"
