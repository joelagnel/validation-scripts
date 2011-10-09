#!/bin/bash

# BeagleBone automatic tester
# 
# This script should run automatically during init and run a setup of sub tasks
# each of which will test a specific component of the board.
# It is expected to be run with the board plugged into the test board.
# Test results should be displayed and/or reported to the testboard through GPIO

COMPONENT_DIR="$( cd "$( dirname "$0" )" && pwd )"/component/

run_test() {
	if [ -z "$1" ] ; then
		echo "run_test: Missing parameter"
		return 1
	fi
	$COMPONENT_DIR/$1.sh
}

run_tests() {
	for test in $* ; do
		run_test $test
		if [ $? -ne 0 ] ; then
			echo "TEST FAILED: $test"
			return $?
		fi
	done
	echo "All test succeeded"
}

run_tests \
	usb_loopback
