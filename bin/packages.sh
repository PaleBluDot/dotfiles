#!/bin/bash

install_packages() {
	PACKAGES=("zsh" "zip" "fontconfig")
	SERVICES=("zsh" "zip" "fc-list")
	FILENAME=$0
	NAME="$(basename $FILENAME)"
	LOCATION=$(command -v ${SERVICES[@]})

	if [ ! "$EUID" -eq 0 ]
		then echo "Please run as root"
		exit
	fi

	for package in ${PACKAGES[@]}
	do
		if ! command -v ${package[@]} &> /dev/null
		then
			echo -e "[-] Installing ${YELLOW}${package}${NC} [-]"
			apt install $package -y &> /dev/null
			echo -e "$package was installed."
			echo
		else
			echo -e "${YELLOW}${package}${NC} is already install."
		fi
	done
}

install_packages

echo
echo -e "Completed ${YELLOW}${NAME^}${NC} on ${CYAN}$(date +%c)${NC}"