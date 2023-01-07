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

export DOTFILES="$HOME/.config/dotfiles"

##########################################
######	FUNCTIONS
##########################################

dotfiles() {
	echo -e "${YELLOW}[-] Downloading Dotfiles [-]${NC}"

	if [[ ! -d $DOTFILES ]]
	then
		git clone https://github.com/PaleBluDot/dotfiles.git $DOTFILES
	else
		echo -e "Repo already exists at ${CYAN}$DOTFILES!${NC}\n"
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

ssh_setup() {
	echo -e "${YELLOW}[-] SSH Setup [-]${NC}"

	if [[ -s $HOME/.ssh/authorized_keys ]]
	then
		echo -e "${YELLOW}WARNING:${NC} ${CYAN}authorized_keys${NC} file is not empty. Making a copy."
		mv $HOME/.ssh/authorized_keys $HOME/.ssh/old.authorized_keys
		echo -e "${GREEN}SUCCESS:${NC} copied old files to ${CYAN}$HOME/.ssh/authorized_keys.old${NC}"
	fi

	ln -fs $DOTFILES/.config/authorized ~/.ssh/authorized_keys
	echo -e "${GREEN}SUCCESS:${NC} Copied keys to ${CYAN}$HOME/.ssh/authorized_keys${NC}"

	sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
	echo -e "${GREEN}SUCCESS:${NC} password was disabled."

	sudo systemctl restart ssh
	echo -e "${GREEN}SUCCESS:${NC} ssh service has been restarted."
	echo
}

install_packages() {
	PACKAGES=("zip" "fontconfig" "zsh-syntax-highlighting" "zsh-autosuggestions")

	for package in ${PACKAGES[@]}
	do
		echo -e "[-] Installing ${YELLOW}${package}${NC} [-]"
		sudo apt install $package -y &> /dev/null
		echo -e "$package was installed."
		echo
	done
}

zsh_install() {
	echo -e "[-] Installing ${YELLOW}ZSH${NC} [-]"

	echo "# Created by newuser for 5.8.1" >> ~/.zshrc

	sudo apt install zsh -y &> /dev/null \

	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

zsh_setup() {
	echo -e "[-] Setting up ${YELLOW}ZSH${NC} [-]"

	rm -rf $HOME/.zshrc
	ln -fs $HOME/.config/dotfiles/.zshrc ~/.zshrc
	rm -rf $HOME/.zshrc.pre-oh-my-zsh
	echo -e "${GREEN}SUCCESS:${NC} .zshrc configured."
	echo
}

p10k_setup() {
	echo -e "[-] Installing ${YELLOW}Powerlevel10k${NC} [-]"
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

	sed -i 's/robbyrussell/powerlevel10k\/powerlevel10k/g' ~/.zshrc

	echo -e '\nPOWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' >> ~/.zshrc

	ln -fs $DOTFILES/.p10k.zsh ~/.p10k.zsh
}

default_shell(){
	sudo chsh -s $(which zsh) $(whoami)
}

main() {
	# if [ ! "$EUID" -eq 0 ]
	# 	then echo "Please run as root"
	# 	exit
	# fi

	dotfiles
	ssh_setup
	install_packages
	zsh_install
	zsh_setup
	p10k_setup
	default_shell
}


##########################################
###### EXECUTE
##########################################
main

echo
echo -e "Completed ${YELLOW}${NAME}${NC} on ${CYAN}$(date +%c)${NC}"
zsh