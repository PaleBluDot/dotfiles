#!/bin/bash

echo
echo -e "Writing ${YELLOW}npm ls --globals${NC} to file..."
npm ls --global | grep "" | tr -d "├── " | tail -n +2 > ~/.config/npm-globals.txt
echo -e "Writing completed to ${YELLOW}~/.config/npm-globals.txt${NC}."
echo