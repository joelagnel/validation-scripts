#!/bin/bash

I2C_ADDR=$1
OFFSET=$2
COUNT=$3

EEPROM_SYSFS="/sys/bus/i2c/devices/1-00${I2C_ADDR}/eeprom";

hexdump -e '8/1 "%c"' $EEPROM_SYSFS -s $OFFSET -n $COUNT

