#!/bin/bash

set -x

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
