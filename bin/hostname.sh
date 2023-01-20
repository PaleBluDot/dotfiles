#!/bin/bash

##################################################
# This section is for updating hostname.
##################################################
old_hn=$(hostname)
new_hn=$1
echo "Old hostname: $old_hn"
echo "Replacing $old_hn with $new_hn"
sed -i "s/$old_hn/$new_hn/g" /etc/hosts
hostnamectl set-hostname $new_hn
# hostnamectl set-hostname "${new_hn^}" --pretty
echo "Hostname is now: $(hostname)"
echo "Please reboot!"