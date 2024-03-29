#!/bin/bash

##########################################
# Script Name:    trial.sh
# Author:         pavel sanchez
# Email:          support@tasteink.me
# Description:    script for testing.
# args:
#  - none
##########################################

if [ "$VERBOSE" = "yes" ]; then set -x; STD=""; else STD="silent"; fi

silent() { "$@" > /dev/null 2>&1; }

YW=$(echo "\033[33m")
RD=$(echo "\033[01;31m")
BL=$(echo "\033[36m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")

RETRY_NUM=2
RETRY_EVERY=3
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD="-"

set -Eeuo pipefail
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
}

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

msg_info "Starting setup script"
sleep 2
# msg_ok "Set up Container OS"

set +e
trap - ERR

if ping -c 1 -W 1 1.1.1.1 &> /dev/null;
then
	msg_ok "Internet Connected";
else
  msg_error "Internet NOT Connected"
    read -r -p "Would you like to continue anyway? <y/N> " prompt
    if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]; then
      echo -e " ⚠️  ${RD}Expect Issues Without Internet${CL}"
    else
      echo -e " 🖧  Check Network Settings"
      exit 1
    fi
fi

RESOLVEDIP=$(dscacheutil -q host -a name github.com | awk '/^ip_address/{print $NF}')

if [[ -z "$RESOLVEDIP" ]];
then
	msg_error "DNS Lookup Failure";
else
	msg_ok "DNS Resolved github.com to ${BL}$RESOLVEDIP${CL}";
fi

set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

msg_info "Updating Container OS"
sleep 2
msg_ok "Updated Container OS"


msg_info "Installing Dependencies"
sleep 1
msg_ok "Installed Dependencies"

msg_ok "Set Up Complete"