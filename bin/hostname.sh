#!/bin/bash

## 1. update hostname
##################################################
# This section is for system, user, and
# group settings.
##################################################
old_hn=$(hostname)
echo "Old hostname: $old_hn"
read -p "Enter hostname? " new_hn

echo "Replacing $old_hn with $new_hn"
sed -i "s/$old_hn/$new_hn/g" /etc/hosts
hostnamectl set-hostname $new_hn
hostnamectl set-hostname "${new_hn^}" --pretty

echo "Hostname is now: $(hostname)"

echo "Please reboot!"