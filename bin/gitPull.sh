#!/bin/bash

REPO=$(git config --get remote.origin.url)
echo -e "Updating ${YELLOW}${REPO}${NC}..."
git pull
echo