#!/bin/bash

function exit_with_error
{
	echo "Syntax: $0 on|off|eco|status" >&2
	exit 3
}

# Check parameters
[ $# -ne 1 ] && exit_with_error


case "$1" in
	on)
		echo "on"
		;;
	off)
		echo "off"
		;;
	eco)
		echo "eco"
		;;
	status)
		echo "on"
		;;
	*)
		exit_with_error
		;;
esac

# vim: ts=4:sw=4:ai:noet
