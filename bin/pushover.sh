#!/bin/bash

######################################################
# Script Name:		pushover.sh
# Version:				v0.0.1
# Author:					Pavel Sanchez (PaleBluDot)
# Email:					support@tasteink.me
# Description:		Script for Pushover notification
# License: 				MIT
# Copyright:			(c) 2023 Pavel Sanchez
# args:
#  - none
######################################################

if [ "$VERBOSE" = "yes" ]; then set -x; STD=""; else STD="silent"; fi

set -Eeuo pipefail
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

readonly NAME="$(basename $0)"
readonly VERSION="v0.0.1"
readonly API_URL="https://api.pushover.net/1/messages.json"
readonly CONFIG_FILE="pushover.cfg"
readonly DEFAULT_CONFIG="/etc/pushover/${CONFIG_FILE}"
readonly USER_OVERRIDE=$DOTFILES/config/terminal/${CONFIG_FILE}
readonly EXPIRE_DEFAULT=180
readonly RETRY_DEFAULT=30
HIDE_REPLY=true

YW=$(echo "\033[33m")
RD=$(echo "\033[01;31m")
BL=$(echo "\033[36m")
GN=$(echo "\033[1;92m")
CY=$(echo "\033[1;34m")
WT=$(echo "\033[1;37m")
CL=$(echo "\033[m")

CM="✔️"
CROSS="❌"
BFR="\\r\\033[K"
HOLD="-"


##########################################
######	FUNCTIONS
##########################################
silent() { "$@" > /dev/null 2>&1; }

error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
}

msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}...${CL}\n"
}

msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

check_online() {
	if ping -c 1 -W 1 1.1.1.1 &> /dev/null;
  sleep 0.5
	then
		msg_ok "Internet Connected";
	else
		msg_error "Internet NOT Connected"
		echo -e " 🛜 Check Network Settings"
		exit 1
	fi
}

check_dns(){
	RESOLVEDIP=$(dscacheutil -q host -a name github.com | awk '/^ip_address/{print $NF}')

	if [[ -z "$RESOLVEDIP" ]];
	then
		msg_error "DNS Lookup Failure";
	else
		msg_ok "DNS Resolved github.com to ${BL}$RESOLVEDIP${CL}";
	fi
}

usage() {
	echo -e "Send ${CY}Pushover ${VERSION}${CL} scripted by Pavel Sanchez."
	echo -e "Push notifications to your Android, iOS, or desktop devices."
	echo
	echo -e "${RD}NOTE:${CL} This script requires an account at http://www.pushover.net."
	echo
	echo -e "${CY}Usage:${CL} $(basename $0) [ --apptoken <token> ] --message <text> [ --config <config file> ] [ options ]"
	echo
	echo -e "  ${WT}OPTIONS:${CL}"
	echo -e "    -t, --token          API token"
	echo -e "    -u, --user           User token"
	echo -e "    -m, --message        Message (required), 1024 chars max"
	echo -e "    -T, --title          Title of your notification, 250 chars max"
	echo -e "    -p, --priority       Priority (https://pushover.net/api#priority)"
	echo -e "    -s, --sound          Sound (https://pushover.net/api#sounds)"
	echo -e "    -a, --attachment     Attach an image (up to 2.5mb)"
	echo -e "    -U, --url            URL Link, 512 chars max"
	echo -e "        --url_title      URL Title, 100 chars max"
	echo -e "    -r, --retry          Retry (seconds)"
	echo -e "    -e, --expire         Expire (seconds)"
	echo -e "    -d, --device         Send to a specific device name"
	echo -e "    -H, --html           Allow HTML in notification"
	echo -e "    -M, --monospace      Monospace format"
	echo
	echo -e "  ${WT}Additional options not in config file${CL}"
	echo
	echo -e "    -v, --verbose      Debug"
	echo -e "    -h, --help         Show this message"
	echo
	echo -e "${WT}Examples:${CL}"
	echo
	echo -e "    pushover.sh -m \"This has the default title.\""
	echo -e "    pushover.sh -m \"This has a custom title.\" -T \"Custom Title\""
	echo -e "    pushover.sh -m \"This plays bike sound\" -s \"bike\""
	echo
}

main () {
  if [ -f ${DEFAULT_CONFIG} ]; then
    source ${DEFAULT_CONFIG}
  fi

  if [ -f ${USER_OVERRIDE} ]; then
    source ${USER_OVERRIDE}
  fi

  if [ ${priority:-0} -eq 2 ]; then
    if [ -z "${expire:-}" ]; then
      expire=${EXPIRE_DEFAULT}
    fi
    if [ -z "${retry:-}" ]; then
      retry=${RETRY_DEFAULT}
    fi
  fi

  if [ -z "${api_token:-}" ]; then
    echo "-t|--token must be set"
    exit 1
  fi

  if [ -z "${title:-}" ]; then
    USER=$(/usr/bin/whoami)
    HOSTNAME=$(/usr/bin/uname -n)
    TITLE=$USER@$HOSTNAME
    title=${TITLE}
  else
    title=${title}
  fi

  if [ -z "${user_key:-}" ]; then
    echo "-u|--user must be set"
    exit 1
  fi

  if [ -z "${message:-}" ]; then
    echo "-m|--message must be set"
    exit 1
  fi

  if [ ! -z "${html:-}" ] && [ ! -z "${monospace:-}" ]; then
    echo "--html and --monospace are mutually exclusive"
    exit 1
  fi

  if [ ! -z "${attachment:-}" ] && [ ! -f "${attachment}" ]; then
    echo "${attachment} not found"
    exit 1
  fi

  if [ -z "${attachment:-}" ]; then
    json="{\"token\":\"${api_token}\",\"user\":\"${user_key}\",\"message\":\"${message}\""
    if [ "${device:-}" ]; then json="${json},\"device\":\"${device}\""; fi
    if [ "${title:-}" ]; then json="${json},\"title\":\"${title}\""; fi
    if [ "${url:-}" ]; then json="${json},\"url\":\"${url}\""; fi
    if [ "${url_title:-}" ]; then json="${json},\"url_title\":\"${url_title}\""; fi
    if [ "${html:-}" ]; then json="${json},\"html\":1"; fi
    if [ "${monospace:-}" ]; then json="${json},\"monospace\":1"; fi
    if [ "${priority:-}" ]; then json="${json},\"priority\":${priority}"; fi
    if [ "${expire:-}" ]; then json="${json},\"expire\":${expire}"; fi
    if [ "${retry:-}" ]; then json="${json},\"retry\":${retry}"; fi
    if [ "${sound:-}" ]; then json="${json},\"sound\":\"${sound}\""; fi
    json="${json}}"

    curl -s ${HIDE_REPLY:+ -o /dev/null} \
      -H "Content-Type: application/json" \
      -d "${json}" \
      "${API_URL}" 2>&1
  else
    curl -s ${HIDE_REPLY:+ -o /dev/null} \
      --form-string "token=${api_token}" \
      --form-string "user=${user_key}" \
      --form-string "message=${message}" \
      --form "attachment=@${attachment}" \
      ${html:+ --form-string "html=1"} \
      ${monospace:+ --form-string "monospace=1"} \
      ${priority:+ --form-string "priority=${priority}"} \
      ${sound:+ --form-string "sound=${sound}"} \
      ${device:+ --form-string "device=${device}"} \
      ${title:+ --form-string "title=${title}"} \
      "${API_URL}" 2>&1
  fi
}

while [ $# -gt 0 ]
do
  case "${1:-}" in
    -t|--token)
      api_token="${2:-}"
      shift
      ;;
    -u|--user)
      user_key="${2:-}"
      shift
      ;;
    -m|--message)
      message="${2:-}"
      shift
      ;;
    -a|--attachment)
      attachment="${2:-}"
      shift
      ;;
    -T|--title)
      title="${2:-}"
      shift
      ;;
    -d|--device)
      device="${2:-}"
      shift
      ;;
    -U|--url)
      url="${2:-}"
      shift
      ;;
    --url-title)
      url_title="${2:-}"
      shift
      ;;
    -H|--html)
      html=1
      ;;
    -M|--monospace)
      monospace=1
      ;;
    -p|--priority)
      priority="${2:-}"
      shift
      ;;
    -s|--sound)
      sound="${2:-}"
      shift
      ;;
    -e|--expire)
      expire="${2:-}"
      shift
      ;;
    -r|--retry)
      retry="${2:-}"
      shift
      ;;
    -v|--verbose)
      unset HIDE_REPLY
      ;;
    -h|--help)
      usage
      exit
      ;;
    *)
      ;;
  esac
  shift
done

curl --version > /dev/null 2>&1 || { echo "This script requires curl; aborting."; echo; exit 1; }



set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

##########################################
###### EXECUTE
##########################################
msg_info "Starting setup script"

msg_info "Checking Dependencies"
check_online
check_dns
msg_ok "Checked Dependencies"

msg_info "Installing Dependencies"
sleep 1
msg_ok "Installed Dependencies"

msg_info "Sending Message"
main
msg_ok "Message Sent"

msg_ok "Set Up Complete"