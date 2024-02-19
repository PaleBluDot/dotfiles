#!/bin/bash

# Check if bc command is available
if ! command -v bc &> /dev/null; then
    echo "'bc' command not found. Attempting to install..."
    # Install bc (adjust as needed based on your package manager)
    sudo apt-get update > /dev/null
    sudo apt-get install -y bc > /dev/null
		echo "Installation completed successfully."
		echo

    # Check again
    if ! command -v bc &> /dev/null; then
        echo "Error: Unable to install 'bc'. Please install bc manually and run the script again."
        exit 1
    fi
fi

# Record start time
start_time=$(date +%s.%N)

######################
##@ VARIABLES
######################

# Export dotfiles directory as an environment variable
export DOT_DIR=$HOME/.config/dotfiles

######################
##@ MACOS
######################

# Function to install packages for macOS
install_macos() {
  local macos_dir="config/os-only/macos/"
  local install_packages=true

  # Check if Brewfile exists
  if [ ! -f "$macos_dir/Brewfile" ]; then
    echo "Error: Brewfile not found in $macos_dir"
    exit 1
  fi

  # Check if -d flag is present
  if [[ $* == *"-d"* ]]; then
    echo "Packages to be installed for macOS:"
    cat "$macos_dir/Brewfile"
    install_packages=false
  fi

  if [ "$install_packages" == true ]; then
    # Update Homebrew
    brew update > /dev/null

    # Install packages for macOS
    echo "Installing packages for macOS..."
    while IFS= read -r line; do
      if [[ $line == brew* ]]; then
        package=$(echo "$line" | awk -F'"' '{print $2}')
        brew install "$package" > /dev/null 2>&1

        # Wait for the version information to become available
        while true; do
          installed_version=$(brew list --versions "$package" 2>/dev/null || echo "Not Installed")
          [ "$installed_version" != "Not Installed" ] && break
        done

        if [ "$installed_version" != "Not Installed" ]; then
          echo "$package: Installed (Version: $installed_version)"
        else
          echo "$package: Installing..."
        fi
      fi
    done < "$macos_dir/Brewfile"
  fi
}

# Function to uninstall packages for macOS
uninstall_macos() {
  local macos_dir="config/os-only/macos/"
  local uninstall_packages=true

  # Check if Brewfile exists
  if [ ! -f "$macos_dir/Brewfile" ]; then
    echo "Error: Brewfile not found in $macos_dir"
    exit 1
  fi

  # Check if -d flag is present
  if [[ $* == *"-d"* ]]; then
    echo "Packages to be uninstalled for macOS:"
    cat "$macos_dir/Brewfile"
    uninstall_packages=false
  fi

  if [ "$uninstall_packages" == true ]; then
    # Update Homebrew
    brew update > /dev/null

    # Uninstall packages for macOS
    echo "Uninstalling packages for macOS..."
    while IFS= read -r line; do
      if [[ $line == brew* ]]; then
        package=$(echo "$line" | awk -F'"' '{print $2}')
        brew uninstall "$package" > /dev/null 2>&1

        # Wait for the version information to become unavailable
        while true; do
          installed_version=$(brew list --versions "$package" 2>/dev/null || echo "Not Installed")
          [ "$installed_version" == "Not Installed" ] && break
          sleep 1
        done

        if [ "$installed_version" == "Not Installed" ]; then
          echo "$package: Uninstalled"
        else
          echo "$package: Uninstalling..."
        fi
      fi
    done < "$macos_dir/Brewfile"
  fi
}

######################
##@ LINUX
######################

# Function to install packages for Linux
install_linux() {
  local linux_dir="config/os-only/linux/"
  local install_packages=true

  # Check if required-packages.txt exists
  if [ ! -f "$linux_dir/required-packages.txt" ]; then
    echo "Error: required-packages.txt not found in $linux_dir"
    exit 1
  fi

  # Check if -d flag is present
  if [[ $* == *"-d"* ]]; then
    echo "Packages to be installed for Linux:"
    cat "$linux_dir/required-packages.txt"
    install_packages=false
  fi

  if [ "$install_packages" == true ]; then
    # Update package list
    sudo apt-get update > /dev/null

    # Install packages for Linux
    echo "Installing packages for Linux..."
    while IFS= read -r package; do
      sudo apt-get install -y "$package" > /dev/null
      sleep 1

      # Wait for the version information to become available
      while true; do
        installed_version=$(dpkg-query -W -f='${Version}\n' "$package" 2>/dev/null || echo "Not Installed")
        [ "$installed_version" != "Not Installed" ] && break
        sleep 1
      done

      if [ "$installed_version" != "Not Installed" ]; then
        echo "$package: Installed (Version: $installed_version)"
      else
        echo "$package: Installing..."
      fi
    done < "$linux_dir/required-packages.txt"
  fi
}

# Function to uninstall packages for Linux
uninstall_linux() {
  local linux_dir="config/os-only/linux/"

  # Check if required-packages.txt exists
  if [ ! -f "$linux_dir/required-packages.txt" ]; then
    echo "Error: required-packages.txt not found in $linux_dir"
    exit 1
  fi

  # Uninstall packages for Linux
  echo "Uninstalling packages for Linux..."
  while IFS= read -r package; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
      sudo apt-get remove -y "$package" > /dev/null
      echo "$package: Uninstalled"
    else
      echo "$package: Not Installed"
    fi
  done < "$linux_dir/required-packages.txt"
}

######################
##@ WINDOWS
######################

# Function to install packages for Windows
install_windows() {
  local windows_dir="config/os-only/windows/"

  # Display packages to be installed
  echo "Packages to be installed for Windows:"
  if [ -f "$windows_dir/required-packages.txt" ]; then
    cat "$windows_dir/required-packages.txt"

    # Check if packages are already installed (Update this part based on Windows package manager)
    echo -e "\nChecking installed packages and versions: (Update this part based on Windows package manager)"

    # Wait for 3 seconds
    sleep 3

    # Install packages for Windows (Adjust as needed, provide instructions or use the appropriate package manager)
    echo "Installing packages for Windows..."
    # Example: choco install packageName
  else
    echo "Error: required-packages.txt not found in $windows_dir"
    exit 1
  fi
}

# Function to uninstall packages for Windows
uninstall_windows() {
  # Uninstall packages for Windows (adjust as needed)
  echo "Uninstalling packages for Windows..."
  # Example: choco uninstall packageName
}

######################
##@ DOTFILES
######################

# Function to install dotfiles
install_dotfiles() {
  local config_dir="config"
  local system_name=$(uname -s)

  # Iterate through directories in config and install symlinks
  for dir in $config_dir/*/; do
    local symlink_file="$dir/symlinks.txt"
    local target_dir="${dir#${config_dir}/}"

    if [ -f "$symlink_file" ]; then
      # Check if the target directory exists, create it if not
      local full_target_dir="${HOME}/${target_dir}"

      # if [ ! -d "$full_target_dir" ]; then
      #   mkdir -p "$full_target_dir"
      #   echo "Created directory: $full_target_dir"
      # fi

      echo "Creating symlinks for $target_dir directory..."

      # Use awk to parse source and target
      awk -F':' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $1, $2}' "$symlink_file" | while read -r source target; do
        source="${HOME}/.config/dotfiles/$dir$source"
        target="${HOME}/${target}"

        if [ -e "$target" ]; then
          if [ -L "$target" ]; then
            echo "Symlinks already exists."
            # echo "Symlink already exists: $target -> $(readlink -f $target)"
          else
            echo "File or directory already exists: $target"
          fi
        else
          ln -fs "$source" "$target"
          echo "Symlink created: $target -> $source"
        fi
      done
      echo
    else
      echo "Warning: $symlink_file not found. Installation skipped for this directory." > /dev/null
    fi
  done

  echo -e "\nDotfiles installation completed successfully."

  # Set CSPELL_DIR based on the OS
  case "$(uname)" in
    Darwin)
      CSPELL_DIR="/opt/homebrew/lib"
      ;;
    Linux)
      CSPELL_DIR="/usr/lib"
      ;;
    MINGW32*|MSYS*|MINGW64*)
      CSPELL_DIR="C:\\Program Files\\nodejs\\"
      ;;
    *)
      echo "Unsupported operating system."
      exit 1
      ;;
  esac

  # DEBUG
  # echo "DOT_DIR: $DOT_DIR"
  # echo "CSPELL_DIR: $CSPELL_DIR"
  # echo "CONFIG_FILE: $CONFIG_FILE"
}

# Function to uninstall dotfiles
uninstall_dotfiles() {
  local config_dir="config"

  # Iterate through directories in config and uninstall symlinks
  for dir in $config_dir/*/; do
    local symlink_file="$dir/symlinks.txt"
    local target_dir="${dir#${config_dir}/}"

    if [ -f "$symlink_file" ]; then
      echo "Removing symlinks for $target_dir directory..."

      # Use awk to parse source and target
      awk -F':' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $1, $2}' "$symlink_file" | while read -r source target; do
        source="${HOME}/.config/dotfiles/$dir$source"
        target="${HOME}/${target}"

        if [ -L "$target" ]; then
          rm -f "$target"
          echo "Symlink removed: $target -> $source"
        elif [ -e "$target" ]; then
          rm -f "$target"
          echo "Not a symlink. File Deleted: $target"
        else
          echo "Target not found: $target"
        fi
      done
      echo
    else
      echo "Warning: $symlink_file not found. Uninstallation skipped for this directory."
    fi
  done

  echo "Dotfiles uninstallation completed successfully."
}


# Function to update dotfiles
update_dotfiles() {
  git pull

  if [ $? -ne 0 ]; then
    echo "Error during git pull. Please resolve merge conflicts and try again."
    git status
    exit 1
  fi

  echo "Dotfiles updated successfully."
}

######################
##@ PACKAGES
######################

# Function to install packages only
install_packages() {
  local os_type="$(uname)"

  case "$os_type" in
    Darwin)
      CSPELL_DIR="/opt/homebrew/lib"
      install_macos
      ;;
    Linux)
      CSPELL_DIR="/usr/lib"
      install_linux
      ;;
    MINGW32*|MSYS*|MINGW64*)
      CSPELL_DIR="C:\\Program Files\\nodejs\\"
      install_windows
      ;;
    *)
      echo "Unsupported operating system."
      exit 1
      ;;
  esac
}

# Function to uninstall packages only
uninstall_packages() {
  local os_type="$(uname)"

  case "$os_type" in
    Darwin)
      uninstall_macos
      ;;
    Linux)
      uninstall_linux
      ;;
    MINGW32*|MSYS*|MINGW64*)
      uninstall_windows
      ;;
    *)
      echo "Unsupported operating system."
      exit 1
      ;;
  esac
}


######################
##@ COMMANDS
######################

# Function to install dotfiles and/or packages based on options
install() {
  local options="$1"

  # Check if -d flag is present
  local install_dotfiles=true
  if [[ $options == *"d"* ]]; then
    install_dotfiles
  fi

  # Check if -p flag is present
  local install_packages=true
  if [[ $options == *"p"* ]]; then
    install_packages
  fi

  # If no flag is used, install both dotfiles and packages
  if [ -z "$options" ]; then
    install_dotfiles
    install_packages
  fi
}

# Function to uninstall dotfiles and/or packages based on options
uninstall() {
  local options="$1"

  # Check if dotfiles option is selected
  if [[ $options == *"d"* ]]; then
    uninstall_dotfiles
  fi

  # Check if packages option is selected
  if [[ $options == *"p"* ]]; then
    uninstall_packages
  fi
}

# Function to update based on options
update() {
  local options="$1"

  # Check if dotfiles option is selected
  if [[ $options == *"d"* ]]; then
    update_dotfiles
  fi

  # Check if packages option is selected
  if [[ $options == *"p"* ]]; then
    update_packages
  fi
}

# Function to display extensive usage
usage() {
  echo "Usage: $0 {command} [options]"
  echo
  echo "Commands:"
  echo "  install   Install dotfiles and/or packages."
  echo "  uninstall Uninstall dotfiles and/or packages."
  echo "  update    Update dotfiles and/or packages."
  echo "  help      Display this help message."
  echo
  echo -e "Options:"
  echo "  -d        Install/uninstall/update dotfiles."
  echo "  -p        Install/uninstall/update packages."
  echo "  -h        Display usage information."
  echo
  echo -e "Examples:"
  echo "  $0 install -d -p   # Install both dotfiles and packages."
  echo "  $0 uninstall -d    # Uninstall dotfiles."
  echo "  $0 update -p       # Update packages."
  echo "  $0 help            # Display this help message."
}

# Check command arguments
if [ "$#" -eq 0 ]; then
  # No arguments provided, default to 'install'
  install
else
  case "$1" in
    install)
      install "$2"
      ;;
    uninstall)
      uninstall "$2"
      ;;
    update)
      update "$2"
      ;;
    help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
fi

# Record the end time
end_time=$(date +%s.%N)

# Calculate and print the execution time
execution_time=$(echo "$end_time - $start_time" | bc)

echo
echo "Script execution time: $execution_time seconds"

exit 0
