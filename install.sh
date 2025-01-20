#!/bin/bash
set -e

echo "Installing sdrivemontpn..."

# Variables
CONFIG_PATH="etc/sdrivemontpn/config.yaml"  # Path to default config in source
SERVICE_SCRIPT="usr/local/bin/sdrivemontpn"  # Path to Python script in source
SYSTEM_CONFIG="/etc/sdrivemontpn/config.yaml"  # Target location for config
TARGET_SCRIPT="/usr/local/bin/sdrivemontpn"  # Target location for Python script
TIMER_PATH="/etc/systemd/system"  # Path for systemd service/timer
OWNER="www-data"
GROUP="www-data"
APACHE_SETUP=true
TIMER_INTERVAL="1h"  # Timer interval for systemd
CLEAN_INSTALL=false  # Flag for removing logs and data on reinstall

# Determine the correct home directory for the invoking user
if [ "$SUDO_USER" ]; then
    USER_HOME=$(eval echo ~"$SUDO_USER")
else
    USER_HOME="$HOME"
fi

# Extract paths from config.yaml
if [ -f "$CONFIG_PATH" ]; then
    DATA_PATH=$(grep "data_directory:" "$CONFIG_PATH" | awk -F': ' '{print $2}' | tr -d '",')
    LOG_PATH=$(grep "log_path:" "$CONFIG_PATH" | awk -F': ' '{print $2}' | tr -d '",')
else
    echo "Error: Config file not found at $CONFIG_PATH. Ensure it exists before running the installer."
    exit 1
fi

# Set backup directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$USER_HOME/sdrivemontpn_backup_$TIMESTAMP"

# Parse flags
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --clean-install)
            CLEAN_INSTALL=true
            # Confirm clean install with the user
            echo "WARNING: Clean install will remove all existing data and logs."
            read -p "Are you sure you want to continue? (yes/no): " CONFIRM
            if [[ "$CONFIRM" != "yes" ]]; then
                echo "Clean install aborted."
                exit 1
            fi
            ;;
        *) 
            echo "Unknown option: $1"; 
            exit 1 ;;
    esac
    shift
done

# Step 1: Stop and disable any prior services
echo "Stopping existing services..."
SERVICE_NAME="sdrivemontpn.service"
TIMER_NAME="sdrivemontpn.timer"
if systemctl is-active --quiet $TIMER_NAME; then
    systemctl stop $TIMER_NAME
    systemctl disable $TIMER_NAME
    echo "Stopped and disabled timer: $TIMER_NAME"
else
    echo "Timer $TIMER_NAME is not active."
fi

if systemctl is-active --quiet $SERVICE_NAME; then
    systemctl stop $SERVICE_NAME
    systemctl disable $SERVICE_NAME
    echo "Stopped and disabled service: $SERVICE_NAME"
else
    echo "Service $SERVICE_NAME is not active."
fi

# Step 2: Remove old files (except data and logs)
echo "Removing old files..."
if [ -f "$TARGET_SCRIPT" ]; then
    rm -f "$TARGET_SCRIPT"
    echo "Removed: $TARGET_SCRIPT"
fi

if [ -f "$TIMER_PATH/$SERVICE_NAME" ]; then
    rm -f "$TIMER_PATH/$SERVICE_NAME"
    echo "Removed: $TIMER_PATH/$SERVICE_NAME"
fi

if [ -f "$TIMER_PATH/$TIMER_NAME" ]; then
    rm -f "$TIMER_PATH/$TIMER_NAME"
    echo "Removed: $TIMER_PATH/$TIMER_NAME"
fi

if [ -f "$SYSTEM_CONFIG" ]; then
    rm -f "$SYSTEM_CONFIG"
    echo "Removed: $SYSTEM_CONFIG"
fi

# Step 3: Handle clean install (backup and removal)
if [ "$CLEAN_INSTALL" = true ]; then
    echo "Performing clean install..."
    echo "Backing up data and logs to $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    if [ -d "$DATA_PATH" ]; then
        cp -r "$DATA_PATH" "$BACKUP_DIR/data"
        echo "Backed up data to $BACKUP_DIR/data"
    fi
    if [ -d "$LOG_PATH" ]; then
        cp -r "$LOG_PATH" "$BACKUP_DIR/logs"
        echo "Backed up logs to $BACKUP_DIR/logs"
    fi
    echo "Removing data and logs..."
    if [ -d "$DATA_PATH" ]; then
        rm -rf "$DATA_PATH"
        echo "Removed: $DATA_PATH"
    fi
    if [ -d "$LOG_PATH" ]; then
        rm -rf "$LOG_PATH"
        echo "Removed: $LOG_PATH"
    fi
else
    echo "Retaining existing data and logs..."
fi

# Step 4: Create directories
echo "Creating directories..."
mkdir -p /usr/local/bin
mkdir -p /etc/sdrivemontpn
mkdir -p "$DATA_PATH"
mkdir -p "$LOG_PATH"

# Step 5: Copy files
echo "Copying files..."
cp "$SERVICE_SCRIPT" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"
cp "$CONFIG_PATH" "$SYSTEM_CONFIG"

# Step 6: Set permissions
echo "Setting permissions..."
chown -R $OWNER:$GROUP "$DATA_PATH"
chown -R root:root "$TARGET_SCRIPT"
chown -R root:root "$SYSTEM_CONFIG"
chown -R $OWNER:$GROUP "$LOG_PATH"
chmod -R 755 "$LOG_PATH"
chmod -R 755 "$DATA_PATH"

# Step 7: Apache setup (optional)
if [ "$APACHE_SETUP" = true ]; then
    echo "Setting up Apache..."
    if [ ! -L "/var/www/html/sdrivemontpn" ]; then
        ln -sf "$DATA_PATH" "/var/www/html/sdrivemontpn"
    fi
    chown -R $OWNER:$GROUP "$DATA_PATH"
fi

# Step 8: Create and enable the systemd timer
echo "Configuring systemd timer..."
cat <<EOF > "$TIMER_PATH/$SERVICE_NAME"
[Unit]
Description=Run sdrivemontpn

[Service]
ExecStart=$TARGET_SCRIPT
StandardOutput=append:$LOG_PATH/sdrivemontpn.log
StandardError=append:$LOG_PATH/sdrivemontpn_error.log
EOF

cat <<EOF > "$TIMER_PATH/$TIMER_NAME"
[Unit]
Description=Timer for sdrivemontpn

[Timer]
OnUnitActiveSec=$TIMER_INTERVAL
Unit=$SERVICE_NAME

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now $TIMER_NAME



# Step 9: Run a test and log the outcome
echo "Testing installation..."

# Capture and display verbose output
TEST_LOG="$LOG_PATH/sdrivemontpn_install_test.log"
echo "Running sdrivemontpn with verbose output. Log file: $TEST_LOG"
echo "---------- INSTALLATION TEST BEGIN ----------" | tee -a "$TEST_LOG"

# Run the script with verbose output
$TARGET_SCRIPT --verbose 2>&1 | tee -a "$TEST_LOG"
if [ $? -eq 0 ]; then
    echo "Script executed successfully." | tee -a "$TEST_LOG"
else
    echo "Script execution failed. Check logs for details." | tee -a "$TEST_LOG"
fi

# Inspect systemd service
echo "Inspecting systemd service..." | tee -a "$TEST_LOG"
systemctl status sdrivemontpn.service 2>&1 | tee -a "$TEST_LOG"

# Inspect systemd timer
echo "Inspecting systemd timer..." | tee -a "$TEST_LOG"
systemctl status sdrivemontpn.timer 2>&1 | tee -a "$TEST_LOG"

echo "---------- INSTALLATION TEST END ------------" | tee -a "$TEST_LOG"

# Provide final result message
if grep -q "failed" "$TEST_LOG"; then
    echo "Installation test completed with errors. Check logs in $TEST_LOG."
else
    echo "Installation test completed successfully."
fi
