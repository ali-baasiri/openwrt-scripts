#!/bin/sh

echo "======================================"
echo "  CIFS + MiniDLNA Auto Installer"
echo "======================================"
echo

# گرفتن اطلاعات از کاربر
read -p "آدرس سرور SMB (مثال: 192.168.90.1): " SMB_IP
read -p "نام اشتراک (مثال: usbshare/usb1_2): " SMB_SHARE
read -p "نام کاربری: " SMB_USER
read -p "رمز عبور: " SMB_PASS
read -p "مسیر مونت محلی (پیش‌فرض /mnt/fibermodem): " MOUNT_POINT

# مقدار پیش‌فرض برای مسیر مونت
[ -z "$MOUNT_POINT" ] && MOUNT_POINT="/mnt/fibermodem"

echo
echo "در حال ساخت اسکریپت..."

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
echo "نصب با موفقیت انجام شد!"
echo "فایل ساخته شد در: /etc/hotplug.d/iface/99-cifs-mount"
echo "برای اعمال، روتر را ریستارت کنید."
