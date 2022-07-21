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

	 exit 0
}

Default() {
	echo
	echo "Writting to default location ~/.config/npm-globals.txt"
	npm ls --global > ~/.config/npm-globals.txt
	sed -i '1d' ~/.config/npm-globals.txt
	sed -i -e 's/[├── ]//g' ~/.config/npm-globals.txt
	sed -i -e 's/[└ ]//g' ~/.config/npm-globals.txt

	echo "Writting completed ~/.config/npm-globals.txt"
	echo

	echo "Add location argument."
	echo -e "example: npm-globals.sh ${RED}~/.config/npm-globals.txt${NC}"

	exit 0
}

Custom() {
	echo
	echo "Writting file to ${LOCATION}"

	npm ls --global > ${LOCATION}
	sed -i '1d' ${LOCATION}
	sed -i -e 's/[├── ]//g' ${LOCATION}
	sed -i -e 's/[└ ]//g' ${LOCATION}

	echo "Write completed ${LOCATION}"

	exit 0
}

Version() {
	echo
	echo "${NAME}: v${VERSION}"
	exit 0
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
