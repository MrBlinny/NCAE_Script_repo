#!/bin/bash

# ================= CONFIGURATION =================
SCORING_USER="scoring"       # User required by scoring engine
SCORING_PASS="ScorePoints!2026" # CHANGE THIS to the competition password
# =================================================

echo "=== NCAE HARDENING: MySQL ==="

# 1. Check if MySQL is installed
if ! command -v mysql >/dev/null 2>&1; then
    echo " [!] MySQL is NOT installed. Skipping."
    exit 0
fi

# 2. Generate SQL Commands
# We use a temporary file to batch execute commands securely
SQL_FILE=$(mktemp)

cat <<EOF > "$SQL_FILE"
-- A. REMOVE INSECURE DEFAULTS
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';
-- Remove remote root login (Root can only log in from localhost)
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- B. CREATE SCORING USER
-- Create user that can connect from ANY host ('%') because scoring checks come from network
CREATE USER IF NOT EXISTS '$SCORING_USER'@'%' IDENTIFIED BY '$SCORING_PASS';

-- C. GRANT SCORING PRIVILEGES
-- Only give data access (SELECT, INSERT, UPDATE, DELETE). NO ADMIN RIGHTS.
GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO '$SCORING_USER'@'%';

-- D. APPLY CHANGES
FLUSH PRIVILEGES;
EOF

# 3. Execute SQL
echo " [*] Applying MySQL Security Policies..."
echo "     -> You will be prompted for the CURRENT MySQL root password."
echo "     -> If it's a fresh install, just press ENTER."

mysql -u root -p < "$SQL_FILE"

if [ $? -eq 0 ]; then
    echo " [+] MySQL Hardening Successful."
else
    echo " [!] MySQL Failed. Did you type the wrong root password?"
fi

# Cleanup
rm "$SQL_FILE"
