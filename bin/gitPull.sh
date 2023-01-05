#!/bin/bash

if [ -d .git ] &> /dev/null
then
	REPO=$(git config --get remote.origin.url)
	echo -e "Updating ${YELLOW}${REPO}${NC}..."
	git pull
	echo
fi