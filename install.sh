#!/bin/bash

##########################################
# Script Name:		install.sh
# Author:					pavel sanchez
# Email:					support@tasteink.me
# Description:		dotfiles install
# args:						- none
##########################################

##########################################
######	VARIABLES
##########################################
NAME="$(basename $0)"
VERSION=$(node -p -e "require('./package.json').version")

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

export DOTFILES="$HOME/.config/dotfiles"

if [ "$VERBOSE" = "yes" ]; then set -x; STD=""; else STD="silent"; fi

silent() { "$@" > /dev/null 2>&1; }

##########################################
######	FUNCTIONS
##########################################
function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
}

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

usage() {
	header "${NAME^} v$VERSION Help"
	echo -e "A file for building scripts."

	echo -e "\nSyntax: ${YELLOW}${NAME^}${NC} ${LIGHTRED}-[i|h]${NC}"

	subHeader "Options:"
	echo -e "-i    			install dotfiles"
	echo -e "-h    			print software help."

	subHeader "Examples:"
	echo -e "${NAME^} -i		install dotfiles"
	echo -e "${NAME^} -h		print help"
	echo

	exit 1
}

dotfiles() {
	header "Downloading Dotfiles"
	# echo -e "${YELLOW}[-] Downloading Dotfiles [-]${NC}"
	sleep 0.2

	if [[ ! -d $DOTFILES ]]
	then
		git clone https://github.com/PaleBluDot/dotfiles.git $DOTFILES
	else
		msg_info "Repo already exists at $DOTFILES\n"
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
		".npmrc"
		".zshrc"
		".p10k.zsh"
		".profile"
	)

	for file in ${linkfiles[@]}; do
		install=~/$file

		if [[ ! -L $install ]]; then
			echo -e "~/$file 	=> ${GREEN}[INSTALLING]${NC}"
			ln -fs "${DOTFILES}/"$file $install
			sleep 0.5
		else
			echo -e "~/$file 	=> ${LIGHTRED}[SKIPPED]${NC}"
			sleep 0.2
		fi
	done

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

	sleep 0.2
	echo
	end=`date +%s`
	runtime=$((end-start))
}


##########################################
###### EXECUTE
##########################################
if [ $# -eq 0 ]; then
	>&2 usage
	exit 1
fi

# Get the options
while getopts ":iIhHqQ" option; do
  case $option in
		[i] | install)
			main
			;;
		[h] | help)
			usage
			;;
		\?)
			msg_error "Error: Invalid option"
			exit;;
  esac
done


