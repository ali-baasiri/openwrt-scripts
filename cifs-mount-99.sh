#!/bin/sh

echo "======================================"
echo "  CIFS + MiniDLNA Auto Installer"
echo "======================================"
echo

# Ask for information
read -p "SMB Server IP (example: 192.168.90.1): " SMB_IP
read -p "SMB Share name (example: usbshare/usb1_2): " SMB_SHARE
read -p "Username: " SMB_USER
read -p "Password: " SMB_PASS
read -p "Local mount point (default: /mnt/fibermodem): " MOUNT_POINT

# Default mount point
[ -z "$MOUNT_POINT" ] && MOUNT_POINT="/mnt/fibermodem"

echo
echo "Creating the script..."

cat > /etc/hotplug.d/iface/99-cifs-mount << EOF
#!/bin/sh

[ "\$ACTION" = "ifup" ] || exit 0
[ "\$INTERFACE" = "lan" ] || exit 0

(
  logger -t cifs-mount "Script started"
  sleep 60

  mkdir -p $MOUNT_POINT

  SUCCESS=0

  for i in 1 2 3 4 5 6 7 8 9 10; do
    if grep -q " $MOUNT_POINT " /proc/mounts; then
      umount $MOUNT_POINT 2>/dev/null
      sleep 2
    fi

    mount -t cifs //$SMB_IP/$SMB_SHARE $MOUNT_POINT \\
      -o username=$SMB_USER,password=$SMB_PASS,vers=2.0,_netdev 2>&1 | logger -t cifs-mount

    sleep 6

    if grep -q " $MOUNT_POINT " /proc/mounts; then
      CONTENT=\$(ls $MOUNT_POINT 2>/dev/null | wc -l)
      logger -t cifs-mount "Try \$i: mounted OK, files=\$CONTENT"

      if [ "\$CONTENT" -gt 0 ]; then
        SUCCESS=1
        break
      fi
    else
      logger -t cifs-mount "Try \$i: not mounted yet"
    fi

    sleep 12
  done

  if [ "\$SUCCESS" = "1" ]; then
    logger -t cifs-mount "CIFS fully ready"
    sleep 15

    /etc/init.d/minidlna stop
    rm -f /var/run/minidlna/files.db*
    sleep 3
    /etc/init.d/minidlna start

    logger -t cifs-mount "MiniDLNA rescanned"
  else
    logger -t cifs-mount "FAILED after all retries"
  fi
) &
EOF

chmod +x /etc/hotplug.d/iface/99-cifs-mount

echo
echo "Installation completed successfully!"
echo "Script created at: /etc/hotplug.d/iface/99-cifs-mount"
echo "Please reboot the router to apply."
