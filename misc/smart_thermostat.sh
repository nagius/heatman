#!/bin/bash

# smart_thermostat.sh - Wrapper for heating control via ESP8266 SmartThermostat
# Copyleft 2017 - Nicolas AGIUS <nicolas.agius@lps-it.fr>

###########################################################################
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
###########################################################################

# This is a wrapper script for the Heatman system to manage electrical heaters
# Available modes are : 
#   - on
#   - off
#   - eco

# See https://github.com/nagius/SmartThermostat for more details regarding
# the WiFi module used by this wrapper

# IP of the ESP8266 SmartThermostat
IP="192.168.1.3"
LOGIN=""
PASSWD=""
ECO=18
COMFORT=20
CURL_OPTS="--retry 3 --connect-timeout 3 -s"

function exit_with_error
{
	echo "Syntax: $0 on|off|eco|status" >&2
	exit 3
}


# Check parameters
[ $# -ne 1 ] && exit_with_error

# Add AuthBasic header
if [ -n "$LOGIN" -a -n "$PASSWD" ]; then
	CURL_OPTS="$CURL_OPTS -u $LOGIN:$PASSWD"
fi

case "$1" in
	on)
		curl $CURL_OPTS -X POST "http://$IP/state?mode=hysteresis&target=$COMFORT" >/dev/null
		;;
	eco)
		curl $CURL_OPTS -X POST "http://$IP/state?mode=hysteresis&target=$ECO" >/dev/null
		;;
	off)
		curl $CURL_OPTS -X POST "http://$IP/state?mode=off" >/dev/null
		;;
	status)
		OUTPUT=$(curl $CURL_OPTS "http://$IP/state")
		TARGET=$(echo $OUTPUT | jq .target)
		MODE=$(echo $OUTPUT | jq .mode | tr -d '"')

		if [ "$MODE" = "hysteresis" -a "$TARGET" = $COMFORT ]; then
			echo "on"
		elif [ "$MODE" = "hysteresis" -a "$TARGET" = $ECO ]; then
			echo "eco"
		elif [ "$MODE" = "off" ]; then
			echo "off"
		else
			echo "ERROR: unpredictable mode."
			exit 1
		fi
		
		;;
	*)
		exit_with_error
		;;
esac

# vim: ts=4:sw=4:ai:noet
