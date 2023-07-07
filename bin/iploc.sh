#!/bin/bash

#
# Author: Abhishek Shingane (abhisheks@iitbhilai.ac.in)
# Date: 11 Sep 2020
#

if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed. Install via https://stedolan.github.io/jq/download/'
  exit 1
fi

if [[ $# -ne 1 ]]; then
	echo 'Provide IP as command line parameter. Usage:  ' $0 ' 15.45.0.1 '
	exit 1
fi

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

