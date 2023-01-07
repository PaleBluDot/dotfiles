#!/bin/bash

source colors.sh

echo -e "${BLUE}-------------------------------------------------------${NC}"
echo -e " ${RED}__      __       .__                               ";
echo -e "/  \    /  \ ____ |  |   ____  ____   _____   ____  ";
echo -e "\   \/\/   // __ \|  | _/ ___\/  _ \ /     \_/ __ \ ";
echo -e " \        /\  ___/|  |_\  \__(  <_> )  Y Y  \  ___/ ";
echo -e "  \__/\  /  \___  >____/\___  >____/|__|_|  /\___  >";
echo -e "       \/       \/          \/            \/     \/ ${NC}";

echo -e "${BLUE}-------------------------------------------------------${NC}"

echo
echo -e " ${YELLOW}${USER}${NC} is on ${YELLOW}$(hostname)${NC}"
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
echo

source gitPull.sh