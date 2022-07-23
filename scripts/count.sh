#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
DARK_BLUE='\033[0;34m'
PINK='\033[0;35m'
BLUE='\033[0;36m'
NC='\033[0m'

COUNT=$1
STRING_NAME=$2

Missing() {
	echo
	echo "Supply number argument to continue."
	echo -e "example: count.sh ${RED}10"

	exit 1
}

Fallback() {
	echo
	echo -e "Using default ${YELLOW}task-${NC} string."
	echo

	for (( count=1; count<=$COUNT; count++ ))
	do
		echo "task-$count"
	done

	echo
	echo "Tip: You can supply a string to appear before the count."
	echo -e "example: count.sh 10 ${RED}task-${NC}"

	Output

	exit 0
}

Custom() {
	echo
	echo -e "Looping number ${YELLOW}${STRING_NAME}1-$COUNT!${NC}"
	echo

	for (( count=1; count<=$COUNT; count++ ))
	do
		echo "${STRING_NAME}$count"
	done

	Output

	exit 0
}

Output() {
	echo
	echo "All numbers have been successfully output. "
	echo
}



if [ -z "$1" ]; then
	Missing
elif [ -z "$2" ]; then
	Fallback
else
	Custom
fi