#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title IP Info
# @raycast.mode fullOutput
# @raycast.packageName Networking
#
# Optional parameters:
# @raycast.icon 🤖
# @raycast.currentDirectoryPath ~
# @raycast.needsConfirmation false
# @raycast.argument1 { "type": "text", "placeholder": "IP Address", "optional": true }
#
# Documentation:
# @raycast.description Write a nice and descriptive summary about your script command here
# @raycast.author Pavel Sanchez
# @raycast.authorURL https://github.com/palebludot/dotfiles

if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed. Install via https://stedolan.github.io/jq/download/'
  exit 1
fi

if [[ $# -ne 1 ]]; then
	link=$(echo "http://ip-api.com/json/"$myip)
	data=$(curl $link -s) # -s for slient output

	status=$(echo $data | jq '.status' -r)

	if [[ $status == "success" ]]; then

		city=$(echo $data | jq '.city' -r)
		regionName=$(echo $data | jq '.regionName' -r)
		country=$(echo $data | jq '.country' -r)
		timezone=$(echo $data | jq '.timezone' -r)
		isp=$(echo $data | jq '.isp' -r)
		org=$(echo $data | jq '.org' -r)
		ip=$(echo $data | jq '.query' -r)
		lat=$(echo $data | jq '.lat' -r)
		lon=$(echo $data | jq '.lon' -r)
		maps=$(echo "https://www.google.com/maps/place/@${lat},${lon},17z/")

		echo
		echo -e "IP:\t\t${ip}"
		echo -e "Org:\t\t${isp}"
		echo -e "ISP:\t\t${org}"
		echo -e "City:\t\t${city}"
		echo -e "Region:\t\t${regionName}"
		echo -e "Country:\t${country}"
		echo -e "Timezone:\t${timezone}"
		echo -e "Map:\t\t${maps}"
	fi
else
	link=$(echo "http://ip-api.com/json/"$1)
	data=$(curl $link -s) # -s for slient output

	status=$(echo $data | jq '.status' -r)

	if [[ $status == "success" ]]; then

		city=$(echo $data | jq '.city' -r)
		regionName=$(echo $data | jq '.regionName' -r)
		country=$(echo $data | jq '.country' -r)
		timezone=$(echo $data | jq '.timezone' -r)
		isp=$(echo $data | jq '.isp' -r)
		org=$(echo $data | jq '.org' -r)
		ip=$(echo $data | jq '.query' -r)
		lat=$(echo $data | jq '.lat' -r)
		lon=$(echo $data | jq '.lon' -r)
		maps=$(echo "https://www.google.com/maps/place/@${lat},${lon},17z/")

		echo
		echo -e "IP:\t\t${ip}"
		echo -e "Org:\t\t${isp}"
		echo -e "ISP:\t\t${org}"
		echo -e "City:\t\t${city}"
		echo -e "Region:\t\t${regionName}"
		echo -e "Country:\t${country}"
		echo -e "Timezone:\t${timezone}"
		echo -e "Map:\t\t${maps}"
	fi
fi