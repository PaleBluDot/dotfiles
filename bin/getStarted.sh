#!/bin/bash

## 1. update hostname
##################################################
# This section is for system, user, and
# group settings.
##################################################
read -p "Do you want change hostname? (y/n) " yn

case $yn in
	[yY] )
		read -p "Enter hostname? " test
		sudo hostnamectl set-hostname $test
		echo "hostname is now $(hostname)"
		;;
	[nN] )
		echo "Skipping step";
		;;
	* )
		echo "invalid response";
		exit 1;;
esac


## 2. ssh
##################################################
# This section is ssh permission and settings.
##################################################
KEYS=$(
cat << EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII56HDlfpc6mLR77f1I4kafMU/7C6vdjCQaWbLx0J3QM Jupiter
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJJlsOk2uVoRpdmsdHQJKE7ESyMOQ7iH3Wk1+KKLztri surface
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKdKi1Mw5i0oZqYQAnDWP9UE58bqMYRuXptMpscVlhr Terminus
EOF
)

if [[ -s $HOME/.ssh/authorized_keys ]]
then
	echo -e "\nFile is not empty. Making a copy."
	echo -e "Cpying too: $HOME/.ssh/authorized_keys.old"
	cp $HOME/.ssh/authorized_keys $HOME/.ssh/old.authorized_keys
fi

echo -e "\n\n[-] Setting up SSH [-]"
echo $KEYS 1 | tee ~/.ssh/authorized_keys
echo "Sucess: Copied keys to $HOME/.ssh/authorized_keys"

echo -e "\n\n[-] Disabling password authentication [-]"
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

echo "Password login now disabled"
sudo systemctl restart ssh
echo "restating SSH service..."
sleep 1
echo "Sucess: serivce restarted"
echo
sleep 1

## 5. install packages
##################################################
# This section is insatlling packages
# for use on zsh promt that can be used
# on one of the many themes available.
##################################################
echo -e "\n\n[-] Installing Packages [-]"
sudo apt install zsh zip unzip fontconfig -y
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chsh -s $(which zsh) $(whoami)
curl -fsSL https://deb.nodesource.com/setup_19.x | sudo -E bash - &&\
sudo apt-get install -y nodejs
rm -rf $HOME/.zshrc


## 3. add personal config
##################################################
# This section is git permission and settings.
##################################################
GITCONFIG() {
	GITCONFIG="$HOME/.gitconfig"

	if [[ -f $GITCONFIG ]]
	then
		echo -e "The file $GITCONFIG exist."
	else
		echo "The file does not exist. Downloading to $GITCONFIG"
		curl https://raw.githubusercontent.com/PaleBluDot/dotfiles/main/.gitconfig -o $GITCONFIG
	fi


}

ALIASES() {
	ALIASES="$HOME/.aliases"

	if [[ -f $ALIASES ]]
	then
		echo -e "The file $ALIASES exist."
	else
		echo -e "The file does not exist. Downloading to $ALIASES"
		curl https://raw.githubusercontent.com/PaleBluDot/dotfiles/main/.aliases -o $ALIASES
	fi
}

ZSHCONFIG() {
	ZSHCONFIG="$HOME/.zshrc"

	if [[ -f $ZSHCONFIG ]]
	then
		echo -e "The file $ZSHCONFIG exist."
	else
		echo -e "The file does not exist. Downloading to $ZSHCONFIG"
		curl https://raw.githubusercontent.com/PaleBluDot/dotfiles/main/.zshrc -o $ZSHCONFIG
		echo -e "\nPOWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true" >> $ZSHCONFIG
	fi
}

P10KCONFIG() {
	P10KCONFIG="$HOME/.p10k.zsh"

	if [[ -f $P10KCONFIG ]]
	then
		echo -e "The file $P10KCONFIG exist."
	else
		echo -e "The file does not exist. Downloading to $P10KCONFIG"
		curl https://raw.githubusercontent.com/PaleBluDot/dotfiles/main/.p10k.zsh -o $P10KCONFIG
	fi
}

echo -e "\n\n[-] Adding personal config [-]"

GITCONFIG
ALIASES
ZSHCONFIG
P10KCONFIG




## 6. install nerdfonts
##################################################
# This section is installing Nerfont
# for use on zsh promt that can be used
# on one of the many themes available.
# Default font is FireCode Nerd Font.
# Find more: https://www.nerdfonts.com/font-downloads
##################################################
URL=https://github.com/ryanoasis/nerd-fonts/releases/download/v2.2.2/FiraCode.zip

# read -p "What is the Font URL? ($DEFAULTFONT)" URL

if [[ -z $URL ]]
then
	echo "Warning: missing URL. Using default $DEFAULTFONT"
	URL=$DEFAULTFONT
else
	echo $URL
fi

FILENAME=$(basename $URL)
FOLDERNAME=$(basename $URL | cut -f 1 -d '.' )

install_font () {
	echo -e "\n\n[-] Downloading fonts [-]"
	if [ -d "~/tmp/" ]
	then
		echo "`~/tmp/` Directory already exists"
	else
		mkdir ~/tmp/
	fi
	wget -P ~/tmp/ $URL
	mkdir $HOME/.fonts/$FOLDERNAME

	echo -e "\n\n[-] Extracting fonts [-]"
	unzip ~/tmp/$FILENAME -d ~/tmp/$FOLDERNAME
	echo "Success: Font extracted"

	echo -e "\n\n[-] Clean up directories [-]"
	command rm -f ~/tmp/$FOLDERNAME/*Compatible.{ttf,otf}
	echo "Success: Removed Windows files"

	echo -e "\n\n[-] Cleaning direcotries [-]"
	mv ~/tmp/$FOLDERNAME/ ~/.fonts/
	rm -r ~/tmp/
	echo "Success: moved $FOLDERNAME to $HOME/.fonts/"
	echo "Success: removed $HOME/tmp"

	echo -e "\n\n[-] Installing fonts [-]"
	fc-cache -fv
	echo "Sucess: Font installed!"
}

if [ -d "$HOME/.fonts/$FOLDERNAME" ]
then
  echo "Error: Font already exists. Try again."
else
	install_font
fi


## 8. install powerline theme
##################################################
# This section is git powerline
##################################################
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
sed -i 's/robbyrussell/powerlevel10k\/powerlevel10k/g' ~/.zshrc

echo
echo "Completed on $(date +%c)"