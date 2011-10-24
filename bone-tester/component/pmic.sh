#!/bin/bash

set -x

# Important to Error Out on any errors
set -e

BONETESTER_DIR=/var/lib/bone-tester/
COMPONENT_DIR=${BONETESTER_DIR}/component/
LIB_DIR=${BONETESTER_DIR}/lib/

if [ $(yes 'Y' | i2cget 1 0x24 0 2>/dev/null) != "0x70" ] ; then
	echo "PMIC test failed"
	exit 1
fi

echo "PMIC test passed!"

