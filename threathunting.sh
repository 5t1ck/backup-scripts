#!/bin/bash
# threat_hunt_full.sh
# Comprehensive threat hunting script compatible with both Rocky Linux and Ubuntu.
# Must be run as root.
#
# This script performs:
# 1. Lists running services and established TCP connections.
# 1.5 Detects running .service files that aren’t default.
# 2. Displays scheduled tasks (system-wide crontab, /etc/cron.d, user crontabs, systemd timers).
# 3. Searches for suspicious files and script content.
# 4. Checks PAM configuration (displays auth files and searches for abnormal references).
# 5. Performs heuristic reverse shell detection (both established and listening)
#    and offers an option to kill any suspect processes.
# 6. Checks binary integrity using debsums (if available) or rpm (runs in background and logs to /root/binary_integrity.txt).
# 7. Searches for system binaries with suspicious names.
# 8. Backs up all system cron jobs to /root/cron.txt and deletes them.
# 9. Scans /etc/shadow for accounts that either have no password set or appear active.

###############################
# Preliminary: Choose netstat or ss
###############################
if command -v netstat >/dev/null 2>&1; then
    EST_CMD="netstat -atunp"
    LIST_CMD="netstat -tnulp"
else
    EST_CMD="ss -atunp"
    LIST_CMD="ss -tnlp"
fi

###############################
# Part 1: System Services & Network
###############################
echo "=== Running Services ==="
running_services=$(systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print $1}')
echo "$running_services"
echo ""

echo "=== Established TCP Connections ==="
$EST_CMD | grep ESTABLISHED
echo ""

###############################
# Part 1.5: Non-default Running Services
###############################
# Define a default services list (common for Rocky Linux and Ubuntu)
default_services=(
  "systemd-journald.service"
  "systemd-udevd.service"
  "systemd-logind.service"
  "NetworkManager.service"
  "network-manager.service"
  "crond.service"
  "cron.service"
  "sshd.service"
  "ssh.service"
  "rsyslog.service"
  "polkit.service"
  "polkit-1.service"
  "chronyd.service"
  "chrony.service"
  "auditd.service"
  "dbus.service"
  "systemd-timesyncd.service"
  "systemd-resolved.service"
)

echo "=== Non-default Running Services ==="
for service in $running_services; do
  found=0
  for def in "${default_services[@]}"; do
    if [ "$service" == "$def" ]; then
      found=1
      break
    fi
  done
  if [ $found -eq 0 ]; then
    echo -e "$service"
  fi
done
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
echo "=== PAM Configuration (Auth) ==="
if [ -f /etc/pam.d/password-auth ]; then
  cat /etc/pam.d/password-auth
elif [ -f /etc/pam.d/common-auth ]; then
  cat /etc/pam.d/common-auth
else
  echo "No PAM auth config file found."
fi
echo ""

echo "=== PAM Configuration (Password/System Auth) ==="
if [ -f /etc/pam.d/system-auth ]; then
  cat /etc/pam.d/system-auth
elif [ -f /etc/pam.d/common-password ]; then
  cat /etc/pam.d/common-password
else
  echo "No PAM system-auth config file found."
fi
echo ""

echo "=== Abnormal PAM References ==="
echo "[*] Extracting all file paths referenced in /etc/pam.d/..."
paths=$(grep -R -o -E '/[^[:space:]]+' /etc/pam.d/ 2>/dev/null | sort -u)
# Define normal directories as a whitelist.
normal_dirs=(
  "/bin/"
  "/sbin/"
  "/usr/bin/"
  "/usr/sbin/"
  "/lib/"
  "/lib64/"
  "/usr/lib/"
  "/usr/lib64/"
)
echo "[*] Checking for file paths not in normal directories:"
echo "$paths" | while read -r path; do
  abnormal=1
  for norm in "${normal_dirs[@]}"; do
    if [[ "$path" == $norm* ]]; then
      abnormal=0
      break
    fi
  done
  if [ $abnormal -eq 1 ]; then
    echo "$path"
  fi
done
echo ""

###############################
# Part 5: Reverse Shell Detection (Final Section)
###############################
echo "=== Heuristic Reverse Shell Search (Final Section) ==="
candidate_established=()
candidate_listening=()

echo "[*] Checking bash processes for established network connections..."
for pid in $(pgrep -x bash); do
  conns=$($EST_CMD 2>/dev/null | grep "$pid/" | grep ESTABLISHED)
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
  conns=$($EST_CMD 2>/dev/null | grep "$pid/" | grep ESTABLISHED)
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
  listening=$($LIST_CMD 2>/dev/null | grep "$pid/" | grep LISTEN)
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
  listening=$($LIST_CMD 2>/dev/null | grep "$pid/" | grep LISTEN)
  if [ -n "$listening" ]; then
    echo "Possible listening reverse shell candidate (nc):"
    ps -p "$pid" -o pid,cmd
    echo "$listening"
    candidate_listening+=($pid)
    echo "----------------------------------------"
  fi
done

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

###############################
# Part 6: Binary Integrity Check (Background)
###############################
echo ""
echo "=== Binary Integrity Check ==="
if command -v debsums >/dev/null 2>&1; then
    echo "[*] Running debsums -s in background; output to /root/binary_integrity.txt (this may take a while)..."
    debsums -s > /root/binary_integrity.txt 2>&1 &
elif command -v rpm >/dev/null 2>&1; then
    echo "[*] Running rpm -Va in background; output to /root/binary_integrity.txt (this may take a while)..."
    rpm -Va > /root/binary_integrity.txt 2>&1 &
else
    echo "Neither debsums nor rpm command found. Cannot check binary integrity."
fi

###############################
# Part 7: Check System Binaries for Suspicious Names
###############################
echo ""
echo "=== Suspicious Named Files ==="
find / -type f \( -name "*redteam*" -o -name "red_herring" -o -name "dropbear" -o -name "watershell" -o -name "shelly"\) 2>/dev/null
echo ""

###############################
# Part 8: Backup and Delete All System Cron Jobs
###############################
echo ""
echo "=== Backup and Delete System Cron Jobs ==="
# Fixed backup file: /root/cron.txt
BACKUP_FILE="/root/cron.txt"
echo "Backing up all cron jobs to $BACKUP_FILE"
echo "Backup created on $(date)" > "$BACKUP_FILE"
echo "----------------------------------------" >> "$BACKUP_FILE"

# Backup and delete /etc/crontab.
echo "Processing /etc/crontab..."
if [ -f /etc/crontab ]; then
    echo "----- /etc/crontab -----" >> "$BACKUP_FILE"
    cat /etc/crontab >> "$BACKUP_FILE"
    rm -f /etc/crontab && echo "Deleted /etc/crontab"
else
    echo "/etc/crontab not found."
fi
echo "----------------------------------------" >> "$BACKUP_FILE"

# Backup and delete files in /etc/cron.d.
echo "Processing /etc/cron.d..."
if [ -d /etc/cron.d ]; then
    for f in /etc/cron.d/*; do
        if [ -f "$f" ]; then
            echo "----- $f -----" >> "$BACKUP_FILE"
            cat "$f" >> "$BACKUP_FILE"
            rm -f "$f" && echo "Deleted $f"
            echo "----------------------------------------" >> "$BACKUP_FILE"
        fi
    done
else
    echo "/etc/cron.d directory not found."
fi

# Backup and delete files in cron periodic directories.
for dir in /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
    echo "Processing $dir..."
    if [ -d "$dir" ]; then
        for f in "$dir"/*; do
            if [ -f "$f" ]; then
                echo "----- $f -----" >> "$BACKUP_FILE"
                cat "$f" >> "$BACKUP_FILE"
                rm -f "$f" && echo "Deleted $f"
                echo "----------------------------------------" >> "$BACKUP_FILE"
            fi
        done
    else
        echo "$dir not found."
    fi
done

echo "Backup complete. All system cron jobs have been deleted."
echo ""

###############################
# Part 9: Check /etc/shadow for Suspicious User Accounts
###############################
echo "=== Suspicious /etc/shadow Entries ==="
echo "[*] Listing accounts with no password set or with active password hashes (i.e. not locked):"
awk -F: '{ if($2 == "" || $2 !~ /^(\*|!)/) print $0 }' /etc/shadow

echo ""
echo "Threat hunting completed."
