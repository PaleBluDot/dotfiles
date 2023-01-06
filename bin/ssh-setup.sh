#!/bin/bash

## 2. ssh
##################################################
# This section is ssh permission and settings.
##################################################
KEYS=$(
cat << EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII56HDlfpc6mLR77f1I4kafMU/7C6vdjCQaWbLx0J3QM Jupiter
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJJlsOk2uVoRpdmsdHQJKE7ESyMOQ7iH3Wk1+KKLztri surface
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKdKi1Mw5i0oZqYQAnDWP9UE58bqMYRuXptMpscVlhr Terminus
EOF
)

if [[ -s $HOME/.ssh/authorized_keys ]]
then
	echo -e "\nFile is not empty. Making a copy."
	echo -e "Cpying too: $HOME/.ssh/authorized_keys.old"
	cp $HOME/.ssh/authorized_keys $HOME/.ssh/old.authorized_keys
fi

echo -e "\n\n[-] Setting up SSH [-]"
echo $KEYS 1 | tee ~/.ssh/authorized_keys
echo "Sucess: Copied keys to $HOME/.ssh/authorized_keys"

echo -e "\n\n[-] Disabling password authentication [-]"
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

echo "Password login now disabled"
sudo systemctl restart ssh
echo "restating SSH service..."
sleep 1
echo "Sucess: serivce restarted"
echo
sleep 1