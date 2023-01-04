#!/bin/bash

########################
## 1. task 1
## 2. task 2
########################

source colors.sh

PACKAGES=(zsh zip unzip fontconfig)
SERVICES=(zsh zip unzip fc-list)
FILENAME=$0
NAME="$(basename $FILENAME)"

if [ ! "$EUID" -eq 0 ]
  then echo "Please run as root"
  exit
fi

for package in zsh zip unzip fc-list
do
	if ! command -v $SERVICES &> /dev/null
	then
		echo -e "[-] Installing ${YELLOW}${package}${NC} [-]"
		apt install $package -y
		echo
		echo -e "$package installed on ${CYAN}$(date +%c)${NC}"
		echo
	else
		echo -e "${YELLOW}${package}${NC} already install"
	fi
done

echo
echo -e "Completed ${YELLOW}${NAME^}${NC} on ${CYAN}$(date +%c)${NC}"