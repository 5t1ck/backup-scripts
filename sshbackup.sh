#!/bin/bash

BACKUP_DIR="/var/lib/.sysbackup/"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# Ensure rsync is installed
if ! command -v rsync &> /dev/null; then
    echo "ERROR: rsync is not installed. Install it and try again." >&2
    exit 1
fi

# Exact files to back up
FILES_TO_BACKUP=(
    "/etc/systemd/system/vsftpd.service"
    "/usr/lib/systemd/system/vsftpd.service"
    "/etc/systemd/system/sshd.service"
    "/usr/lib/systemd/system/sshd.service"
    
    "/etc/vsftpd/vsftpd.conf"
    "/etc/ssh/sshd_config"

    "/etc/passwd"
    "/etc/shadow"
)

backup() {
    echo "[*] Starting backup on Rocky Linux..."
    mkdir -p "$BACKUP_DIR"

    for FILE in "${FILES_TO_BACKUP[@]}"; do
        if [ -e "$FILE" ]; then
            rsync -av --relative "$FILE" "$BACKUP_DIR"
        else
            echo "WARNING: $FILE not found, skipping..." >&2
        fi
    done

    chmod -R 600 "$BACKUP_DIR"
    echo "[+] Backup completed at: $BACKUP_DIR"
}

restore() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "ERROR: No backup found in $BACKUP_DIR" >&2
        exit 1
    fi

    echo "[*] Restoring files from: $BACKUP_DIR"
    for FILE in "${FILES_TO_BACKUP[@]}"; do
        REL_PATH=$(echo "$FILE" | sed 's|^/||')
        if [ -e "$BACKUP_DIR/$REL_PATH" ]; then
            sudo rsync -av --relative "$BACKUP_DIR/$REL_PATH" /
        else
            echo "WARNING: Backup of $FILE not found, skipping..." >&2
        fi
    done

    echo "[+] Restore completed. Services may need a restart or system reboot."
}

if [[ "$1" == "restore" ]]; then
    restore
else
    backup
fi
