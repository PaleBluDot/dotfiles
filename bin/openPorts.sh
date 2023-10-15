#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Open Port
# @raycast.mode fullOutput
# @raycast.packageName Networking
#
# Optional parameters:
# @raycast.icon 🤖
# @raycast.currentDirectoryPath ~
# @raycast.needsConfirmation false
#
# Documentation:
# @raycast.description Write a nice and descriptive summary about your script command here
# @raycast.author Pavel Sanchez
# @raycast.authorURL https://github.com/palebludot/dotfiles

sudo netstat -tulpn | grep LISTEN
