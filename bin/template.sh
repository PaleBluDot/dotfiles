#!/bin/bash

##########################################
# Script Name:		test.sh
# Author:					pavel sanchez
# Email:					support@tasteink.me
# Description:		script for testing.
# args:						- none
##########################################

source colors.sh

NAME="$(basename $0)"

usage() {
	echo -e "\n${YELLOW}${NAME^} Help${NC}"
	echo -e "A file for building scripts."

	echo -e "\nSyntax: ${YELLOW}${NAME^}${NC} ${LIGHTRED}-[z|n|h|q]${NC}"

	echo -e "\n${DARKGRAY}Options:${NC}"
	echo -e "${LIGHTRED}-z${NC}     			install zsh."
	echo -e "${LIGHTRED}-n${NC}     			install nodejs."
	echo -e "${LIGHTRED}-h${NC}     			print software help."
	echo -e "${LIGHTRED}-q${NC}     			exit program."

	echo -e "\n${DARKGRAY}Examples:${NC}"
	echo -e "test.sh -zn		install zsh"
	echo -e "test.sh -h		print help\n"a
}

zsh_setup() {
	echo -e "[-] Installing ${YELLOW}ZSH${NC} [-]"
	# set up script
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

	# set zsh as default shell
	chsh -s $(which zsh) $(whoami)

	# remove default .zshrc and link
	# my personal .zshrc
	rm -rf $HOME/.zshrc
	ln -fs $dotfiles/.zshrc ~/.zshrc
	source ~/.zshrc
}

node_setup() {
	echo -e "[-] Installing ${YELLOW}NodeJS${NC} [-]"
	# set up script
	curl -fsSL https://deb.nodesource.com/setup_19.x | sudo -E bash -
	# install nodejs
	apt install nodejs -y
}

# read -p "Which would you like to install? (z/n/q)" znq

# Get the options
while getopts ":zZnNhHqQ" option; do
  case $option in
		[zZ] | zsh)
			zsh_setup
			;;
		[nN] | node)
			node_setup
			;;
		[hH] | help)
			usage
			exit;;
		[qQ] | quit)
			echo "quit installation"
			exit;;
		\?)
			echo "Error: Invalid option"
			exit;;
  esac
done

echo
echo -e "Completed ${YELLOW}${NAME^}${NC} on ${CYAN}$(date +%c)${NC}"
