#!/bin/bash

echo "USB loopback test"

set -e
set -x

BONETESTER_DIR=/var/lib/bone-tester/
COMPONENT_DIR=${BONETESTER_DIR}/component/
LIB_DIR=${BONETESTER_DIR}/lib/
source ${LIB_DIR}/utils.sh


G_FILE_STORAGE_NAME=${COMPONENT_DIR}/data/backing-file
G_FILE_BACKING_SIZE_M=20
G_FILE_BACKING_DEV=/dev/sda
G_FILE_BACKING_MNT=/home/root/.mnt-gadget
TMPFS=/home/root/.tmpfs
# Check if backing file exists
if ! [ -e ${G_FILE_STORAGE_NAME} ] ; then
	bone_echo "Please reinstall the bone tester."
fi

# Load kernel modules
# Load required kernel modules for test purposes
# This will go away once PSP fixes the OTG host-mode issue.

# Load modules in the right order
bone_echo " Removing kernel modules.."
rmmod g_zero			|| true
rmmod g_file_storage	|| true
rmmod g_ether			|| true

# USB0 Gadget
bone_echo "Loading USB kernel modules.."
modprobe g_file_storage file=${G_FILE_STORAGE_NAME}

if [ "x$(lsmod | grep g_file_storage)" = "x" ] ; then
	bone_echo "Failed to load kernel modules."
	exit $?
fi

bone_echo "Syncing to get gadget block device to showup.."
sync	# This makes sure the filesystem state is reflected correctly
		# Without sync'ing, the gadget device doesn't show up

bone_echo "Checking if gadget device is up"
# FIXME: dev name should be auto detected
if ! [ -e /dev/sda ] ; then
	bone_echo "Gadget FS Device didn't come up.. waiting for a few seconds"
	sleep 5
	if ! [ -e /dev/sda ] ; then
		bone_echo "Gadget FS Device didn't come up"
		exit 1;
	else
		bone_echo "Now it did."
	fi
fi

bone_echo "Gadget Mounting and test file creation.."
rm -rf ${G_FILE_BACKING_MNT}
mkdir -p ${G_FILE_BACKING_MNT}
mount /dev/sda ${G_FILE_BACKING_MNT}

mkdir -p ${TMPFS}
mount -t tmpfs nodev ${TMPFS}
dd if=/dev/urandom of=${TMPFS}/test-file bs=512k count=1

bone_echo "Copying test file.."
cp ${TMPFS}/test-file ${G_FILE_BACKING_MNT}/

umount ${G_FILE_BACKING_MNT}
mount /dev/sda ${G_FILE_BACKING_MNT}

bone_echo "Check if file is copied properly.."
if [ "x$(diff ${G_FILE_BACKING_MNT}/test-file ${TMPFS}/test-file)" != "x" ] ; then
	bone_echo "Data copied onto Gadget FS not present or corrupt"
	exit 1
fi

umount ${G_FILE_BACKING_MNT}
rm -rf ${G_FILE_BACKING_MNT}
umount ${TMPFS}
rm -rf ${TMPFS}

bone_echo "USB Host/Device Test Passed!"
