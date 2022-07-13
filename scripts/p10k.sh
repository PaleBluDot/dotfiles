#!/bin/bash


# if [ -z "$1" ]; then
# 	echo ""
# 	echo "Waiting for Powerlevel10k setting. Please refer to you settings doc for the name."
# 	exit 1
# else
# 	name=$1
# fi

# echo ""
# echo "Looping colors for $1."
# echo ""

# For loop
# This method works fine and is less code than the
# for loop. Although this might be less performant.
for (( count=0; count<=5; count++ ))
do
	echo "POWERLEVEL9K_PACKAGE_BACKGROUND=$count"
done


# WHILE LOOP
# This is using a while loop to display the numbers.
# This method works fine but it is more code than the
# for loop. Although this might be more performant.
# c=0
# while true; do
# 	if [[ "$c" -gt 5 ]]; then
# 			exit 1
# 	fi
# 	echo "POWERLEVEL9K_PACKAGE_BACKGROUND=$c"
# 	((c++))
# done

echo ""
echo "All $1 colors completes. Find your color carefully"
echo ""

exit 0
