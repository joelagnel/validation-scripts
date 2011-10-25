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

bone_echo "EEPROM test passed!"

