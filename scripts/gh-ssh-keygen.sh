#!/bin/bash

##################################################
#
# Github API SSH Key
# Small script for adding SSH key using the
# API when setting up a new install script.
# Created by @PaleBluDot.
#
# Original code from from @jaunique.
# https://gist.github.com/juanique/4092969
# The code below has been modified to use
# the newer Github standards.
#
##################################################

# Reading the user input for the Github
# email and outputting the email to the console.
read -p "Enter github email : " email

# Generate SSH key to the default folder
# ~/.ssh. All questions will be skipped.
# Once the key has been added it will add
# the key and display the public key.
read -p "Enter SSH key name : " sshkey
ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/${sshkey} -N '' <<<$'\n'

# eval `ssh-agent -s`
ssh-add ~/.ssh/${sshkey}
pub=`cat ~/.ssh/${sshkey}.pub`

# Reading the user input for the Github
# email and outputting the email to the console.
read -p "Enter github username: " githubuser

# Reading the user input for the Github
# password. The password will remain invisible.
read -s -p "Enter github password for user $githubuser: " githubpass
echo

# Use the Curl command to send the
# data over Github API. You will get back
# the status of the API request.
echo
curl -u "$githubuser:$githubpass" -X POST -d "{\"title\":\"$sshkey\",\"key\":\"$pub\"}" https://api.github.com/user/keys

# Display message when API key has been finished.
echo
echo "SSH Key has been uploaded to Github!"