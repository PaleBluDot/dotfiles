#!/bin/bash

##########################################
# Script Name:		config.sh
# Author:					pavel sanchez
# Email:					support@tasteink.me
# Description:		copy personal config files
# args:						- none
##########################################

dotfiles() {
	dotfiles=$HOME/.config/dotfiles

	if [[ ! -d $dotfiles ]]
	then
		git clone https://github.com/PaleBluDot/dotfiles.git $dotfiles
	fi

	if [[ ! -d $HOME/.ssh/ ]]
	then
		mkdir $HOME/.ssh
	fi

	ln -fs $dotfiles/.config/authorized ~/.ssh/authorized_keys
	ln -fs $dotfiles/.config/npm-globals.txt ~/.config/npm-globals.txt


	ln -fs $dotfiles/.config/configstore/ ~/.config/configstore
	ln -fs $dotfiles/.vscode/ ~/.vscode
	ln -fs $dotfiles/bin/ ~/bin


	ln -fs $dotfiles/.aliases ~/.aliases
	ln -fs $dotfiles/.bashrc ~/.bashrc
	ln -fs $dotfiles/.gitconfig ~/.gitconfig
	ln -fs $dotfiles/.nanorc ~/.nanorc
	ln -fs $dotfiles/.npmrc ~/.npmrc
	ln -fs $dotfiles/.p10k.zsh ~/.p10k.zsh
	ln -fs $dotfiles/.zshrc ~/.zshrc
	echo "all config files linked"
	echo
}

dotfiles

echo
echo -e "Completed ${YELLOW}${NAME^}${NC} on ${CYAN}$(date +%c)${NC}"
