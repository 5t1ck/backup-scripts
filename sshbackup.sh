#!/bin/bash

BACKUP_DIR="/var/lib/.sysbackup/"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# Ensure rsync is installed
if ! command -v rsync &> /dev/null; then
    echo "ERROR: rsync is not installed. Install it and try again." >&2
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR/systemd"
mkdir -p "$BACKUP_DIR/configs"

# Define exact files to back up
declare -A FILES_TO_BACKUP=(
    ["/etc/systemd/system/vsftpd.service"]="$BACKUP_DIR/systemd/vsftpd.service"
    ["/usr/lib/systemd/system/vsftpd.service"]="$BACKUP_DIR/systemd/vsftpd-lib.service"
    ["/etc/systemd/system/sshd.service"]="$BACKUP_DIR/systemd/sshd.service"
    ["/lib/systemd/system/sshd.service"]="$BACKUP_DIR/systemd/sshd-lib.service"
    ["/etc/vsftpd.conf"]="$BACKUP_DIR/configs/vsftpd.conf"
    ["/etc/ssh/sshd_config"]="$BACKUP_DIR/configs/sshd_config"
    ["/etc/passwd"]="$BACKUP_DIR/passwd"
    ["/etc/shadow"]="$BACKUP_DIR/shadow"
)

backup() {
    echo "[*] Starting backup..."
    
    for SRC in "${!FILES_TO_BACKUP[@]}"; do
        DEST="${FILES_TO_BACKUP[$SRC]}"
        if [ -e "$SRC" ]; then
            rsync -av "$SRC" "$DEST"
        else
            echo "WARNING: $SRC not found, skipping..." >&2
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
    for SRC in "${!FILES_TO_BACKUP[@]}"; do
        DEST="${FILES_TO_BACKUP[$SRC]}"
        if [ -e "$DEST" ]; then
            sudo rsync -av "$DEST" "$SRC"
        else
            echo "WARNING: Backup of $SRC not found, skipping..." >&2
        fi
    done

    echo "[+] Restore completed. Services may need a restart or system reboot."
}

# Handle script arguments
if [[ "$1" == "restore" ]]; then
    restore
else
    backup
fi
