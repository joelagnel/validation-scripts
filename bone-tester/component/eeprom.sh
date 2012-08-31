#!/bin/bash

BONETESTER_DIR=/var/lib/bone-tester/
COMPONENT_DIR=${BONETESTER_DIR}/component/
LIB_DIR=${BONETESTER_DIR}/lib/

source ${LIB_DIR}/utils.sh

set -x
# Important to Error Out on any errors
set -e

BONETESTER_DIR=/var/lib/bone-tester/
COMPONENT_DIR=${BONETESTER_DIR}/component/
LIB_DIR=${BONETESTER_DIR}/lib/

if [ $(${LIB_DIR}/read-eeprom.sh 50 4 8) != "A335BONE" ] ; then
	bone_echo "EEPROM test failed"
	exit 1
fi

if [ "x$(lsusb -v|grep -i beaglebone)" != "x" ] ; then
	bone_echo "FTDI EEPROM test passed, detected beaglebone in USB device descriptor"
else
	bone_echo "FTDI EEPROM test failed"
	bone_echo "USB devices present:"
	bone_echo $(lsusb)
	exit 1
fi

BONEREVISION="$(${LIB_DIR}/read-eeprom.sh 50 14 2)"
BONESERIAL="$(${LIB_DIR}/read-eeprom.sh 50 16 12)"

bone_echo "Beaglebone $BONEREVISION with serial $BONESERIAL"

bone_echo "EEPROM test passed!"

