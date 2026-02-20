#!/bin/bash

# ================= CONFIGURATION =================
SCORING_USER="scoring"
SCORING_PASS="ScorePoints!2026"
SCORING_DB="scoring_db" # Usually creates a DB named after the user
# =================================================

echo "=== NCAE HARDENING: PostgreSQL ==="

# 1. Check if Postgres is running
if ! command -v psql >/dev/null 2>&1; then
    echo " [!] PostgreSQL is NOT installed. Skipping."
    exit 0
fi

# 2. Create Scoring User & DB
echo " [*] Creating Scoring User and Database..."
# Run as 'postgres' user (system admin for pgsql)
sudo -u postgres psql -c "CREATE USER $SCORING_USER WITH PASSWORD '$SCORING_PASS';"
sudo -u postgres psql -c "CREATE DATABASE $SCORING_DB OWNER $SCORING_USER;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $SCORING_DB TO $SCORING_USER;"

echo "     -> User '$SCORING_USER' created."

# 3. Secure pg_hba.conf (The "Firewall" for Postgres)
# Locate the config file (version varies, so we search)
PG_HBA=$(find /etc/postgresql -name "pg_hba.conf" | head -n 1)

if [ -f "$PG_HBA" ]; then
    echo " [*] Hardening $PG_HBA..."
    cp "$PG_HBA" "${PG_HBA}.bak"
    
    # We want to replace "host all all ... trust" with "md5" (password required)
    # This sed command finds lines starting with 'host' and forces 'md5' auth
    sed -i 's/trust/md5/g' "$PG_HBA"
    sed -i 's/peer/md5/g' "$PG_HBA"
    
    # Ensure Scoring User can connect from anywhere (Network Scored)
    # Append a specific allow rule to the top if not exists
    if ! grep -q "$SCORING_USER" "$PG_HBA"; then
        echo "host    all             $SCORING_USER            0.0.0.0/0               md5" >> "$PG_HBA"
    fi
    
    # Restart Postgres to apply
    systemctl restart postgresql
    echo " [+] PostgreSQL restarted. Password auth enforced."
else
    echo " [!] Could not find pg_hba.conf!"
fi
