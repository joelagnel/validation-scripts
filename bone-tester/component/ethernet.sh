#!/bin/bash

# Important to Error Out on any errors
set -e

HOST_DEV=eth0
HOST_IP="192.168.100.1"

HUB_DEV=eth1
HUB_IP="192.168.100.2"

HOST_RX_PACKETS=/sys/class/net/eth0/statistics/rx_packets
HUB_RX_PACKETS=/sys/class/net/eth1/statistics/rx_packets

PING_INTERVAL=1
PING_COUNT=10

# Load kernel modules
# Load required kernel modules for test purposes
# This will go away once PSP fixes the OTG host-mode issue.

echo "Loading USB kernel modules.."
if [ "x$(lsmod | grep g_zero)" = "x" ] ; then
	modprobe g_zero
	echo "Loaded g_zero"
	sleep 5		# Wait for the kernel to do its job of detecting the interfaces, registering drivers etc.
fi

ifconfig ${HOST_DEV} ${HOST_IP} up
ifconfig ${HUB_DEV} ${HUB_IP} up

old_rx=$(cat ${HOST_RX_PACKETS})

ping -b -I ${HUB_DEV} -i ${PING_INTERVAL} 255.255.255.0 -c ${PING_COUNT} || true

new_rx=$(cat ${HOST_RX_PACKETS})

total_rx=$(echo "${new_rx}-${old_rx}" | bc)

deviation=$(echo "${PING_COUNT}-${total_rx}" | bc)

if [ ${deviation} -gt 2 ] ; then
	echo "Packet loss encountered, ethernet test fail."
	exit 1
fi

echo "Ethernet test passed!"

