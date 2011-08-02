
# Narcissus - Online image builder for the angstrom distribution
# Copyright (C) 2008 - 2011 Koen Kooi
# Copyright (C) 2010        Denys Dmytriyenko
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

set -x

SCRIPTDIR="$( cd "$( dirname "$0" )" && pwd )"
WORKDIR=$SCRIPTDIR
TARGETDIR=$SCRIPTDIR/output/target
INPUTDIR=$SCRIPTDIR/input/
MACHINE=beagleboard

IMAGENAME=test

function do_sdimg() 
{
	if [ ! -e $INPUTDIR/${IMAGENAME}-${MACHINE}.tar.gz ]; then
		echo "FATAL: Source tar ball not found"
		exit
	fi

	if [ ! -e $INPUTDIR/${IMAGENAME}-${MACHINE}.ubi ]; then
		echo "FATAL: Source UBIFS image not found"
		exit
	fi

if [ -e ${WORKDIR}/conf/${MACHINE}/sd ] ; then
	MD5SUM_SD="$(md5sum ${TARGET_DIR}/boot/uImage | awk '{print $1}')"	

	for sdsize in $(ls ${WORKDIR}/conf/${MACHINE}/sd/sd-master* | sed -e s:${WORKDIR}/conf/${MACHINE}/sd/sd-master-::g -e 's:.img.gz::g' | xargs echo) ; do

	echo "SD size: $sdsize"

	if true ; then
		echo "No cached SD image found, generating new one"
		zcat ${WORKDIR}/conf/${MACHINE}/sd/sd-master-$sdsize.img.gz > sd.img
		/sbin/fdisk -l -u sd.img

		# Output looks like:
		# Disk sd-master-1GiB.img: 0 MB, 0 bytes
		# 255 heads, 63 sectors/track, 0 cylinders, total 0 sectors
		# Units = sectors of 1 * 512 = 512 bytes
		# Sector size (logical/physical): 512 bytes / 512 bytes
		# I/O size (minimum/optimal): 512 bytes / 512 bytes
		# Disk identifier: 0x00000000
		# 
		#             Device Boot      Start         End      Blocks   Id  System
		# sd-master-1GiB.img1   *          63      144584       72261    c  W95 FAT32 (LBA)
		# sd-master-1GiB.img2          144585     1959929      907672+  83  Linux
	
	
		BYTES_PER_SECTOR="$(/sbin/fdisk -l -u sd.img | grep Units | awk '{print $9}')"
		VFAT_SECTOR_OFFSET="$(/sbin/fdisk -l -u sd.img | grep img1 | awk '{print $3}')"
		EXT3_SECTOR_OFFSET="$(/sbin/fdisk -l -u sd.img | grep img2 | awk '{print $2}')"

		LOOP_DEV="/dev/loop1"
		LOOP_DEV_FS="/dev/loop2"

		echo ""

		# VFAT
		echo "/sbin/losetup -v -o $(expr ${BYTES_PER_SECTOR} "*" ${VFAT_SECTOR_OFFSET}) ${LOOP_DEV} sd.img"
		/sbin/losetup -v -o $(expr ${BYTES_PER_SECTOR} "*" ${VFAT_SECTOR_OFFSET}) ${LOOP_DEV} sd.img

		# EXT3
		echo "/sbin/losetup -v -o $(expr ${BYTES_PER_SECTOR} "*" ${EXT3_SECTOR_OFFSET}) ${LOOP_DEV_FS} sd.img"
		/sbin/losetup -v -o $(expr ${BYTES_PER_SECTOR} "*" ${EXT3_SECTOR_OFFSET}) ${LOOP_DEV_FS} sd.img
		echo "/sbin/mkfs.ext3 -L Narcissus-rootfs ${LOOP_DEV_FS}"
		/sbin/mkfs.ext3 -L Narcissus-rootfs ${LOOP_DEV_FS}

		echo ""
	
		echo "mount ${LOOP_DEV}"
		mount ${LOOP_DEV}

		echo "mount ${LOOP_DEV_FS}"
		mount ${LOOP_DEV_FS}

		# report mount status to log
		mount | grep loop


		ls  ${TARGET_DIR}/boot

		echo "copying files to vfat"
		if [ -e ${WORKDIR}/conf/${MACHINE}/sd/MLO ] ; then
			cp -v ${WORKDIR}/conf/${MACHINE}/sd/MLO /mnt/narcissus/sd_image1/MLO
		else
			rm -f /mnt/narcissus/sd_image1/MLO		
		fi
		if [ -e ${TARGET_DIR}/boot/u-boot-*.bin ] ;then
			cp -v ${TARGET_DIR}/boot/u-boot-*.bin /mnt/narcissus/sd_image1/u-boot.bin
			echo "Copied u-boot from /boot"
		else
			cp -v ${WORKDIR}/conf/${MACHINE}/sd/u-boot.bin /mnt/narcissus/sd_image1/u-boot.bin
			echo "Using u-boot from narcissus, no u-boot.bin found in rootfs"
		fi
		if [ -e ${TARGET_DIR}/boot/uImage-2.6* ] ;then 
			cp -v ${TARGET_DIR}/boot/uImage-2.6* /mnt/narcissus/sd_image1/uImage
			echo "Copied uImage from /boot"
		else
			cp -v ${WORKDIR}/conf/${MACHINE}/sd/uImage.bin /mnt/narcissus/sd_image1/uImage
			echo "Using uImage from narcissus, no uImage found in rootfs"
		fi

		if [ -e ${TARGET_DIR}/boot/user.txt ] ; then
			cp -v ${TARGET_DIR}/boot/user.txt /mnt/narcissus/sd_image1/
		fi

		if [ -e ${TARGET_DIR}/boot/uEnv.txt ] ; then
			cp -v ${TARGET_DIR}/boot/uEnv.txt /mnt/narcissus/sd_image1/
		fi

		echo "Remounting ${LOOP_DEV}"
		umount ${LOOP_DEV}
		mount ${LOOP_DEV}

		echo "Copying file system:"
		echo "tar xzf ${TARGET_DIR}/../${IMAGENAME}-${MACHINE}.tar.gz -C /mnt/narcissus/sd_image2"
		tar xzf ${TARGET_DIR}/../${IMAGENAME}-${MACHINE}.tar.gz -C /mnt/narcissus/sd_image2

		if [ -e ${UBIFS_TMP_DIR}/${IMAGENAME}-${MACHINE}.ubi ] ; then
			echo "Copying UBIFS image to file system:"
			cp ${UBIFS_TMP_DIR}/${IMAGENAME}-${MACHINE}.ubi /mnt/narcissus/sd_image2/boot/fs.ubi
		fi

		touch  /mnt/narcissus/sd_image2/narcissus-was-here
		echo "Remounting ${LOOP_DEV_FS}"
		umount ${LOOP_DEV_FS}
		mount ${LOOP_DEV_FS}

		echo "files in ext3 partition:" $(du -hs /mnt/narcissus/sd_image2/* | sed s:/mnt/narcissus/sd_image2/::g)

		echo "umount ${LOOP_DEV}"	
		umount ${LOOP_DEV}
		echo "umount ${LOOP_DEV_FS}"
		umount ${LOOP_DEV_FS}
	
		/sbin/losetup -d ${LOOP_DEV}
		/sbin/losetup -d ${LOOP_DEV_FS}

		echo "gzip -c sd.img > ${TARGET_DIR}/../${IMAGENAME}-${MACHINE}-sd-$sdsize.img.gz"
		gzip -c sd.img > ${TARGET_DIR}/../${IMAGENAME}-${MACHINE}-sd-$sdsize.img.gz
	fi
	done
fi
}

