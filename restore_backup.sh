#!/bin/bash
set -e

# Variables
BACKUP_DIR="$1"  # Backup directory to restore from (passed as argument)
DATA_PATH="/var/log/sdrivemontpn/data"
LOG_PATH="/var/log/sdrivemontpn"
CONFIG_PATH="/etc/sdrivemontpn/config.yaml"
SERVICE_SCRIPT="/usr/local/bin/sdrivemontpn"
TIMER_PATH="/etc/systemd/system"
SERVICE_NAME="sdrivemontpn.service"
TIMER_NAME="sdrivemontpn.timer"

# Ensure the backup directory is provided
if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 <backup_directory>"
    exit 1
fi

# Confirm restore
read -p "Are you sure you want to restore the backup from $BACKUP_DIR? This will overwrite existing files. (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Step 1: Stop the service and timer
echo "Stopping existing services..."
if systemctl is-active --quiet $TIMER_NAME; then
    systemctl stop $TIMER_NAME
    systemctl disable $TIMER_NAME
fi
if systemctl is-active --quiet $SERVICE_NAME; then
    systemctl stop $SERVICE_NAME
    systemctl disable $SERVICE_NAME
fi

# Step 2: Restore files
echo "Restoring backup from $BACKUP_DIR..."

# Restore data
if [ -d "$BACKUP_DIR/data" ]; then
    echo "Restoring data files..."
    rm -rf "$DATA_PATH"
    cp -r "$BACKUP_DIR/data" "$DATA_PATH"
    chown -R www-data:www-data "$DATA_PATH"
    chmod -R 755 "$DATA_PATH"
fi

# Restore logs
if [ -d "$BACKUP_DIR/logs" ]; then
    echo "Restoring log files..."
    rm -rf "$LOG_PATH"
    cp -r "$BACKUP_DIR/logs" "$LOG_PATH"
    chown -R www-data:www-data "$LOG_PATH"
    chmod -R 750 "$LOG_PATH"
fi

# Restore config
if [ -f "$BACKUP_DIR/config.yaml" ]; then
    echo "Restoring configuration..."
    cp "$BACKUP_DIR/config.yaml" "$CONFIG_PATH"
    chown root:root "$CONFIG_PATH"
    chmod 644 "$CONFIG_PATH"
fi

# Restore script
if [ -f "$BACKUP_DIR/sdrivemontpn" ]; then
    echo "Restoring service script..."
    cp "$BACKUP_DIR/sdrivemontpn" "$SERVICE_SCRIPT"
    chown root:root "$SERVICE_SCRIPT"
    chmod 755 "$SERVICE_SCRIPT"
fi

# Step 3: Restart the service and timer
echo "Re-enabling services..."
systemctl daemon-reload
systemctl enable --now $TIMER_NAME

echo "Restore completed successfully!"
