#!/bin/sh
# Written by jkridner and keesj from #beagle in irc.freenode.net.
#
# Required /etc/fstab entries:
#  sudo echo "/dev/loop1 /mnt/sd_image1 vfat user 0 0" >> /etc/fstab
#
# Required directories 
#  sudo mkdir -p /mnt/sd_image1
#
# You man need into install the loop driver (sudo modprobe loop) if you don't have /dev/loop[1,2]
#
# mount related command require root permission.
#
#SUDO='sudo'
SUDO=
#
#
# You need the files in $FILES and $ROOTFS_TARBALL are your current working directory

FILES="MLO u-boot.bin uImage"

# Usage: ./mksdimg.sh
#

set -x

SD_IMG=beagleboard-validation.img

#VFAT_LOOP=/dev/loop1
VFAT_LOOP=/dev/loop3
VFAT_TARGET=/mnt/sd_image1

VOL_LABEL=BEAGLE

SYNC=
MKFS_VFAT=/usr/sbin/mkfs.vfat
MKFS_EXT3=/sbin/mkfs.ext3
LOSETUP=/sbin/losetup
FDISK=/sbin/fdisk
SFDISK=/sbin/sfdisk
#READ=read -p
READ=/usr/bin/echo

CYL=16
HEADS=255
SECTOR_SIZE=512
SECTOR_PER_TRACK=63

BS_SIZE=`echo $HEADS \* $SECTOR_PER_TRACK \* $SECTOR_SIZE | bc`
BS_CNT=$CYL

IMG_SIZE=`echo $BS_SIZE \* $BS_CNT | bc`

FS1_OFFSET=`echo $SECTOR_SIZE \* $SECTOR_PER_TRACK | bc`
FS1_PARTITION_SIZE=15
FS1_SECTOR_CNT=`echo $FS1_PARTITION_SIZE \* $HEADS \* $SECTOR_PER_TRACK | bc`
FS1_SIZE=`echo $FS1_SECTOR_CNT \* $SECTOR_SIZE | bc` 

CWD=`pwd`

function clean_up {
    $SUDO umount $VFAT_LOOP
    $SUDO $LOSETUP -d $VFAT_LOOP
}

function erase_image {
    rm -f $SD_IMG $SD_IMG.gz
}

function create_image {
    if [ -r $SD_IMG ] ; then
        SIZE=`ls -l $SD_IMG | awk "{print $5}"`
    else
        SIZE=0
    fi

#    if [ $SIZE -ne $IMG_SIZE ] ; then
        erase_image $SD_IMG
        dd if=/dev/zero of=$SD_IMG bs=$BS_SIZE count=$BS_CNT
#    fi
}

function partition_image {
#  the format for sfdisk is
#  <start> <size> <id> <bootable>
   $SFDISK -C $CYL -H $HEADS -S $SECTOR_PER_TRACK -D $SD_IMG <<EOF
,$FS1_PARTITION_SIZE,0x0c,*
EOF
   $FDISK -l -u $SD_IMG > $SD_IMG.txt
}

function mount_fat {
    # 512 (sector size) * 63 (starting sector) = 32256
    #$SUDO $LOSETUP -d $VFAT_LOOP
    $SUDO $LOSETUP -v -o $FS1_OFFSET $VFAT_LOOP $SD_IMG
    if [ "$1" = "format" ]; then
        # 120456
        $SUDO $MKFS_VFAT $VFAT_LOOP -n $VOL_LABEL -F 32 120456
    fi
    $SUDO mount $VFAT_LOOP
}

function copy_fat_files {
   md5sum $FILES > md5sum.txt
   $SUDO cp -R $FILES $VFAT_TARGET
   $SUDO cp md5sum.txt $VFAT_TARGET
}

function unmount_fat {
   $SYNC
   $SUDO umount $VFAT_LOOP
   $SUDO $LOSETUP -d $VFAT_LOOP
}

function compress_image {
   gzip -c $SD_IMG > $SD_IMG.gz
}

clean_up
$READ "clean_up complete" a

create_image
$READ "create_image complete" a

partition_image
$READ "partition_image complete" a

mount_fat format
$READ "mount_fat format complete" a

copy_fat_files
$READ "copy_fat_files complete" a

unmount_fat
$READ "unmount_fat complete" a

compress_image

