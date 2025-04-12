#!/bin/bash

# Ensure the script is run as root
if [ $(id -u) -ne 0 ]; then
  echo "ERROR: Script is not running as sudo or root. Exiting..."
  exit
fi

read -p 'Would you like to skip looking at currently listening connections? (y/n) ' answer

# Collect listening connections
mapfile -t listening < <(ss -tulnap | grep LISTEN | awk '{ print $2, $5, $6, $7 }')

if [[ "$answer" != "y" ]]; then
  echo "Printing listening ports"
  for line in "${listening[@]}"; do
    echo "$line"
  done
fi

# Collect established connections
mapfile -t established < <(ss -tulnap | grep ESTAB | awk '{ print $2, $5, $6, $7 }')
echo ""
echo "Printing established connections"
for line in "${established[@]}"; do
  echo "$line"
done

# Function to inspect and optionally kill processes
function kill_process {
  processes=("$@")
  for process in "${processes[@]}"; do
    echo ""
    echo "Getting info for: $process"

    pids=$(echo "$process" | grep -oP 'pid=\K\d+')
    pid_csv=$(echo "$pids" | tr '\n' ',' | sed 's/,$//')
    echo "PIDs: $pid_csv"

    ps -p "$pid_csv" -o pid,ppid,user,comm,args,etime
    pids=$(ps -p "$pid_csv" -o pid,ppid,user,comm,args,etime | awk 'NR>1 {print $1}')

    read -p "Would you like to kill $pid_csv? Be sure this is a malicious process!! (y/n) " answer2
    if [[ "$answer2" = "y" ]]; then
      echo "$pids" | while read -r pid; do
        if [ -d "/proc/$pid" ]; then
          echo "PID $pid still exists. Killing..."
          readlink -f /proc/$pid/exe >> potentially_malicious_binaries.txt
          path=$(readlink -f /proc/$pid/exe)
          kill -9 "$pid"

          if [ $? -ne 0 ]; then
            echo "Failed to kill process $pid" >> pkill.log
          else
            echo "Killed PID $pid at $path" >> pkill.log
          fi
        else
          echo "PID $pid no longer exists. Skipping."
        fi
      done
    fi
  done
}

read -p "Would you like to run through established connections to kill potentially malicious processes? (y/n) " answer1
if [[ "$answer1" = "y" ]]; then
  mapfile -t established < <(ss -tulnap | grep ESTAB | awk '{ print $2, $5, $6, $7 }')
  kill_process "${established[@]}"
fi

read -p "Would you like to run through listening connections to kill potentially malicious processes? (y/n) " answer1
if [[ "$answer1" = "y" ]]; then
  mapfile -t listening < <(ss -tulnap | grep LISTEN | awk '{ print $2, $5, $6, $7 }')
  kill_process "${listening[@]}"
fi

echo "done"
