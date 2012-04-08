#!/bin/bash

set -x
set -e

BONETESTER_DIR=/var/lib/bone-tester/
COMPONENT_DIR=${BONETESTER_DIR}/component/
LIB_DIR=${BONETESTER_DIR}/lib/
source ${LIB_DIR}/utils.sh

# 0x70 on old chips or 0xf1 on newer
PMIC="$(i2cget -f -y 1 0x24 0 2>/dev/null)"
pmicdetected=0

if [ $PMIC = "0x70" ] ; then
	pmicdetected=1
fi

if [ $PMIC = "0xf1" ] ; then
	pmicdetected=1
fi

if [ $pmicdetected = "1" ] ; then
	bone_echo "PMIC test passed!"
else
	bone_echo "PMIC test failed, returned unknow value: $PMIC"
fi

