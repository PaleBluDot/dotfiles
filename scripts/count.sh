#!/bin/bash

RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$1" ]; then
	echo ""
	echo "No number argument has been supplied. Please supply one to continue."
	echo -e "example: ${RED}count.sh 10"
	exit 1
else
	count=$1
fi

if [ -z "$2" ]; then
	echo ""
	echo "No number argument has been supplied. Please supply one to continue."
	echo -e "example: ${RED}count.sh 10 task"
	exit 1
else
	name=$1
fi

echo ""
echo -e "Looping number ${BLUE}1-$1!${NC}"
echo ""


for (( count=1; count<=$1; count++ ))
do
	echo "$2$count"
done

echo ""
echo "All numbers have been successfully output. "
echo ""

exit 0