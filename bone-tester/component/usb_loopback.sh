#!/bin/bash

echo "USB loopback test"

set -e

COMPONENT_DIR="$( cd "$( dirname "$0" )" && pwd )"

G_FILE_STORAGE_NAME=${COMPONENT_DIR}/data/backing-file
G_FILE_BACKING_SIZE_M=20
G_FILE_BACKING_DEV=/dev/sda
G_FILE_BACKING_MNT=/tmp/mnt

# Check if backing file exists
if ! [ -e ${G_FILE_STORAGE_NAME} ] ; then
	echo "Please reinstall the bone tester."
fi

# Load kernel modules
# Load required kernel modules for test purposes
# This will go away once PSP fixes the OTG host-mode issue.

# Load modules in the right order
rmmod g_zero			|| true
rmmod g_file_storage	|| true
rmmod g_ether			|| true

# USB0 Gadget
modprobe g_file_storage file=${G_FILE_STORAGE_NAME}

# Turn on USB1 Host
modprobe g_zero

if [ "x$(lsmod | grep g_zero)" = "x" ] ; then
	echo "Failed to load kernel modules."
	exit $?
fi
if [ "x$(lsmod | grep g_file_storage)" = "x" ] ; then
	echo "Failed to load kernel modules."
	exit $?
fi

sync	# This makes sure the filesystem state is reflected correctly
		# Without sync'ing, the gadget device doesn't show up

# FIXME: dev name should be auto detected
if ! [ -e /dev/sda ] ; then
	echo "Gadget FS Device didn't come up.. waiting for a few seconds"
	sleep 5
fi
if ! [ -e /dev/sda ] ; then
	echo "Gadget FS Device didn't come up"
	exit 1
fi

mkdir -p ${G_FILE_BACKING_MNT}
mount /dev/sda ${G_FILE_BACKING_MNT}

dd if=/dev/urandom of=/tmp/test-file bs=4k count=$((256 * 4))
cp /tmp/test-file ${G_FILE_BACKING_MNT}/

umount ${G_FILE_BACKING_MNT}
mount /dev/sda ${G_FILE_BACKING_MNT}

if [ "x$(diff ${G_FILE_BACKING_MNT}/test-file /tmp/test-file)" != "x" ] ; then
	echo "Data copied onto Gadget FS not present or corrupt"
fi

umount ${G_FILE_BACKING_MNT}
rm /tmp/test-file

echo "USB Host/Device Test Passed!"
