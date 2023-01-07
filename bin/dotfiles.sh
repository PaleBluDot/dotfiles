#!/bin/bash

##########################################
# Script Name:		dotfiles.sh
# Author:					pavel sanchez
# Email:					support@tasteink.me
# Description:		insatlling dotfiles
# args:						- none
##########################################

##########################################
######	VARIABLES
##########################################

NAME="$(basename $0)"

export DOTFILES="$HOME/.config/dotfiles"

##########################################
######	FUNCTIONS
##########################################

dotfiles() {
	echo -e "${YELLOW}[-] Downloading Dotfiles [-]${NC}"

	if [[ ! -d $DOTFILES ]]
	then
		git clone https://github.com/PaleBluDot/dotfiles.git $DOTFILES
	fi

	if [[ ! -d $HOME/.ssh/ ]]
	then
		mkdir $HOME/.ssh
	fi

	ln -fs $DOTFILES/.config/npm-globals.txt ~/.config/npm-globals.txt
	ln -fs $DOTFILES/.config/configstore/cspell.json ~/.config/cspell.json
	ln -fs $DOTFILES/.vscode/ ~/.vscode
	ln -fs $DOTFILES/bin/ ~/bin

	ln -fs $DOTFILES/.aliases ~/.aliases
	ln -fs $DOTFILES/.bashrc ~/.bashrc
	ln -fs $DOTFILES/.gitconfig ~/.gitconfig
	ln -fs $DOTFILES/.nanorc ~/.nanorc
	ln -fs $DOTFILES/.npmrc ~/.npmrc

	echo -e "${YELLOW}[-] Linking Dotfiles [-]${NC}"
cat << EOF
.aliases ---> 		~/.aliases
.bashrc ---> 		~/.bashrc
.gitconfig ---> 	~/.gitconfig
.nanorc ---> 		~/.nanorc
.npmrc ---> 		~/.npmrc
.vscode/ ---> 		~/.vscode
bin/ ---> 		~/bin
cspell.json ---> 	~/.config/cspell.json
npm-globals.txt ---> 	~/.config/npm-globals.txt
EOF

	chmod +x ~/bin/*

	echo "all config files linked"
	echo
}

main() {
	dotfiles
}


##########################################
###### EXECUTE
##########################################
main

echo
echo -e "Completed ${YELLOW}${NAME}${NC} on ${CYAN}$(date +%c)${NC}"