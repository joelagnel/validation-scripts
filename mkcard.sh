#!/bin/bash
# mkcard.sh v0.3.beagleboard-validation-scripts.1
# (c) Copyright 2009 Graeme Gregory <dp@xora.org.uk>
# Licensed under terms of GPLv2

DRIVE=$1
MLO=$2
UBOOT=$3
UIMAGE=$4
BOOTSCR=$5
RAMDISK=$6
USERSCR=$7
LOCALSRC=/media/mmcblk0
WGETSRC=http://www.beagleboard.org/~arago/xm-testing
DST=/media/target

function do_clean {
dd if=/dev/zero of=$DRIVE bs=1024 count=1024
}

function do_format {
for tool in sfdisk mkfs.vfat mke2fs; do
	if ! type $tool >/dev/null 2>&1; then
		echo "ERROR: \"$tool\" not found."
		echo "	Try 'opkg install dosfstools e2fsprogs e2fsprogs-mke2fs'"
		exit 2
	fi
done
SIZE=`fdisk -l $DRIVE | grep Disk | awk '{print $5}'`
echo DISK SIZE - $SIZE bytes
CYLINDERS=`echo $SIZE/255/63/512 | bc`
echo CYLINDERS - $CYLINDERS
{
echo ,9,0x0C,*
echo ,,,-
} | sfdisk -D -H 255 -S 63 -C $CYLINDERS $DRIVE
sync
sleep 1
if [ -b ${DRIVE}1 ]; then
	umount ${DRIVE}1
	mkfs.vfat -F 32 -n "boot" ${DRIVE}1
else
	if [ -b ${DRIVE}p1 ]; then
		umount ${DRIVE}p1
		mkfs.vfat -F 32 -n "boot" ${DRIVE}p1
	else
		echo "Cant find boot partition in ${DRIVE}(1|p1)"
		exit -1
	fi
fi
if [ -b ${DRIVE}2 ]; then
	umount ${DRIVE}2
	mke2fs -j -L "rootfs" ${DRIVE}2
else
	if [ -b ${DRIVE}p2 ]; then
		umount ${DRIVE}p2
		mke2fs -j -L "rootfs" ${DRIVE}p2
	else
		echo "Cant find rootfs partition in ${DRIVE}(2|p2)"
		exit -1
	fi
fi
}

function do_mount {
	sync
	mkdir -p ${DST}p1
	mkdir -p ${DST}p2
	mount ${DRIVE}p1 ${DST}p1
	mount ${DRIVE}p2 ${DST}p2
}

function do_copy {
if [ "x$MLO" = "x" ]; then
	MLO=${SRC}p1/MLO
fi;
if [ -e $MLO ]; then
	cp -v $MLO ${DST}p1/MLO
else
	echo "Cannot find MLO at $MLO"
	exit -1
fi
if [ "x$UBOOT" = "x" ]; then
	UBOOT=${SRC}p1/u-boot.bin
fi;
if [ -e $UBOOT ]; then
	cp -v $UBOOT ${DST}p1/u-boot.bin
else
	echo "Cannot find u-boot.bin at $UBOOT"
	exit -1
fi
if [ "x$UIMAGE" = "x" ]; then
	UIMAGE=${SRC}p1/uImage
fi;
if [ -e $UIMAGE ]; then
	cp -v $UIMAGE ${DST}p1/uImage
else
	echo "Cannot find uImage at $UIMAGE"
	exit -1
fi
if [ "x$BOOTSCR" = "x" ]; then
	BOOTSCR=${SRC}p1/boot.scr
fi;
if [ -e $BOOTSCR ]; then
	cp -v $BOOTSCR ${DST}p1/boot.scr
fi
if [ "x$RAMDISK" != "x" && -e $RAMDISK ]; then
	cp -v $RAMDISK ${DST}p1/ramdisk.gz
fi
if [ "x$USERSCR" != "x" && -e $USERSCR ]; then
	cp -v $USERSCR ${DST}p1/user.scr
fi
}

do_clean
do_format
#do_mount
#do_wget
#do_copy
