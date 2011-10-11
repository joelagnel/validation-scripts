#!/bin/bash

echo "USB loopback test"

set -e

COMPONENT_DIR="$( cd "$( dirname "$0" )" && pwd )"

G_FILE_STORAGE_NAME=${COMPONENT_DIR}/data/backing-file
G_FILE_BACKING_SIZE_M=20
G_FILE_BACKING_DEV=/dev/sda
G_FILE_BACKING_MNT=/home/root/.mnt-gadget
TMPFS=/home/root/.tmpfs
# Check if backing file exists
if ! [ -e ${G_FILE_STORAGE_NAME} ] ; then
	echo "Please reinstall the bone tester."
fi

# Load kernel modules
# Load required kernel modules for test purposes
# This will go away once PSP fixes the OTG host-mode issue.

# Load modules in the right order
echo " Removing kernel modules.."
rmmod g_zero			|| true
rmmod g_file_storage	|| true
rmmod g_ether			|| true

# USB0 Gadget
echo "Loading USB kernel modules.."
modprobe g_file_storage file=${G_FILE_STORAGE_NAME}
# Turn on USB1 Host
modprobe g_zero

echo "Checking if loaded correctly.."
if [ "x$(lsmod | grep g_zero)" = "x" ] ; then
	echo "Failed to load kernel modules."
	exit $?
fi
if [ "x$(lsmod | grep g_file_storage)" = "x" ] ; then
	echo "Failed to load kernel modules."
	exit $?
fi

echo "Syncing to get gadget block device to showup.."
sync	# This makes sure the filesystem state is reflected correctly
		# Without sync'ing, the gadget device doesn't show up

echo "Checking if gadget device is up"
# FIXME: dev name should be auto detected
if ! [ -e /dev/sda ] ; then
	echo "Gadget FS Device didn't come up.. waiting for a few seconds"
	sleep 5
	if ! [ -e /dev/sda ] ; then
		echo "Gadget FS Device didn't come up"
		exit 1;
	else
		echo "Now it did."
	fi
fi

echo "Gadget Mounting and test file creation.."
rm -rf ${G_FILE_BACKING_MNT}
mkdir -p ${G_FILE_BACKING_MNT}
mount /dev/sda ${G_FILE_BACKING_MNT}

mkdir -p ${TMPFS}
mount -t tmpfs nodev ${TMPFS}
dd if=/dev/urandom of=${TMPFS}/test-file bs=512k count=1

echo "Copying test file.."
cp ${TMPFS}/test-file ${G_FILE_BACKING_MNT}/

umount ${G_FILE_BACKING_MNT}
mount /dev/sda ${G_FILE_BACKING_MNT}

echo "Check if file is copied properly.."
if [ "x$(diff ${G_FILE_BACKING_MNT}/test-file ${TMPFS}/test-file)" != "x" ] ; then
	echo "Data copied onto Gadget FS not present or corrupt"
	exit 1
fi

umount ${G_FILE_BACKING_MNT}
rm -rf ${G_FILE_BACKING_MNT}
umount ${TMPFS}
rm -rf ${TMPFS}

echo "USB Host/Device Test Passed!"
