#!/usr/bin/env bash
#
# checkDirtyRepos.sh
#
# Scans a two-level-deep github.com/org/repo directory for repos with
# uncommitted changes or unpushed commits, and prints a bordered box
# summary — but only when there's something to report. Silent on a
# clean run.
#
# Self-contained: does NOT rely on the calling shell's variables
# (colors are defined below). Run it directly as an executable —
# it is not meant to be sourced.
#
# To run on every interactive shell, add this line to .zshrc:
#   /path/to/check-repos.sh
#
# Compatible with bash 3.2+ (macOS system default) — no bash 4-only
# features (no `mapfile`, no associative arrays).

shopt -s nullglob

GITHUB_ROOT="${1:-/Users/psanchez/Documents/github.com}"
RED=$'\033[0;31m'      # dirty / uncommitted changes
YELLOW=$'\033[0;33m'   # unpushed commits
CYAN=$'\033[0;36m'     # no upstream branch set
NC=$'\033[0m'

# Phase 1 — data producer. Emits one plain (no color codes) line per
# issue found: "<marker> <repo_label>: <detail>".
_scan_repos_raw() {
	local root="$1"
	[[ -d "$root" ]] || return

	for org_dir in "$root"/*/; do
		for repo_dir in "${org_dir}"*/; do
			[[ -d "${repo_dir}.git" ]] || continue

			(
				cd "$repo_dir" || exit
				local org_name repo_name repo_label
				org_name=$(basename "$org_dir")
				repo_name=$(basename "$repo_dir")
				repo_label="${org_name}/${repo_name}"

				local dirty_count
				dirty_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

				local unpushed upstream_exit
				unpushed=$(git log '@{u}..HEAD' --oneline 2>/dev/null)
				upstream_exit=$?

				if [[ "$dirty_count" -gt 0 ]]; then
					echo "* ${repo_label}: ${dirty_count} uncommitted change(s)"
				fi

				if [[ $upstream_exit -eq 0 && -n "$unpushed" ]]; then
					local ahead_count
					ahead_count=$(echo "$unpushed" | wc -l | tr -d ' ')
					echo "^ ${repo_label}: ${ahead_count} unpushed commit(s)"
				elif [[ $upstream_exit -ne 0 ]]; then
					echo "! ${repo_label}: no upstream branch set"
				fi
			)
		done
	done
}

# Phase 2 — presentation. Runs the scan, and only if something was
# found, draws it inside a bordered box sized to the longest line.
check_dirty_repos() {
	local root="${1:-$GITHUB_ROOT}"

	local findings=()
	while IFS= read -r line; do
		[[ -n "$line" ]] && findings+=("$line")
	done < <(_scan_repos_raw "$root")

	[[ ${#findings[@]} -eq 0 ]] && return

	local title=" Repos with unsaved work "

	local max_len=${#title}
	local line
	for line in "${findings[@]}"; do
		(( ${#line} > max_len )) && max_len=${#line}
	done

	local border=""
	local i
	for (( i = 0; i < max_len + 2; i++ )); do
		border+="─"
	done

	# Blank line up top for separation from whatever printed before this
	# (previous command's output, shell prompt, etc.)
	echo ""

	printf "┌%s┐\n" "$border"
	printf "│ %-*s │\n" "$max_len" "$title"
	printf "├%s┤\n" "$border"
	for line in "${findings[@]}"; do
		# Pad the PLAIN (uncolored) line to max_len first — padding must
		# be computed on the visible text only. Only after padding is
		# fixed do we wrap it in a color code, since escape sequences
		# have zero visible width but nonzero byte length, and would
		# throw off %-*s if included before padding.
		local padded_line color
		padded_line=$(printf "%-*s" "$max_len" "$line")

		case "${line:0:1}" in
			"*") color="$RED" ;;      # dirty / uncommitted changes
			"^") color="$YELLOW" ;;   # unpushed commits
			"!") color="$CYAN" ;;     # no upstream branch set
			*)   color="$NC" ;;
		esac

		printf "│ %s%s%s │\n" "$color" "$padded_line" "$NC"
	done
	printf "└%s┘\n" "$border"
}

check_dirty_repos "$GITHUB_ROOT"
