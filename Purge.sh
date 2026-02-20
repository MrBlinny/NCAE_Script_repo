#!/bin/bash

WHITELIST_FILE="authorized_users.txt"
NEW_PASSWORD="ChangeMe!123" 
DRY_RUN=true 

# --- SANITIZE WHITELIST ---
# Create a clean temporary list without spaces or Windows characters
if [[ ! -f "$WHITELIST_FILE" ]]; then
    echo "Error: $WHITELIST_FILE not found!"
    exit 1
fi
CLEAN_LIST=$(mktemp)
sed 's/\r$//; s/^[ \t]*//; s/[ \t]*$//' "$WHITELIST_FILE" > "$CLEAN_LIST"

# --- CHECK FOR UID 0 ROGUES ---
echo "=== Checking for UID 0 Imposters ==="
# Find any user with UID 0 that is NOT named 'root'
ROGUE_ROOTS=$(awk -F: '($3 == 0 && $1 != "root") {print $1}' /etc/passwd)

if [ -n "$ROGUE_ROOTS" ]; then
    for rogue in $ROGUE_ROOTS; do
        echo " [!!!] CRITICAL: User '$rogue' has UID 0 (Root Access)!"
        if [ "$DRY_RUN" = false ]; then
             pkill -KILL -u "$rogue"
             userdel -rf "$rogue"
             echo "     -> TERMINATED."
        else
             echo "     -> (Dry Run) Would KILL and DELETE."
        fi
    done
else
    echo " [OK] No rogue UID 0 accounts found."
fi

# --- STANDARD USER PURGE ---
echo "=== Verifying Standard Users ==="
# Loop through all users with UID >= 1000
grep -E "^[^:]+:[^:]+:[0-9]{4,}:" /etc/passwd | cut -d: -f1 | while read user; do

    # Check against the sanitized whitelist
    if grep -Fxq "$user" "$CLEAN_LIST"; then
        echo "[+] '$user' is AUTHORIZED."
    else
        echo "[-] '$user' is UNAUTHORIZED."
        if [ "$DRY_RUN" = false ]; then
            pkill -KILL -u "$user"
            userdel -rf "$user"
            echo "    -> User wiped."
        else
            echo "    -> (Dry Run) Would kill processes and delete user."
        fi
    fi
done

rm "$CLEAN_LIST"
echo "=== Audit Complete ==="
