#!/bin/bash


## 8. install powerline theme
##################################################
# This section is git powerline
##################################################
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

sed -i 's/robbyrussell/powerlevel10k\/powerlevel10k/g' ~/.zshrc

echo
echo "Completed on $(date +%c)"
