#!/bin/bash

# boiler.sh - Wrapper for water-boiler control system via GPIO
# Copyleft 2014 - Nicolas AGIUS <nicolas.agius@lps-it.fr>

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

# This is a wrapper script for the Heatman system to manage electrical water heaters.
# Available mode are : 
#   - on
#   - off

# This script use Raspberry Pi's GPIO output to switch relays sending 230V to the boiler.
#
#                     =5V                          ~230V
#                     VCC                           VAC
#                      +                             +
#                      |                             |
#                      |             .---------------o
#                      |             |               |
#   GPIO 22  ___     |/              o               o
#       ----|___|----|               (   FUSE        (   FUSE
#                    |>               )  2A           )  25A
#                      |             o               o
#                      |             |               |
#                      |             |               |
#                      o--------.    |              .-. 
#                      |        |    |             ( X ) Boiler
#                      -       _|_   o  /           '-'
#                      ^      |_/_|-   /             |
#                      |        |     /              |
#                      |        |    o               |
#                      o--------'    |               |
#                      |              ----------.    |    
#                      |                       _|_   o  /   
#                      |                      |_/_|-   /    Max 250V 25A 
#                      |                        |     /     Legrand 412501
#                      |                        |    o
#                      |                        |    |
#                      |                        '----o
#                      |                             |
#                     ===                           ===
#                     GND                        AC Neutral

# Select which GPIO port to use
GPIO=22

# Internal variables
GPIO_PATH="/sys/class/gpio"
GPIO_FILE="$GPIO_PATH/gpio$GPIO/value"

function exit_with_error
{
	echo "Syntax: $0 on|off|eco|status" >&2
	exit 3
}

function enable_gpio_port
{
	# Check if machine is GPIO enabled
	if [ ! -d $GPIO_PATH ]; then
		echo "ERROR: GPIO not available."
		exit 1
	fi

	# Configure GPIO port as output
	if [ ! -e $GPIO_PATH/gpio$1/value ]; then
		echo $1 >$GPIO_PATH/export
		echo "out" > $GPIO_PATH/gpio$1/direction
	fi
}


# Check parameters
[ $# -ne 1 ] && exit_with_error

# Configure GPIO
enable_gpio_port $GPIO


case "$1" in
	on)
		echo 1 >$GPIO_FILE
		;;
	off)
		echo 0 >$GPIO_FILE
		;;
	status)
		if [ "$(cat $GPIO_FILE)" -eq 1 ]; then
			echo "on"
		elif [ "$(cat $GPIO_FILE)" -eq 0 ]; then
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
