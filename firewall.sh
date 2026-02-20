#!/bin/bash

# ================= CONFIGURATION =================
# Your internal subnet (The "Blue Team LAN" from the diagram)
INTERNAL_NET="192.168.0.0/16" 
# =================================================

echo "=== NCAE HARDENING: Host Firewall Deployer ==="
echo "Select the role of THIS machine:"
echo "1) Web Server (.5)"
echo "2) Database Server (.7)"
echo "3) DNS Server (.12)"
echo "4) Generic/Backup (SSH Only)"
echo "5) FLUSH ALL (Reset to Open - Emergency Button)"
read -p "Selection [1-5]: " ROLE

# --- 1. FLUSH EXISTING RULES ---
# Clear all current rules to start fresh
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

if [ "$ROLE" == "5" ]; then
    echo " [!] Firewall Flushed. All traffic allowed."
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    exit 0
fi

echo " [*] Applying Base Policies..."

# --- 2. BASE POLICIES ---
# Drop everything by default
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT # Allow outbound for now (updates/scoring checks)

# --- 3. UNIVERSAL ALLOW RULES ---
iptables -A INPUT -i lo -j ACCEPT

# Allow Established/Related (If we asked for it, allow the reply)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow ICMP (Ping) - Required for "Router ICMP Ping" scoring? 
# Usually good to allow internal ping for debugging.
iptables -A INPUT -p icmp -j ACCEPT

# --- 4. SSH ACCESS (INTERNAL ONLY) ---
# Scoring checks SSH from "Internal Network"
# We allow SSH only from the 192.168.x.x range.
iptables -A INPUT -p tcp --dport 22 -s $INTERNAL_NET -j ACCEPT
echo " [+] SSH allowed from $INTERNAL_NET only."

# --- 5. ROLE SPECIFIC RULES ---
case $ROLE in
    1) # Web Server
        echo " [+] Configuring WEB Server Rules..."
        # Allow HTTP (80) and HTTPS (443) from ANYWHERE
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        ;;
    2) # Database Server
        echo " [+] Configuring DB Server Rules..."
        # Allow MySQL (3306) and Postgres (5432)
        # Router forwards these from WAN, so we must allow from ANY IP
        iptables -A INPUT -p tcp --dport 3306 -j ACCEPT
        iptables -A INPUT -p tcp --dport 5432 -j ACCEPT
        ;;
    3) # DNS Server
        echo " [+] Configuring DNS Server Rules..."
        # Allow DNS (53) UDP and TCP
        iptables -A INPUT -p udp --dport 53 -j ACCEPT
        iptables -A INPUT -p tcp --dport 53 -j ACCEPT
        ;;
    4) # Generic
        echo " [+] Configuring Generic Rules (SSH Only)..."
        # No extra ports needed
        ;;
    *)
        echo "Invalid selection."
        exit 1
        ;;
esac

# --- 6. LOGGING (OPTIONAL) ---
# Log dropped packets (limit to prevent log spam)
# Helpful to see if the scoring engine is getting blocked
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

echo "=== Firewall Configured Successfully ==="
echo "Current Rules:"
iptables -S
