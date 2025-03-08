#!/bin/bash
# threat_hunt_full.sh
# Comprehensive threat hunting script.
# Must be run as root.
#
# This script performs:
# 1. Lists running services and established TCP connections.
# 2. Displays scheduled tasks (system-wide crontab, cron.d, user crontabs, systemd timers).
# 3. Searches for suspicious files and script content.
# 4. Checks PAM configuration (prints password-auth and system-auth, and searches for bash script references).
# 5. Finally, performs heuristic reverse shell detection (both established and listening)
#    and offers an option to kill any suspect processes.

###############################
# Part 1: System Services & Network
###############################
echo "=== Running Services ==="
systemctl list-units --type=service --state=running --no-pager
echo ""

echo "=== Established TCP Connections (netstat) ==="
netstat -tnp | grep ESTABLISHED
echo ""

###############################
# Part 2: Scheduled Tasks (Crontabs & Timers)
###############################
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

###############################
# Part 5: Reverse Shell Detection (Final Section)
###############################
echo "=== Heuristic Reverse Shell Search (Final Section) ==="
# Initialize arrays for established and listening candidates.
candidate_established=()
candidate_listening=()

echo "[*] Checking bash processes for established network connections..."
for pid in $(pgrep -x bash); do
  conns=$(netstat -tnp 2>/dev/null | grep "$pid/" | grep ESTABLISHED)
  if [ -n "$conns" ]; then
    echo "Possible reverse shell candidate (bash, established):"
    ps -p "$pid" -o pid,cmd
    echo "$conns"
    candidate_established+=($pid)
    echo "----------------------------------------"
  fi
done

echo "[*] Checking nc processes for established network connections..."
for pid in $(pgrep -x nc); do
  conns=$(netstat -tnp 2>/dev/null | grep "$pid/" | grep ESTABLISHED)
  if [ -n "$conns" ]; then
    echo "Possible reverse shell candidate (nc, established):"
    ps -p "$pid" -o pid,cmd
    echo "$conns"
    candidate_established+=($pid)
    echo "----------------------------------------"
  fi
done

echo "[*] Checking bash processes for listening connections..."
for pid in $(pgrep -x bash); do
  listening=$(netstat -tnlp 2>/dev/null | grep "$pid/" | grep LISTEN)
  if [ -n "$listening" ]; then
    echo "Possible listening reverse shell candidate (bash):"
    ps -p "$pid" -o pid,cmd
    echo "$listening"
    candidate_listening+=($pid)
    echo "----------------------------------------"
  fi
done

echo "[*] Checking nc processes for listening connections..."
for pid in $(pgrep -x nc); do
  listening=$(netstat -tnlp 2>/dev/null | grep "$pid/" | grep LISTEN)
  if [ -n "$listening" ]; then
    echo "Possible listening reverse shell candidate (nc):"
    ps -p "$pid" -o pid,cmd
    echo "$listening"
    candidate_listening+=($pid)
    echo "----------------------------------------"
  fi
done

# Summary and prompt for action.
if [ ${#candidate_established[@]} -gt 0 ] || [ ${#candidate_listening[@]} -gt 0 ]; then
  echo "Potential reverse shell candidate process IDs:"
  echo "Established: ${candidate_established[@]}"
  echo "Listening: ${candidate_listening[@]}"
  read -p "Would you like to kill these processes? (y/N): " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    for pid in "${candidate_established[@]}"; do
      kill "$pid" && echo "Killed process $pid" || echo "Failed to kill process $pid"
    done
    for pid in "${candidate_listening[@]}"; do
      kill "$pid" && echo "Killed process $pid" || echo "Failed to kill process $pid"
    done
  else
    echo "Processes not killed."
  fi
else
  echo "No reverse shell candidates found."
fi

echo "Threat hunting completed."
