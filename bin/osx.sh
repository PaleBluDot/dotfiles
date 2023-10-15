#!/bin/bash

##########################################
# Script Name:		linuxSetup.sh
# Author:					pavel sanchez
# Email:					support@tasteink.me
# Description:		linux setup
# args:						- none
##########################################

##########################################
######	VARIABLES
##########################################

NAME="$(basename $0)"

YELLOW='\033[1;33m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
LIGHTRED='\033[0;31m'
LIGHTGREEN='\033[0;32m'
LIGHTYELLOW='\033[0;33m'
NC='\033[0m'

export DOTFILES="$HOME/Github/PaleBluDot/dotfiles"

##########################################
######	FUNCTIONS
##########################################

dotfiles() {
	echo -e "${YELLOW}[-] Downloading Dotfiles [-]${NC}"

	if [[ ! -d $DOTFILES ]]
	then
		mkdir -p ~/Github/PaleBluDot/
		git clone https://github.com/PaleBluDot/dotfiles.git $DOTFILES
	else
		echo -e "Repo already exists at ${CYAN}$DOTFILES!${NC}\n"
	fi

	if [[ ! -d $HOME/.ssh/ ]]
	then
		mkdir -p $HOME/.ssh
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

	echo -e "\n${YELLOW}[-] Linking Dotfiles [-]${NC}"
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

install_packages() {
	PACKAGES=("node" "fontconfig" "gh")

	echo -e "[-] Installing ${YELLOW}${package}${NC} [-]"
	brew install node &> /dev/null
	brew install gh &> /dev/null
	brew install fontconfig &> /dev/null

	if ! command -v ${package[@]} &> /dev/null
	then
		echo -e "$package was not installed."
		echo
	else
		echo -e "$package was installed."
		echo
	fi
}

zsh_setup() {
	echo -e "[-] Setting up ${YELLOW}ZSH${NC} [-]"

	rm -rf $DOTFILES/.zshrc
	ln -fs $DOTFILES/.zshrc ~/.zshrc
	rm -rf $DOTFILES/.zshrc.pre-oh-my-zsh

	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions &> /dev/null

	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting &> /dev/null

	echo -e "${GREEN}SUCCESS:${NC} .zshrc configured."
	echo
}

p10k_setup() {
	echo -e "[-] Installing ${YELLOW}Powerlevel10k${NC} [-]"
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k &> /dev/null

	sed -i 's/robbyrussell/powerlevel10k\/powerlevel10k/g' ~/.zshrc

	echo -e '\nPOWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' >> ~/.zshrc

	ln -fs $DOTFILES/.p10k.zsh ~/.p10k.zsh
	echo -e "${GREEN}SUCCESS:${NC} .p10k.zsh configured."
	echo
}

##########################################
###### EXECUTE
##########################################
main() {
	dotfiles
	install_packages
	zsh_setup
	p10k_setup
}

main

echo
echo -e "Completed ${YELLOW}${NAME}${NC} on ${CYAN}$(date +%c)${NC}"
zsh