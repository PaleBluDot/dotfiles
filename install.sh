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
error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
}

header() {
  local msg="$1"
	echo
  echo -e "${YELLOW}[-] ${msg} [-]${NC}"
}

subHeader() {
  local msg="$1"
  echo -e "${CYAN}${msg}${NC}"
}

msg_info() {
  local msg="$1"
  echo -e "${CYAN} ${INFO} ${msg}${NC}"
}

msg_ok() {
  local msg="$1"
  echo -e "${GREEN} ${CM} ${msg} ${NC}"
}

msg_error() {
  local msg="$1"
  echo -e "${LIGHTRED} ${CROSS} ${msg} ${NC}"
}

# Checks if a given package is installed
command_exists () {
  command -v "$1" 1> /dev/null
}

# On error, displays death banner, and terminates app with exit code 1
terminate () {
  make_banner "Installation failed. Terminating..." ${RED_B}
  exit 1
}

# Checks if command / package (in $1) exists and then shows
# either shows a warning or error, depending if package required ($2)
system_verify () {
  if ! command_exists $1; then
    if $2; then
      echo -e "🚫 ${RED_B}Error:${PLAIN_B} $1 is not installed${RESET}"
      terminate
    else
      echo -e "⚠️  ${YELLOW_B}Warning:${PLAIN_B} $1 is not installed${RESET}"
    fi
  fi
}

usage() {
	header "Dotfiles Install Help"
	echo -e "Install script for dotfiles repository!"
	subHeader "version: ${VERSION}"

	echo -e "\nSyntax: ${YELLOW}${NAME}${NC} ${LIGHTRED}-[i|h]${NC}\n"

	subHeader "Options:"
	echo -e "-i    			install dotfiles"
	echo -e "-h    			print software help."
	echo

	subHeader "Examples:"
	echo -e "${NAME} -i		install dotfiles"
	echo -e "${NAME} -h		print help"
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

	if ! command_exists "yq"; then
		msg_error "Command missing..."
	fi

	SYMLINKS=$(yq eval '.links.*.install' symlinks.yml)
	INSTALL_LOC=$(yq eval '.links.*.install' symlinks.yml)
	SOURCE_LOC=$(yq eval '.links.*.source' symlinks.yml)

	for file in ${SYMLINKS[@]}; do
		source="$DOTFILES/$SOURCE_LOC"
		install="$HOME/$INSTALL_LOC"

		if [[ ! -L $install ]]; then
			msg_info "$file	=> $(msg_ok "INSTALLING")"
			echo
			echo -e "symlink:\n$source $install"
			echo
			ln -fs $source $install
			sleep 0.2
			msg_ok "Completed:\n$install"
		else
			msg_info "$file 	=> $(msg_error "SKIPPED")"
			sleep 0.2
		fi
	done

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
	>&2 main
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


