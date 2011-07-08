#!/bin/bash

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


# This script is to be run from an init script once the board has booted
if [ ! -e /dev/mtd4 ]; then
  echo "ERROR: No NAND Filesystem partition found. Aborting flashing."
  exit 1
fi

if [ ! -e /boot/mtd4.gz ]; then
  echo "ERROR: No NAND image to copy from. exiting."
  exit 1
fi

# This script is to be run from an init script once the board has booted
NAND_IMG_GZ=/boot/mtd4.gz

echo "Erasing nand"
flash_eraseall /dev/mtd4

echo "writing to flash"
zcat $NAND_IMG_GZ | dd of=/dev/mtd4 bs=1M

read -p "Done, remove card and hit enter to power off."
poweroff

