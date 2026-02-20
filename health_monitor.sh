#!/bin/bash

# ================= CONFIGURATION =================
# The IP of the Router/Gateway (to check connectivity)
GATEWAY_IP="192.168.0.1" 

# Services to check (Adjust based on the machine role)
CHECK_WEB=true   # Set to false if this machine isn't a Web Server
CHECK_DB=true    # Set to false if not a DB
CHECK_SSH=true   # Always check SSH
# =================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' 
CLEAR_SCREEN="\033[2J\033[H"

while true; do
    echo -e "$CLEAR_SCREEN"
    echo "=== NCAE SERVICE HEALTH DASHBOARD ==="
    echo "Time: $(date)"
    echo "-------------------------------------"

    # 1. CHECK CONNECTIVITY (Ping Gateway)
    if ping -c 1 -W 1 "$GATEWAY_IP" >/dev/null 2>&1; then
        echo -e "NETWORK: [ ${GREEN}ONLINE${NC} ] (Gateway reachable)"
    else
        echo -e "NETWORK: [ ${RED}OFFLINE${NC} ] (Cannot ping $GATEWAY_IP)"
    fi

    # 2. CHECK SSH (Port 22)
    if [ "$CHECK_SSH" = true ]; then
        if ss -tuln | grep -q ":22 "; then
             echo -e "SSH    : [ ${GREEN}UP${NC} ]"
        else
             echo -e "SSH    : [ ${RED}DOWN${NC} ] (Panic!)"
        fi
    fi

    # 3. CHECK WEB (Port 80)
    if [ "$CHECK_WEB" = true ]; then
        # Check if Port 80 is listening
        if ss -tuln | grep -q ":80 "; then
             STATUS_80="${GREEN}UP${NC}"
        else
             STATUS_80="${RED}DOWN${NC}"
        fi
        
        # Check actual HTML content (Localhost check)
        # Allows you to see if the page is serving content or an error
        HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" http://localhost)
        if [ "$HTTP_CODE" == "200" ]; then
            CONTENT="${GREEN}200 OK${NC}"
        else
            CONTENT="${RED}$HTTP_CODE${NC}"
        fi
        echo -e "WEB    : [ $STATUS_80 ] (Content: $CONTENT)"
    fi

    # 4. CHECK DB (Port 3306 or 5432)
    if [ "$CHECK_DB" = true ]; then
        if ss -tuln | grep -q ":3306 "; then
             echo -e "MySQL  : [ ${GREEN}UP${NC} ]"
        elif ss -tuln | grep -q ":5432 "; then
             echo -e "Postgre: [ ${GREEN}UP${NC} ]"
        else
             echo -e "DB     : [ ${RED}DOWN${NC} ] (Check service status!)"
        fi
    fi

    echo "-------------------------------------"
    echo "Press [CTRL+C] to stop."
    sleep 5
done
