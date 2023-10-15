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

echo
echo -e "${LIGHTRED}######################################################${NC}"
echo -e "  ${YELLOW}_  _  ____  __     ___  __   _  _  ____${NC}"
echo -e " ${YELLOW}/ )( \(  __)(  )   / __)/  \ ( \/ )(  __)${NC}"
echo -e " ${YELLOW}\ /\ / ) _) / (_/\( (__(  O )/ \/ \ ) _)${NC}"
echo -e " ${YELLOW}(_/\_)(____)\____/ \___)\__/ \_)(_/(____)${NC} ${LIGHTRED}${USER}${NC}"
echo
echo -e "${LIGHTCYAN}---------------------------------------------------${NC}"
echo
echo -e "  Connections monitored and tracked!"
if [[ -n "$ZSH_VERSION" ]]; then
  echo -e "  Loaded ${LIGHTGREEN}~/.zhrc${NC}"
else
  echo -e "  Loaded ${LIGHTGREEN}~/.bashrc${NC}"
fi
echo -e "  Contact ${CYAN}${CONTACT}${NC}"
echo
echo -e "${LIGHTRED}#####################################################${NC}"
echo



# echo -e "${YELLOW}"
# cat << EOF
#     @@@@@@@@@@@
#   @@@@@@@@@@@@@@@@
#   @@@@@      @@@@@@@@@@@@@@@
#   @@@@@       @@@@@@@@@@@@@@@@@
#   @@@@@@@@@@@@@@@@@      @@@@@
#   @@@@@@@@@@@@@@@@@@@@
#   @@@@@         @@@@@@@@@@@@@@
#   @@@@@                @@@@@@@@@
#   @@@@@       @@@@@        @@@@
#                @@@@@@@@@@@@@@
#                  @@@@@@@@@
# EOF
# echo
# echo -e "---------------------------------${NC}"


# echo
# echo -e " ${YELLOW}${USER}${NC} is on ${YELLOW}$(hostname)${NC}"
# echo
# if [[ -n "$ZSH_VERSION" ]]
# then
# 	echo -e " Loaded ${BLUE}~/.zhrc${NC}"
# else
# 	echo -e " Loaded ${BLUE}~/.bashrc${NC}"
# fi
# echo -e " Edit aliases: ${BLUE}edit${NC}"
# echo -e " To refresh run: ${BLUE}fresh${NC}"
# echo -e " View all aliases: ${BLUE}alias${NC}"
# echo
