#!/bin/bash

if [ "$(id -u)" != "0" ]; then
    echo " [!] Run as root."
    exit 1
fi

echo "Nuking unwanted programs"

# 1. Network & Reverse Shell Tools
rm -f /usr/bin/nc /usr/bin/netcat /usr/bin/ncat /usr/bin/socat
rm -f /usr/bin/telnet /usr/bin/rsh /usr/bin/rlogin /usr/bin/rcp

# 2. Scanners & Sniffers
rm -f /usr/bin/nmap /usr/bin/zenmap /usr/bin/masscan
rm -f /usr/bin/tcpdump /usr/bin/wireshark /usr/bin/tshark
rm -f /usr/bin/hping3 /usr/bin/fping

# 3. Hacking Frameworks
rm -f /usr/bin/hydra /usr/bin/john /usr/bin/sqlmap /usr/bin/medusa /usr/bin/nikto /usr/bin/hashcat /usr/bin/mimikatz

# 4. Compilers 
rm -f /usr/bin/gcc* /usr/bin/g++* /usr/bin/cc /usr/bin/c++
rm -f /usr/bin/make /usr/bin/cmake /usr/bin/automake /usr/bin/autoconf
rm -f /usr/bin/as /usr/bin/nasm /usr/bin/yasm
rm -f /usr/bin/byacc /usr/bin/yacc /usr/bin/flex /usr/bin/bison

# 5. File Transfer Clients
rm -f /usr/bin/ftp /usr/bin/lftp /usr/bin/tftp

# 6. Obfuscation Tools
rm -f /usr/bin/base64 /usr/bin/uuencode /usr/bin/uudecode

echo "Moving wget and curl..."
mv /usr/bin/wget /usr/bin/download
mv /usr/bin/curl /usr/bin/browse


echo "Nuking Complete."
