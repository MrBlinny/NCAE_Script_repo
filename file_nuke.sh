#!/bin/bash

# ============================================================================
# nuke_and_seal.sh — The "Scorched Earth" Baseline (Fixed)
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

# Clients (Keep wget/curl if you haven't finished downloading yet!)
rm -f /usr/bin/ftp /usr/bin/lftp /usr/bin/tftp
# rm -f /usr/bin/wget /usr/bin/curl

# Obfuscation
rm -f /usr/bin/base64 /usr/bin/uuencode /usr/bin/uudecode

echo "Moving wget and curl..."
[ -f /usr/bin/wget ] && mv /usr/bin/wget /usr/bin/download
[ -f /usr/bin/curl ] && mv /usr/bin/curl /usr/bin/browse

echo "    -> Binaries destroyed."

# --- 2. THE PERMISSION SEAL (Programmatic Fix) ---
echo "[*] Phase 2: Applying Safe Permissions (Sane Defaults)..."

# 1. Fix Root Permissions (Standard Security)
# Directories -> 755, Files -> 644
echo "    -> Securing /etc, /usr, /var..."
find /etc /usr /var -type d -exec chmod 755 {} + 2>/dev/null
find /etc /usr /var -type f -exec chmod 644 {} + 2>/dev/null

# 2. Lock down Shadow/Passwd
echo "    -> Locking User Credentials..."
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 600 /etc/shadow
chmod 600 /etc/gshadow
chown root:root /etc/passwd /etc/group /etc/shadow /etc/gshadow

# 3. Secure Binaries (Executable but not writable)
echo "    -> Securing Binaries..."
chmod 755 /bin /sbin /usr/bin /usr/sbin
chmod 755 /bin/* /sbin/* /usr/bin/* /usr/sbin/* 2>/dev/null

# 4. Critical Tmp Permissions (Sticky Bit)
echo "    -> Fixing /tmp Sticky Bit..."
chmod 1777 /tmp /var/tmp
chown root:root /tmp /var/tmp

# --- 3. THE SAFETY NET (Fix Broken Services) ---
echo "[*] Phase 3: Checking Service Health..."

# Web Server (Sessions must be writable by www-data)
if [ -d "/var/lib/php/sessions" ]; then
    echo "    -> Fixing PHP Sessions..."
    chmod 1733 /var/lib/php/sessions
    chown root:www-data /var/lib/php/sessions
fi

# Web Root (Writable by owner, readable by web server)
if [ -d "/var/www/html" ]; then
    echo "    -> Fixing Web Root..."
    chown -R www-data:www-data /var/www/html
    find /var/www/html -type d -exec chmod 755 {} \;
    find /var/www/html -type f -exec chmod 644 {} \;
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

echo "[+] SYSTEM SEALED."
