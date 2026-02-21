#!/bin/bash

# ============================================================================
# nixarmor_fast.sh — Quick & Dirty Hardening (Polished)
# ============================================================================

# Check for Root
if [ "$(id -u)" != "0" ]; then echo "Root required."; exit 1; fi

harden_php() {
    echo "[*] Hardening PHP (Sed Mode)..."
    
    # 1. Define the disable list. 
    DISABLE_SAFE="pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,dl,symlink,link,show_source,highlight_file,phpinfo"
    
    # Uncomment this line if you want to go FULL SCORCHED EARTH (Risk of service failure):
    # DISABLE_SAFE="${DISABLE_SAFE},system,shell_exec,passthru,exec,popen,proc_open"

    # Find every php.ini
    find /etc/php -name "php.ini" 2>/dev/null | while read i; do
        echo "    -> Securing $i"
        
        # Nuking error display (Matches optional leading spaces)
        sed -i 's/^\s*display_errors.*/display_errors = Off/' "$i"
        sed -i 's/^\s*log_errors.*/log_errors = On/' "$i"
        
        # Killing remote file inclusion
        sed -i 's/^\s*allow_url_fopen.*/allow_url_fopen = Off/' "$i"
        sed -i 's/^\s*allow_url_include.*/allow_url_include = Off/' "$i"
        
        # Upping limits
        sed -i 's/^\s*memory_limit.*/memory_limit = 128M/' "$i"
        sed -i 's/^\s*upload_max_filesize.*/upload_max_filesize = 2M/' "$i"
        
        # The Golden String (Logic fixed to handle comments)
        if grep -q "^\s*disable_functions" "$i"; then
            # If it exists (even commented), replace it
            sed -i "s/^\s*disable_functions.*/disable_functions = ${DISABLE_SAFE}/" "$i"
        else
            # If not found, append it
            echo "disable_functions = ${DISABLE_SAFE}" >> "$i"
        fi
    done
}

harden_apache() {
    echo "[*] Hardening Apache..."
    CONF="/etc/apache2/apache2.conf"
    
    if [ -f "$CONF" ]; then
        # Check before appending to avoid duplicates
        grep -q "ServerTokens Prod" "$CONF" || echo "ServerTokens Prod" >> "$CONF"
        grep -q "ServerSignature Off" "$CONF" || echo "ServerSignature Off" >> "$CONF"
        grep -q "TraceEnable Off" "$CONF" || echo "TraceEnable Off" >> "$CONF"
        
        # Check config syntax before restarting so we don't kill the service
        if command -v apache2ctl >/dev/null; then
            if apache2ctl -t >/dev/null 2>&1; then
                systemctl restart apache2 2>/dev/null
                echo "    -> Apache restarted."
            else
                echo "    -> WARNING: Apache config syntax is BAD. Did not restart."
            fi
        fi
    else
        echo "    -> Apache conf not found, skipping."
    fi
}

main() {
    harden_php
    harden_apache
    echo "[+] Done."
}

main "$@"
