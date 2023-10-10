#!/usr/bin/bash

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

export DOTFILES="~/.config/dotfiles"

if [ "$VERBOSE" = "yes" ]; then set -x; STD=""; else STD="silent"; fi

silent() { "$@" > /dev/null 2>&1; }

##########################################
######	FUNCTIONS
##########################################
function header() {
  local msg="$1"
	echo
  echo -e "${YELLOW}[-] ${msg} [-]${NC}"
}

function subHeader() {
  local msg="$1"
	echo
  echo -e "${CYAN}${msg}${NC}"
}

function msg_info() {
  local msg="$1"
  echo -e "${CYAN} ${INFO} ${msg}${NC}"
}

function msg_ok() {
  local msg="$1"
  echo -e "${GREEN} ${CM} ${msg} ${NC}"
}

function msg_error() {
  local msg="$1"
  echo -e "${LIGHTRED} ${CROSS} ${msg} ${NC}"
}

dotfiles() {
	header "Downloading Dotfiles"

	if [[ ! -d $DOTFILES ]]
	then
		git clone https://github.com/PaleBluDot/dotfiles.git $DOTFILES
	else
		msg_info "Repo already exists at $DOTFILES\n"
	fi

	if [[ ! -d ~/.ssh/ ]]
	then
		mkdir ~/.ssh
	fi

	header "Linking Dotfiles"
	msg_info "Checking if files are exist..."
	sleep 0.2
	echo

	linkfiles=(
		".aliases"
		".bashrc"
		".gitconfig"
		".nanorc"
		".profile"
		"bin/"
	)

	for file in ${linkfiles[@]}; do
		install=~/$file

		if [[ ! -L $install ]]; then
			msg_info "$file 	=> INSTALLING"
			ln -fs "${DOTFILES}/"$file $install
			sleep 0.3
			msg_ok "$file 	=> INSTALLED"
		else
			msg_error "$file 	=> SKIPPED"
			sleep 0.1
		fi
	done

	chmod +x ~/bin/*

	echo
	msg_ok "All files linked"
}

details() {
	header "Details"
	echo -e "Ended: ${CYAN}$(date +%c)${NC} "
	echo -e "Duration: ${CYAN}$runtime second(s)${NC}"
	echo
	msg_ok "Dotfiles installation complete"
	echo
}

main() {
	start=`date +%s`
	echo
	dotfiles
	details
	echo
	end=`date +%s`
	runtime=$((end-start))
}


##########################################
###### EXECUTE
##########################################
main
