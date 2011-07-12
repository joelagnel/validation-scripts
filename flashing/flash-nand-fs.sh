#!/bin/bash

# This script is to be run from an init script once the board has booted
UBI_IMG=/boot/fs.ubi

# These commands build a ubi image
#
# mkfs.ubifs -r /home/joel/nfsexport/c5-ubiformat/mount -o /home/joel/nfsexport/c5-ubiformat/fs.ubifs -m 2048 -e 129024 -c 1996
# ubinize -o /home/joel/nfsexport/c5-ubiformat/mount/fs.ubi -m 2048 -p 128KiB -s 512 /home/joel/nfsexport/c5-ubiformat/ubinize.cfg

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

if [ ! -e $UBI_IMG ]; then
  echo "ERROR: No UBI image found on SD Card. Please download one from Narcissus. exiting."
  exit 1
fi

echo "Erasing nand"
flash_eraseall /dev/mtd4

echo "writing to flash"
ubiformat /dev/mtd4 -s 512 -f ${UBI_IMG}

read -p "Done, remove card and hit enter to power off."
poweroff

