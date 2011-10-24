#!/bin/bash
set -x
# Important to Error Out on any errors
set -e

BONETESTER_DIR=/var/lib/bone-tester/
COMPONENT_DIR=${BONETESTER_DIR}/component/
LIB_DIR=${BONETESTER_DIR}/lib/

if [ $(${LIB_DIR}/read-eeprom.sh 50 4 8) != "A335BONE" ] ; then
	echo "EEPROM test failed"
	exit 1
fi

echo "EEPROM test passed!"

