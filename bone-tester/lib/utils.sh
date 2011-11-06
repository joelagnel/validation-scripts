#!/bin/bash

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

read_gpio() {
	echo $1 > /sys/class/gpio/export
	cat /sys/class/gpio/gpio$1/value
	echo $1 > /sys/class/gpio/unexport
}

bone_echo() {
	echo "[bone-info] $*"
	if [ -e /dev/ttyUSB0 ] ; then
		echo "[$(date)] [bone-info] $*" > /dev/ttyUSB0
	fi
}
