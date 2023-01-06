#!/bin/bash

##########################################
# Script Name:		test.sh
# Author:					pavel sanchez
# Email:					support@tasteink.me
# Description:		script for testing.
# args:						- none
##########################################

source colors.sh

NAME="$(basename $0)"

usage() {
	echo -e "\n${YELLOW}${NAME^} Help${NC}"
	echo -e "A file for building scripts."

	echo -e "\nSyntax: ${YELLOW}${NAME^}${NC} ${LIGHTRED}-[z|n|h|q]${NC}"

	echo -e "\n${DARKGRAY}Options:${NC}"
	echo -e "${LIGHTRED}-z${NC}     			install zsh."
	echo -e "${LIGHTRED}-n${NC}     			install nodejs."
	echo -e "${LIGHTRED}-h${NC}     			print software help."
	echo -e "${LIGHTRED}-q${NC}     			exit program."

	echo -e "\n${DARKGRAY}Examples:${NC}"
	echo -e "test.sh -zn		install zsh"
	echo -e "test.sh -h		print help\n"a
}

usage