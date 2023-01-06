#!/bin/bash

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

p10k_setup() {
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

	sed -i 's/robbyrussell/powerlevel10k\/powerlevel10k/g' ~/.zshrc
}

zsh_setup
p10k_setup