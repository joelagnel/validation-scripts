#!/bin/bash

BONETESTER_DIR=/var/lib/bone-tester/
COMPONENT_DIR=${BONETESTER_DIR}/component/
LIB_DIR=${BONETESTER_DIR}/lib/

source ${LIB_DIR}/utils.sh

set -x

# Important to Error Out on any errors
set -e

HOST_DEV=$(get_iface_name plat)
HOST_IP="192.168.100.1"

if [ "x${HOST_DEV}" = "x" ] ; then
	echo "Board ethernet device not found!"
	exit 1
fi

HUB_DEV=$(get_iface_name usb)
HUB_IP="192.168.100.2"

if [ "x${HUB_DEV}" = "x" ] ; then
	echo "Hub ethernet device not found!"
	exit 1
fi

HOST_RX_PACKETS=/sys/class/net/${HOST_DEV}/statistics/rx_packets
HUB_RX_PACKETS=/sys/class/net/${HUB_DEV}/statistics/rx_packets

PING_INTERVAL=1
PING_COUNT=10

ifconfig ${HOST_DEV} ${HOST_IP} up
ifconfig ${HUB_DEV} ${HUB_IP} up

old_rx=$(cat ${HOST_RX_PACKETS})

ping -b -I ${HUB_DEV} -i ${PING_INTERVAL} 255.255.255.0 -c ${PING_COUNT} || true

new_rx=$(cat ${HOST_RX_PACKETS})

total_rx=$(echo "${new_rx}-${old_rx}" | bc)

deviation=$(echo "${PING_COUNT}-${total_rx}" | bc)

if [ ${deviation} -gt 2 ] ; then
	bone_echo "Packet loss encountered, ethernet test fail."
	exit 1
fi

bone_echo "Ethernet test passed!"

