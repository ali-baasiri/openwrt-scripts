#!/bin/sh

echo "======================================"
echo "  CIFS + MiniDLNA Auto Installer"
echo "======================================"
echo

read -p "SMB Server IP (example: 192.168.90.1): " SMB_IP
read -p "SMB Share name (example: usbshare/usb1_2): " SMB_SHARE
read -p "Username: " SMB_USER
read -p "Password: " SMB_PASS
read -p "Local mount point (default: /mnt/fibermodem): " MOUNT_POINT

[ -z "$MOUNT_POINT" ] && MOUNT_POINT="/mnt/fibermodem"

echo
echo "Creating the script..."

# پاک کردن فایل قبلی
rm -f /etc/hotplug.d/iface/99-cifs-mount

# نوشتن فایل خط به خط (روش مقاوم)
cat << 'EOF' > /etc/hotplug.d/iface/99-cifs-mount
#!/bin/sh

[ "$ACTION" = "ifup" ] || exit 0
[ "$INTERFACE" = "lan" ] || exit 0

(
  logger -t cifs-mount "Script started"
  sleep 60

  mkdir -p MOUNT_POINT

  SUCCESS=0

  for i in 1 2 3 4 5 6 7 8 9 10; do
    if grep -q " MOUNT_POINT " /proc/mounts; then
      umount MOUNT_POINT 2>/dev/null
      sleep 2
    fi

    mount -t cifs //__SMB_IP__/__SMB_SHARE__ MOUNT_POINT -o username=__SMB_USER__,password=__SMB_PASS__,vers=2.0,_netdev 2>&1 | logger -t cifs-mount

    sleep 6

    if grep -q " MOUNT_POINT " /proc/mounts; then
      CONTENT=$(ls MOUNT_POINT 2>/dev/null | wc -l)
      logger -t cifs-mount "Try $i: mounted OK, files=$CONTENT"

      if [ "$CONTENT" -gt 0 ]; then
        SUCCESS=1
        break
      fi
    else
      logger -t cifs-mount "Try $i: not mounted yet"
    fi

    sleep 12
  done

  if [ "$SUCCESS" = "1" ]; then
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

# جایگزینی مقادیر با sed
sed -i "s|__MOUNT_POINT__|$MOUNT_POINT|g" /etc/hotplug.d/iface/99-cifs-mount
sed -i "s|__SMB_IP__|$SMB_IP|g" /etc/hotplug.d/iface/99-cifs-mount
sed -i "s|__SMB_SHARE__|$SMB_SHARE|g" /etc/hotplug.d/iface/99-cifs-mount
sed -i "s|__SMB_USER__|$SMB_USER|g" /etc/hotplug.d/iface/99-cifs-mount
sed -i "s|__SMB_PASS__|$SMB_PASS|g" /etc/hotplug.d/iface/99-cifs-mount

chmod +x /etc/hotplug.d/iface/99-cifs-mount

echo
echo "Installation completed successfully!"
echo "File created: /etc/hotplug.d/iface/99-cifs-mount"
echo "Please reboot the router."
