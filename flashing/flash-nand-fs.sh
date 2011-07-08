#!/bin/bash

# This script is to be run from an init script once the board has booted
TAR_GZ_IMG=/boot/validation-c5-jun24-image-beagleboard.tar.gz

# Determine user-button value
echo 7 > /sys/class/gpio/unexport
echo 7 > /sys/class/gpio/export

if [ $? != "0" ]; then
  echo "Error exporting GPIO value"
  exit
fi

if [ ! -e /sys/class/gpio/gpio7/value ]; then
  echo "Couldn't determine user-button value, value file doesn't exit"
  exit
fi

USER_BUTTON_PRESSED=`cat /sys/class/gpio/gpio7/value`

if [ "x$USER_BUTTON_PRESSED" = "x0" ]; then
  exit
fi

if [ ! -e /dev/mtd4 ]; then
  echo "ERROR: No NAND Filesystem partition found. Aborting flashing."
  exit 1
fi

if [ ! -e $TAR_GZ_IMG ]; then
  echo "ERROR: No fs tar.gz file found. Please download one from Narcissus. exiting."
  exit 1
fi

echo "writing to flash"
mkdir -p /mnt/flash

echo "Erasing nand"
flash_eraseall /dev/mtd4

echo "attaching"
ubiattach /dev/ubi_ctrl -m 4

echo "ubimkvol /dev/ubi0 -N beagleboard-rootfs -s 500MiB"
ubimkvol /dev/ubi0 -N beagleboard-rootfs -s 490MiB

echo "mount -t ubifs ubi0:beagleboard-rootfs /mnt/flash"
mount -t ubifs ubi0:beagleboard-rootfs /mnt/flash

cd /mnt/flash
echo "untar"
tar -zxvf $TAR_GZ_IMG
cd /
umount /mnt/flash
ubidetach /dev/ubi_ctrl -m 4
read -p "Done, remove card and hit enter to power off."
poweroff

