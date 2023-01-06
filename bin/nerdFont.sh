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