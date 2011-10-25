#!/bin/bash

set -x
set -e

BONETESTER_DIR=/var/lib/bone-tester/
COMPONENT_DIR=${BONETESTER_DIR}/component/
LIB_DIR=${BONETESTER_DIR}/lib/
source ${LIB_DIR}/utils.sh

if [ "x$(yes 'Y' | i2cget 1 0x24 0 2>/dev/null)" != "x0x70" ] ; then
	bone_echo "PMIC test failed"
	exit 1
fi

bone_echo "PMIC test passed!"

