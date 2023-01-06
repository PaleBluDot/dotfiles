#!/bin/bash

node_setup() {
	echo -e "[-] Installing ${YELLOW}NodeJS${NC} [-]"
	# set up script
	curl -fsSL https://deb.nodesource.com/setup_19.x | sudo -E bash -
	# install nodejs
	apt install nodejs -y
}

node_setup