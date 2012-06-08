#!/bin/bash

TTYDEV=/dev/$(basename /sys/bus/usb-serial/drivers/pl2303/ttyUSB*)

if [ ! -e $TTYDEV ] ; then
        echo "couldn't find usb device"
        exit
fi

stty -F $TTYDEV 115200

USB_MODULES="g_ether \
	g_mass_storage   \
	g_zero           \
	g_file_storage   \
    g_serial"

rmmod_all_usb_modules() {
	for mod in ${USB_MODULES} ; do
		rmmod ${mod} || true
	done
}

get_iface_name() {
	type=$1
	iface=""
	for i in /sys/class/net/* ; do
		iface=$(basename $i)
		if [ "$iface" = "lo" ] ; then iface="" ; continue ; fi
		if [ "x$(ls -la $i/device/ | grep $type)" != "x" ] ; then
			echo $iface
			return 0
		fi
	done
	echo $iface
	return 0
}

# This function takes the 'converted' number of the gpio: 
#	gpio 0_17 -> gpio 17
#	gpio 1_13 -> gpio 45
#	gpio 2_3  -> gpio 67 
read_gpio() {
	echo $1 > /sys/class/gpio/export
	cat /sys/class/gpio/gpio$1/value
	echo $1 > /sys/class/gpio/unexport
}

bone_echo() {
	echo "[bone-info] $*"
	if [ -e $TTYDEV ] ; then
		echo "[$(date)] [bone-info] $*" > $TTYDEV
	fi
}
