#!/bin/bash

NC='\033[0m'
BLACK='\033[0;30m'
LIGHTRED='\033[0;31m'
LIGHTGREEN='\033[0;32m'
LIGHTYELLOW='\033[0;33m'
LIGHTBLUE='\033[0;34m'
PINK='\033[0;35m'
LIGHTCYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'

DARKGRAY='\033[1;30m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'

CONTACT=support@tasteink.me
USER=$(whoami)
clear
echo

# cat << "EOF"
#                .
#   .uef^"      @88>
# :d88E         %8P
# `888E          .
#  888E .z8k   .@88u
#  888E~?888L ''888E`
#  888E  888E   888E
#  888E  888E   888E
#  888E  888E   888E
#  888E  888E   888&
# m888N= 888>   R888"
#  `Y"   888     ""
#       J88"
#       @%
#     :"
# EOF

figlet -f fraktur -S -w 90 hi!

# echo -e "${LIGHTCYAN} ---------------------------------------------------${NC}"
# echo
# echo -e "  Connections monitored and tracked!"
# if [[ -n "$ZSH_VERSION" ]]; then
#   echo -e "  Loaded ${LIGHTGREEN}~/.zhrc${NC}"
# else
#   echo -e "  Loaded ${LIGHTGREEN}~/.bashrc${NC}"
# fi
# echo -e "  Contact ${CYAN}${CONTACT}${NC}"
# echo -e "  Edit aliases: ${CYAN}edit${NC}"
# echo -e "  View all aliases: ${CYAN}alias${NC}"
# echo -e "  Date: $(dateF yyyymmdd -s -)"
# echo