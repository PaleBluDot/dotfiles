#!/bin/bash -e

declare -rx STEPS=(
  'pre-install'
  'install'
  'post-install'
)
declare -rx CMDS=(
  'sleep 1'
  'sleep 1'
  'sleep 1'
)

progress() {
	declare -rx BAR_SIZE="=========="
	declare -rx CLEAR_LINE="\\033[K"

	start() {
		local MAX_STEPS=${#STEPS[@]}
		local MAX_BAR_SIZE="${#BAR_SIZE}"

		tput civis -- invisible

		echo -ne "\\r[${BAR_SIZE:0:0}] 0 %$CLEAR_LINE"
		for step in "${!STEPS[@]}"; do
			${CMDS[$step]}

			perc=$(((step + 1) * 100 / MAX_STEPS))
			percBar=$((perc * MAX_BAR_SIZE / 100))
			echo -ne "\\r[${BAR_SIZE:0:percBar}] $perc %$CLEAR_LINE"
		done
		echo ""

		tput cnorm -- normal
	}
	start
}

advanced() {
	start() {
		local MAX_STEPS=${#STEPS[@]}
		local BAR_SIZE="##########"
		local MAX_BAR_SIZE="${#BAR_SIZE}"
		local CLEAR_LINE="\\033[K"

		tput civis -- invisible

		for step in "${!STEPS[@]}"; do
			perc=$((step * 100 / MAX_STEPS))
			percBar=$((perc * MAX_BAR_SIZE / 100))
			echo -ne "\\r- ${STEPS[step]} [ ]$CLEAR_LINE\\n"
			echo -ne "\\r[${BAR_SIZE:0:percBar}] $perc %$CLEAR_LINE"

			${CMDS[$step]}

			perc=$(((step + 1) * 100 / MAX_STEPS))
			percBar=$((perc * MAX_BAR_SIZE / 100))
			echo -ne "\\r\\033[1A- ${STEPS[step]} [✔]$CLEAR_LINE\\n"
			echo -ne "\\r[${BAR_SIZE:0:percBar}] $perc %$CLEAR_LINE"
		done
		echo ""

		tput cnorm -- normal
	}
	start
}

spinner() {
	declare -x FRAME
	declare -x FRAME_INTERVAL

	FRAME=("-" "\\" "|" "/")
	FRAME_INTERVAL=0.25

	start() {
		local step=0

		tput civis -- invisible

		while [ "$step" -lt "${#CMDS[@]}" ]; do
			${CMDS[$step]} & pid=$!

			while ps -p $pid &>/dev/null; do
				echo -ne "\\r[   ] ${STEPS[$step]} ..."

				for k in "${!FRAME[@]}"; do
					echo -ne "\\r[ ${FRAME[k]} ]"
					sleep $FRAME_INTERVAL
				done
			done

			echo -ne "\\r[ ✔ ] ${STEPS[$step]}\\n"
			step=$((step + 1))
		done

		tput cnorm -- normal
	}

	start
}

case $1 in
  progress)
    progress
    ;;
  advanced)
    advanced
    ;;
  spinner*)
    spinner
    ;;
  *)
    echo "Invalid option $1!"
    exit 1
esac
