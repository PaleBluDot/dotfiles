#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
DARK_BLUE='\033[0;34m'
PINK='\033[0;35m'
BLUE='\033[0;36m'
NC='\033[0m'

echo
echo -e "${BLUE}--------------------------${NC}"
echo -e " ${YELLOW}Welcome ${USER}${NC}"
echo
echo -e " Loaded ${BLUE}~/.zhrc${NC}"
echo -e " Edit aliases: ${BLUE}edit${NC}"
echo -e " To refresh run: ${BLUE}fresh${NC}"
echo -e " View all aliases: ${BLUE}alias${NC}"
echo -e "${BLUE}--------------------------${NC}"
echo

echo
echo -e "Writing ${YELLOW}npm ls --globals${NC} to file..."
npm ls --global | grep "" | tr -d "├── " | tail -n +2 > ~/.config/npm-globals.txt
echo -e "Writing completed to ${YELLOW}~/.config/npm-globals.txt${NC}."
echo

# Doing a git pull to bring in
# any fresh changes.
REPO=$(git config --get remote.origin.url)
echo -e "Updating ${YELLOW}${REPO}${NC}..."
git pull
echo