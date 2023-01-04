#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
DARK_BLUE='\033[0;34m'
PINK='\033[0;35m'
BLUE='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}-------------------------------------------------------${NC}"
echo -e " ${RED}__      __       .__                               ";
echo -e "/  \    /  \ ____ |  |   ____  ____   _____   ____  ";
echo -e "\   \/\/   // __ \|  | _/ ___\/  _ \ /     \_/ __ \ ";
echo -e " \        /\  ___/|  |_\  \__(  <_> )  Y Y  \  ___/ ";
echo -e "  \__/\  /  \___  >____/\___  >____/|__|_|  /\___  >";
echo -e "       \/       \/          \/            \/     \/ ${NC}";

echo -e "${BLUE}-------------------------------------------------------${NC}"

echo -e " ${YELLOW}${USER}${NC} is on ${YELLOW}${HOSTNAME}${NC}"
echo
if [[ -n "$ZSH_VERSION" ]]
then
	echo -e " Loaded ${BLUE}~/.zhrc${NC}"
else
	echo -e " Loaded ${BLUE}~/.bashrc${NC}"
fi
echo -e " Edit aliases: ${BLUE}edit${NC}"
echo -e " To refresh run: ${BLUE}fresh${NC}"
echo -e " View all aliases: ${BLUE}alias${NC}"

echo -e "${BLUE}-------------------------------------------------------${NC}"
echo

source gitPull.sh