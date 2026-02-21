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

nuke_compilers() {
    echo "[*] Nuking Compilers (rm -f)..."
    # No package managers. Just deletion.
    rm -f /usr/bin/gcc* /usr/bin/g++* /usr/bin/cc /usr/bin/make /usr/bin/cmake /usr/bin/clang*
    rm -f /usr/bin/byacc /usr/bin/yacc /usr/bin/bcc /usr/bin/kgcc
}

nuke_hackertools() {
    echo "[*] Nuking Hacker Tools..."
    # Common tools Red Team uses that you probably don't need
    rm -f /usr/bin/nc /usr/bin/netcat /usr/bin/ncat /usr/bin/socat
    rm -f /usr/bin/nmap /usr/bin/zenmap
    rm -f /usr/bin/wireshark /usr/bin/tshark
    rm -f /usr/bin/telnet
    # Be careful with these two, remove if you need them:
    # rm -f /usr/bin/wget /usr/bin/curl 
}

apply_fileperms() {
    echo "[*] Applying fileperms.txt..."
    if [ -f "fileperms.txt" ]; then
        # Piping directly to bash as requested
        cat fileperms.txt | bash 2>/dev/null
    else
        echo " [!] fileperms.txt missing!"
    fi
}

main() {
    harden_php
    harden_apache
    nuke_compilers
    nuke_hackertools
    apply_fileperms
    echo "[+] Done."
}

main "$@"
