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

RETRY_NUM=2
RETRY_EVERY=3
INFO="${GN}${CL}"
CM="${GN}${CL}"
CROSS="${RD}${CL}"
BFR="\\r\\033[K"
HOLD="-"

YELLOW='\033[1;33m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
LIGHTRED='\033[0;31m'
LIGHTGREEN='\033[0;32m'
LIGHTYELLOW='\033[0;33m'
NC='\033[0m'

set -a
export DOTFILES="$HOME/.config/dotfiles"
set +a

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
		msg_info "Repo already exists at $DOTFILES"
	fi

	if [[ ! -d $HOME/.ssh/ ]]
	then
		mkdir $HOME/.ssh
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
	)

	for file in ${linkfiles[@]}; do
		install=$HOME/$file

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

	msg_info "${DOTFILES}/bin/* 	=> INSTALLING"
	ln -fs "${DOTFILES}/bin/*" $HOME
	chmod +x $HOME/bin/*
	sleep 0.5
	msg_ok "$HOME/bin/* 	=> INSTALLED"

	echo
	msg_ok "All files linked"
}

details() {
	runtime=$((end-start))
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
	echo
	end=`date +%s`
	details
}


##########################################
###### EXECUTE
##########################################
main
