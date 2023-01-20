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
sudo sed -i "s/$old_hn/$new_hn/g" /etc/hosts
sudo hostnamectl set-hostname $new_hn
sudo hostnamectl set-hostname "${new_hn^}" --pretty

echo "Hostname is now: $(hostname)"

echo "Please reboot!"