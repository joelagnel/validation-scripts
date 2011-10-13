#!/bin/bash

SYSFS_DIR=/sys/class/leds

function sleep_for() {
	python -c "import time; time.sleep($1)"
}

function init_leds()
{
	for i in $(seq 0 3) ; do
		echo none > ${SYSFS_DIR}/beaglebone::usr$i/trigger
		turn_off $i
	done
}

function turn_on()
{
	echo 255 > ${SYSFS_DIR}/beaglebone::usr$1/brightness
}

function turn_off()
{
	echo 0 > ${SYSFS_DIR}/beaglebone::usr$1/brightness
}

function turn_on_all()
{
	for i in $(seq 0 3) ; do
		turn_on $i
	done
}

function flash_all()
{
	init_leds
	while [ 1 ] ; do
		sleep_for 0.5
		for i in $(seq 0 3) ; do
			turn_on $i
		done
		sleep_for 0.5
		for i in $(seq 0 3) ; do
			turn_off $i
		done
	done
}

function round_robin()
{
	init_leds
	if [ -z $1 ] ; then
		cur_led=0
	else
		cur_led=$1
	fi
	turn_off $(echo "(${cur_led}+3)%4" | bc)
	turn_on ${cur_led}
	next_led=$(echo "(${cur_led}+1)%4" | bc)
	sleep_for 0.3
	round_robin ${next_led}
}

function stop_led_function()
{
	killall leds.sh
}

$*
