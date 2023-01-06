#!/bin/bash

## 1. update hostname
##################################################
# This section is for system, user, and
# group settings.
##################################################
read -p "Do you want change hostname? (y/n) " yn

case $yn in
	[yY] )
		read -p "Enter hostname? " test
		sudo hostnamectl set-hostname $test
		echo "hostname is now $(hostname)"
		;;
	[nN] )
		echo "Skipping step";
		;;
	* )
		echo "invalid response";
		exit 1;;
esac