#!/bin/bash

set -x
set -e

BONETESTER_DIR=/var/lib/bone-tester/
COMPONENT_DIR=${BONETESTER_DIR}/component/
LIB_DIR=${BONETESTER_DIR}/lib/
source ${LIB_DIR}/utils.sh

memtester 1M 1

echo "Memory tests passed."
