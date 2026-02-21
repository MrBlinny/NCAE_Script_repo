#!/bin/sh
# ============================================================================
# user_admin.sh — CCDC User Management (Standalone / No-AD Version)
# ============================================================================
# usage:
#   sudo sh user_admin.sh                          # Interactive mode
#   sudo sh user_admin.sh --audit-only             # Read-only audit
#   sudo sh user_admin.sh --passwords-only         # Just rotate passwords
# ============================================================================

# ── Modes ───────────────────────────────────────────────────────────────────
AUDIT_ONLY=false; PASSWORDS_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --audit-only) AUDIT_ONLY=true ;;
        --passwords-only) PASSWORDS_ONLY=true ;;
    esac
done

# ── Globals ─────────────────────────────────────────────────────────────────
HOSTNAME=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "unknown")
TIMESTAMP=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo "notime")
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
STATE_DIR="$SCRIPT_DIR/.ccdc_state"
SNAPSHOT="$STATE_DIR/last_snapshot.txt"
FIRST_SNAPSHOT="$STATE_DIR/first_snapshot.txt"
REPORT_DIR="${SCRIPT_DIR}/ccdc_reports/users_${HOSTNAME}_${TIMESTAMP}"
BACKUP_DIR="$REPORT_DIR/backups"
LOG="$REPORT_DIR/report.log"
mkdir -p "$BACKUP_DIR" "$STATE_DIR" "$REPORT_DIR/ir_evidence"
chmod 700 "$REPORT_DIR" "$STATE_DIR" 2>/dev/null

# Save snapshot on exit
save_snapshot() {
    if [ -n "$CURRENT_SNAP" ]; then
        echo "$CURRENT_SNAP" > "$SNAPSHOT" 2>/dev/null
        chmod 600 "$SNAPSHOT" 2>/dev/null
    fi
}
trap save_snapshot EXIT INT TERM

# ── Colors ──────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
    R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; B='\033[1m'; N='\033[0m'
else
    R=''; G=''; Y=''; C=''; B=''; N=''
fi

# ── Helpers ─────────────────────────────────────────────────────────────────
cmd_exists() { command -v "$1" > /dev/null 2>&1; }
log()    { printf "[%s] %s\n" "$(date +%H:%M:%S 2>/dev/null)" "$1" >> "$LOG"; }
banner() { printf "\n${C}${B}══════════════════════════════════════════════════════════════${N}\n"; }
header() { printf "\n${C}${B}[*] %s${N}\n" "$1"; printf '%60s\n' '' | tr ' ' '-'; }
ok()     { printf "${G}  [✓] %s${N}\n" "$1"; log "OK: $1"; }
warn_()  { printf "${Y}  [!] %s${N}\n" "$1"; log "WARN: $1"; WARNINGS=$((WARNINGS+1)); }
crit()   { printf "${R}${B}  [!!!] %s${N}\n" "$1"; log "CRIT: $1"; CRITICALS=$((CRITICALS+1)); }
info()   { printf "  [-] %s\n" "$1"; }
skip()   { printf "${Y}  [—] SKIPPED: %s${N}\n" "$1"; log "SKIP: $1"; }
fix()    { printf "${C}      ↳ FIX: %s${N}\n" "$1"; }
indent() { sed 's/^/      /'; }

confirm() {
    if [ "$AUDIT_ONLY" = true ]; then return 1; fi
    printf "${Y}  [?] %s [y/N]: ${N}" "$1"
    read -r ans < /dev/tty
    case "$ans" in y|Y|yes|YES) return 0;; *) return 1;; esac
}

backup_file() {
    if [ -f "$1" ]; then
        safe_chattr -i "$1"
        dest="$BACKUP_DIR/$(echo "$1" | tr '/' '_')"
        cp -a "$1" "$dest" 2>/dev/null
        log "BACKUP: $1 -> $dest"
    fi
}

safe_chattr() {
    flag="$1"; file="$2"
    if ! cmd_exists chattr; then return 1; fi
    if chattr "$flag" "$file" 2>/dev/null; then return 0; else return 1; fi
}

critical_operation() {
    CRITICAL_FILES="/etc/passwd /etc/shadow /etc/group /etc/gshadow"
    LOCKED_FILES=""
    for f in $CRITICAL_FILES; do
        [ -f "$f" ] || continue
        if cmd_exists lsattr; then
            if lsattr "$f" 2>/dev/null | awk '{print $1}' | grep -q 'i'; then
                LOCKED_FILES="$LOCKED_FILES $f"
                safe_chattr -i "$f"
            fi
        fi
    done
    "$@"
    result=$?
    for f in $LOCKED_FILES; do safe_chattr +i "$f"; done
    return $result
}

# ── Root Check ──────────────────────────────────────────────────────────────
if [ "$(id -u)" != "0" ]; then
    printf "${R}${B}  [!] This script must be run as root!${N}\n"
    exit 1
fi

CRITICALS=0; WARNINGS=0; FIXED=0

banner
printf "${C}${B}  USER MANAGEMENT (Standalone) — %s${N}\n" "$HOSTNAME"
printf "${C}  Report:  %s${N}\n" "$REPORT_DIR"
if [ "$AUDIT_ONLY" = true ]; then printf "${G}${B}  MODE: AUDIT-ONLY (no changes)${N}\n"; fi
banner

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  0. GLOBAL EXCLUSIONS & CONFIG                                          ║
# ╚════════════════════════════════════════════════════════════════════════════╝
EXCLUDE_FILE="${SCRIPT_DIR}/global_exclude.txt"
EXCLUDED_USERS=""
EXCLUDED_PROCS=""

load_exclusions() {
    if [ -f "$EXCLUDE_FILE" ]; then
        info "Loading exclusions from $EXCLUDE_FILE..."
        EXCLUDED_USERS=$(grep "^USER:" "$EXCLUDE_FILE" 2>/dev/null | cut -d: -f2 | tr '\n' ' ' | sed 's/ $//')
        EXCLUDED_PROCS=$(grep "^PROC:" "$EXCLUDE_FILE" 2>/dev/null | cut -d: -f2 | tr '\n' ' ' | sed 's/ $//')
        [ -n "$EXCLUDED_USERS" ] && ok "Excluded Users: $EXCLUDED_USERS"
    else
        if [ "$AUDIT_ONLY" = false ]; then
            echo ""
            printf "${Y}${B}  ╔══════════════════════════════════════════════════════════╗${N}\n"
            printf "${Y}${B}  ║  ⚠  CRITICAL: DO NOT BREAK SCORING / INFRASTRUCTURE    ║${N}\n"
            printf "${Y}${B}  ║  Create global_exclude.txt for scoring users/services  ║${N}\n"
            printf "${Y}${B}  ╚══════════════════════════════════════════════════════════╝${N}\n"
            
            if confirm "Configure global exclusions now?"; then
                printf "${Y}  Enter USERS to exclude (space separated, e.g. scoring ubuntu): ${N}"
                read -r ex_users
                echo "# CCDC Global Exclusions" > "$EXCLUDE_FILE"
                for u in $ex_users; do echo "USER:$u" >> "$EXCLUDE_FILE"; done
                EXCLUDED_USERS="$ex_users"
                ok "Exclusions saved to $EXCLUDE_FILE"
            fi
        fi
    fi
}

is_excluded_user() {
    [ -z "$EXCLUDED_USERS" ] && return 1
    echo "$EXCLUDED_USERS" | grep -qwF "$1"
}

load_exclusions

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  1. LOAD AUTHORIZED LISTS                                               ║
# ╚════════════════════════════════════════════════════════════════════════════╝
header "LOADING AUTHORIZED LISTS"
info "Reads admins.txt and users.txt. Users not listed here will be flagged."

clean_list() {
    [ -f "$1" ] || return
    tr -d '\r' < "$1" 2>/dev/null | grep -v '^#\|^[[:space:]]*$' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sort -u
}

ADMINS_FILE="$SCRIPT_DIR/admins.txt"
USERS_FILE="$SCRIPT_DIR/users.txt"

if [ -f "$ADMINS_FILE" ]; then
    ADMINS=$(clean_list "$ADMINS_FILE")
    ok "Loaded admins.txt"
else
    warn_ "admins.txt not found! Create it with one admin username per line."
    ADMINS=""
fi

if [ -f "$USERS_FILE" ]; then
    USERS=$(clean_list "$USERS_FILE")
    ok "Loaded users.txt"
else
    warn_ "users.txt not found!"
    USERS=""
fi

ALL_AUTHORIZED=$(printf '%s\n%s\nroot\n' "$ADMINS" "$USERS" | grep -v '^$' | sort -u)

# ── User Context Helper ─────────────────────────────────────────────────────
is_user_locked() {
    passwd -S "$1" 2>/dev/null | grep -qE "L|LK"
}

show_user_context() {
    _u="$1"
    if is_user_locked "$_u"; then _lock="LOCKED"; else _lock="ACTIVE"; fi
    _shell=$(grep "^${_u}:" /etc/passwd 2>/dev/null | cut -d: -f7)
    _uid=$(id -u "$_u" 2>/dev/null)

    printf "${R}      %-15s UID:%-6s Status:%-8s Shell:%s${N}\n" "$_u" "$_uid" "$_lock" "$_shell"

    _procs=$(ps -u "$_u" -o comm= 2>/dev/null | sort -u | tr '\n' ', ' | sed 's/,$//')
    if [ -n "$_procs" ]; then
        printf "      Processes: %s\n" "$_procs"
    fi
    
    if cmd_exists ss; then
        _ports=$(ss -tlnp 2>/dev/null | grep "$_u" | awk '{print $4}' | tr '\n' ', ' | sed 's/,$//')
        [ -n "$_ports" ] && printf "${Y}      Listening Ports: %s${N}\n" "$_ports"
    fi
}

kill_user_procs() {
    target_user="$1"
    if is_excluded_user "$target_user"; then
        warn_ "Skipping process kill for $target_user (Excluded)"
        return
    fi
    
    pcount=$(ps -u "$target_user" -o pid= 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$pcount" -gt 0 ] 2>/dev/null; then
        # Capture Evidence before killing
        evidence_file="$REPORT_DIR/ir_evidence/${target_user}_$(date +%H%M%S).txt"
        ps -u "$target_user" -o pid,ppid,user,stat,start,time,cmd > "$evidence_file" 2>/dev/null
        
        if confirm "Kill $pcount processes for $target_user?"; then
            info "Killing processes... (Evidence saved to $evidence_file)"
            pkill -KILL -u "$target_user" 2>/dev/null
            sleep 1
            ok "Killed processes for $target_user"
        fi
    fi
}

# If passwords-only mode, skip directly to password rotation
if [ "$PASSWORDS_ONLY" = true ]; then
    info "Skipping audit/snapshot steps (passwords-only mode)..."
else

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  2. SNAPSHOT & DIFF                                                     ║
# ╚════════════════════════════════════════════════════════════════════════════╝
header "CHANGE TRACKING"
# Simple snapshot: username:uid:shell
current_snap() {
    awk -F: '($3==0 || $3>=1000) && $1!="nobody" {printf "%s:%s:%s\n", $1, $3, $7}' /etc/passwd 2>/dev/null | sort
}
CURRENT_SNAP=$(current_snap)

if [ -f "$SNAPSHOT" ]; then
    OLD_SNAP=$(cat "$SNAPSHOT")
    NEW_USERS=$(echo "$CURRENT_SNAP" | while read -r line; do
        u=$(echo "$line" | cut -d: -f1)
        echo "$OLD_SNAP" | grep -q "^${u}:" || echo "$u"
    done)

    if [ -n "$NEW_USERS" ]; then
        crit "NEW USERS FOUND since last run:"
        echo "$NEW_USERS" | indent
    else
        ok "No new users since last run"
    fi
else
    info "First run — creating baseline snapshot"
fi

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  3. ENUMERATE & REMOVE UNAUTHORIZED USERS                               ║
# ╚════════════════════════════════════════════════════════════════════════════╝
header "USER COMPARISON"

# Get all real users (UID >= 1000 + root)
SYSTEM_USERS=$(awk -F: '($3==0 || $3>=1000) && $1!="nobody" && $1!="nfsnobody" {print $1}' /etc/passwd 2>/dev/null | sort)

UNAUTHORIZED=$(echo "$SYSTEM_USERS" | while read -r u; do
    [ -z "$u" ] && continue
    echo "$ALL_AUTHORIZED" | grep -qx "$u" || echo "$u"
done)

if [ -n "$UNAUTHORIZED" ]; then
    crit "UNAUTHORIZED USERS FOUND:"
    echo "$UNAUTHORIZED" | while read -r u; do
        [ -z "$u" ] && continue
        
        if is_excluded_user "$u"; then
            printf "${C}      [SKIPPED] %s (Globally Excluded)${N}\n" "$u"
            continue
        fi
        
        show_user_context "$u"

        if [ "$AUDIT_ONLY" = false ]; then
            printf "${Y}  [?] [L]ock / [D]isable Shell / [R]emove / [K]ill Procs / [S]kip (%s): ${N}" "$u"
            read -r action < /dev/tty
            action=${action:-S}

            case "$action" in
                l|L)
                    kill_user_procs "$u"
                    critical_operation usermod -L "$u" 2>/dev/null
                    ok "Locked $u"
                    ;;
                d|D)
                    kill_user_procs "$u"
                    critical_operation usermod -s /usr/sbin/nologin "$u" 2>/dev/null
                    ok "Disabled shell for $u"
                    ;;
                r|R)
                    kill_user_procs "$u"
                    if [ -d "/home/$u" ]; then
                        cp -a "/home/$u" "$BACKUP_DIR/home_${u}" 2>/dev/null
                        info "Home dir backed up"
                    fi
                    critical_operation userdel "$u" 2>/dev/null
                    ok "Removed $u"
                    ;;
                k|K)
                    kill_user_procs "$u"
                    ;;
                *)
                    skip "$u"
                    ;;
            esac
        fi
    done
else
    ok "No unauthorized users found (System matches admins.txt + users.txt)"
fi

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  4. ADMIN GROUP AUDIT                                                   ║
# ╚════════════════════════════════════════════════════════════════════════════╝
header "ADMIN GROUP AUDIT"

# Detect sudo/wheel
if grep -q '^sudo:' /etc/group 2>/dev/null; then ADMIN_GROUP="sudo"
elif grep -q '^wheel:' /etc/group 2>/dev/null; then ADMIN_GROUP="wheel"
fi

if [ -n "$ADMIN_GROUP" ]; then
    # Get users currently in the admin group
    ACTUAL_ADMINS=$(grep "^${ADMIN_GROUP}:" /etc/group 2>/dev/null | cut -d: -f4 | tr ',' '\n' | grep -v '^$' | sort)
    
    # Check for unauthorized admins
    echo "$ACTUAL_ADMINS" | while read -r u; do
        [ -z "$u" ] && continue
        if ! echo "$ADMINS" | grep -qx "$u"; then
            crit "$u is in $ADMIN_GROUP but NOT in admins.txt"
            if [ "$AUDIT_ONLY" = false ]; then
                if confirm "Remove $u from $ADMIN_GROUP group?"; then
                    critical_operation gpasswd -d "$u" "$ADMIN_GROUP" 2>/dev/null || critical_operation deluser "$u" "$ADMIN_GROUP" 2>/dev/null
                    ok "Removed $u from $ADMIN_GROUP"
                fi
            fi
        fi
    done

    # Check for NOPASSWD in sudoers
    if grep -r "NOPASSWD" /etc/sudoers /etc/sudoers.d 2>/dev/null; then
        crit "Found NOPASSWD in sudoers (Dangerous!):"
        grep -r "NOPASSWD" /etc/sudoers /etc/sudoers.d 2>/dev/null | indent
        if [ "$AUDIT_ONLY" = false ] && confirm "Remove all NOPASSWD entries?"; then
            sed -i 's/NOPASSWD:/PASSWD:/g' /etc/sudoers 2>/dev/null
            find /etc/sudoers.d -type f -exec sed -i 's/NOPASSWD:/PASSWD:/g' {} + 2>/dev/null
            ok "Remediated NOPASSWD entries"
        fi
    fi
fi

# Audit Docker group (Root equivalent)
if grep -q "^docker:" /etc/group; then
    warn_ "Docker group found (Root Equivalent!). Users:"
    grep "^docker:" /etc/group | cut -d: -f4 | tr ',' '\n' | indent
fi

fi # End Audit/Snapshot block

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  5. PASSWORD ROTATION                                                   ║
# ╚════════════════════════════════════════════════════════════════════════════╝
header "PASSWORD ROTATION"

rotate_passwords() {
    target_group="$1"
    user_list="$2"

    [ -z "$user_list" ] && return
    
    echo ""
    if confirm "Rotate passwords for $target_group?"; then
        printf "${Y}${B}  Enter NEW password for $target_group: ${N}"
        stty -echo; read -r NEWPW; stty echo; echo ""
        
        [ -z "$NEWPW" ] && { warn_ "Empty password! Skipping."; return; }

        for user in $user_list; do
            if is_excluded_user "$user"; then
                warn_ "Skipping $user (Excluded)"
                continue
            fi
            
            # Unlock, set password, restore lock if needed
            was_locked=false; is_user_locked "$user" && was_locked=true
            
            safe_chattr -i /etc/shadow
            usermod -U "$user" 2>/dev/null
            echo "${user}:${NEWPW}" | chpasswd 2>/dev/null
            if [ $? -eq 0 ]; then
                ok "Password set for $user"
            else
                warn_ "Failed to set password for $user"
            fi
            
            if [ "$was_locked" = true ]; then usermod -L "$user" 2>/dev/null; fi
            safe_chattr +i /etc/shadow
        done
    fi
}

if [ "$AUDIT_ONLY" = true ]; then
    info "Skipping password rotation (audit mode)"
else
    # 1. Root
    rotate_passwords "ROOT" "root"
    
    # 2. Admins (Local)
    rotate_passwords "ADMINS" "$ADMINS"

    # 3. Standard Users (Anyone in users.txt who is not an admin)
    STD_USERS=""
    if [ -n "$USERS" ]; then
        for u in $USERS; do
            echo "$ADMINS" | grep -qx "$u" && continue
            id "$u" >/dev/null 2>&1 && STD_USERS="$STD_USERS $u"
        done
    fi
    rotate_passwords "STANDARD USERS" "$STD_USERS"
    
    echo ""
    printf "${R}${B}  ⚠  SCORING ALERT: Update scoring engine with new service passwords!${N}\n"
fi

if [ "$PASSWORDS_ONLY" = true ]; then
    ok "Password rotation complete."
    exit 0
fi

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  6. SECURITY AUDIT (Keys, Backdoors, Shells)                            ║
# ╚════════════════════════════════════════════════════════════════════════════╝
header "SYSTEM SECURITY AUDIT"

# Check for empty passwords
if [ -r /etc/shadow ]; then
    empty_pw=$(awk -F: '$2=="" && $1!="*" {print $1}' /etc/shadow 2>/dev/null)
    if [ -n "$empty_pw" ]; then
        crit "EMPTY PASSWORDS DETECTED:"
        echo "$empty_pw" | indent
        if [ "$AUDIT_ONLY" = false ] && confirm "Lock these accounts?"; then
            for u in $empty_pw; do usermod -L "$u" 2>/dev/null; done
            ok "Accounts locked"
        fi
    fi
fi

# Check SSH Keys
for hd in /root /home/*; do
    [ -d "$hd" ] || continue
    u=$(basename "$hd"); [ "$hd" = "/root" ] && u="root"
    
    ak="$hd/.ssh/authorized_keys"
    if [ -s "$ak" ]; then
        warn_ "SSH Keys found for $u"
        if [ "$AUDIT_ONLY" = false ] && confirm "  Remove SSH keys for $u?"; then
            backup_file "$ak"
            : > "$ak"
            ok "Keys removed"
        fi
    fi
    
    # Check for backdoors in bashrc
    for rc in .bashrc .bash_profile; do
        f="$hd/$rc"; [ -f "$f" ] || continue
        if grep -q "nc \|/dev/tcp\|python" "$f"; then
            crit "Suspicious commands in $u's $rc"
            grep "nc \|/dev/tcp\|python" "$f" | indent
        fi
    done
done

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  7. CRITICAL FILE LOCKING                                               ║
# ╚════════════════════════════════════════════════════════════════════════════╝
header "FILE HARDENING"

LOCKABLE_FILES="/etc/passwd /etc/shadow /etc/group /etc/sudoers /etc/ssh/sshd_config"

if [ "$AUDIT_ONLY" = true ]; then
    info "Skipping file locking (audit mode)"
elif confirm "Lock critical files (chattr +i)?"; then
    if ! cmd_exists chattr; then
        warn_ "chattr not found, installing..."
        apt-get install -y e2fsprogs >/dev/null 2>&1
    fi

    for f in $LOCKABLE_FILES; do
        [ -f "$f" ] || continue
        safe_chattr -i "$f" # Unlock first to be safe
        if safe_chattr +i "$f"; then
            ok "Locked $f"
        else
            warn_ "Failed to lock $f (Filesystem support?)"
        fi
    done
fi

banner
printf "${B}  COMPLETE. Review $REPORT_DIR for details.${N}\n"
banner
