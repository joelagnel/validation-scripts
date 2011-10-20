#!/bin/bash

# BeagleBone automatic tester
# 
# This script should run automatically during init and run a setup of sub tasks
# each of which will test a specific component of the board.
# It is expected to be run with the board plugged into the test board.
# Test results should be displayed and/or reported to the testboard through GPIO

BONETESTER_DIR=/var/lib/bone-tester/
COMPONENT_DIR=${BONETESTER_DIR}/component/
LIB_DIR=${BONETESTER_DIR}/lib/

source ${LIB_DIR}/utils.sh

run_test() {
	if [ -z "$1" ] ; then
		echo "run_test: Missing parameter"
		return 1
	fi
	$COMPONENT_DIR/$1.sh
}

delete_uenv() {
	set -e
	mkdir /tmp/mnt
	mount /dev/mmcblk0p1 /tmp/mnt
	rm -f /tmp/mnt/uEnv.txt
	umount /tmp/mnt
	set +e
}

run_tests() {
	run_led_command init_leds
	run_led_command toggle_timer 3 300
	for test in $* ; do
		run_test $test
		if [ $? -ne 0 ] ; then
			echo "TEST FAILED: $test"
			run_led_command flash_all
			return $?
		fi
	done
	run_led_command turn_on_all
	delete_uenv
	echo "All tests succeeded"
}

function run_led_command() {
	${BONETESTER_DIR}/lib/leds.sh $*
}

run_led_command stop_led_function

# systemd gadget-init service unit might insert usb modules, prepare for this
rmmod_all_usb_modules

run_tests \
    usb_loopback \
    ethernet \
    eeprom \
