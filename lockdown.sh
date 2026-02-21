#!/bin/bash

# ================= CONFIGURATION =================
# List all 6 files here. Use full paths.
FILES=(
    "/etc/bind/named.conf"
    "/etc/bind/named.conf.options"
    "/etc/bind/named.conf.local"
    "/etc/bind/zones/db.internal"
    "/etc/bind/zones/db.192"
    "/etc/bind/zones/db.external"
)

BACKUP_DIR="/root/.dns_safe_copies"
# Your secret renamed chattr binary (change this to match your system)
CHATTR="/usr/bin/chattr" 
# =================================================

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# --- INITIALIZATION PHASE ---
echo "[*] Initializing Watchdog..."

for FILE in "${FILES[@]}"; do
    if [ -f "$FILE" ]; then
        # Create a unique backup name by replacing slashes with underscores
        SAFE_NAME=$(echo "$FILE" | sed 's/\//_/g')
        
        # Copy to backup dir
        cp "$FILE" "$BACKUP_DIR/$SAFE_NAME"
        
        # Lock the file immediately
        $CHATTR +i "$FILE" 2>/dev/null
        
        echo "Locked and secured: $FILE"
    else
        echo "[!] WARNING: File not found: $FILE"
    fi
done

echo "[*] Watchdog Active. Monitoring..."

# --- MONITORING LOOP ---
while true; do
    for FILE in "${FILES[@]}"; do
        # 1. Reconstruct the backup path
        SAFE_NAME=$(echo "$FILE" | sed 's/\//_/g')
        BACKUP_PATH="$BACKUP_DIR/$SAFE_NAME"
        
        # 2. Check if file still exists (in case they deleted it)
        if [ ! -f "$FILE" ]; then
            echo "[!] ALERT: $FILE was DELETED! Restoring..."
            # Restore
            cp "$BACKUP_PATH" "$FILE"
            $CHATTR +i "$FILE"
            continue
        fi

        # 3. Compare Hashes (Current vs Backup)
        HASH_ORIG=$(md5sum "$BACKUP_PATH" | awk '{print $1}')
        HASH_LIVE=$(md5sum "$FILE" | awk '{print $1}')

        if [ "$HASH_ORIG" != "$HASH_LIVE" ]; then
            echo "[!] TAMPER DETECTED on $FILE! Reverting..."
            
            # Unlock
            $CHATTR -i "$FILE"
            
            # Force Restore from Backup
            cat "$BACKUP_PATH" > "$FILE"
            
            # Relock
            $CHATTR +i "$FILE"
            
            # Optional: Log the attack
            echo "$(date): $FILE was modified and restored." >> /var/log/guard_dog.log
        fi
    done
    
    # Sleep to save CPU (0.5s is fast enough)
    sleep 0.5
done
