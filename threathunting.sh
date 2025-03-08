#!/bin/bash
# threat_hunt_full.sh
# Comprehensive threat hunting script.
# Must be run as root.
#
# This script:
# 1. Lists running services and established TCP connections.
# 2. Performs heuristic reverse shell detection with an option to kill candidate processes.
# 3. Gathers scheduled tasks (crontabs and systemd timers).
# 4. Searches for suspicious files and script content.
# 5. Checks PAM configuration for potential abuse (prints password-auth and system-auth and searches for bash script references).

###############################
# Part 1: System Services & Network
###############################
echo "=== Running Services ==="
systemctl list-units --type=service --state=running --no-pager
echo ""

echo "=== Established TCP Connections ==="
ss -tnp | grep ESTAB
echo ""

echo "=== Heuristic Reverse Shell Search ==="
candidate_pids=()

echo "[*] Checking bash processes for network connections..."
for pid in $(pgrep -x bash); do
    conns=$(ss -tnp 2>/dev/null | grep "pid $pid," | grep ESTAB)
    if [ -n "$conns" ]; then
        echo "Possible reverse shell candidate (bash):"
        ps -p "$pid" -o pid,cmd
        echo "$conns"
        candidate_pids+=($pid)
        echo "----------------------------------------"
    fi
done

echo "[*] Checking nc processes for network connections..."
for pid in $(pgrep -x nc); do
    conns=$(ss -tnp 2>/dev/null | grep "pid $pid," | grep ESTAB)
    if [ -n "$conns" ]; then
        echo "Possible reverse shell candidate (nc):"
        ps -p "$pid" -o pid,cmd
        echo "$conns"
        candidate_pids+=($pid)
        echo "----------------------------------------"
    fi
done

if [ ${#candidate_pids[@]} -gt 0 ]; then
    echo "Potential reverse shell candidate process IDs: ${candidate_pids[@]}"
    read -p "Would you like to kill these processes? (y/N): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        for pid in "${candidate_pids[@]}"; do
            kill "$pid" && echo "Killed process $pid" || echo "Failed to kill process $pid"
        done
    else
        echo "Processes not killed."
    fi
else
    echo "No reverse shell candidates found."
fi

###############################
# Part 2: Scheduled Tasks (Crontabs & Timers)
###############################
echo ""
echo "=== System-Wide Crontab (/etc/crontab) ==="
if [ -f /etc/crontab ]; then
  cat /etc/crontab
else
  echo "/etc/crontab not found."
fi
echo ""

echo "=== Cron.d Files (/etc/cron.d) ==="
if [ -d /etc/cron.d ]; then
    for file in /etc/cron.d/*; do
        [ -e "$file" ] || continue
        echo "---- $file ----"
        cat "$file"
        echo "----------------------------------------"
    done
else
    echo "/etc/cron.d directory not found."
fi
echo ""

echo "=== Cron Periodic Jobs (daily, hourly, weekly, monthly) ==="
for dir in /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
    if [ -d "$dir" ]; then
        echo "---- Directory: $dir ----"
        ls -la "$dir"
        echo "----------------------------------------"
    else
        echo "$dir not found."
    fi
done
echo ""

echo "=== User Crontabs ==="
for user in $(cut -d: -f1 /etc/passwd); do
    echo "---- Crontab for user: $user ----"
    crontab -l -u "$user" 2>/dev/null || echo "No crontab for $user."
    echo "----------------------------------------"
done
echo ""

echo "=== Systemd Timers ==="
systemctl list-timers --all --no-pager
echo ""

###############################
# Part 3: Suspicious Files & Script Content
###############################
echo "=== Suspicious Files in /tmp & /var/tmp ==="
find /tmp /var/tmp -type f \( -perm -o+w -o -perm -4000 -o -perm -2000 \) -exec ls -la {} \; 2>/dev/null
echo ""

echo "=== Suspicious Script Content ('eval(') in /home & /etc ==="
grep -R "eval(" /home /etc 2>/dev/null
echo ""

###############################
# Part 4: PAM Configuration Checks
###############################
echo "=== /etc/pam.d/password-auth ==="
if [ -f /etc/pam.d/password-auth ]; then
  cat /etc/pam.d/password-auth
else
  echo "File /etc/pam.d/password-auth not found."
fi
echo ""

echo "=== /etc/pam.d/system-auth ==="
if [ -f /etc/pam.d/system-auth ]; then
  cat /etc/pam.d/system-auth
else
  echo "File /etc/pam.d/system-auth not found."
fi
echo ""

echo "=== Searching /etc/pam.d for bash script references ==="
grep -R -E '(/bin/bash|\.sh)' /etc/pam.d/ 2>/dev/null
echo ""

echo "Threat hunting completed."
