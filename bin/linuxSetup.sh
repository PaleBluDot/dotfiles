#!/bin/bash

########################
## 1. task 1
## 2. task 2
########################

source ~/bin/colors.sh

link_files() {
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

link_files
install_packages

echo
echo -e "Completed ${YELLOW}${NAME^}${NC} on ${CYAN}$(date +%c)${NC}"
