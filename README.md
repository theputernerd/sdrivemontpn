# **sdrivemontpn**
SMART Drive monitor by the puter nerd
`sdrivemontpn` is a Python-based SMART drive monitoring utility designed to track critical drive health metrics and provide insights into potential hardware issues. It supports logging, data analysis, and optional integration with Apache for easy web-based visualization.

---

## **Features**

- **SMART Attribute Monitoring**: Tracks key drive attributes like temperature, reallocated sectors, and power-on hours.
- **Automated Logging**: Periodically collects and logs data in CSV format.
- **Data Visualization**: Generates plots for individual and combined attributes with rolling statistics.
- **Systemd Integration**: Runs as a scheduled service using timers.
- **Backup and Restore**: Facilitates easy backup and restoration of data and configurations.
- **Apache Integration**: Optionally creates a symlink for Apache to enable web-based visualization.

---

## **Installation**

1. Clone the repository:
   ```bash
   git clone <repository_url>
   cd sdrivemontpn
   ```

2. Run the installation script:
   ```bash
   sudo ./install.sh
   ```

   ### **Installation Options**
   - **Clean Install**: Add `--clean-install` to remove existing data and logs.
     ```bash
     sudo ./install.sh --clean-install
     ```
   - The installation script will:
     - Stop and disable existing services.
     - Backup existing data and logs to `~/sdrivemontpn_backup_<timestamp>`.
     - Install the Python script and configuration file.
     - Create required directories for data and logs.
     - Set up and enable the systemd timer.

3. Confirm installation success by checking the logs:
   ```bash
   tail -f /var/log/sdrivemontpn/sdrivemontpn_install_test.log
   ```

---

## **Configuration**

Configuration is stored in `/etc/sdrivemontpn/config.yaml`:

```yaml
data_directory: "/var/log/sdrivemontpn/data"
log_file: "/var/log/sdrivemontpn/sdrivemontpn.log"
attributes_to_monitor:
  - 1   # Raw_Read_Error_Rate
  - 197 # Current Pending Sector Count
  - 5   # Reallocated Sectors Count
  - 187 # Reported Uncorrectable Errors
  - 10  # Spin_Retry_Count
  - 196 # Reallocated_Event_Count
  - 198 # Offline_Uncorrectable
  - 9   # Power_On_Hours
  - 193 # Load_Cycle_Count
  - 194 # Temperature
  - 3   # Spin_Up_Time
  - 4   # Start_Stop_Count
  - 12  # Power_Cycle_Count
  - 199 # UDMA_CRC_Error_Count
```

---

## **Usage**

- **View Logs**:
  ```bash
  tail -f /var/log/sdrivemontpn/sdrivemontpn.log
  ```

- **Run Script Manually** (for testing):
  ```bash
  sudo /usr/local/bin/sdrivemontpn --verbose
  ```

---

## **Backup and Restore**

- **Backup**:
  Automatically performed during a clean install. Files are saved to:
  ```
  ~/sdrivemontpn_backup_<timestamp>
  ```

- **Restore**:
  Use the provided script to restore from a specific backup:
  ```bash
  sudo ./restore_backup.sh /path/to/backup
  ```

---

## **Apache Integration**

- By default, the installation script sets up a symlink for Apache:
  ```
  /var/www/html/sdrivemontpn -> /var/log/sdrivemontpn/data
  ```

- You can access the data and plots via:
  ```
  http://<server_ip>/sdrivemontpn
  ```

---

## **Uninstallation**

To remove `sdrivemontpn` completely:
1. Stop and disable the service and timer:
   ```bash
   sudo systemctl stop sdrivemontpn.timer sdrivemontpn.service
   sudo systemctl disable sdrivemontpn.timer sdrivemontpn.service
   ```

2. Remove installed files:
   ```bash
   sudo rm -rf /usr/local/bin/sdrivemontpn /etc/sdrivemontpn /etc/systemd/system/sdrivemontpn.* /var/log/sdrivemontpn
   ```

---

## **Requirements**

- Python 3.x
- `smartmontools`
- `matplotlib`
- `pandas`
- Apache (optional for web-based visualization)

---

## **Contributions**

Contributions are welcome! Open issues or submit pull requests to suggest improvements or report bugs.

---

## **License**

`sdrivemontpn` is open-source software licensed under the MIT License.
