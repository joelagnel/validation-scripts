#!/bin/sh
# Written by jkridner and keesj from #beagle in irc.freenode.net.
#
# Required /etc/fstab entries:
#  /dev/loop1 /mnt/arago/sd_image1 vfat user 0 0
#  /dev/loop2 /mnt/arago/sd_image2 ext3 user 0 0
#
# Required directories 
#  /mnt/arago/sd_image1 
#  /mnt/arago/sd_image2
#
#      sudo mkdir -p /mnt/arago/sd_image1 /mnt/arago/sd_image2
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

#FILES="MLO u-boot.bin uImage.bin ramdisk.gz boot.scr boot.sh readme.txt u-boot-f.bin normal.scr reset.scr modules.tgz"
FILES="boot.scr uImage.001 uImage.002 readme.txt switchboot menu linux.inf gserial.inf"

# Usage: ./mksdimg.sh
#

set -x

VFAT_LOOP=/dev/loop1
EXT3_LOOP=/dev/loop2
VFAT_TARGET=/mnt/arago/sd_image1
EXT3_TARGET=/mnt/arago/sd_image2

VOL_LABEL=ESC_BEAGLE

SYNC=
MKFS_VFAT=/usr/sbin/mkfs.vfat
MKFS_EXT3=/sbin/mkfs.ext3
LOSETUP=/sbin/losetup
FDISK=/sbin/fdisk
SFDISK=/sbin/sfdisk
#READ=read -p
READ=/usr/bin/echo

CYL=486
HEADS=255
SECTOR_SIZE=512
SECTOR_PER_TRACK=63

BS_SIZE=`echo $HEADS \* $SECTOR_PER_TRACK \* $SECTOR_SIZE | bc`
BS_CNT=$CYL

IMG_SIZE=`echo $BS_SIZE \* $BS_CNT | bc`

SD_FORMATTED=sd-4gb-formatted.img

SD_IMG=esc-boston-2009-006.img
FS1_OFFSET=`echo $SECTOR_SIZE \* $SECTOR_PER_TRACK | bc`
FS1_PARTITION_SIZE=15
FS1_SECTOR_CNT=`echo $FS1_PARTITION_SIZE \* $HEADS \* $SECTOR_PER_TRACK | bc`
FS1_SIZE=`echo $FS1_SECTOR_CNT \* $SECTOR_SIZE | bc` 
FS2_OFFSET=$FS1_SIZE
FS2_PARTITION_SIZE=471

#SD_IMG=esc2009sj.v12.img
#FS1_OFFSET=`echo $SECTOR_SIZE \* $SECTOR_PER_TRACK | bc`
#FS1_PARTITION_SIZE=15
#FS1_SECTOR_CNT=`echo $FS1_PARTITION_SIZE \* $HEADS \* $SECTOR_PER_TRACK | bc`
#FS1_SIZE=`echo $FS1_SECTOR_CNT \* $SECTOR_SIZE | bc` 
#FS2_OFFSET=`echo 176715 \* $SECTOR_SIZE | bc`
##FS2_OFFSET=`echo 674730 \* $SECTOR_SIZE | bc`
##FS2_OFFSET=`echo 2939895 \* $SECTOR_SIZE | bc`
#FS2_PARTITION_SIZE=471

CWD=`pwd`

function clean_up {
    $SUDO umount $VFAT_LOOP
    $SUDO umount $EXT3_LOOP
    $SUDO $LOSETUP -d $VFAT_LOOP
    $SUDO $LOSETUP -d $EXT3_LOOP
}

function erase_image {
    rm -f $SD_IMG $SD_IMG.gz
}

function create_image {
    if [ -r $SD_IMG ] ; then
        SIZE=`ls -l $SD_IMG | cut -c33-44`
    else
        SIZE=0
    fi

    if [ $SIZE -ne $IMG_SIZE ] ; then
        erase_image $SD_IMG
        dd if=/dev/zero of=$SD_IMG bs=$BS_SIZE count=$BS_CNT
    fi
}

function partition_image {
#  the format for sfdisk is
#  <start> <size> <id> <bootable>
   $SFDISK -C $CYL -H $HEADS -S $SECTOR_PER_TRACK -D $SD_IMG <<EOF
,$FS1_PARTITION_SIZE,0x0c,*
,$FS2_PARTITION_SIZE,0x83,-
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

function mount_ext3 {
    # 15 * 255 * 63 = 240975 (starting sector)
    # 512 (sector size) * 240975 (starting sector) = 123379200
    #$SUDO $LOSETUP -d $EXT3_LOOP
    $SUDO $LOSETUP -v -o $FS2_OFFSET $EXT3_LOOP $SD_IMG
    if [ "$1" = "format" ]; then
        $SUDO $MKFS_EXT3 $EXT3_LOOP
    fi
    $SUDO mount $EXT3_LOOP
}

function copy_ext3_files {
   LOCAL_PATH=$1
   if echo "$ROOTFS_TARBALL" | fgrep -q '/' ; then
      PATH_ROOTFS_TARBALL=$ROOTFS_TARBALL
   else
      PATH_ROOTFS_TARBALL=$CWD/$ROOTFS_TARBALL
   fi
   if [ "$LOCAL_PATH" != "" ] ; then
      TARGET_PATH=$EXT3_TARGET/$LOCAL_PATH
      mkdir -p $TARGET_PATH
   else
      TARGET_PATH=$EXT3_TARGET
   fi
   pushd $TARGET_PATH
   if echo "$ROOTFS_TARBALL" | fgrep -q '.gz' ; then
      $SUDO tar xzf $PATH_ROOTFS_TARBALL
   elif echo "$ROOTFS_TARBALL" | fgrep -q '.bz2' ; then
      $SUDO tar xjf $PATH_ROOTFS_TARBALL
   else
      $SUDO cp $PATH_ROOTFS_TARBALL .
   fi
   popd
}

function unmount_ext3 {
   $SYNC
   $SUDO umount $EXT3_LOOP
   $SUDO $LOSETUP -d $EXT3_LOOP
}

function compress_image {
   gzip -c $SD_IMG > $SD_IMG.gz
}

clean_up
$READ "clean_up complete" a

#create_image
#$READ "create_image complete" a

#partition_image
#$READ "partition_image complete" a

#mount_fat format
#$READ "mount_fat format complete" a

#unmount_fat
#$READ "unmount_fat complete" a

#mount_ext3 format
#$READ "mount_ext3 format complete" a

#unmount_ext3
#$READ "unmount_ext3  complete" a

cp $SD_FORMATTED.gz $SD_IMG.gz
gunzip $SD_IMG.gz
$READ "cp $SD_FORMATTED $SD_IMG"

mount_fat
$READ "mount_fat complete" a

copy_fat_files
$READ "copy_fat_files complete" a

unmount_fat
$READ "unmount_fat complete" a

mount_ext3
$READ "mount_ext3 complete" a

ROOTFS_TARBALL="Beagleboard-esc-demo-image-beagleboard.tar.bz2"
copy_ext3_files
$READ "copy_ext3_files esc-boston-2009 complete" a

#ROOTFS_TARBALL="esc-boston-2009-001-image-beagleboard.tar.bz2"
#copy_ext3_files
#$READ "copy_ext3_files esc-boston-2009 complete" a

ROOTFS_TARBALL="beagleboard-overlay-001.tar.bz2"
copy_ext3_files
$READ "copy_ext3_files beagleboard-overlay complete" a

ROOTFS_TARBALL="090903-fall-esc-gst-script-overlay.tar.bz2"
copy_ext3_files
$READ "copy_ext3_files gst-script-overlay complete" a

ROOTFS_TARBALL="090903-fall-esc-gst-media-overlay.tar.bz2"
copy_ext3_files opt
$READ "copy_ext3_files gst-media-overlay complete" a

#ROOTFS_TARBALL="esc_boston_graphics.tar.gz"
#copy_ext3_files
#$READ "copy_ext3_files beagleboard-overlay complete" a

ROOTFS_TARBALL="esc_boston_graphics_overlay.bin"
copy_ext3_files home/root
$READ "copy_ext3_files graphics complete" a

ROOTFS_TARBALL="android-001.tar.bz2"
copy_ext3_files
$READ "copy_ext3_files android complete" a

ROOTFS_TARBALL="switchboot"
copy_ext3_files
$READ "copy_ext3_files switchboot complete" a

unmount_ext3
$READ "unmount_ext3  complete" a

compress_image

