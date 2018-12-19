#!/bin/bash 

# This script is design to pair with SerialOregon.ino
# It will read on the serial port where the Arduino is plugged in and 
# will parse its json output to write the result in a key-value format
# readable by bash.

PORT="/dev/ttyS1"
SPEED="9600"
DIR="/run/shm/oregon"

stty -F $PORT $SPEED

while read -r LINE; do
	CHANNEL=$(echo "$LINE" | jq -r .channel)
	TEMP=$(echo "$LINE" | jq -r .temp)
	HUM=$(echo "$LINE" | jq -r .hum)
	if [ -n "$CHANNEL" -a -n "$TEMP" -a -n "$HUM" ]; then
		cat <<- EOF >$DIR/channel$CHANNEL
			TS=$(date +%s)
			TEMP=$TEMP
			HUM=$HUM
		EOF
	fi
done < $PORT

# vim: ts=4:sw=4:ai
