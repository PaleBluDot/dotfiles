#!/bin/bash

RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

LOCATION=$1
VERSION=1.0.2
NAME="NPM Globals"
DESCRIPTION="This script pull all global NPM installed packages and writes it to a local text file. Local file is used on a build script on new installs."

Help() {
	# Display Help
	echo
	echo "${NAME}: v$VERSION"
	echo "${DESCRIPTION}"
	echo
	echo "Syntax: npm-globals.sh [-h|v]"
	echo "options:"
	echo "h     Print this Help."
	echo "v     Print software version and exit."
}

Default() {
	echo
	echo "Writing to default location ~/.config/npm-globals.txt"
	echo "Add location argument."
	echo -e "example: npm-globals.sh ${RED}~/.config/npm-globals.txt${NC}"
	echo

	npm ls --global | grep "" | tr -d "├── " | tail -n +2 | tee ~/.config/npm-globals.txt

	echo
	echo "Writing completed ~/.config/npm-globals.txt"
	echo
}

Custom() {
	echo
	echo "Writing file to ${LOCATION}"
	echo

	npm ls --global | grep "" | tr -d "├── " | tail -n +2 | tee ./${LOCATION}

	echo
	echo "Write completed ${LOCATION}"
	echo
}

Version() {
	echo
	echo "${NAME}: v${VERSION}"
}

if [ -z "$1" ]; then
	Default
elif [ "$1" == "help" ]; then
	Help
elif [ "$1" == "-h" ]; then
	Help
elif [ "$1" == "-v" ]; then
	Version
else
	Custom
fi
