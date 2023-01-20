#!/bin/bash

## 1. update hostname
##################################################
# This section is for system, user, and
# group settings.
##################################################
read -p "Do you want change hostname? (y/n) " yn

case $yn in
	[yY] )
		old_hn=$(hostname)
		echo "Old hostname: $old_hn"
		read -p "Enter hostname? " new_hn

		sudo sed -i "s/$old_hn/$new_hn/g" /etc/hosts
		sudo hostnamectl set-hostname $new_hn
		sudo hostnamectl set-hostname "${new_hn^}" --pretty

		echo "Hostname is now:  $(hostname)"
		echo "/etc/host is now: $(cat /etc/hosts | grep $new_hn)"

		echo "please reboot"
		;;
	[nN] )
		echo "Exiting....";
		exit 0;;
	* )
		echo "invalid response";
		exit 1;;
esac