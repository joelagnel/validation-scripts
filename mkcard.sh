#!/bin/bash -xv
# mkcard.sh v0.3.beagleboard-validation-scripts.1
# (c) Copyright 2009 Graeme Gregory <dp@xora.org.uk>
# Licensed under terms of GPLv2

DRIVE=$1
CYLINDERS=$2
#LOCALSRC=/media/mmcblk0
WGETSRC=http://www.beagleboard.org/~arago/xm-testing
DST=/media/target

for tool in dd sfdisk partx mkfs.vfat mke2fs; do
	if ! type $tool >/dev/null 2>&1; then
		echo "ERROR: \"$tool\" not found."
		echo "	Try 'opkg install dosfstools e2fsprogs e2fsprogs-mke2fs'"
		exit 2
	fi
done

function do_clean {
if [ "x$DRIVE" = "x" ]; then
 echo "DRIVE not set, exiting."
 exit -1
fi
sleep 3
umount ${DRIVE}1
umount ${DRIVE}2
umount ${DRIVE}p1
umount ${DRIVE}p2
if [ `dd if=/dev/zero of=$DRIVE bs=1024 count=1024` ]; then
 echo "Do you need to run the script as 'root'?"
 exit -1
fi
}

function do_format {
if [ "x$DRIVE" = "x" ]; then
 echo "DRIVE not set, exiting."
 exit -1
fi
SIZE=`fdisk -l $DRIVE | grep Disk | awk '{print $5}'`
if [ "x$CYLINDERS" = "x" ]; then
 if [ "x$SIZE" = "x" ]; then
  echo "Unable to determine disk size, exiting."
  exit -1
 else
  echo DISK SIZE - $SIZE bytes
  CYLINDERS=`echo $SIZE/255/63/512 | bc`
 fi
fi
echo CYLINDERS - $CYLINDERS
sync
sleep 3
{
echo ,9,0x0C,*
echo ,,,-
} | sfdisk -D -H 255 -S 63 -C $CYLINDERS $DRIVE
partx $DRIVE
sleep 3
if [ -b ${DRIVE}1 ]; then
 DRIVE1=${DRIVE}1
else
 if [ -b ${DRIVE}p1 ]; then
  DRIVE1=${DRIVE}p1
 else
  echo "Cant find boot partition in ${DRIVE}(1|p1)"
  exit -1
 fi
fi
echo "Found first partition at ${DRIVE1}"
umount ${DRIVE1}
dd if=/dev/zero of=${DRIVE1} bs=512 count=1
mkfs.vfat -F 32 -n "boot" ${DRIVE1}
if [ -b ${DRIVE}2 ]; then
 DRIVE2=${DRIVE}2
else
 if [ -b ${DRIVE}p2 ]; then
  DRIVE2=${DRIVE}2
 else
  echo "Cant find rootfs partition in ${DRIVE}(2|p2)"
  exit -1
 fi
fi
echo "Found second partition at ${DRIVE2}"
umount ${DRIVE2}
mke2fs -j -L "rootfs" ${DRIVE2}
}

function do_mount {
umount ${DRIVE1}
umount ${DRIVE2}
mkdir -p ${DST}-1
mkdir -p ${DST}-2
mount ${DRIVE1} ${DST}-1
mount ${DRIVE2} ${DST}-2
}

function do_copy {
for file in MLO u-boot.bin uImage boot.scr user.scr ramdisk.gz; do
 if [ ! -e $file ]; then
  echo "Cannot find $file, attempting to download from $WGETSRC"
  wget $WGETSRC/$file
 fi
 if [ -e $file ]; then
  cp -v $file ${DST}-1/$file
 else
  echo "Still cannot find $file"
  #exit -1
 fi
done
}

function do_umount {
umount ${DRIVE1}
umount ${DRIVE2}
}

do_clean
do_format
do_mount
do_copy
do_umount

