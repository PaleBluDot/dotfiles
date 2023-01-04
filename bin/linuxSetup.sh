#!/bin/bash

########################
## 1. task 1
## 2. task 2
########################

source colors.sh

dotfiles=$HOME/.config/dotfiles

if [[ ! -d $dotfiles ]]
then
	git clone https://github.com/PaleBluDot/dotfiles.git $dotfiles
fi

if [[ ! -d $HOME/.ssh/ ]]
then
	mkdir $HOME/.ssh
fi

link_files() {
	ln -fs $HOME/.config/dotfiles/.config/authorized ~/.ssh/authorized_keys
	ln -fs $HOME/.config/dotfiles/.config/npm-globals.txt ~/.config/npm-globals.txt


	ln -fs $HOME/.config/dotfiles/.config/configstore/ ~/.config/configstore
	ln -fs $HOME/.config/dotfiles/.vscode/ ~/.vscode
	ln -fs $HOME/.config/dotfiles/bin/ ~/bin


	ln -fs $HOME/.config/dotfiles/.aliases ~/.aliases
	ln -fs $HOME/.config/dotfiles/.bashrc ~/.bashrc
	ln -fs $HOME/.config/dotfiles/.gitconfig ~/.gitconfig
	ln -fs $HOME/.config/dotfiles/.nanorc ~/.nanorc
	ln -fs $HOME/.config/dotfiles/.npmrc ~/.npmrc
	ln -fs $HOME/.config/dotfiles/.p10k.zsh ~/.p10k.zsh
	ln -fs $HOME/.config/dotfiles/.zshrc ~/.zshrc
	echo "all config files linked"
}

link_files

echo
echo "Completed on $(date +%c)"