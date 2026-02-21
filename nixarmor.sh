#!/bin/bash

# ============================================================================
# nixarmor_fast.sh — Quick & Dirty Hardening
# ============================================================================

# Check for Root (The only check we keep)
if [ "$(id -u)" != "0" ]; then echo "Root required."; exit 1; fi

harden_php() {
    echo "[*] Hardening PHP (Sed Mode)..."
    # Find every php.ini and hammer it with sed
    find /etc/php -name "php.ini" 2>/dev/null | while read i; do
        # Nuking error display
        sed -i 's/^display_errors.*/display_errors = Off/' "$i"
        sed -i 's/^log_errors.*/log_errors = On/' "$i"
        
        # Killing remote file inclusion
        sed -i 's/^allow_url_fopen.*/allow_url_fopen = Off/' "$i"
        sed -i 's/^allow_url_include.*/allow_url_include = Off/' "$i"
        
        # Upping limits (Prevent crashes, but keep it tight)
        sed -i 's/^memory_limit.*/memory_limit = 128M/' "$i"
        
        # The Golden String (Direct Append/Replace)
        DISABLE="pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,dl,symlink,link,show_source,highlight_file,phpinfo,system,shell_exec,passthru,exec,popen,proc_open"
        
        if grep -q "^disable_functions" "$i"; then
            sed -i "s/^disable_functions.*/disable_functions = ${DISABLE}/" "$i"
        else
            echo "disable_functions = ${DISABLE}" >> "$i"
        fi
    done
}

harden_apache() {
    echo "[*] Hardening Apache..."
    # If file exists, echo configs to the bottom. Fast.
    CONF="/etc/apache2/apache2.conf"
    if [ -f "$CONF" ]; then
        echo "ServerTokens Prod" >> "$CONF"
        echo "ServerSignature Off" >> "$CONF"
        echo "TraceEnable Off" >> "$CONF"
        systemctl restart apache2 2>/dev/null
    fi
}


main() {
    harden_php
    harden_apache
    
    echo "[+] Done."
}

main "$@"
