#!/usr/bin/env bash
#
# dotfiles.sh: install, link and manage the tools in this repo.
# Build spec: plan.md. Written for Bash 3.2 (macOS /bin/bash) and up.

set -euo pipefail
set -o errtrace

# ─── First run (plan Section 2) ─────────────────────────────────────────
# A bare machine's first run asks where to clone; this is only the suggested
# answer. DOTFILES / DOTFILES_REPO / DOTFILES_BRANCH in the environment skip
# the question or override the source (testing, other paths).
readonly SUGGESTED_DOTFILES_DIR="$HOME/Projects/github.com/PaleBluDot/dotfiles"
readonly DEFAULT_DOTFILES_REPO="https://github.com/PaleBluDot/dotfiles.git"
ORIG_ARGS=()   # the arguments as given, for re-running from the clone
ORIG_PATH="$PATH"   # PATH as the user has it (the hint in _path_check checks this)
RUNNING_FROM_FILE=false

# ─── Flags (internal, never exported) ───────────────────────────────────
DRY_RUN=false
FORCE=false
VERBOSE=false
NO_COLOR_FLAG=false   # --no-color: the banner without colour
REQUIRED_FLAG=false   # --required: link adds the tools to required: in config.yml
QUIET=false   # interactive mode: info/success and command output go to the log only
# link/update (#24): a tool's success lines wait in TOOL_HELD while
# TOOL_HOLD is true. The first other line prints them (something is
# happening); a tool where nothing changed gets one line instead.
TOOL_HOLD=false
TOOL_HELD=""

# ─── Logging state ──────────────────────────────────────────────────────
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
LOG_FILE=""
LOG_CMD="main"

# ════════════════════════════════════════════════════════════════════════
# LOGGING (plan Section 11)
# ════════════════════════════════════════════════════════════════════════

# ISO 8601 time with a colon in the offset: 2026-10-12T16:20:01-04:00.
# BSD date (macOS) has no -I flag, so build it from +%z (-0400).
# Bash 4.2+ formats the time itself (printf %(…)T): no date process for
# every log line. macOS's /bin/bash 3.2 still uses date.
_timestamp() {
  local ts
  if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2))); then
    printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  else
    ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  fi
  printf '%s:%s' "${ts%??}" "${ts: -2}"
}

# Append one line to the log file. Never fails the script.
_log_to_file() {
  if [[ -n $LOG_FILE ]]; then
    printf '%s [%s] [%s] %s\n' "$(_timestamp)" "$1" "$LOG_CMD" "$2" >>"$LOG_FILE" 2>/dev/null || true
  fi
}

# log <level> <message...>
# error, warn, debug -> stderr; info, success -> stdout.
# debug shows in the terminal only with --verbose; the file gets everything.
log() {
  local level="${1:-}"
  shift || true
  local message="$*"
  local label

  case "$level" in
    error)   label="ERROR" ;;
    warn)    label="WARN" ;;
    info)    label="INFO" ;;
    success) label="SUCCESS" ;;
    debug)   label="DEBUG" ;;
    *)
      label="ERROR"
      message="log() called with unknown level '$level': $message"
      level="error"
      ;;
  esac

  _log_to_file "$label" "$message"

  case "$level" in
    error | warn)
      _tool_release
      printf '[%s] %s\n' "$label" "$message" >&2
      ;;
    debug)
      if [[ $VERBOSE == true ]]; then
        printf '[%s] %s\n' "$label" "$message" >&2
      fi
      ;;
    *)
      if [[ $TOOL_HOLD == true && $level == success ]]; then
        TOOL_HELD+="[$label] $message"$'\n'
      elif [[ $QUIET != true || $VERBOSE == true ]]; then
        _tool_release
        printf '[%s] %s\n' "$label" "$message"
      fi
      ;;
  esac
}

# link/update: start holding one tool's success lines (not with -v, and
# not on the interactive screens, which print their own line per tool).
_tool_hold() {
  TOOL_HELD=""
  TOOL_HOLD=false
  if [[ $VERBOSE != true && $QUIET != true ]]; then
    TOOL_HOLD=true
  fi
}

# Print the held lines and stop holding: something is happening.
_tool_release() {
  if [[ $TOOL_HOLD == true ]]; then
    TOOL_HOLD=false
    printf '%s' "$TOOL_HELD"
    TOOL_HELD=""
  fi
}

# End of one tool: nothing changed = one line, as on the interactive
# screen ("bat  installed, linked"); a change = the held lines.
TOOL_WIDTH=0
_tool_done() {
  local tool="$1" line name
  if [[ $TOOL_HOLD != true ]]; then
    return 0
  fi
  if [[ $CHANGED == true ]]; then
    _tool_release
    return 0
  fi
  TOOL_HOLD=false
  TOOL_HELD=""
  # The name column is as wide as the longest name in this run.
  if [[ $TOOL_WIDTH -eq 0 ]]; then
    for name in ${TOOLS[@]+"${TOOLS[@]}"}; do
      if [[ ${#name} -gt $TOOL_WIDTH ]]; then
        TOOL_WIDTH=${#name}
      fi
    done
  fi
  printf -v line '  %-*s  %s' "$TOOL_WIDTH" "$tool" "$(_state_text "$tool")"
  out "$line"
}

# A full-width rule with a title, for -v: "===== installing x (brew) =====".
# No title = a plain rule.
_rule() {
  local title="${1:+ $1 }" total=76 left right pad
  left=$(((total - ${#title}) / 2))
  right=$((total - ${#title} - left))
  printf -v pad '%*s' "$total" ""
  pad="${pad// /=}"
  printf '%s%s%s\n' "${pad:0:left}" "$title" "${pad:0:right}"
}

# Create the log folder and file. If that fails, keep going terminal-only.
init_log() {
  if mkdir -p "$LOG_DIR" 2>/dev/null && touch "$LOG_DIR/dotfiles.log" 2>/dev/null; then
    LOG_FILE="$LOG_DIR/dotfiles.log"
  else
    LOG_FILE=""
    log warn "can't write a log file in $LOG_DIR; logging to the terminal only"
  fi
}

# Runs when the script exits for any reason.
_on_exit() {
  local code="$1" command="$2"
  # set -e stopped the run: say where. Not for "exit N" (the script already
  # said why), and only when the last command is the failure _on_error saw.
  if [[ $code -ne 0 && -n $ERR_LINE && $command == "$ERR_COMMAND" &&
    $command != exit && $command != "exit "* ]]; then
    log error "command failed (exit $code) at line $ERR_LINE: $ERR_COMMAND"
  fi
  # What's installed now, for the next run's config.yml check: after
  # wipe, the tools it removed are still listed for link to set up again.
  case "${LOG_CMD:-}" in
    link | unlink | update | wipe | interactive) _installed_state_save ;;
  esac
  log debug "run finished, exit code $code"
}

# Runs when a command fails: remembers where, for _on_exit. It doesn't log
# itself: Bash 3.2 (macOS /bin/bash) also runs it for failures inside
# if/|| tests in functions and $(…), which aren't errors (Bash 4+ doesn't).
ERR_LINE=""
ERR_COMMAND=""
_on_error() {
  ERR_LINE="$1"
  ERR_COMMAND="$2"
}

trap '_on_exit $? "$BASH_COMMAND"' EXIT
trap '_on_error $LINENO "$BASH_COMMAND"' ERR

# ════════════════════════════════════════════════════════════════════════
# ENVIRONMENT (plan Section 3)
# ════════════════════════════════════════════════════════════════════════

# DOTFILES comes from the environment when set. Otherwise use the folder
# this script lives in, following symlinks (~/.local/bin/dotfiles -> repo).
resolve_dotfiles() {
  if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
    RUNNING_FROM_FILE=true
  fi
  if [[ -n ${DOTFILES:-} ]]; then
    log debug "DOTFILES from the environment: $DOTFILES"
    # On a first run (curl | bash) the clone doesn't exist yet: no warning.
    if [[ $RUNNING_FROM_FILE == true && ! -d $DOTFILES ]]; then
      log warn "DOTFILES is set to $DOTFILES, but that folder doesn't exist"
    fi
  else
    local src="${BASH_SOURCE[0]:-}"
    local target
    if [[ -n $src && -f $src ]]; then
      RUNNING_FROM_FILE=true
      while [[ -L $src ]]; do
        target="$(readlink "$src")"
        case "$target" in
          /*) src="$target" ;;
          *)  src="$(dirname "$src")/$target" ;;
        esac
      done
      DOTFILES="$(cd "$(dirname "$src")" && pwd -P)"
      log debug "DOTFILES not set; using the script's folder: $DOTFILES"
    else
      DOTFILES=""
      log debug "DOTFILES not set and the script isn't running from a file (curl | bash?)"
    fi
  fi

  # Two files: every tool (dotfiles.yml, in the repo), and what this machine
  # uses (config.yml, a real file in ~/.config/dotfiles, never committed).
  if [[ -n $DOTFILES ]]; then
    DOTFILES_TOOLS="$DOTFILES/config/dotfiles/dotfiles.yml"
    HOOKS_DIR="$DOTFILES/config/dotfiles/hooks"
  else
    DOTFILES_TOOLS=""
    HOOKS_DIR=""
  fi
  CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
  DOTFILES_CONFIG="$CONFIG_DIR/config.yml"
  export DOTFILES DOTFILES_CONFIG
  log debug "DOTFILES_TOOLS: ${DOTFILES_TOOLS:-<none>} DOTFILES_CONFIG: $DOTFILES_CONFIG"
}

# ════════════════════════════════════════════════════════════════════════
# OS DETECTION (plan Section 4)
# ════════════════════════════════════════════════════════════════════════

DOTFILES_OS=""      # macos | linux | windows
DOTFILES_DISTRO=""  # display only, Linux only: "<NAME> <kernel>"
DISTRO_ID=""        # internal, Linux only: debian | pacman | fedora
PKG_MANAGER=""      # internal: pacman | apt | dnf | brew | winget
PLATFORM=""         # the dotfiles.yml key: arch | debian | fedora | mac | windows
PLATFORM_KEYS="all" # the keys that apply here, most specific first: "arch linux all"

# Print one field from an os-release file. The file is read, not sourced:
# sourcing would run it as code and overwrite variables like NAME and ID.
_os_release_field() {
  local field="$1" file="$2"
  local key value
  # "|| [[ -n $key ]]" keeps the last line when the file has no final newline.
  while IFS='=' read -r key value || [[ -n $key ]]; do
    if [[ $key == "$field" ]]; then
      value="${value%\"}"
      value="${value#\"}"
      value="${value%\'}"
      value="${value#\'}"
      printf '%s' "$value"
      return 0
    fi
  done <"$file"
}

# Map "ID ID_LIKE..." to the internal distro ID. The first word that
# matches wins, so ID beats ID_LIKE.
_distro_id_from() {
  local word
  # $1 is unquoted on purpose: "omarchy arch" splits into two words.
  for word in $1; do
    case "$word" in
      debian | ubuntu) echo "debian"; return 0 ;;
      arch)            echo "pacman"; return 0 ;;
      fedora)          echo "fedora"; return 0 ;;
    esac
  done
}

detect_linux() {
  local file="/etc/os-release"
  # The os-release spec: use /usr/lib/os-release when /etc has none.
  if [[ ! -r $file ]]; then
    file="/usr/lib/os-release"
  fi
  if [[ ! -r $file ]]; then
    DOTFILES_DISTRO="unknown $(uname -r)"
    log warn "no os-release file found; can't tell which Linux distro this is"
    return 0
  fi

  local id id_like name
  id="$(_os_release_field ID "$file")"
  id_like="$(_os_release_field ID_LIKE "$file")"
  name="$(_os_release_field NAME "$file")"
  log debug "os-release ($file): ID=${id:-<none>} ID_LIKE=${id_like:-<none>} NAME=${name:-<none>}"

  DISTRO_ID="$(_distro_id_from "$id $id_like")"
  DOTFILES_DISTRO="${name:-${id:-unknown}} $(uname -r)"

  if [[ -z $DISTRO_ID ]]; then
    log warn "unsupported Linux distro (ID=$id, ID_LIKE=${id_like:-none}); supported: debian, arch and fedora families"
  fi
}

detect_os() {
  local kernel
  kernel="$(uname -s)"
  log debug "uname -s: $kernel"

  case "$kernel" in
    Darwin)                   DOTFILES_OS="macos" ;;
    Linux)                    DOTFILES_OS="linux"; detect_linux ;;
    MINGW* | MSYS* | CYGWIN*)
      DOTFILES_OS="windows"
      # Git Bash's ln -s silently copies when it can't make a symlink.
      # nativestrict makes it fail instead, so a link is a link or an error.
      export MSYS="winsymlinks:nativestrict${MSYS:+ $MSYS}"
      ;;
    *) log warn "unsupported OS: $kernel" ;;
  esac

  case "$DOTFILES_OS:$DISTRO_ID" in
    linux:pacman) PKG_MANAGER="pacman"; PLATFORM="arch" ;;
    linux:debian) PKG_MANAGER="apt";    PLATFORM="debian" ;;
    linux:fedora) PKG_MANAGER="dnf";    PLATFORM="fedora" ;;
    macos:*)      PKG_MANAGER="brew";   PLATFORM="mac" ;;
    windows:*)    PKG_MANAGER="winget"; PLATFORM="windows" ;;
  esac
  # The dotfiles.yml keys that apply here, most specific first.
  PLATFORM_KEYS="${PLATFORM:+$PLATFORM }"
  if [[ $DOTFILES_OS == linux ]]; then
    PLATFORM_KEYS+="linux "
  fi
  PLATFORM_KEYS+="all"
  export DOTFILES_PLATFORM="$PLATFORM"

  export DOTFILES_OS DOTFILES_DISTRO
  log debug "DOTFILES_OS=${DOTFILES_OS:-<unknown>} DOTFILES_DISTRO=${DOTFILES_DISTRO:-<none>} package manager=${PKG_MANAGER:-<none>} platform=${PLATFORM:-<none>}"
}

# ════════════════════════════════════════════════════════════════════════
# CONFIG FILES (#51)
#   config/dotfiles/dotfiles.yml      every tool: package, links, clones (repo)
#   config/dotfiles/hooks/<tool>.sh   extra steps for a tool (repo, optional)
#   ~/.config/dotfiles/config.yml     this machine: settings, required, tools
# ════════════════════════════════════════════════════════════════════════

BACKUP_SUFFIX=".bak"
THEME="starburst"   # settings.theme: the theme machines without Omarchy use

# Run one yq query against a file (default: dotfiles.yml).
_yq() {
  yq eval "$1" "${2:-$DOTFILES_TOOLS}"
}

# Read both files, once they can be read: dotfiles.yml (and the hooks),
# then this machine's config.yml (written from the old config.yaml on the
# first run after #51), then its settings. Unset = built-in default.
# Runs in the main shell: a first read inside $(…) or < <(…) would be lost
# with the subshell.
load_settings() {
  if [[ -z $DOTFILES_TOOLS || ! -f $DOTFILES_TOOLS ]] || ! command -v yq >/dev/null 2>&1; then
    return 0
  fi
  _cfg_load
  case "$LOG_CMD" in
    help | version) ;;
    *) _config_migrate ;;
  esac
  _machine_load
  local value
  value="$(_cfg_setting theme)"
  THEME="${value:-$THEME}"
  value="$(_cfg_setting backup_suffix)"
  if [[ -n $value ]]; then
    BACKUP_SUFFIX="$value"
  fi
  value="$(_cfg_setting log_file)"
  # "~" in YAML is plain text; ${value/#\~/$HOME} turns a leading ~ into $HOME.
  value="${value/#\~/$HOME}"
  if [[ -n $value && $value != "$LOG_FILE" ]]; then
    if mkdir -p "$(dirname "$value")" 2>/dev/null && touch "$value" 2>/dev/null; then
      log debug "settings.log_file: logging to $value from here on"
      LOG_FILE="$value"
    else
      log warn "settings.log_file: can't write $value; still logging to ${LOG_FILE:-the terminal only}"
    fi
  fi
  log debug "settings: backup_suffix=$BACKUP_SUFFIX log_file=${LOG_FILE:-<none>}"
}

# ─── dotfiles.yml and the hooks, read once per run ──────────────────────
# Every field the script needs comes out of one yq call and is kept in
# shell variables, so asking for a tool's package or links costs nothing
# (one yq call per question made update take ~17 s, and the interactive
# screens ~3 min).
#   CFG_TOOLS               tool names: dotfiles.yml order, then hook-only ones
#   CFG_<id>_PRIO           "high" (priority: high, or PRIORITY=high in the hook)
#   CFG_<id>_HASPKG         1 when the tool has package:
#   CFG_<id>_P_<platform>   "=name" for a package: entry (a list space-separated;
#                           "=" alone for ~: nothing to install there)
#   CFG_<id>_C_<platform>   "=name" for a command: entry (all = a plain command:)
#   CFG_<id>_L              links: "src platform dest" lines (all = one dest)
#   CFG_<id>_K              clones: "repo dest" lines
#   CFG_<id>_HOOK           1 when hooks/<tool>.sh exists
# Records use the unit separator (\x1f) between fields: tabs would collapse
# empty fields when read.
CFG_LOADED=false
CFG_TOOLS=""
readonly CFG_SEP=$'\x1f'

# A name as a variable-name part: letters and digits kept, anything else
# as _<hex> (chromium-flags.conf -> chromium_2dflags_2econf). Into NAME_ID.
NAME_ID=""
_name_id() {
  local name="$1" id="" char i
  # Most names are letters and digits only: nothing to convert.
  if [[ $name != *[!A-Za-z0-9]* ]]; then
    NAME_ID="$name"
    return 0
  fi
  for ((i = 0; i < ${#name}; i++)); do
    char="${name:i:1}"
    case "$char" in
      [A-Za-z0-9]) id+="$char" ;;
      *)
        # printf -v: no $(…) fork for every character of a long path.
        printf -v char '_%02x' "'$char"
        id+="$char"
        ;;
    esac
  done
  NAME_ID="$id"
}

# A tool's variable-name part, into CFG_ID (the last one is remembered).
CFG_ID_FOR=""
CFG_ID=""
_cfg_id() {
  if [[ $1 == "$CFG_ID_FOR" ]]; then
    return 0
  fi
  _name_id "$1"
  CFG_ID_FOR="$1"
  CFG_ID="t_$NAME_ID"
}

_cfg_load() {
  if [[ $CFG_LOADED == true ]]; then
    return 0
  fi
  local dump line kind tool a b c var
  # Marked loaded only once yq has read the file: doctor installs yq first.
  # The whole list after "as $v |" is in ( ): yq binds $v only for the
  # first item of a bare comma list. Every output uses . (the H line its
  # tag): a string made only of literals and $vars is printed even when
  # the select before it let nothing through.
  dump="$(_yq '.tools // {} | to_entries | .[] | .key as $t | .value as $v | (
    ("T\t" + $t + "\t" + (($v.priority // "") | tostring)),
    ($v.package | select(tag == "!!map" or tag == "!!str" or tag == "!!seq") | "H\t" + $t + "\t" + (. | tag)),
    ($v.package | select(tag == "!!str") | "P\t" + $t + "\tall\t" + .),
    ($v.package | select(tag == "!!seq") | "P\t" + $t + "\tall\t" + join(" ")),
    ($v.package | select(tag == "!!map") | to_entries | .[] | select((.value | tag) == "!!seq") | "P\t" + $t + "\t" + .key + "\t" + (.value | join(" "))),
    ($v.package | select(tag == "!!map") | to_entries | .[] | select((.value | tag) == "!!null") | "P\t" + $t + "\t" + .key + "\t"),
    ($v.package | select(tag == "!!map") | to_entries | .[] | select((.value | tag) != "!!seq" and (.value | tag) != "!!null" and (.value | tag) != "!!map") | "P\t" + $t + "\t" + .key + "\t" + (.value | tostring)),
    ($v.command | select(tag == "!!str") | "C\t" + $t + "\tall\t" + .),
    ($v.command | select(tag == "!!map") | to_entries | .[] | "C\t" + $t + "\t" + .key + "\t" + (.value | tostring)),
    ($v.links | select(tag == "!!map") | to_entries | .[] | .key as $s |
      ((.value | select(tag == "!!str") | "L\t" + $t + "\t" + $s + "\tall\t" + .),
       (.value | select(tag == "!!map") | to_entries | .[] | "L\t" + $t + "\t" + $s + "\t" + .key + "\t" + ((.value // "") | tostring)))),
    ($v.clone | select(tag == "!!map") | to_entries | .[] | "K\t" + $t + "\t" + .key + "\t" + ((.value // "") | tostring)) )' 2>/dev/null)" || return 0
  CFG_LOADED=true
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    line="${line//$'\t'/$CFG_SEP}"
    IFS="$CFG_SEP" read -r kind tool a b c <<<"$line"
    _cfg_id "$tool"
    case "$kind" in
      T)
        CFG_TOOLS+="$tool"$'\n'
        if [[ $a == high ]]; then
          printf -v "CFG_${CFG_ID}_PRIO" 'high'
        fi
        ;;
      H) printf -v "CFG_${CFG_ID}_HASPKG" '1' ;;
      # Platform keys are plain words; anything else is left for doctor.
      P | C)
        if [[ $a =~ ^[A-Za-z0-9_]+$ ]]; then
          printf -v "CFG_${CFG_ID}_${kind}_$a" '=%s' "$b"
        fi
        ;;
      L)
        var="CFG_${CFG_ID}_L"
        printf -v "$var" '%s%s\n' "${!var:-}" "$a$CFG_SEP$b$CFG_SEP$c"
        ;;
      K)
        var="CFG_${CFG_ID}_K"
        printf -v "$var" '%s%s\n' "${!var:-}" "$a$CFG_SEP$b"
        ;;
    esac
  done <<<"$dump"

  # Hooks: config/dotfiles/hooks/<tool>.sh. A hook with no dotfiles.yml
  # entry is a tool of its own (after the others, by name).
  local hook name high=""
  if [[ -n $HOOKS_DIR && -d $HOOKS_DIR ]]; then
    high="$(grep -l '^PRIORITY=high' "$HOOKS_DIR"/*.sh 2>/dev/null)" || true
    for hook in "$HOOKS_DIR"/*.sh; do
      [[ -f $hook ]] || continue
      name="${hook##*/}"
      name="${name%.sh}"
      _cfg_id "$name"
      printf -v "CFG_${CFG_ID}_HOOK" '1'
      if [[ $'\n'$high$'\n' == *$'\n'"$hook"$'\n'* ]]; then
        printf -v "CFG_${CFG_ID}_PRIO" 'high'
      fi
      if ! _tool_exists "$name"; then
        CFG_TOOLS+="$name"$'\n'
      fi
    done
  fi
}

# Read dotfiles.yml and the hooks again (update, after the pull).
_cfg_reload() {
  local var
  # compgen -v lists the variables with that prefix (Bash 3.2 has it too).
  for var in $(compgen -v CFG_t_) $(compgen -v CFG_F_); do
    unset "$var"
  done
  CFG_LOADED=false
  CFG_TOOLS=""
  CFG_ID_FOR=""
  _cfg_load
}

# Every tool, one per line: dotfiles.yml order, then hook-only ones.
manifest_tools() {
  _cfg_load
  printf '%s' "$CFG_TOOLS"
}

# True when the name is a tool (in dotfiles.yml or a hook).
_tool_exists() {
  _cfg_load
  [[ $'\n'$CFG_TOOLS == *$'\n'"$1"$'\n'* ]]
}

# Every tool, space-separated, for "unknown tool" messages.
_tool_names() {
  manifest_tools | paste -sd ' ' -
}

# This platform's entry in a per-platform map (package:, command:, a link's
# dests): its own key (arch, mac…), then linux (on Linux), then all.
# $1 is the variable prefix (CFG_t_fd_P); the value goes into PICKED.
# Returns 1 when no key matches. PLATFORM_KEYS is set by detect_os.
PICKED=""
_cfg_pick() {
  local key var
  PICKED=""
  for key in $PLATFORM_KEYS; do
    var="$1_$key"
    if [[ -n ${!var:-} ]]; then
      PICKED="${!var#=}"
      return 0
    fi
  done
  return 1
}

# A link's rank for this platform: its own key 3, linux 2, all 1, else 0.
_platform_rank() {
  case "$1" in
    "$PLATFORM") PLATFORM_RANK=3 ;;
    linux) if [[ $DOTFILES_OS == linux ]]; then PLATFORM_RANK=2; else PLATFORM_RANK=0; fi ;;
    all) PLATFORM_RANK=1 ;;
    *) PLATFORM_RANK=0 ;;
  esac
}
PLATFORM_RANK=0

_tool_has_hook() {
  _cfg_load
  _cfg_id "$1"
  local var="CFG_${CFG_ID}_HOOK"
  [[ -n ${!var:-} ]]
}

_tool_is_high() {
  _cfg_load
  _cfg_id "$1"
  local var="CFG_${CFG_ID}_PRIO"
  [[ ${!var:-} == high ]]
}

# True when the tool is used on this platform: it has a hook (the hook
# handles the platforms package: doesn't list), or no package: at all
# (links only), or a package: entry for this platform (~ included).
_tool_is_used_here() {
  _cfg_load
  _cfg_id "$1"
  local var="CFG_${CFG_ID}_HOOK"
  if [[ -n ${!var:-} ]]; then
    return 0
  fi
  var="CFG_${CFG_ID}_HASPKG"
  if [[ -z ${!var:-} ]]; then
    return 0
  fi
  _cfg_pick "CFG_${CFG_ID}_P"
}

# Package name on this platform. Empty = nothing to install here (~, no
# package:, or a platform only the hook handles). A list (brew:
# [1password, 1password-cli]) comes out space-separated; package_version,
# pm_install and pm_remove handle each name.
tool_package() {
  _tool_package_get "$1"
  echo "$TOOL_PACKAGE"
}

# tool_package into TOOL_PACKAGE.
TOOL_PACKAGE=""
_tool_package_get() {
  _cfg_load
  _cfg_id "$1"
  TOOL_PACKAGE=""
  if _cfg_pick "CFG_${CFG_ID}_P"; then
    TOOL_PACKAGE="$PICKED"
  fi
}

# Command that proves the tool is installed: command: (this platform's
# entry when it's a map), else the tool's name.
tool_command() {
  _tool_command_get "$1"
  echo "$TOOL_COMMAND"
}

# tool_command into TOOL_COMMAND.
TOOL_COMMAND=""
_tool_command_get() {
  _cfg_load
  _cfg_id "$1"
  TOOL_COMMAND="$1"
  if _cfg_pick "CFG_${CFG_ID}_C" && [[ -n $PICKED ]]; then
    TOOL_COMMAND="$PICKED"
  fi
}

# A dest from dotfiles.yml as the script uses it: $HOME/… (or ~/…) becomes
# relative to $HOME, anything else absolute stays (a system file). Into DEST.
DEST=""
_dest_norm() {
  DEST="$1"
  case "$DEST" in
    '$HOME/'*) DEST="${DEST#\$HOME/}" ;;
    '${HOME}/'*) DEST="${DEST#\$\{HOME\}/}" ;;
    '~/'*) DEST="${DEST#\~/}" ;;
    "$HOME/"*) DEST="${DEST#"$HOME"/}" ;;
  esac
}

# Links, one "src<TAB>dest" line each: this platform's dest when a link
# has several (no dest for this platform = not linked here). dest is
# relative to $HOME, or absolute for a system file. Nothing for a tool
# that isn't used here.
tool_links() {
  if ! _tool_is_used_here "$1"; then
    return 0
  fi
  _cfg_id "$1"
  local var="CFG_${CFG_ID}_L" src platform dest cur="" best="" best_rank=0
  while IFS="$CFG_SEP" read -r src platform dest; do
    [[ -n $src ]] || continue
    if [[ $src != "$cur" ]]; then
      if [[ -n $cur && -n $best ]]; then
        _dest_norm "$best"
        printf '%s\t%s\n' "$cur" "$DEST"
      fi
      cur="$src" best="" best_rank=0
    fi
    _platform_rank "$platform"
    if [[ $PLATFORM_RANK -gt $best_rank ]]; then
      best="$dest" best_rank=$PLATFORM_RANK
    fi
  done <<<"${!var:-}"
  if [[ -n $cur && -n $best ]]; then
    _dest_norm "$best"
    printf '%s\t%s\n' "$cur" "$DEST"
  fi
}

# What a link is, from its files (nothing to write in dotfiles.yml), into
# LINK_COPY, LINK_INJECT and LINK_ENABLE (true/false):
#   copy    dest is outside $HOME (/etc, /usr): a root-owned copy, never a
#           symlink (root must not run files you can edit)
#   enable  a copied systemd unit with [Install]: systemctl enable --now
#   inject  a file with op:// references: dest gets a copy filled in from
#           1Password instead of a symlink
# The file checks are kept for the run (CFG_F_<src>), so the lists don't
# grep every file again for every tool.
LINK_COPY=false LINK_INJECT=false LINK_ENABLE=false
_link_flags_get() {
  local src="$1" dest="$2" var src_path
  LINK_COPY=false LINK_INJECT=false LINK_ENABLE=false
  case "$dest" in
    /*) LINK_COPY=true ;;
  esac
  _name_id "$src"
  var="CFG_F_$NAME_ID"
  if [[ -z ${!var:-} ]]; then
    src_path="$DOTFILES/config/$src"
    printf -v "$var" '%s' "-"
    if [[ -f $src_path ]]; then
      if grep -q 'op://' "$src_path" 2>/dev/null; then
        printf -v "$var" '%s' "${!var}i"
      fi
      if grep -q '^\[Install\]' "$src_path" 2>/dev/null; then
        printf -v "$var" '%s' "${!var}u"
      fi
    fi
  fi
  if [[ $LINK_COPY == true ]]; then
    if [[ ${!var} == *u* && $dest == /etc/systemd/* ]]; then
      LINK_ENABLE=true
    fi
  elif [[ ${!var} == *i* ]]; then
    LINK_INJECT=true
  fi
}

# One flag of a link as true/false: _link_flag <src> <dest> copy|inject|enable
_link_flag() {
  _link_flags_get "$1" "$2"
  case "$3" in
    copy) echo "$LINK_COPY" ;;
    inject) echo "$LINK_INJECT" ;;
    enable) echo "$LINK_ENABLE" ;;
  esac
}
tool_link_enable() { _link_flag "$1" "$2" enable; }

# A link dest as a full path, and as shown in messages: under $HOME
# unless it's absolute (system files).
_dest_path() {
  case "$1" in
    /*) echo "$1" ;;
    *) echo "$HOME/$1" ;;
  esac
}
_dest_shown() {
  case "$1" in
    /*) echo "$1" ;;
    *) echo "~/$1" ;;
  esac
}

# Repos to clone, one "repo<TAB>dest" line each (dest relative to $HOME).
# owner/repo is on GitHub; anything with :// or git@ is used as written.
tool_clones() {
  if ! _tool_is_used_here "$1"; then
    return 0
  fi
  _cfg_id "$1"
  local var="CFG_${CFG_ID}_K" repo dest
  while IFS="$CFG_SEP" read -r repo dest; do
    if [[ -z $repo && -z $dest ]]; then
      continue
    fi
    case "$repo" in
      *://* | git@*) ;;
      ?*/?*) repo="https://github.com/$repo.git" ;;
    esac
    _dest_norm "$dest"
    printf '%s\t%s\n' "$repo" "$DEST"
  done <<<"${!var:-}"
}

# ─── config.yml: this machine ───────────────────────────────────────────
#   CFG_REQUIRED    required: names, one per line
#   CFG_USED        tools: names, one per line
#   CFG_SET_<key>   "=value" for a settings: entry
MACHINE_LOADED=false
CFG_REQUIRED=""
CFG_USED=""

_machine_load() {
  if [[ $MACHINE_LOADED == true ]]; then
    return 0
  fi
  MACHINE_LOADED=true
  CFG_REQUIRED=""
  CFG_USED=""
  if [[ ! -f $DOTFILES_CONFIG ]] || ! command -v yq >/dev/null 2>&1; then
    return 0
  fi
  local dump line kind a b
  if ! dump="$(_yq '(.settings // {} | to_entries | .[] | select((.value | tag) != "!!null") | "G\t" + .key + "\t" + (.value | tostring)),
    (.required // [] | .[] | "R\t" + (. | tostring)),
    (.tools // [] | .[] | "U\t" + (. | tostring))' "$DOTFILES_CONFIG" 2>/dev/null)"; then
    log warn "$(_tilde "$DOTFILES_CONFIG") can't be read; run: dotfiles doctor"
    return 0
  fi
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    line="${line//$'\t'/$CFG_SEP}"
    IFS="$CFG_SEP" read -r kind a b <<<"$line"
    case "$kind" in
      G)
        # Only names a variable can have (settings keys are plain words).
        if [[ $a =~ ^[A-Za-z0-9_]+$ ]]; then
          printf -v "CFG_SET_$a" '=%s' "$b"
        fi
        ;;
      R) CFG_REQUIRED+="$a"$'\n' ;;
      U) CFG_USED+="$a"$'\n' ;;
    esac
  done <<<"$dump"
}

# A settings: value, or nothing when it isn't set.
_cfg_setting() {
  _machine_load
  local var="CFG_SET_$1" value
  value="${!var:-}"
  echo "${value#=}"
}

# required: on this machine (unlink and the interactive screen keep it).
_tool_is_required() {
  _machine_load
  [[ $'\n'$CFG_REQUIRED == *$'\n'"$1"$'\n'* ]]
}

# In config.yml at all (required: or tools:): the tool is used here.
_tool_is_listed() {
  _machine_load
  [[ $'\n'$CFG_REQUIRED$'\n'$CFG_USED == *$'\n'"$1"$'\n'* ]]
}

# "required", "tools" or "-": where config.yml lists the tool.
_tool_listed_as() {
  if _tool_is_required "$1"; then
    echo required
  elif _tool_is_listed "$1"; then
    echo tools
  else
    echo -
  fi
}

# Every tool in config.yml that is a tool and used on this platform.
_listed_tools() {
  local tool
  while IFS= read -r tool; do
    if _tool_is_listed "$tool" && _tool_is_used_here "$tool"; then
      echo "$tool"
    fi
  done < <(manifest_tools)
}

# The tools named in the arguments, in run order: priority: high, then
# required here, then the rest; dotfiles.yml order within each.
_order_tools() {
  local wanted tool pass
  wanted=$'\n'"$(printf '%s\n' "$@")"$'\n'
  for pass in high required rest; do
    while IFS= read -r tool; do
      [[ -n $tool && $wanted == *$'\n'"$tool"$'\n'* ]] || continue
      case "$pass" in
        high) _tool_is_high "$tool" || continue ;;
        required) { ! _tool_is_high "$tool" && _tool_is_required "$tool"; } || continue ;;
        rest) { ! _tool_is_high "$tool" && ! _tool_is_required "$tool"; } || continue ;;
      esac
      echo "$tool"
    done <<<"$CFG_TOOLS"
  done
}

# A list as YAML: "key: []", or "key:" with one "  - name" line each.
_yaml_list() {
  local key="$1" names="$2" name
  if [[ -z ${names//$'\n'/} ]]; then
    echo "$key: []"
    return 0
  fi
  echo "$key:"
  while IFS= read -r name; do
    if [[ -n $name ]]; then
      echo "  - $name"
    fi
  done <<<"$names"
}

# A new config.yml. $1: settings lines ("  theme: starburst"), if any.
_config_template() {
  cat <<EOF
# This machine's dotfiles setup: never in the repo. dotfiles rewrites
# required: and tools: (alphabetical); everything else here, and your own
# edits, are kept. Every run, a tool installed here goes into tools: and
# one removed outside dotfiles comes off; one you add by hand stays until
# link installs it.

settings:
${1:-  # theme: starburst}
  # log_file: ~/.local/state/dotfiles/dotfiles.log
  # backup_suffix: .bak

# Required here: unlink and the interactive screen never remove these
# (unlink --force does, and takes the tool off this list).
required: []

# The other tools used here.
tools: []
EOF
}

# Write required: and tools: (each sorted) into config.yml. Only those two
# blocks change: comments, settings and hand edits stay. A missing file is
# made from the template first.
_config_write() {
  local required="$1" used="$2" file="$DOTFILES_CONFIG" tmp
  if [[ -L $CONFIG_DIR && $(_physical "$CONFIG_DIR") == "$(_physical "$DOTFILES/config/dotfiles")" ]]; then
    log error "$(_tilde "$CONFIG_DIR") still links into the repo; config.yml must not go in git (run: dotfiles doctor)"
    return 1
  fi
  mkdir -p "$CONFIG_DIR"
  if [[ ! -f $file ]]; then
    _config_template >"$file"
  fi
  tmp="$file.tmp.$$"
  REQ_BLOCK="$(_yaml_list required "$(printf '%s' "$required" | sort -u)")" \
    TOOLS_BLOCK="$(_yaml_list tools "$(printf '%s' "$used" | sort -u)")" \
    awk '
      function block(k) { return (k == "required") ? ENVIRON["REQ_BLOCK"] : ENVIRON["TOOLS_BLOCK"] }
      /^(required|tools):/ {
        k = $0; sub(/:.*/, "", k)
        if (!(k in done)) { print block(k); done[k] = 1 }
        skip = 1; next
      }
      skip && /^([ \t]|-)/ { next }
      { skip = 0; print }
      END {
        if (!("required" in done)) { print ""; print block("required") }
        if (!("tools" in done)) { print ""; print block("tools") }
      }
    ' "$file" >"$tmp"
  if ! yq eval '.' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    log error "couldn't update $(_tilde "$file") (it isn't valid YAML afterwards); left it as it was"
    return 1
  fi
  mv "$tmp" "$file"
}

# Put a tool in config.yml: required, tools, or none (taken off both).
#   _config_set <tool> required|tools|none
_config_set() {
  local tool="$1" where="$2" required="" used="" name before
  _machine_load
  before="$(_tool_listed_as "$tool")"
  if [[ $before == "$where" || ( $where == none && $before == - ) ]]; then
    log debug "$tool: config.yml already has it as $before"
    return 0
  fi
  while IFS= read -r name; do
    if [[ -n $name && $name != "$tool" ]]; then
      required+="$name"$'\n'
    fi
  done <<<"$CFG_REQUIRED"
  while IFS= read -r name; do
    if [[ -n $name && $name != "$tool" ]]; then
      used+="$name"$'\n'
    fi
  done <<<"$CFG_USED"
  case "$where" in
    required) required+="$tool"$'\n' ;;
    tools) used+="$tool"$'\n' ;;
  esac
  local what
  case "$where" in
    required) what="added to required:" ;;
    tools) what="added to tools:" ;;
    none) what="taken off $before:" ;;
  esac
  if [[ $DRY_RUN == true ]]; then
    log info "dry run, $tool: would be $what in config.yml"
  else
    _config_write "$required" "$used" || return 1
    log info "$tool: $what in config.yml"
  fi
  CFG_REQUIRED="$required"
  CFG_USED="$used"
}

# ─── first run after #51: config.yaml -> config.yml ─────────────────────
# ~/.config/dotfiles used to link to the repo's config/dotfiles, and each
# tool's enabled:/locked: lived in the repo's config.yaml. Now the folder
# is a real one, and config.yml is written from those values (enabled =
# used here, locked = required), so nothing gets switched off. The old file
# comes from the working tree, or from git once the pull removed it. No old
# file = a new machine: empty lists. Either way _config_sync then lists
# only what's installed here.
_config_migrate() {
  if [[ -z $DOTFILES ]]; then
    return 0
  fi
  local shown repo_link=false
  shown="$(_tilde "$CONFIG_DIR")"
  if [[ -L $CONFIG_DIR ]]; then
    if [[ $(_physical "$CONFIG_DIR") == "$(_physical "$DOTFILES/config/dotfiles")" ]]; then
      if [[ $DRY_RUN == true ]]; then
        # Still the link in a dry run: whatever is "there" is the repo's.
        repo_link=true
        log info "dry run, would replace the link $shown (to the repo) with a real folder for config.yml"
      else
        rm "$CONFIG_DIR"
        mkdir -p "$CONFIG_DIR"
        log info "$shown linked to the repo; it's a real folder now (it holds config.yml)"
      fi
    else
      log debug "$shown links to $(readlink "$CONFIG_DIR"); config.yml is read from there"
    fi
  fi
  if [[ $repo_link != true && -f $DOTFILES_CONFIG ]]; then
    return 0
  fi

  local old="" from="" rev
  if [[ -f $DOTFILES/config/dotfiles/config.yaml ]]; then
    old="$(cat "$DOTFILES/config/dotfiles/config.yaml")"
    from="config/dotfiles/config.yaml"
  elif command -v git >/dev/null 2>&1 &&
    rev="$(git -C "$DOTFILES" log -1 --diff-filter=D --format=%h -- config/dotfiles/config.yaml 2>/dev/null)" && [[ -n $rev ]]; then
    old="$(git -C "$DOTFILES" show "$rev^:config/dotfiles/config.yaml" 2>/dev/null)" || old=""
    from="config.yaml from git (before $rev)"
  fi

  local dump="" line kind a b required="" used="" settings=""
  if [[ -n $old ]]; then
    dump="$(yq eval '(.packages // {} | to_entries | .[] | select(.value.enabled == true) |
        ((select(.value.locked == true) | "R\t" + .key), (select(.value.locked != true) | "U\t" + .key))),
      (.settings // {} | to_entries | .[] | select((.value | tag) != "!!null") | "G\t" + .key + "\t" + (.value | tostring))' - <<<"$old" 2>/dev/null)" || dump=""
  fi
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    IFS=$'\t' read -r kind a b <<<"$line"
    case "$kind" in
      R | U)
        # Only tools that still exist and are used on this platform.
        _tool_exists "$a" && _tool_is_used_here "$a" || continue
        if [[ $kind == R ]]; then required+="$a"$'\n'; else used+="$a"$'\n'; fi
        ;;
      G) settings+="  $a: $b"$'\n' ;;
    esac
  done <<<"$dump"
  settings="${settings%$'\n'}"

  local counts
  if [[ -n $from ]]; then
    counts="$(grep -c . <<<"$required" || true) required, $(grep -c . <<<"$used" || true) other tools"
  fi
  if [[ $DRY_RUN == true ]]; then
    if [[ -n $from ]]; then
      log info "dry run, would write $shown/config.yml from $from ($counts)"
    else
      log info "dry run, would write an empty $shown/config.yml (new machine)"
    fi
  else
    mkdir -p "$CONFIG_DIR"
    _config_template "$settings" >"$DOTFILES_CONFIG"
    if [[ -n $from ]]; then
      _config_write "$required" "$used" || return 0
      log success "wrote $shown/config.yml from $from ($counts)"
    else
      log info "new machine: wrote $shown/config.yml (the tools installed here go in it); pick more with: dotfiles (or dotfiles link <tool>)"
    fi
  fi
  # This run uses the new lists (a dry run has no file to read them from).
  MACHINE_LOADED=true
  CFG_REQUIRED="$required"
  CFG_USED="$used"
  while IFS= read -r line; do
    [[ $line =~ ^\ \ ([A-Za-z0-9_]+):\ (.*)$ ]] || continue
    printf -v "CFG_SET_${BASH_REMATCH[1]}" '=%s' "${BASH_REMATCH[2]}"
  done <<<"$settings"
}

# ─── config.yml follows the machine (every run) ─────────────────────────
# config.yml lists the tools installed here: one installed outside dotfiles
# goes into tools:, one removed outside dotfiles comes off. INSTALLED_STATE
# remembers what was installed at the end of the last run, so a tool added
# to the file by hand (not installed yet: link installs it) isn't mistaken
# for one that was removed. Names that aren't tools used here, and which
# list a tool is in, are left as they are.
INSTALLED_STATE="$LOG_DIR/installed"
SYNC_READY=false

# "name" is one of the lines in $2.
_in_lines() {
  [[ $'\n'$2$'\n' == *$'\n'"$1"$'\n'* ]]
}

# The tools used here that are installed now, one per line.
_installed_now() {
  local tool
  while IFS= read -r tool; do
    if _tool_is_used_here "$tool" && _tool_is_installed "$tool"; then
      echo "$tool"
    fi
  done < <(manifest_tools)
}

_config_sync() {
  if [[ $MACHINE_LOADED != true || -z $DOTFILES_TOOLS || ! -f $DOTFILES_TOOLS ]]; then
    return 0
  fi
  if [[ ! -f $DOTFILES_CONFIG && $DRY_RUN != true ]]; then
    return 0
  fi
  SYNC_READY=true
  local now before="" have_state=false name required="" used="" added="" dropped=""
  now="$(_installed_now)"
  if [[ -f $INSTALLED_STATE ]]; then
    have_state=true
    before="$(<"$INSTALLED_STATE")"
  fi
  # Listed but not installed: removed outside dotfiles when it was
  # installed last time (or there's no last time yet); otherwise added by
  # hand, and kept for link to install.
  local list kept
  for list in required used; do
    kept=""
    while IFS= read -r name; do
      [[ -n $name ]] || continue
      if _tool_exists "$name" && _tool_is_used_here "$name" && ! _in_lines "$name" "$now" &&
        { [[ $have_state != true ]] || _in_lines "$name" "$before"; }; then
        dropped="${dropped:+$dropped }$name"
        continue
      fi
      kept+="$name"$'\n'
    done <<<"$(if [[ $list == required ]]; then printf '%s' "$CFG_REQUIRED"; else printf '%s' "$CFG_USED"; fi)"
    if [[ $list == required ]]; then required="$kept"; else used="$kept"; fi
  done
  # Installed but not listed: into tools:.
  while IFS= read -r name; do
    [[ -n $name ]] || continue
    if ! _in_lines "$name" "$required$used"; then
      used+="$name"$'\n'
      added="${added:+$added }$name"
    fi
  done <<<"$now"

  if [[ -n $added || -n $dropped ]]; then
    if [[ $DRY_RUN == true ]]; then
      [[ -z $added ]] || log info "dry run, config.yml: would add (installed here): $added"
      [[ -z $dropped ]] || log info "dry run, config.yml: would take off (not installed): $dropped"
    elif _config_write "$required" "$used"; then
      [[ -z $added ]] || log info "config.yml: added (installed here): $added"
      [[ -z $dropped ]] || log info "config.yml: took off (not installed any more): $dropped"
    else
      return 0
    fi
    CFG_REQUIRED="$required"
    CFG_USED="$used"
  fi
  _installed_state_save "$now"
}

# Write INSTALLED_STATE (not in a dry run). No argument: look again, with a
# fresh package list (the run may have installed or removed packages).
_installed_state_save() {
  if [[ $DRY_RUN == true || ${SYNC_READY:-} != true ]]; then
    return 0
  fi
  local now
  if [[ $# -gt 0 ]]; then
    now="$1"
  else
    pkg_cache_load
    now="$(_installed_now)"
  fi
  if mkdir -p "$(dirname "$INSTALLED_STATE")" 2>/dev/null; then
    printf '%s\n' "$now" >"$INSTALLED_STATE" 2>/dev/null || true
  fi
}

# Print the installed version of a package, or return 1 if it isn't
# installed. Asks the package manager, because a package name often isn't
# a command (bind provides dig and nslookup).
# Several names (a list in dotfiles.yml): all must be installed; prints the
# first one's version.
package_version() {
  local name first="" version
  for name in $1; do
    if ! version="$(_package_version_one "$name")"; then
      return 1
    fi
    first="${first:-$version}"
  done
  if [[ -z $first ]]; then
    return 1
  fi
  echo "$first"
}

# Every installed pacman package and its version, read once in the main
# shell (pkg_cache_load) so each $(…) check is a lookup instead of a pacman
# call (~60 ms each, once per tool on every screen). A name that isn't in
# it still asks pacman: pacman -Q also finds provided names (sh -> bash).
# Needs an associative array (Bash 4); pacman machines have Bash 5.
PKG_CACHE_LOADED=false
pkg_cache_load() {
  PKG_CACHE_LOADED=false
  if [[ $PKG_MANAGER != pacman ]] || ((BASH_VERSINFO[0] < 4)) || ! command -v pacman >/dev/null 2>&1; then
    return 0
  fi
  local list name version
  list="$(pacman -Q 2>/dev/null)" || return 0
  unset PKG_VERSIONS
  declare -gA PKG_VERSIONS=()
  while read -r name version; do
    PKG_VERSIONS[$name]="$version"
  done <<<"$list"
  PKG_CACHE_LOADED=true
}

_package_version_one() {
  local package="$1" output
  case "$PKG_MANAGER" in
    pacman)
      # aur/<name>: installed from the AUR, but pacman -Q knows it all the same.
      package="${package#aur/}"
      if [[ $PKG_CACHE_LOADED == true && -n ${PKG_VERSIONS[$package]:-} ]]; then
        echo "${PKG_VERSIONS[$package]}"
        return 0
      fi
      output="$(pacman -Q "$package" 2>/dev/null)" || return 1
      echo "${output#* }"
      ;;
    apt)
      output="$(dpkg-query -W -f='${Status} ${Version}' "$package" 2>/dev/null)" || return 1
      case "$output" in
        "install ok installed "*) echo "${output##* }" ;;
        *) return 1 ;;
      esac
      ;;
    dnf)
      output="$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$package" 2>/dev/null)" || return 1
      echo "$output"
      ;;
    brew)
      output="$(brew list --versions "$package" 2>/dev/null)" || return 1
      if [[ -z $output ]]; then
        return 1
      fi
      echo "${output#* }"
      ;;
    winget)
      winget list -e --id "$package" >/dev/null 2>&1 || return 1
      echo "installed"
      ;;
    *)
      return 1
      ;;
  esac
}

# Print the version the package manager would install, or nothing.
# Used by dry runs, before anything is installed.
package_available_version() {
  local package="${1%% *}" output
  case "$PKG_MANAGER" in
    pacman)
      if [[ $package == aur/* ]]; then
        output="$(yay -Si "${package#aur/}" 2>/dev/null)" || return 0
      else
        output="$(pacman -Si "$package" 2>/dev/null)" || return 0
      fi
      awk -F': ' '/^Version/ { print $2; exit }' <<<"$output"
      ;;
    apt)
      output="$(apt-cache policy "$package" 2>/dev/null)" || return 0
      awk '/Candidate:/ { if ($2 != "(none)") print $2; exit }' <<<"$output"
      ;;
    dnf)
      dnf repoquery --latest-limit 1 --qf '%{version}-%{release}' "$package" 2>/dev/null | head -n 1 || true
      ;;
    brew)
      output="$(brew info "$package" 2>/dev/null)" || return 0
      # First line: "==> name: stable 1.2.3 (bottled)"
      awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "stable") { print $(i + 1); exit } }' <<<"$output"
      ;;
    winget)
      output="$(winget show -e --id "$package" 2>/dev/null)" || return 0
      awk -F': ' '/^Version/ { print $2; exit }' <<<"$output"
      ;;
  esac
}

# "name (version)" for summaries: the installed version, or in a dry run
# the version that would be installed.
_with_version() {
  local name="$1" version="$2"
  if [[ -n $version ]]; then
    echo "$name ($version)"
  else
    echo "$name"
  fi
}

# ════════════════════════════════════════════════════════════════════════
# RUNNING COMMANDS AND INSTALLING PACKAGES
# Bare bones, so doctor can install its prerequisites. Step 7 builds the
# link (install) and unlink (remove) on top of this.
# ════════════════════════════════════════════════════════════════════════

# Run a command that changes the system. Its output shows in the terminal
# and goes into the log file line by line. Honors --dry-run.
CHANGED=false   # set by run_cmd: something was changed (or would be, in a dry run)
HIDE_OUTPUT=false   # set by _pm: the package manager's own output shows only with -v
run_cmd() {
  CHANGED=true
  if [[ $DRY_RUN == true ]]; then
    log info "dry run, would run: $*"
    return 0
  fi
  log info "running: $*"
  local line
  # With pipefail, the pipeline's exit code is the command's, not the loop's.
  # </dev/null: the command can't eat input meant for a loop around run_cmd.
  "$@" </dev/null 2>&1 | while IFS= read -r line || [[ -n $line ]]; do
    if [[ ( $QUIET != true && $HIDE_OUTPUT != true ) || $VERBOSE == true ]]; then
      printf '%s\n' "$line"
    fi
    _log_to_file "DEBUG" "  > $line"
  done
}

APT_UPDATED="${APT_UPDATED:-false}"

# Install or remove one package with this OS's package manager.
# _pm install|remove <package>
_pm() {
  local action="$1" package="$2"
  local -a cmd

  case "$action:$PKG_MANAGER" in
    # aur/<name> (dotfiles.yml): an AUR package, installed with yay. yay
    # runs as you and asks for sudo itself; pacman removes it like any other.
    install:pacman)
      if [[ $package == aur/* ]]; then
        cmd=(yay -S --needed --noconfirm --answerdiff None --answerclean None "${package#aur/}")
      else
        cmd=(pacman -S --needed --noconfirm "$package")
      fi
      ;;
    remove:pacman)  cmd=(pacman -R --noconfirm "${package#aur/}") ;;
    # apt (not apt-get), as used by hand on Debian/Ubuntu. The -o option turns
    # off apt's "no stable CLI interface" warning, printed when its output is
    # piped (run_cmd pipes it into the log).
    install:apt)    cmd=(apt -o Apt::Cmd::Disable-Script-Warning=true install -y "$package") ;;
    remove:apt)     cmd=(apt -o Apt::Cmd::Disable-Script-Warning=true remove -y "$package") ;;
    install:dnf)    cmd=(dnf install -y "$package") ;;
    remove:dnf)     cmd=(dnf remove -y "$package") ;;
    install:brew)   cmd=(brew install "$package") ;;
    remove:brew)    cmd=(brew uninstall "$package") ;;
    install:winget)
      cmd=(winget install -e --accept-package-agreements --accept-source-agreements --id "$package")
      ;;
    remove:winget)  cmd=(winget uninstall -e --id "$package") ;;
    *)
      log error "can't $action $package: no package manager for ${DOTFILES_OS:-this OS}"
      return 1
      ;;
  esac

  if [[ $PKG_MANAGER == brew ]] && ! command -v brew >/dev/null 2>&1; then
    log error "can't $action $package: Homebrew isn't installed (https://brew.sh)"
    return 1
  fi

  if [[ ${cmd[0]} == yay ]]; then
    if ! command -v yay >/dev/null 2>&1; then
      log error "can't $action $package: it's an AUR package and yay isn't installed"
      return 1
    fi
    if [[ $EUID -eq 0 ]]; then
      log error "can't $action $package: yay doesn't run as root"
      return 1
    fi
  # Linux package managers need root. $EUID is 0 when already root (VMs, containers).
  elif [[ $DOTFILES_OS == linux && $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      log error "can't $action $package: needs root, and sudo isn't installed"
      return 1
    fi
    cmd=(sudo "${cmd[@]}")
  fi
  # The package manager's own output (downloads, brew's warnings) goes to
  # the log; the terminal shows it only with -v. The [INFO] lines stay.
  HIDE_OUTPUT=true
  # apt needs fresh package lists on a new machine; once per run is enough.
  if [[ $action == install && $PKG_MANAGER == apt && $APT_UPDATED != true ]]; then
    APT_UPDATED=true
    if [[ ${cmd[0]} == sudo ]]; then
      run_cmd sudo apt -o Apt::Cmd::Disable-Script-Warning=true update
    else
      run_cmd apt -o Apt::Cmd::Disable-Script-Warning=true update
    fi
  fi

  local code=0
  run_cmd "${cmd[@]}" || code=$?
  HIDE_OUTPUT=false
  # The installed packages changed: read the list again.
  if [[ $PKG_CACHE_LOADED == true && $DRY_RUN != true ]]; then
    pkg_cache_load
  fi
  return "$code"
}

# Several names: each one that's missing is installed (each installed one
# removed), one package manager call per name.
pm_install() {
  local name
  for name in $1; do
    if [[ $1 == *" "* ]] && _package_version_one "$name" >/dev/null; then
      log debug "package $name: already installed"
      continue
    fi
    _pm install "$name" || return 1
  done
}
pm_remove() {
  local name
  for name in $1; do
    if [[ $1 == *" "* ]] && ! _package_version_one "$name" >/dev/null; then
      continue
    fi
    _pm remove "$name" || return 1
  done
}

# ════════════════════════════════════════════════════════════════════════
# ARGUMENTS (plan Section 7)
# ════════════════════════════════════════════════════════════════════════

# Flags can go anywhere on the line. Everything else lands in ARGS.
# Short flags combine: -dv = -d -v.
ARGS=()
parse_args() {
  local arg i char
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY_RUN=true ;;
      --force)   FORCE=true ;;
      --verbose) VERBOSE=true ;;
      --no-color) NO_COLOR_FLAG=true ;;
      --required) REQUIRED_FLAG=true ;;
      -[!-]*)
        # One dash: walk the letters after it. ${arg:i:1} = 1 char at i.
        for ((i = 1; i < ${#arg}; i++)); do
          char="${arg:i:1}"
          case "$char" in
            d) DRY_RUN=true ;;
            v) VERBOSE=true ;;
            *)
              log error "unknown flag: -$char in $arg (see: dotfiles.sh help)"
              exit 2
              ;;
          esac
        done
        ;;
      -*)
        log error "unknown flag: $arg (see: dotfiles.sh help)"
        exit 2
        ;;
      *) ARGS+=("$arg") ;;
    esac
  done
}

# Warn about flags that do nothing for this command (matches the help).
warn_unused_flags() {
  local cmd="$1"
  case "$cmd" in
    link | unlink | update | wipe | doctor | interactive) ;;
    *)
      if [[ $DRY_RUN == true ]]; then
        log warn "--dry-run has no effect on '$cmd'"
      fi
      ;;
  esac
  case "$cmd" in
    link | unlink | update | interactive) ;;
    *)
      if [[ $FORCE == true ]]; then
        log warn "--force has no effect on '$cmd'"
      fi
      ;;
  esac
  if [[ $REQUIRED_FLAG == true && $cmd != link ]]; then
    log warn "--required has no effect on '$cmd' (only link)"
  fi
}

# ════════════════════════════════════════════════════════════════════════
# COMMANDS
# ════════════════════════════════════════════════════════════════════════

cmd_help() {
  local topic="${1:-}"
  case "$topic" in
    "") _help_main ;;
    link)
      cat <<'EOF'
dotfiles link [tool...] [--required] [-d] [-v] [--force]

Install tools and link their configs: install the package if it's missing
(neither its command nor the package manager finds it), link every config,
clone its repos, run its hook, and add it to config.yml (tools:).
No tool = every tool in config.yml. --required adds the named tools to
required: instead (unlink and the interactive screen keep those).

Order: priority: high first, then the required tools, then the rest.
A tool with nothing to install here (~ in dotfiles.yml, or no package:) is
still linked, and dotfiles checks that its command is there. A tool that
isn't used on this platform is skipped. Repos under clone: are cloned once
the links are in place, only when missing (an existing clone is never
touched). Then config/dotfiles/hooks/<tool>.sh runs, if there is one.

What's in the way of a link:
  nothing                   link it
  already our link          "already linked"
  a real file               ask, back it up to <file>.bak, link it
  a real folder             leave it alone (warn)
  a link to somewhere else  ask, replace it

Never touches anything inside the repo (through a linked folder).

System files (a dest outside $HOME, e.g. omarchy, limine) get a
root-owned copy instead of a symlink. When one is missing or differs from
the repo, linking asks for your sudo password first; refused = nothing
changes. All in place = no password. A copy that differs from the repo is
replaced after you say y (the old one is kept in /var/lib/dotfiles/backup).

A file with op:// references (e.g. ~/.ssh/config) is filled in from
1Password, only again when its source in the repo changed; --force fills
it in again anyway (for values changed in 1Password).

Things to do by hand (apps to download) are listed under "Next steps" at
the end.

  -d  show what would happen, change nothing (doesn't ask for sudo)
  -v  also show the package manager's output and ls -l of each link
  --force  no questions, no backups: replace files and folders, and fill
           in 1Password files again
  --required  add the named tools to required: in config.yml

Examples:
  dotfiles link -dv neovim fd
  dotfiles link --required git
EOF
      ;;
    unlink)
      cat <<'EOF'
dotfiles unlink [tool...] [-d] [-v] [--force]

Remove tools: the package, then the config links (backups are put back),
then the tool comes off config.yml. Doesn't ask before removing the
package. Hook steps aren't undone.

  dotfiles unlink             interactive: pick from the tools in config.yml
  dotfiles unlink cowsay      that tool

Removes the package only (pacman -R, apt remove, ...), never its
dependencies. If removing fails, the tool stays linked and in config.yml.
A tool with nothing to install here is just unlinked.

A required tool (required: in config.yml) isn't removed; --force removes
it and takes it off required:.

  -d  show what would happen, change nothing
  -v  show every step
  --force  also remove required tools

Example:
  dotfiles unlink -dv cowsay
EOF
      ;;
    interactive)
      cat <<'EOF'
dotfiles [-d] [-v] [--force]

Interactive setup, two steps:
  1. every tool used on this platform, [x] = in config.yml, [R] = required.
     Enter continues, numbers switch tools on/off. Switched on = link
     (install + link), switched off = unlink (unlink + remove the
     package). Required tools can't be switched off here.
  2. which of the picked tools are required on this machine.

Picking in lists: 1 3 5, 2-4, a = all, Enter = continue.

  -d  show what would happen, change nothing
  -v  show every step (quiet otherwise; everything goes to the log)
  --force  no questions, no backups: replace whatever is in the way
EOF
      ;;
    wipe)
      cat <<'EOF'
dotfiles wipe [-d] [-v]

Undo everything dotfiles set up on this machine, to test it again from
scratch:
  - every tool used here: remove its links and system copies (backups are
    put back), and for the tools in config.yml its package (not the
    required ones)
  - then dotfiles' own link (~/.local/bin/dotfiles)

Kept: required packages, config.yml (so "dotfiles.sh link" sets up the
same tools again), and everything in the repo: no file in it is changed
or removed. The log stays too. Hook steps aren't undone. A package others
depend on (e.g. Omarchy's) can't be removed: wipe reports it and carries
on.

Shows the list first, then asks you to type the hostname. Asks for sudo
when a tool has system files.

  -d  show the list and what would run, change nothing
  -v  show every step

Example:
  dotfiles wipe -d
EOF
      ;;
    update)
      cat <<'EOF'
dotfiles update [-d] [-v] [--force]

Get the latest repo changes and bring this machine in line with them:
  1. git fetch
  2. git pull --rebase --autostash (your local changes are set aside and
     put back; a conflict stops with how to continue or undo)
  3. for every tool in config.yml: install it if it's new (never
     upgrades), make sure every link is there, run its hook

Made to run from .zshrc/.bashrc on every new shell: it only asks for sudo
when a system file changes, and only asks 1Password when a filled-in file's
source changed. With nothing to do it ends with:
  [INFO] update: nothing to change

  -d  fetch, pull nothing, change nothing; show what would change
  -v  also show the package manager's output
  --force  no questions, no backups (like link), and fill in 1Password
           files (~/.ssh/config) again

Example:
  dotfiles update -dv
EOF
      ;;
    status)
      cat <<'EOF'
dotfiles status [tool] [-v]

  dotfiles status          every tool used here: CONFIG (required, tools
                           or - for not in config.yml), INSTALLED, LINKED
  dotfiles status neovim   one tool: package, command, where it's installed,
                           version, its hook, and each link (source,
                           symlink, problem)

Changes nothing.

Example:
  dotfiles status neovim
EOF
      ;;
    doctor)
      cat <<'EOF'
dotfiles doctor [-d] [-v]

Check that everything dotfiles needs is in place, and fix what it can:
  OS and package manager, git, yq (installs either when missing; on
  Debian/Ubuntu yq comes from its GitHub release, checksum-verified),
  dotfiles.yml and config.yml, the dotfiles command link, PATH, and every
  tool in dotfiles.yml (platform names, link sources, hooks).

Exit code 1 when a check fails.

  -d  show what it would install or link, change nothing
  -v  show what every tool resolves to on this machine

Example:
  dotfiles doctor -dv
EOF
      ;;
    help)
      cat <<'EOF'
dotfiles help [command]

Show the overview, or help for one command:
  link, unlink, interactive, update, wipe, status, doctor, help, version
EOF
      ;;
    version)
      cat <<'EOF'
dotfiles version

Print the release this repo is at: its latest git tag (e.g. v2.1.7), which
the release workflow creates. Before the repo is cloned, the newest tag on
GitHub; offline, "unknown".
EOF
      ;;
    *)
      log error "no help for unknown command: $topic (see: dotfiles help)"
      exit 2
      ;;
  esac
}

_help_main() {
  cat <<EOF
Install, link and manage the tools in this repo.

Usage: dotfiles [command] [tool...] [flags]
       dotfiles                 interactive setup (help interactive)

Commands:
  link [tool...]        install tools and link their configs (no tool = config.yml)
  unlink [tool...]      remove tools and their links (no tool = pick from a list)
  update                pull the repo, install new tools, check links
  wipe                  undo everything dotfiles set up here (for re-testing)
  status [tool]         what's installed and linked
  doctor                check (and fix) what dotfiles needs
  help [command]        this overview, or help for one command
  version               print the version

Flags (work anywhere on the line):
  -d, --dry-run         show what would happen, change nothing
  -v, --verbose         show every step
  --force               no questions, no backups (link, update, interactive);
                        unlink: also required tools
  --required            link: add the tools to required: in config.yml
  --no-color            the banner without colour (interactive, update)
  Short flags combine: -dv

The interactive setup and update start with a "dotfiles" banner on a
terminal at least 84 columns wide, fading through the terminal's ANSI
colours. help, status and doctor start with "dotfiles <version>".

Files:
  tools:   ${DOTFILES_TOOLS:-<not found>}
  hooks:   ${HOOKS_DIR:-<not found>}
  config:  ${DOTFILES_CONFIG:-<not found>}  (this machine)
  log:     ${LOG_FILE:-<not available>}

More: dotfiles help <command>
EOF
}

# The release this repo is at: the latest git tag, which the release
# workflow creates for each version (e.g. v2.1.7). No version is written in
# the script. Without a clone (curl | bash before cloning), the newest tag
# on GitHub; offline, "unknown".
_version() {
  local tag=""
  if ! command -v git >/dev/null 2>&1; then
    echo "unknown"
    return 0
  fi
  if [[ -n ${DOTFILES:-} ]]; then
    tag="$(git -C "$DOTFILES" describe --tags --abbrev=0 2>/dev/null)" || tag=""
  fi
  if [[ -z $tag ]]; then
    tag="$(git ls-remote --tags --refs --sort=-v:refname "${DOTFILES_REPO:-$DEFAULT_DOTFILES_REPO}" 'v*' 2>/dev/null |
      head -n 1 | sed 's|.*refs/tags/||')" || tag=""
  fi
  echo "${tag:-unknown}"
}

cmd_version() {
  echo "dotfiles $(_version)"
}

# One line with the version, for help, status and doctor.
_title() {
  printf 'dotfiles %s\n\n' "$(_version)"
}

# Stubs: each one is replaced in its build step (plan Section 16).
# Expected failures log a message and exit with a code; the ERR trap is
# only for failures nobody planned for.
_not_built() {
  log error "$1: not built yet (Step $2)"
  exit 1
}
cmd_interactive() { _interactive_link; }

# ─── status (plan Sections 7 and 8) ─────────────────────────────────────

# Program output (tables, details): stdout, and a copy in the log file.
# Quiet mode keeps it in the log only.
out() {
  if [[ $QUIET != true || $VERBOSE == true ]]; then
    printf '%s\n' "$*"
  fi
  _log_to_file "INFO" "$*"
}

# Interactive screens and their one-line results: always shown.
ui() {
  printf '%s\n' "$*"
  _log_to_file "INFO" "$*"
}

# Commands that read the tools need dotfiles.yml and yq. config.yml may
# be missing (a new machine): it's written by the first link.
_require_config() {
  if [[ -z $DOTFILES_TOOLS || ! -f $DOTFILES_TOOLS ]]; then
    log error "dotfiles.yml not found${DOTFILES_TOOLS:+ at $DOTFILES_TOOLS}; run: dotfiles.sh doctor"
    exit 1
  fi
  if ! command -v yq >/dev/null 2>&1; then
    log error "yq is not installed; run: dotfiles.sh doctor"
    exit 1
  fi
  if [[ $CFG_LOADED != true ]]; then
    log error "dotfiles.yml can't be read; run: dotfiles.sh doctor"
    exit 1
  fi
}

# Absolute path with every symlink resolved. Missing paths come back as is.
_physical() {
  local path="$1" dir
  if [[ -d $path ]]; then
    (cd -P "$path" 2>/dev/null && pwd -P) || echo "$path"
  elif [[ -e $path ]]; then
    if dir="$(cd -P "$(dirname "$path")" 2>/dev/null && pwd -P)"; then
      echo "$dir/$(basename "$path")"
    else
      echo "$path"
    fi
  else
    echo "$path"
  fi
}

# Where a link's source lives: src is a path under config/.
_src_path() {
  echo "$DOTFILES/config/$1"
}

# State of one link:
#   linked          dest is a symlink to src
#   linked-parent   dest is src already, through a linked parent folder
#   elsewhere       dest is a symlink to somewhere else
#   broken          dest is a symlink to nothing
#   file / folder   a real file or folder is in the way
#   missing         nothing at dest
_link_state() {
  local src_path="$1" dest_path="$2" target
  if [[ -L $dest_path ]]; then
    if [[ ! -e $dest_path ]]; then
      echo "broken"
      return 0
    fi
    target="$(readlink "$dest_path")"
    case "$target" in
      /*) ;;
      *) target="$(dirname "$dest_path")/$target" ;;
    esac
    # Most links point straight at the repo path: no need to resolve both.
    if [[ ${target%/} == "${src_path%/}" ]] ||
      [[ $(_physical "$target") == "$(_physical "$src_path")" ]]; then
      echo "linked"
    else
      echo "elsewhere"
    fi
  elif [[ -e $dest_path ]]; then
    if [[ $(_physical "$dest_path") == "$(_physical "$src_path")" ]]; then
      echo "linked-parent"
    elif [[ -d $dest_path ]]; then
      echo "folder"
    else
      echo "file"
    fi
  else
    echo "missing"
  fi
}

# State of one dotfiles.yml link. An inject link is a filled-in file, not
# a symlink: "injected" when it's there, "symlink" when an old link is
# still in its place.
_tool_link_state() {
  _tool_link_state_get "$@"
  echo "$LINK_STATE"
}

# _tool_link_state into LINK_STATE.
LINK_STATE=""
_tool_link_state_get() {
  local tool="$1" src="$2" dest_path src_path="$DOTFILES/config/$2"
  case "$3" in
    /*) dest_path="$3" ;;
    *) dest_path="$HOME/$3" ;;
  esac
  _link_flags_get "$src" "$3"
  if [[ $LINK_COPY == true ]]; then
    LINK_STATE="$(_copy_state "$src_path" "$dest_path")"
  elif [[ $LINK_INJECT != true ]]; then
    LINK_STATE="$(_link_state "$src_path" "$dest_path")"
  elif [[ -L $dest_path ]]; then
    LINK_STATE="symlink"
  elif [[ -f $dest_path ]]; then
    LINK_STATE="injected"
  elif [[ -e $dest_path ]]; then
    LINK_STATE="folder"
  else
    LINK_STATE="missing"
  fi
}

# The repo's version of a system file with the literal text $HOME and
# $USER filled in for this user. The repo holds no home path or user name;
# the installed copy needs the real ones (it runs as root, where $HOME is
# /root, and systemd unit lines don't expand variables).
_render_copy() {
  sed -e "s|\$HOME|$HOME|g" -e "s|\$USER|$(id -un)|g" "$1"
}

# State of a system file (a dest outside $HOME):
#   copied   dest is a regular file with the repo's content
#   differs  something else is there (changed by hand, or a symlink)
#   folder   a folder is in the way
#   missing  nothing at dest
# SHA-256 of stdin, hex only. sha256sum (Linux) or shasum (macOS).
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  else
    shasum -a 256 | cut -d' ' -f1
  fi
}

_copy_state() {
  local src_path="$1" dest_path="$2"
  if [[ -d $dest_path && ! -L $dest_path ]]; then
    echo "folder"
  elif [[ -f $dest_path && ! -L $dest_path ]] &&
    # sha256sum (coreutils) rather than cmp: minimal systems lack diffutils
    [[ $(_render_copy "$src_path" | sha256sum) == "$(sha256sum <"$dest_path")" ]]; then
    echo "copied"
  elif [[ -e $dest_path || -L $dest_path ]]; then
    echo "differs"
  else
    echo "missing"
  fi
}

# A link state in words.
_link_state_text() {
  case "$1" in
    copied)        echo "copied (root-owned)" ;;
    differs)       echo "differs from the repo; dotfiles link copies it again" ;;
    injected)      echo "filled in from 1Password" ;;
    symlink)       echo "still a symlink; dotfiles link fills it in from 1Password" ;;
    linked)        echo "linked" ;;
    linked-parent) echo "linked (through a linked parent folder)" ;;
    elsewhere)     echo "links somewhere else: $(readlink "$2")" ;;
    broken)        echo "broken link to $(readlink "$2")" ;;
    file)          echo "a real file is in the way" ;;
    folder)        echo "a real folder is in the way" ;;
    missing)       echo "not linked" ;;
  esac
}

# Installed version of a tool. Asks the package manager when the tool has a
# package, which never starts the program: some programs don't know
# --version and open a window instead (xdg-terminal-exec opens a
# terminal). Tools without a package fall back to "<command> --version".
_tool_installed_version() {
  local tool="$1" package version
  package="$(tool_package "$tool")"
  if [[ -n $package ]] && version="$(package_version "$package")"; then
    echo "$version"
    return 0
  fi
  _tool_version "$(tool_command "$tool")"
}

# Fallback version (plan Section 8): first line of "<command> --version".
# </dev/null so a tool that ignores --version can't sit waiting for input.
# Only the version number when the line has one ("aether 4.32.0" -> 4.32.0,
# "aerospace CLI client version: 0.21.3-Beta d56e…" -> 0.21.3-Beta).
_tool_version() {
  local cmd_name="$1" output number
  if output="$("$cmd_name" --version </dev/null 2>&1)" && [[ -n $output ]]; then
    output="${output%%$'\n'*}"
    number="$(grep -oE '[0-9]+(\.[0-9]+)+[^ ,()]*' <<<"$output" | head -n 1)" || true
    echo "${number:-$output}"
  else
    echo "unknown"
  fi
}

# Where an installed tool was found: its command's path, else the package
# manager's record ("brew package 1password"). Apps like the 1Password
# desktop app have no command on PATH, but the package manager knows them.
# Returns 1 when neither finds it.
# A tool with several packages (1password: the app and the CLI) counts as
# installed only when the package manager has every one of them.
_tool_location() {
  local tool="$1" path package
  package="$(tool_package "$tool")"
  if [[ $package == *" "* ]]; then
    if package_version "$package" >/dev/null; then
      echo "$PKG_MANAGER packages ${package// /, }"
      return 0
    fi
    return 1
  fi
  if path="$(command -v "$(tool_command "$tool")" 2>/dev/null)"; then
    echo "$path"
    return 0
  fi
  if [[ -n $package ]] && package_version "$package" >/dev/null; then
    echo "$PKG_MANAGER package $package"
    return 0
  fi
  return 1
}

# "true" when the tool is installed (_tool_location finds it).
_tool_installed() {
  if _tool_is_installed "$1"; then
    echo true
  else
    echo false
  fi
}

# The same test as _tool_location, as a return code, without its $(…).
_tool_is_installed() {
  local tool="$1" package
  _tool_package_get "$tool"
  package="$TOOL_PACKAGE"
  if [[ $package == *" "* ]]; then
    package_version "$package" >/dev/null
    return
  fi
  _tool_command_get "$tool"
  if command -v "$TOOL_COMMAND" >/dev/null 2>&1; then
    return 0
  fi
  [[ -n $package ]] && package_version "$package" >/dev/null
}

# "true" when every link is in place (directly or through a linked parent).
_tool_linked() {
  if _tool_is_linked "$1"; then
    echo true
  else
    echo false
  fi
}

# _tool_linked as a return code.
_tool_is_linked() {
  local tool="$1" src dest result=0
  while IFS=$'\t' read -r src dest; do
    _tool_link_state_get "$tool" "$src" "$dest"
    log debug "$tool: $(_dest_shown "$dest") is $LINK_STATE"
    case "$LINK_STATE" in
      linked | linked-parent | injected | copied) ;;
      *) result=1 ;;
    esac
  done < <(tool_links "$tool")
  return "$result"
}

# One line per tool used on this platform.
_status_all() {
  local tool installed linked width=4 unused=0
  # The first column is as wide as the longest tool name.
  while IFS= read -r tool; do
    if [[ ${#tool} -gt $width ]]; then
      width=${#tool}
    fi
  done < <(manifest_tools)
  out "$(printf '%-*s  %-9s %-10s %s' "$width" TOOL CONFIG INSTALLED LINKED)"
  while IFS= read -r tool; do
    if ! _tool_is_used_here "$tool"; then
      unused=$((unused + 1))
      continue
    fi
    installed="$(_tool_installed "$tool")"
    linked="$(_tool_linked "$tool")"
    out "$(printf '%-*s  %-9s %-10s %s' "$width" "$tool" "$(_tool_listed_as "$tool")" "$installed" "$linked")"
  done < <(manifest_tools)
  if [[ $unused -gt 0 ]]; then
    out ""
    out "Not used on ${PLATFORM:-this platform}: $unused tools (dotfiles status <tool> shows one)"
  fi
  if [[ ! -f $DOTFILES_CONFIG ]]; then
    out "No config.yml yet: dotfiles link <tool> (or dotfiles) writes $(_tilde "$DOTFILES_CONFIG")"
  fi
}

# Details for one tool.
_status_tool() {
  local tool="$1"
  local command package src dest state shown installed linked first=true

  if ! _tool_exists "$tool"; then
    log error "unknown tool: $tool (tools: $(_tool_names))"
    exit 2
  fi

  out "$tool"
  if ! _tool_is_used_here "$tool"; then
    out "  not used on ${PLATFORM:-this platform} (dotfiles.yml has no package for it here)"
    return 0
  fi
  command="$(tool_command "$tool")"
  package="$(tool_package "$tool")"
  installed="$(_tool_installed "$tool")"
  linked="$(_tool_linked "$tool")"

  case "$(_tool_listed_as "$tool")" in
    required) out "  config:     required (config.yml)" ;;
    tools)    out "  config:     tools (config.yml)" ;;
    *)        out "  config:     not in config.yml (dotfiles link $tool adds it)" ;;
  esac
  if [[ -n $package ]]; then
    out "  package:    $package (${PKG_MANAGER:-no package manager})"
  elif _tool_has_hook "$tool"; then
    out "  package:    none here; the hook installs it, or says how"
  else
    out "  package:    none here (only checks that $command is there)"
  fi
  out "  command:    $command"
  if [[ $installed == true ]]; then
    out "  installed:  $(_tool_location "$tool")"
    out "  version:    $(_tool_installed_version "$tool")"
  else
    out "  installed:  no"
  fi
  if _tool_has_hook "$tool"; then
    out "  hook:       config/dotfiles/hooks/$tool.sh"
  fi
  if _tool_is_high "$tool"; then
    out "  priority:   high (installed before the others)"
  fi
  if [[ $linked == true && -z $(tool_links "$tool") ]]; then
    out "  links:      none"
    return 0
  fi
  out "  links:"
  while IFS=$'\t' read -r src dest; do
    if [[ $first != true ]]; then
      out ""
    fi
    first=false
    state="$(_tool_link_state "$tool" "$src" "$dest")"
    shown="$(_dest_shown "$dest")"
    out "    source:   config/$src"
    _link_flags_get "$src" "$dest"
    if [[ $LINK_COPY == true ]]; then
      out "    copy:     $dest  (root-owned)"
    elif [[ $LINK_INJECT == true ]]; then
      out "    filled:   $shown  (op inject)"
    else
      out "    symlink:  $shown"
    fi
    case "$state" in
      linked | linked-parent | injected | copied) ;;
      *) out "    problem:  $(_link_state_text "$state" "$(_dest_path "$dest")")" ;;
    esac
  done < <(tool_links "$tool")
}

cmd_status() {
  _require_config
  if [[ $# -gt 1 ]]; then
    log error "status takes at most one tool (got: $*)"
    exit 2
  fi
  if [[ $# -eq 1 ]]; then
    _status_tool "$1"
  else
    _status_all
  fi
}

# ─── link / unlink (plan Sections 7, 10, 11) ────────────────────────────

# Ask yes/no on the terminal. /dev/tty works even under curl | bash, where
# stdin is the script itself. No terminal = no.
confirm() {
  local question="$1" answer=""
  if ! { true </dev/tty; } 2>/dev/null; then
    log warn "no terminal to ask \"$question\"; treating it as no"
    return 1
  fi
  printf '%s [y/N] ' "$question" >/dev/tty
  read -r answer </dev/tty || true
  _log_to_file "INFO" "asked: $question -> ${answer:-<no answer>}"
  case "$answer" in
    y | Y | yes | Yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

# The closest part of a path that exists: /a/b/c -> /a/b if c is missing.
_nearest_existing() {
  local path="$1"
  while [[ ! -e $path && ! -L $path && $path != "/" ]]; do
    path="$(dirname "$path")"
  done
  echo "$path"
}

# True when a path is inside the repo once symlinks are resolved.
_inside_repo() {
  local path repo
  path="$(_physical "$(_nearest_existing "$1")")"
  repo="$(_physical "$DOTFILES")"
  case "$path/" in
    "$repo/"*) return 0 ;;
    *) return 1 ;;
  esac
}

# The closest folder above a path that is a symlink, for messages.
_linked_parent() {
  local path
  path="$(dirname "$1")"
  while [[ $path != "/" && $path != "$HOME" ]]; do
    if [[ -L $path ]]; then
      echo "$path"
      return 0
    fi
    path="$(dirname "$path")"
  done
}

# ~/... form of a path under $HOME, for messages.
_tilde() {
  case "$1" in
    "$HOME"/*) echo "~/${1#"$HOME"/}" ;;
    *) echo "$1" ;;
  esac
}

# "true" when linking (link) or unlinking (unlink) a tool would change a
# system file: for link, a copy is missing or differs, or its unit isn't
# enabled yet; for unlink, a copy is there to remove.
_system_needs_root() {
  local tool="$1" mode="$2" src dest state
  while IFS=$'\t' read -r src dest; do
    _link_flags_get "$src" "$dest"
    if [[ $LINK_COPY != true ]]; then
      continue
    fi
    state="$(_copy_state "$(_src_path "$src")" "$dest")"
    if [[ $mode == unlink ]]; then
      if [[ $state != missing ]]; then
        echo true
        return 0
      fi
    elif [[ $state != copied ]]; then
      echo true
      return 0
    elif [[ $LINK_ENABLE == true ]] &&
      command -v systemctl >/dev/null 2>&1 &&
      ! systemctl is-enabled --quiet "$(basename "$dest")" 2>/dev/null; then
      echo true
      return 0
    fi
  done < <(tool_links "$tool")
  echo false
}

# Tools with system files (a dest outside $HOME) need root for them. Before
# changing anything, ask for the sudo password (sudo -v); refused = stop,
# nothing changed. Later sudo calls in this run don't ask again. A dry run
# changes nothing, so it doesn't ask.
# Only tools whose system files would actually change count: a link run
# where every copy is already in place (and its unit enabled) doesn't ask,
# so update can run from a shell's startup file without a password prompt.
#   _require_sudo link|unlink <tool...>
_require_sudo() {
  local mode="$1" tool need=""
  shift
  if [[ $DRY_RUN == true || $EUID -eq 0 ]]; then
    return 0
  fi
  for tool in "$@"; do
    if [[ $(_system_needs_root "$tool" "$mode") == true ]]; then
      need="${need:+$need, }$tool"
    fi
  done
  if [[ -z $need ]]; then
    return 0
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    log error "$need installs system files and needs root, but sudo isn't installed; nothing changed"
    exit 1
  fi
  # Shown even when QUIET: it explains the password prompt that follows.
  local why="system files to install or update"
  if [[ $mode == unlink ]]; then
    why="system files to remove"
  fi
  printf '%s\n' "$need: $why; sudo needs your password" >&2
  _log_to_file "INFO" "$need: $why; sudo needs your password"
  if ! sudo -v; then
    log error "$need installs system files and sudo was refused; nothing changed"
    exit 1
  fi
}

# Tools to act on, into TOOLS (in run order): the ones named, or every tool
# in config.yml. Unknown names stop the run before anything changes.
TOOLS=()
_pick_tools() {
  local cmd="$1" tool
  shift
  TOOLS=()
  if [[ $# -gt 0 ]]; then
    for tool in "$@"; do
      if ! _tool_exists "$tool"; then
        log error "unknown tool: $tool (tools: $(_tool_names))"
        exit 2
      fi
    done
    while IFS= read -r tool; do
      TOOLS+=("$tool")
    done < <(_order_tools "$@")
  else
    # shellcheck disable=SC2046
    while IFS= read -r tool; do
      TOOLS+=("$tool")
    done < <(_order_tools $(_listed_tools))
    if [[ ${#TOOLS[@]} -eq 0 && $cmd == update ]]; then
      log info "update: no tools in config.yml yet; nothing to install or link"
    elif [[ ${#TOOLS[@]} -eq 0 ]]; then
      log info "$cmd: no tools in config.yml yet; name one: dotfiles.sh $cmd <tool> (or run dotfiles to pick)"
    fi
  fi
  log debug "$cmd: tools: ${TOOLS[*]:-<none>}"
}

# End-of-run summary when more than one tool was handled: only what
# changed, and what failed. Empty lines are left out; nothing to report
# means no summary.
_summary() {
  local verb="$1" changed="$2" failed="$3"
  if [[ ${#TOOLS[@]} -le 1 || ( -z $changed && -z $failed ) ]]; then
    return 0
  fi
  out ""
  out "Summary:"
  if [[ -n $changed ]]; then
    if [[ $DRY_RUN == true ]]; then
      out "  Test: $changed"
    else
      out "  $verb: $changed"
    fi
  fi
  if [[ -n $failed ]]; then
    out "  failed: $failed"
  fi
}

# Link one src/dest pair from dotfiles.yml. Returns 1 when the link isn't
# in place afterwards.
_link_one() {
  local tool="$1" src="$2" dest="$3"
  if [[ -z $src || -z $dest ]]; then
    log error "$tool: a link in dotfiles.yml is missing its source or dest"
    return 1
  fi
  _link_flags_get "$src" "$dest"
  if [[ $LINK_COPY == true ]]; then
    _copy_path "$tool" "$src" "$dest"
  elif [[ $LINK_INJECT == true ]]; then
    _inject_path "$tool" "$(_src_path "$src")" "$dest"
  else
    _link_path "$tool" "$(_src_path "$src")" "$dest"
  fi
}

# Run a command as root: directly when already root (a container), else
# through sudo (dotfiles was started with sudo, so it doesn't ask again).
_root_cmd() {
  if [[ $EUID -eq 0 ]]; then
    run_cmd "$@"
  else
    run_cmd sudo "$@"
  fi
}

# Where a system file that was in the way is kept, so unlink can put it
# back. Not next to it: a .bak in a hooks folder would still be run.
SYSTEM_BACKUP_DIR="/var/lib/dotfiles/backup"

# For a copied systemd unit: reload systemd when the file was just copied
# ($4 = copied), and enable the unit when it has [Install] and isn't
# enabled yet. Containers have no running systemd: warn, don't fail.
_systemd_after_copy() {
  local tool="$1" src="$2" dest_path="$3" copied="${4:-false}" unit
  case "$dest_path" in
    /etc/systemd/*) ;;
    *) return 0 ;;
  esac
  if ! command -v systemctl >/dev/null 2>&1; then
    return 0
  fi
  unit="$(basename "$dest_path")"
  if [[ $copied == true ]] && ! _root_cmd systemctl daemon-reload; then
    log warn "$tool: systemctl daemon-reload failed (no running systemd?)"
    return 0
  fi
  if [[ $(tool_link_enable "$src" "$dest_path") == true ]] && ! systemctl is-enabled --quiet "$unit" 2>/dev/null; then
    if _root_cmd systemctl enable --now "$unit"; then
      log success "$tool: enabled $unit"
    else
      log warn "$tool: couldn't enable $unit"
    fi
  fi
}

# Put a root-owned copy of a system file in place (a dest outside $HOME). Asks
# before replacing a different file; the old one goes to
# $SYSTEM_BACKUP_DIR. Returns 1 when the copy isn't in place afterwards.
_copy_path() {
  local tool="$1" src="$2" dest_path="$3"
  local src_path state mode tmp
  src_path="$(_src_path "$src")"
  if [[ ! -f $src_path ]]; then
    log error "$tool: source config/$src doesn't exist"
    return 1
  fi
  state="$(_copy_state "$src_path" "$dest_path")"
  log debug "$tool: $dest_path is $state"

  case "$state" in
    copied)
      log success "$tool: already in place: $dest_path (root-owned copy)"
      _systemd_after_copy "$tool" "$src" "$dest_path"
      return 0
      ;;
    folder)
      log warn "$tool: $dest_path is a folder; left it alone"
      return 1
      ;;
    differs)
      if [[ $FORCE != true ]]; then
        if [[ $DRY_RUN == true ]]; then
          log info "dry run, would ask: $dest_path differs from the repo. Replace it?"
        elif ! confirm "$tool: $dest_path differs from the repo. Replace it (the old one is kept in $SYSTEM_BACKUP_DIR)?"; then
          log warn "$tool: left $dest_path alone"
          return 1
        fi
      fi
      if [[ ! -e $SYSTEM_BACKUP_DIR$dest_path ]]; then
        _root_cmd mkdir -p "$(dirname "$SYSTEM_BACKUP_DIR$dest_path")"
        _root_cmd cp -P "$dest_path" "$SYSTEM_BACKUP_DIR$dest_path"
      fi
      ;;
  esac

  CHANGED=true
  mode=644
  if [[ -x $src_path ]]; then
    mode=755
  fi
  if [[ $DRY_RUN == true ]]; then
    log info "dry run, would copy config/$src to $dest_path (root-owned, $mode)"
    _systemd_after_copy "$tool" "$src" "$dest_path" true
    return 0
  fi
  tmp="$(mktemp)"
  _render_copy "$src_path" >"$tmp"
  _root_cmd mkdir -p "$(dirname "$dest_path")"
  if [[ -L $dest_path ]]; then
    _root_cmd rm -f "$dest_path"
  fi
  if ! _root_cmd install -o 0 -g 0 -m "$mode" "$tmp" "$dest_path"; then
    rm -f "$tmp"
    log error "$tool: copying $dest_path failed"
    return 1
  fi
  rm -f "$tmp"
  log success "$tool: copied $dest_path (root-owned, $mode)"
  _systemd_after_copy "$tool" "$src" "$dest_path" true
}

# Remove a system file that is still the repo's copy, and put back what
# was there before. A changed file is left alone.
_uncopy_path() {
  local tool="$1" src="$2" dest_path="$3" state unit
  state="$(_copy_state "$(_src_path "$src")" "$dest_path")"
  case "$state" in
    missing)
      log info "$tool: $dest_path isn't there; nothing to do"
      return 0
      ;;
    copied) ;;
    *)
      log warn "$tool: $dest_path differs from the repo ($(_link_state_text "$state")); left it alone"
      return 0
      ;;
  esac
  unit="$(basename "$dest_path")"
  if [[ $(tool_link_enable "$src" "$dest_path") == true ]] &&
    command -v systemctl >/dev/null 2>&1; then
    _root_cmd systemctl disable --now "$unit" || log warn "$tool: couldn't disable $unit"
  fi
  _root_cmd rm "$dest_path"
  if [[ -e $SYSTEM_BACKUP_DIR$dest_path || -L $SYSTEM_BACKUP_DIR$dest_path ]]; then
    _root_cmd mv "$SYSTEM_BACKUP_DIR$dest_path" "$dest_path"
    if [[ $DRY_RUN != true ]]; then
      log success "$tool: removed $dest_path and put the old one back"
    fi
  elif [[ $DRY_RUN != true ]]; then
    log success "$tool: removed $dest_path"
  fi
  if [[ $dest_path == /etc/systemd/* ]] && command -v systemctl >/dev/null 2>&1; then
    _root_cmd systemctl daemon-reload || true
  fi
}

# Fill a repo file's op:// references with op inject and write the result
# to dest, outside the repo, owner-only. The result is written next to dest
# and renamed into place, so an old symlink is replaced, never written
# through (that would put the real values into the repo).
#
# The header records the source's SHA-256. When it still matches, the file
# is left alone without calling op (no 1Password unlock prompt on every
# update); --force fills it in again anyway, for values changed in 1Password.
_inject_path() {
  local tool="$1" src_path="$2" dest="$3"
  local dest_path="$HOME/$3" shown="~/$3" tmp err src_hash
  local first="# GENERATED FILE: do not edit. Changes here are overwritten."
  if [[ ! -f $src_path ]]; then
    log error "$tool: source ${src_path#"$DOTFILES"/} doesn't exist"
    return 1
  fi
  src_hash="$(_sha256 <"$src_path")"
  if [[ $FORCE != true && -f $dest_path && ! -L $dest_path && $(head -n 1 "$dest_path") == "$first" ]] &&
    head -n 5 "$dest_path" | grep -qxF "# Source-SHA256: $src_hash"; then
    log success "$tool: already up to date: $shown (source unchanged; --force fills it in from 1Password again)"
    return 0
  fi
  if ! command -v op >/dev/null 2>&1; then
    log warn "$tool: $shown needs the 1Password CLI (op) to fill in its op:// references; skipped"
    return 1
  fi
  if _inside_repo "$(dirname "$dest_path")"; then
    log error "$tool: $shown is inside the repo; not writing secrets there"
    return 1
  fi
  if [[ -d $dest_path && ! -L $dest_path ]]; then
    log warn "$tool: $shown is a real folder; left it alone"
    return 1
  fi
  CHANGED=true
  if [[ $DRY_RUN == true ]]; then
    log info "dry run, would fill $shown from ${src_path#"$DOTFILES"/} with op inject (owner-only)"
    return 0
  fi

  mkdir -p "$(dirname "$dest_path")"
  tmp="$(mktemp "$(dirname "$dest_path")/.dotfiles-inject.XXXXXX")"
  log info "running: op inject -i ${src_path#"$DOTFILES"/} -o $shown"
  if ! err="$(op inject -f -i "$src_path" -o "$tmp" 2>&1 >/dev/null)"; then
    rm -f "$tmp"
    log error "$tool: op inject failed for $shown (is 1Password unlocked?): $err"
    return 1
  fi
  chmod 600 "$tmp"

  # Up to date = same content and source under the 5-line header (the
  # header's time is when the content last changed, so it isn't compared).
  if [[ -f $dest_path && ! -L $dest_path && $(head -n 1 "$dest_path") == "$first" ]] &&
    head -n 5 "$dest_path" | grep -qxF "# Source-SHA256: $src_hash" &&
    tail -n +6 "$dest_path" | cmp -s - "$tmp"; then
    rm -f "$tmp"
    CHANGED=false
    log success "$tool: already up to date: $shown (filled in from 1Password)"
    return 0
  fi
  if [[ -L $dest_path ]]; then
    log info "$tool: replacing the symlink $shown with the filled-in file"
  fi
  {
    printf '%s\n' "$first" \
      "# Source: $(_tilde "$src_path") (op:// references filled in by op inject)" \
      "# Source-SHA256: $src_hash" \
      "# Edit the source, then run: dotfiles link $tool" \
      "# Generated: $(_timestamp)"
    cat "$tmp"
  } >"$tmp.full"
  chmod 600 "$tmp.full"
  rm -f "$tmp"
  mv -f "$tmp.full" "$dest_path"
  log success "$tool: filled $shown from ${src_path#"$DOTFILES"/} (owner-only)"
}

# Folders (under $HOME) that must stay owner-only: the 1Password CLI
# refuses to run when ~/.config/op is readable by others ("permissions are
# too broad"). A link into one creates it as 700, or tightens it to 700.
PRIVATE_DIRS=(".config/op")

# File mode as octal digits (755). stat differs: GNU -c, BSD/macOS -f.
_mode() {
  stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"
}

# "true" when a dest's folder is one of PRIVATE_DIRS.
_private_parent() {
  local dir="$1" private
  for private in "${PRIVATE_DIRS[@]}"; do
    if [[ $dir == "$HOME/$private" ]]; then
      echo true
      return 0
    fi
  done
  echo false
}

# Make a private folder 700 when it already exists with a wider mode.
_tighten_private_parent() {
  local tool="$1" dir="$2"
  if [[ $(_private_parent "$dir") == true && -d $dir && ! -L $dir && $(_mode "$dir") != 700 ]]; then
    run_cmd chmod 700 "$dir"
    if [[ $DRY_RUN != true ]]; then
      log success "$tool: set $(_tilde "$dir") to 700 (owner-only)"
    fi
  fi
}

# Link a full source path to a dest under $HOME, with all the conflict
# handling (plan Section 10). Also used for dotfiles.sh's own links.
_link_path() {
  local tool="$1" src_path="$2" dest="$3"
  local dest_path state shown target
  dest_path="$HOME/$dest"
  shown="~/$dest"

  if [[ ! -e $src_path ]]; then
    log error "$tool: source ${src_path#"$DOTFILES"/} doesn't exist"
    return 1
  fi

  state="$(_link_state "$src_path" "$dest_path")"
  log debug "$tool: $shown is $state"
  _tighten_private_parent "$tool" "$(dirname "$dest_path")"

  if [[ $state == linked ]]; then
    log success "$tool: already linked: $shown"
    if [[ $VERBOSE == true ]]; then
      out "$(ls -ld "$dest_path")"
    fi
    return 0
  fi
  if [[ $state == linked-parent ]]; then
    target="$(_linked_parent "$dest_path")"
    log success "$tool: already linked: $shown (through the linked folder $(_tilde "$target"))"
    if [[ $VERBOSE == true ]]; then
      out "$(ls -ld "$target")"
    fi
    return 0
  fi

  # If the folder dest sits in is really inside the repo (through a linked
  # folder), whatever is there is the repo's own file: moving, deleting or
  # adding to it would change the repo. The folder decides, not dest
  # itself: an old symlink pointing into the repo can still be replaced.
  if _inside_repo "$(dirname "$dest_path")"; then
    log error "$tool: $shown is inside the repo (through $(_tilde "$(_linked_parent "$dest_path")")); not touching it"
    return 1
  fi

  case "$state" in
    missing) ;;
    file)
      if [[ $FORCE == true ]]; then
        log warn "$tool: --force: replacing the real file $shown, no backup"
        run_cmd rm -f "$dest_path"
      else
        if [[ -e $dest_path$BACKUP_SUFFIX || -L $dest_path$BACKUP_SUFFIX ]]; then
          log error "$tool: $shown is a real file, and an old backup $shown$BACKUP_SUFFIX is in the way; check it, delete it, then run link again"
          return 1
        fi
        if [[ $DRY_RUN == true ]]; then
          log info "dry run, would ask: back up $shown to $shown$BACKUP_SUFFIX and link it?"
        elif ! confirm "$tool: $shown is a real file. Back it up to $shown$BACKUP_SUFFIX and link it?"; then
          log warn "$tool: left $shown alone"
          return 1
        fi
        run_cmd mv "$dest_path" "$dest_path$BACKUP_SUFFIX"
        if [[ $DRY_RUN != true ]]; then
          log warn "$tool: backup made: $shown$BACKUP_SUFFIX (delete it once you're sure)"
        fi
      fi
      ;;
    folder)
      if [[ $FORCE != true ]]; then
        log warn "$tool: $shown is a real folder; left it alone (--force replaces it, with no backup)"
        return 1
      fi
      log warn "$tool: --force: deleting the real folder $shown, no backup"
      run_cmd rm -rf "$dest_path"
      ;;
    elsewhere | broken)
      target="$(readlink "$dest_path")"
      if [[ $FORCE != true ]]; then
        if [[ $DRY_RUN == true ]]; then
          log info "dry run, would ask: replace the symlink $shown (now -> $target)?"
        elif ! confirm "$tool: $shown links to $target. Replace it?"; then
          log warn "$tool: left $shown alone"
          return 1
        fi
      fi
      if [[ $DRY_RUN != true ]]; then
        log info "$tool: replacing the symlink $shown (was -> $target)"
      fi
      run_cmd rm -f "$dest_path"
      ;;
  esac

  if [[ $(_private_parent "$(dirname "$dest_path")") == true && ! -e $(dirname "$dest_path") ]]; then
    run_cmd mkdir -p -m 700 "$(dirname "$dest_path")"
  else
    run_cmd mkdir -p "$(dirname "$dest_path")"
  fi
  run_cmd ln -s "$src_path" "$dest_path"
  if [[ $DRY_RUN != true ]]; then
    log success "$tool: linked $shown -> ${src_path#"$DOTFILES"/}"
    if [[ $VERBOSE == true ]]; then
      out "$(ls -ld "$dest_path")"
    fi
  fi
}

# Clone one repo from a tool's clone: list if it isn't there yet. An
# existing clone is never touched (oh-my-zsh updates itself). Returns 1
# when the dest is in the way or the clone fails.
_clone_one() {
  local tool="$1" repo="$2" dest="$3"
  local dest_path="$HOME/$3" shown="~/$3"
  if [[ -z $repo || -z $dest ]]; then
    log error "$tool: a clone: entry needs both repo and dest"
    return 1
  fi
  if [[ -d $dest_path/.git ]]; then
    log success "$tool: already cloned: $shown"
    return 0
  fi
  if [[ -e $dest_path && -n $(ls -A "$dest_path" 2>/dev/null) ]]; then
    log warn "$tool: $shown exists but isn't a git clone; left it alone"
    return 1
  fi
  # Inside the repo (through a linked folder) the clone must be gitignored,
  # or it would show up as a nested repo in git status.
  if [[ $DRY_RUN != true ]] && _inside_repo "$(dirname "$dest_path")" &&
    ! git -C "$DOTFILES" check-ignore -q "$(_physical "$(dirname "$dest_path")")/$(basename "$dest_path")" 2>/dev/null; then
    log warn "$tool: $shown is inside the repo but not gitignored; add it to .gitignore"
  fi
  if ! command -v git >/dev/null 2>&1; then
    log error "$tool: git is needed to clone $repo; run: dotfiles doctor"
    return 1
  fi
  CHANGED=true
  log info "$tool: cloning $repo into $shown"
  if ! run_cmd git clone --depth 1 "$repo" "$dest_path"; then
    log error "$tool: cloning $repo failed"
    return 1
  fi
  if [[ $DRY_RUN != true ]]; then
    log success "$tool: cloned $shown"
  fi
}

# A tool that used to link its whole folder (~/.config/aether -> config/aether)
# and now links parts of it: the old folder link is replaced by a real folder,
# or the new links would land inside the repo.
UNFOLDED=""   # dry run: folder links that would have been replaced
_unfold_tool_link() {
  local tool="$1" src dest parent target
  while IFS=$'\t' read -r src dest; do
    [[ $dest == /* || -z $dest ]] && continue
    parent="$(dirname "$HOME/$dest")"
    [[ $'\n'$UNFOLDED$'\n' == *$'\n'"$parent"$'\n'* ]] && continue
    if [[ -L $parent ]]; then
      target="$(_physical "$parent")"
      if [[ $target == "$(_physical "$DOTFILES/config/$tool")" ]]; then
        run_cmd rm "$parent"
        run_cmd mkdir -p "$parent"
        UNFOLDED+="$parent"$'\n'
        if [[ $DRY_RUN != true ]]; then
          log info "$tool: $(_tilde "$parent") linked the whole folder; it's a real folder now, with links and copies inside"
        fi
      fi
    fi
  done < <(tool_links "$tool")
}

# Link one tool's configs and clone its repos. Returns 1 when a link isn't
# in place.
_link_configs() {
  local tool="$1" src dest repo ok=true
  _unfold_tool_link "$tool"
  while IFS=$'\t' read -r src dest; do
    if ! _link_one "$tool" "$src" "$dest"; then
      ok=false
    fi
  done < <(tool_links "$tool")
  # Clones often go inside a linked folder (~/.config/zsh/oh-my-zsh), so
  # only clone once every link is in place.
  if [[ $ok == true ]]; then
    while IFS=$'\t' read -r repo dest; do
      if ! _clone_one "$tool" "$repo" "$dest"; then
        ok=false
      fi
    done < <(tool_clones "$tool")
  fi
  [[ $ok == true ]]
}

# ─── hooks: config/dotfiles/hooks/<tool>.sh ─────────────────────────────
# Runs, when it exists, after the tool's package and links (link, update,
# interactive). Gets --dry-run, --verbose and --force as given to dotfiles,
# and DOTFILES, DOTFILES_OS, DOTFILES_PLATFORM, DOTFILES_TOOL and
# PKG_MANAGER in its environment. Its output shows as it runs (and goes to
# the log; the interactive screen shows it with -v only). A line
# "next: <text>" goes to the Next steps list at the end instead. A hook
# prints nothing when there's nothing to do (update runs from the shell's
# startup file); anything else it prints counts as a change. An exit code
# other than 0 = the tool failed.
NEXT_STEPS=""
_run_hook() {
  local tool="$1" hook="$HOOKS_DIR/$1.sh" line code_file code=0 printed=false
  local -a args=()
  if [[ -z $HOOKS_DIR || ! -f $hook ]]; then
    return 0
  fi
  if [[ $DRY_RUN == true ]]; then args+=(--dry-run); fi
  if [[ $VERBOSE == true ]]; then args+=(--verbose); fi
  if [[ $FORCE == true ]]; then args+=(--force); fi
  log debug "$tool: running hooks/$tool.sh ${args[*]:-}"
  code_file="$(mktemp)"
  # </dev/null: the hook can't eat input meant for a loop around it. The
  # exit code comes back through code_file (a < <(…) has no $?).
  while IFS= read -r line || [[ -n $line ]]; do
    case "$line" in
      next:*)
        line="${line#next:}"
        line="${line# }"
        NEXT_STEPS+="$tool: $line"$'\n'
        _log_to_file "INFO" "$tool: next step: $line"
        ;;
      *)
        printed=true
        if [[ $QUIET != true || $VERBOSE == true ]]; then
          _tool_release
          printf '%s\n' "$line"
        fi
        _log_to_file "INFO" "  $tool hook> $line"
        ;;
    esac
  done < <(DOTFILES_TOOL="$tool" PKG_MANAGER="$PKG_MANAGER" bash "$hook" ${args[@]+"${args[@]}"} </dev/null 2>&1
    echo "$?" >"$code_file")
  code="$(cat "$code_file" 2>/dev/null)" || code=1
  rm -f "$code_file"
  if [[ $printed == true ]]; then
    CHANGED=true
  fi
  if [[ ${code:-1} != 0 ]]; then
    log error "$tool: hooks/$tool.sh failed (exit ${code:-?})"
    return 1
  fi
}

# Things to do by hand, collected from the hooks and from tools with
# nothing to install here. Shown at the end of link, update and the
# interactive setup, even when the screen is quiet.
_next_steps() {
  local line
  if [[ -z $NEXT_STEPS ]]; then
    return 0
  fi
  ui ""
  ui "Next steps:"
  while IFS= read -r line; do
    if [[ -n $line ]]; then
      ui "  - $line"
    fi
  done <<<"$NEXT_STEPS"
}

# ─── Theme templates on machines without Omarchy ────────────────────────
# Omarchy renders config/omarchy/themed/*.tpl on every theme change and runs
# the theme-set hooks. Elsewhere (macOS, Windows, other Linux), link and
# update do the same for settings.theme: fill each template from that
# theme's colors.toml (in the repo) into the same folder Omarchy uses, so
# every config points at one place, then run the dotfiles theme hook. Only
# when the theme, its colours or a template changed.
THEME_STATE_DIR="$HOME/.local/state/omarchy/current/theme"
THEME_CHANGED=false
_render_theme() {
  THEME_CHANGED=false
  # Omarchy records its current theme here (dotfiles never writes it).
  if [[ -f $HOME/.local/state/omarchy/current/theme.name ]]; then
    log debug "theme: Omarchy renders the theme here; settings.theme is ignored"
    return 0
  fi
  if [[ -z $THEME ]]; then
    log debug "theme: no settings.theme in config.yml; nothing to render"
    return 0
  fi
  local colors="$DOTFILES/config/omarchy/themes/$THEME/colors.toml"
  local themed="$DOTFILES/config/omarchy/themed"
  if [[ ! -f $colors ]]; then
    log warn "theme: settings.theme is $THEME, but config/omarchy/themes/$THEME/colors.toml doesn't exist"
    return 0
  fi
  local stamp tpl
  stamp="$( { echo "$THEME"; cat "$colors"; for tpl in "$themed"/*.tpl; do [[ -f $tpl ]] && cat "$tpl"; done; } | _sha256)"
  if [[ -f $THEME_STATE_DIR/.dotfiles-stamp && $(<"$THEME_STATE_DIR/.dotfiles-stamp") == "$stamp" ]]; then
    log debug "theme: $THEME already rendered"
    return 0
  fi
  if [[ $DRY_RUN == true ]]; then
    log info "dry run, would render the theme templates for $THEME and run the theme hook"
    THEME_CHANGED=true
    return 0
  fi

  # key = "#rrggbb" lines; selection_* get Omarchy's defaults when missing.
  local -a keys=() values=()
  local key value line
  while IFS= read -r line; do
    if [[ $line =~ ^([a-z_0-9]+)[[:space:]]*=[[:space:]]*\"(#[0-9a-fA-F]{6})\" ]]; then
      keys+=("${BASH_REMATCH[1]}")
      values+=("${BASH_REMATCH[2]}")
    fi
  done <"$colors"
  _theme_value() {
    local i
    for ((i = 0; i < ${#keys[@]}; i++)); do
      if [[ ${keys[i]} == "$1" ]]; then
        echo "${values[i]}"
        return 0
      fi
    done
    return 1
  }
  if ! _theme_value selection_background >/dev/null && value="$(_theme_value selection)"; then
    keys+=(selection_background); values+=("$value")
  fi
  if ! _theme_value selection_foreground >/dev/null && value="$(_theme_value bright_foreground)"; then
    keys+=(selection_foreground); values+=("$value")
  fi

  mkdir -p "$THEME_STATE_DIR"
  cp "$colors" "$THEME_STATE_DIR/colors.toml"
  local content out count=0 i hex r g b
  for tpl in "$themed"/*.tpl; do
    [[ -f $tpl ]] || continue
    content="$(<"$tpl")"
    for ((i = 0; i < ${#keys[@]}; i++)); do
      hex="${values[i]#\#}"
      r=$((16#${hex:0:2})); g=$((16#${hex:2:2})); b=$((16#${hex:4:2}))
      content="${content//"{{ ${keys[i]}_strip }}"/$hex}"
      content="${content//"{{ ${keys[i]}_rgb }}"/$r,$g,$b}"
      content="${content//"{{ ${keys[i]} }}"/${values[i]}}"
    done
    out="$THEME_STATE_DIR/$(basename "$tpl" .tpl)"
    printf '%s\n' "$content" >"$out"
    if grep -q '{{ ' "$out"; then
      log warn "theme: $(basename "$tpl") uses a colour $THEME doesn't define: $(grep -o '{{ [a-z_0-9]* }}' "$out" | sort -u | tr '\n' ' ')"
    fi
    count=$((count + 1))
  done
  if [[ -x $DOTFILES/config/omarchy/hooks/theme-set.d/60-dotfiles-theme ]]; then
    bash "$DOTFILES/config/omarchy/hooks/theme-set.d/60-dotfiles-theme" "$THEME"
  fi
  printf '%s\n' "$stamp" >"$THEME_STATE_DIR/.dotfiles-stamp"
  THEME_CHANGED=true
  log success "theme: rendered $count templates for $THEME"
}

# link [tool...]: install each tool's package if it's missing, link its
# configs, run its hook, add it to config.yml (--required: to required:).
# No tool = every tool in config.yml.
cmd_link() {
  _require_config
  if [[ $REQUIRED_FLAG == true && $# -eq 0 ]]; then
    log error "link --required needs the tools to add, e.g. dotfiles link --required git"
    exit 2
  fi
  _pick_tools link "$@"
  _require_sudo link ${TOOLS[@]+"${TOOLS[@]}"}
  local tool good="" bad="" as=tools
  if [[ $REQUIRED_FLAG == true ]]; then
    as=required
  fi
  for tool in ${TOOLS[@]+"${TOOLS[@]}"}; do
    CHANGED=false
    if ! _tool_is_used_here "$tool"; then
      if [[ $# -gt 0 ]]; then
        log warn "$tool: not used on ${PLATFORM:-this platform} (dotfiles.yml has no package for it here); skipped"
      else
        log debug "$tool: not used on ${PLATFORM:-this platform}; skipped"
      fi
      continue
    fi
    _tool_hold
    if ! _link_tool "$tool" "$as"; then
      _tool_release
      bad="${bad:+$bad, }$tool"
    else
      _tool_done "$tool"
      if [[ $CHANGED == true ]]; then
        good="${good:+$good, }$(_tool_with_version "$tool")"
      fi
    fi
  done
  _render_theme
  _summary linked "$good" "$bad"
  _next_steps
  if [[ -n $bad ]]; then
    exit 1
  fi
}

# Remove one link and put its .bak back if there is one.
_unlink_one() {
  local tool="$1" src="$2" dest="$3"
  local src_path dest_path state shown
  if [[ $dest == /* ]]; then
    _uncopy_path "$tool" "$src" "$dest"
    return
  fi
  src_path="$(_src_path "$src")"
  dest_path="$HOME/$dest"
  shown="~/$dest"
  state="$(_tool_link_state "$tool" "$src" "$dest")"
  log debug "$tool: $shown is $state"

  case "$state" in
    injected | symlink)
      run_cmd rm "$dest_path"
      if [[ $DRY_RUN != true ]]; then
        log success "$tool: removed $shown (dotfiles link fills it in again)"
      fi
      ;;
    linked)
      run_cmd rm "$dest_path"
      if [[ -e $dest_path$BACKUP_SUFFIX || -L $dest_path$BACKUP_SUFFIX ]]; then
        run_cmd mv "$dest_path$BACKUP_SUFFIX" "$dest_path"
        if [[ $DRY_RUN != true ]]; then
          log success "$tool: unlinked $shown and restored the backup"
        fi
      elif [[ $DRY_RUN != true ]]; then
        log success "$tool: unlinked $shown"
      fi
      ;;
    linked-parent)
      log error "$tool: $shown is linked through the folder $(_tilde "$(_linked_parent "$dest_path")"); unlink that folder instead"
      return 1
      ;;
    missing)
      log info "$tool: $shown isn't linked; nothing to do"
      ;;
    *)
      log warn "$tool: $shown isn't a link to the repo ($(_link_state_text "$state" "$dest_path")); left it alone"
      ;;
  esac
}

# Unlink one tool's configs. Returns 1 on failure.
_unlink_configs() {
  local tool="$1" src dest ok=true i
  local -a pairs=()
  while IFS= read -r src; do
    pairs+=("$src")
  done < <(tool_links "$tool")
  # Last link first: the reverse of linking (a .path unit is switched off
  # before the service it starts is removed).
  for ((i = ${#pairs[@]} - 1; i >= 0; i--)); do
    IFS=$'\t' read -r src dest <<<"${pairs[i]}"
    if ! _unlink_one "$tool" "$src" "$dest"; then
      ok=false
    fi
  done
  [[ $ok == true ]]
}

# unlink [tool...]: remove each tool's package, unlink its configs, take
# it off config.yml. No tool = pick from config.yml (never all of them at
# once without asking).
cmd_unlink() {
  if [[ $# -eq 0 ]]; then
    _interactive_unlink
    return 0
  fi
  _require_config
  _pick_tools unlink "$@"
  _require_sudo unlink ${TOOLS[@]+"${TOOLS[@]}"}
  local tool good="" bad=""
  for tool in ${TOOLS[@]+"${TOOLS[@]}"}; do
    CHANGED=false
    if ! _unlink_tool "$tool"; then
      bad="${bad:+$bad, }$tool"
    elif [[ $CHANGED == true ]]; then
      good="${good:+$good, }$tool"
    fi
  done
  _summary unlinked "$good" "$bad"
  if [[ -n $bad ]]; then
    exit 1
  fi
}

# ─── packages: install for link, remove for unlink (plan Sections 7, 8, 11)

# Install one tool's package if it's missing. A tool with nothing to
# install here (~, no package:) is only checked: missing = a warning and a
# next step, unless its hook installs it or says how.
_install_package() {
  local tool="$1" cmd_name package path
  cmd_name="$(tool_command "$tool")"
  package="$(tool_package "$tool")"

  if path="$(_tool_location "$tool")"; then
    # The interactive screens hide this line (log file only), so skip the
    # version there: for a tool without a package it means starting the
    # program (cspell --version takes ~1 s).
    if [[ $QUIET == true && $VERBOSE != true ]]; then
      log success "$tool: already installed: $path"
    else
      log success "$tool: already installed: $path ($(_tool_installed_version "$tool"))"
    fi
    return 0
  fi
  if [[ -z $package ]]; then
    if _tool_has_hook "$tool"; then
      log debug "$tool: not installed yet; nothing to install here, hooks/$tool.sh handles it"
    else
      log warn "$tool: $cmd_name isn't installed, and dotfiles.yml has nothing to install it on ${PLATFORM:-this platform}"
      NEXT_STEPS+="$tool: install $cmd_name (dotfiles.yml has nothing to install it on ${PLATFORM:-this platform})"$'\n'
    fi
    return 0
  fi

  if [[ $package == *" "* ]]; then
    local name missing=""
    for name in $package; do
      if ! _package_version_one "$name" >/dev/null; then
        missing="${missing:+$missing, }$name"
      fi
    done
    log info "$tool: not installed ($missing missing), installing it"
  else
    log info "$tool: not installed, installing package $package"
  fi
  # -v: the package manager's output in its own block, easy to tell apart.
  if [[ $VERBOSE == true ]]; then
    printf '\n%s\n' "$(_rule "installing $tool ($PKG_MANAGER)")"
  fi
  local installed=true
  if ! pm_install "$package"; then
    installed=false
  fi
  if [[ $VERBOSE == true ]]; then
    printf '%s\n\n' "$(_rule)"
  fi
  if [[ $installed != true ]]; then
    log error "$tool: installing $package failed; run again with -v to see why"
    return 1
  fi
  if [[ $DRY_RUN == true ]]; then
    return 0
  fi
  hash -r
  if ! path="$(_tool_location "$tool")"; then
    log error "$tool: $package installed, but $cmd_name still isn't on PATH"
    return 1
  fi
  log success "$tool: installed $package: $path ($(_tool_installed_version "$tool"))"
}

# Install, link, clone and run the hook for one tool, then put it in
# config.yml: $2 = tools (link), required (link --required), or keep
# (update: config.yml stays as it is). Returns 1 on failure, and then
# config.yml isn't changed. Links even when there was nothing to install
# (plan Section 18).
_link_tool() {
  local tool="$1" as="${2:-keep}"
  if ! _install_package "$tool"; then
    return 1
  fi
  if ! _link_configs "$tool"; then
    return 1
  fi
  if ! _run_hook "$tool"; then
    return 1
  fi
  case "$as" in
    required) _config_set "$tool" required ;;
    tools)
      # Already in config.yml (also as required): left as it is.
      if ! _tool_is_listed "$tool"; then
        _config_set "$tool" tools
      fi
      ;;
  esac
}

# "tool (version)": the installed version; for a tool not installed yet
# in a dry run, the version that would be installed.
_tool_with_version() {
  local tool="$1"
  if [[ $(_tool_installed "$tool") == true ]]; then
    _with_version "$tool" "$(_tool_installed_version "$tool")"
  elif [[ $DRY_RUN == true && -n $(tool_package "$tool") ]]; then
    _with_version "$tool" "$(package_available_version "$(tool_package "$tool")")"
  else
    echo "$tool"
  fi
}

# Remove one tool's package (no question: unlink always removes it).
# Returns 1 when removing failed, so the tool stays linked and in config.yml.
_remove_package() {
  local tool="$1" cmd_name package
  cmd_name="$(tool_command "$tool")"
  package="$(tool_package "$tool")"

  if [[ -z $package ]]; then
    log info "$tool: no package to remove here; if you installed it by hand, remove it the same way"
    return 0
  fi
  # Several packages: remove whichever are installed (pm_remove skips the rest).
  local name any=false
  if [[ $package == *" "* ]]; then
    for name in $package; do
      if _package_version_one "$name" >/dev/null; then
        any=true
      fi
    done
  elif [[ $(_tool_installed "$tool") == true ]]; then
    any=true
  fi
  if [[ $any != true ]]; then
    log info "$tool: $cmd_name isn't installed; nothing to remove"
    return 0
  fi

  if ! pm_remove "$package"; then
    log error "$tool: removing $package failed"
    return 1
  fi
  if [[ $DRY_RUN == true ]]; then
    return 0
  fi
  hash -r
  if command -v "$cmd_name" >/dev/null 2>&1; then
    log warn "$tool: $package removed, but $cmd_name is still on PATH ($(command -v "$cmd_name")); it may be installed another way too"
  else
    log success "$tool: removed package $package"
  fi
}

# Remove the package, unlink, take the tool off config.yml. A required
# tool needs --force (then it comes off required:). Returns 1 on failure;
# a failed removal leaves the links and config.yml as they were. Hook
# steps aren't undone.
_unlink_tool() {
  local tool="$1"
  if _tool_is_required "$tool" && [[ $FORCE != true ]]; then
    log error "$tool: required on this machine (config.yml); kept it. dotfiles unlink --force $tool removes it"
    return 1
  fi
  if ! _remove_package "$tool"; then
    return 1
  fi
  if ! _unlink_configs "$tool"; then
    return 1
  fi
  if [[ $KEEP_CONFIG != true ]]; then
    _config_set "$tool" none
  fi
}

# ─── interactive link / unlink (plan Section 7) ─────────────────────────

ANSWER=""

# Interactive mode reads answers from the terminal.
_require_tty() {
  if ! { true </dev/tty; } 2>/dev/null; then
    log error "interactive mode needs a terminal; name tools instead, e.g. dotfiles link neovim"
    exit 1
  fi
}

# Show a prompt and read one line from the terminal into ANSWER.
_ask() {
  printf '%s' "$1" >/dev/tty
  ANSWER=""
  read -r ANSWER </dev/tty || true
  _log_to_file "INFO" "asked: $1-> ${ANSWER:-<Enter>}"
}

# Turn picks like "1 3 5-7" or "a" into numbers between 1 and max, in
# PICKS. Returns 1, with a message, when something isn't a valid pick.
PICKS=()
_parse_picks() {
  local input="${1//,/ }" max="$2" word from to i
  PICKS=()
  # Only digits, letters, spaces and dashes: keeps * and ? from being
  # expanded as file names when $input is split into words below.
  if [[ $input == *[!0-9A-Za-z\ -]* ]]; then
    ui "  Use numbers (1 3), ranges (2-4) or a."
    return 1
  fi
  for word in $input; do
    case "$word" in
      a | A | all)
        for ((i = 1; i <= max; i++)); do
          PICKS+=("$i")
        done
        ;;
      *-*)
        from="${word%-*}"
        to="${word#*-}"
        if ! [[ $from =~ ^[0-9]+$ && $to =~ ^[0-9]+$ ]] || ((from < 1 || to > max || from > to)); then
          ui "  \"$word\" isn't a range between 1 and $max."
          return 1
        fi
        for ((i = from; i <= to; i++)); do
          PICKS+=("$i")
        done
        ;;
      *)
        if ! [[ $word =~ ^[0-9]+$ ]] || ((word < 1 || word > max)); then
          ui "  \"$word\" isn't a number between 1 and $max."
          return 1
        fi
        PICKS+=("$word")
        ;;
    esac
  done
}

# Short state of a tool for the lists: installed / linked.
_state_text() {
  local tool="$1" text=""
  if _tool_is_installed "$tool"; then
    text="installed"
  elif _tool_package_get "$tool" && [[ -z $TOOL_PACKAGE ]] && ! _tool_has_hook "$tool"; then
    text="install by hand"
  fi
  # Only a tool with links (aether and vscode have none).
  if [[ -n $(tool_links "$tool") ]] && _tool_is_linked "$tool"; then
    text="${text:+$text, }linked"
  fi
  echo "${text:--}"
}

# The interactive setup: every tool used on this platform. Step 1 picks
# the tools ([x] = in config.yml; required ones can't be switched off),
# step 2 which of them are required here. Then each picked tool is linked
# (install, link, hook) and each one switched off is unlinked (package and
# links removed).
INTERACTIVE_FAILED=false
_screen_tools() {
  local -a names=() selected=() before=() required=()
  local name mark i n
  while IFS= read -r name; do
    _tool_is_used_here "$name" || continue
    names+=("$name")
    if _tool_is_listed "$name"; then
      selected+=(true)
      before+=(true)
    else
      selected+=(false)
      before+=(false)
    fi
    if _tool_is_required "$name"; then
      required+=(true)
    else
      required+=(false)
    fi
  done < <(manifest_tools)

  ui ""
  if [[ ${#names[@]} -eq 0 ]]; then
    ui "Tools: none for ${PLATFORM:-this platform} (add them to dotfiles.yml)"
    return 0
  fi

  # Step 1: the tools.
  while true; do
    ui "Tools ([x] = used here, [R] = required here):"
    for ((i = 0; i < ${#names[@]}; i++)); do
      mark=" "
      if [[ ${required[i]} == true ]]; then
        mark="R"
      elif [[ ${selected[i]} == true ]]; then
        mark="x"
      fi
      ui "$(printf '  %2d) [%s] %-16s %s' "$((i + 1))" "$mark" "${names[i]}" "$(_state_text "${names[i]}")")"
    done
    _ask "Enter = continue, or numbers to switch on/off (a = all on): "
    if [[ -z $ANSWER ]]; then
      break
    fi
    if [[ $ANSWER == a || $ANSWER == A ]]; then
      for ((i = 0; i < ${#names[@]}; i++)); do
        selected[i]=true
      done
    elif _parse_picks "$ANSWER" "${#names[@]}"; then
      for n in "${PICKS[@]}"; do
        if [[ ${required[n - 1]} == true ]]; then
          ui "  ${names[n - 1]} is required here; dotfiles unlink --force ${names[n - 1]} removes it."
        elif [[ ${selected[n - 1]} == true ]]; then
          selected[n - 1]=false
        else
          selected[n - 1]=true
        fi
      done
    fi
    ui ""
  done

  # Step 2: which picked tools are required here. Only the ones that
  # aren't yet can be switched (unlink --force takes one off).
  local -a picked=()
  for ((i = 0; i < ${#names[@]}; i++)); do
    if [[ ${selected[i]} == true ]]; then
      picked+=("$i")
    fi
  done
  if [[ ${#picked[@]} -gt 0 ]]; then
    local -a was_required=("${required[@]}")
    ui ""
    while true; do
      ui "Required here ([R] = unlink and this screen keep it):"
      for ((n = 0; n < ${#picked[@]}; n++)); do
        i="${picked[n]}"
        mark=" "
        if [[ ${required[i]} == true ]]; then
          mark="R"
        fi
        ui "$(printf '  %2d) [%s] %s' "$((n + 1))" "$mark" "${names[i]}")"
      done
      _ask "Enter = continue, or numbers to switch required on/off: "
      if [[ -z $ANSWER ]]; then
        break
      fi
      if _parse_picks "$ANSWER" "${#picked[@]}"; then
        for n in "${PICKS[@]}"; do
          i="${picked[n - 1]}"
          if [[ ${was_required[i]} == true ]]; then
            ui "  ${names[i]} is already required; dotfiles unlink --force ${names[i]} takes it off."
          elif [[ ${required[i]} == true ]]; then
            required[i]=false
          else
            required[i]=true
          fi
        done
      fi
      ui ""
    done
  fi

  # Run order: priority: high, then required, then the rest.
  local -a order=()
  local pass
  for pass in high required rest; do
    for ((i = 0; i < ${#names[@]}; i++)); do
      case "$pass" in
        high) _tool_is_high "${names[i]}" || continue ;;
        required) { ! _tool_is_high "${names[i]}" && [[ ${required[i]} == true ]]; } || continue ;;
        rest) { ! _tool_is_high "${names[i]}" && [[ ${required[i]} != true ]]; } || continue ;;
      esac
      order+=("$i")
    done
  done

  ui ""
  local as
  for i in "${order[@]}"; do
    name="${names[i]}"
    CHANGED=false
    if [[ ${selected[i]} == true ]]; then
      as=tools
      if [[ ${required[i]} == true ]]; then
        as=required
      fi
      if ! _link_tool "$name" "$as"; then
        ui "  $name: failed (see the messages above)"
        INTERACTIVE_FAILED=true
      elif [[ $CHANGED != true ]]; then
        ui "  $name: already installed and linked"
      elif [[ $DRY_RUN == true ]]; then
        ui "  Test: $(_tool_with_version "$name")"
      else
        ui "  $name: installed and linked ($(_tool_installed_version "$name"))"
      fi
    elif [[ ${before[i]} == true ]]; then
      if ! _unlink_tool "$name"; then
        ui "  $name: unlinking failed (see the messages above)"
        INTERACTIVE_FAILED=true
      elif [[ $DRY_RUN == true ]]; then
        ui "  Test: unlink $name"
      else
        ui "  $name: unlinked and removed"
      fi
    fi
  done
}

# dotfiles with no command.
_interactive_link() {
  _require_config
  local tool
  local -a here=()
  while IFS= read -r tool; do
    if _tool_is_used_here "$tool"; then
      here+=("$tool")
    fi
  done < <(manifest_tools)
  _require_sudo link ${here[@]+"${here[@]}"}
  _require_tty
  QUIET=true
  INTERACTIVE_FAILED=false
  _screen_tools
  _next_steps
  if [[ $INTERACTIVE_FAILED == true ]]; then
    exit 1
  fi
}

# dotfiles unlink with no tool: pick from the tools in config.yml (not the
# required ones).
_interactive_unlink() {
  _require_config
  local -a names=()
  local name n failed=false kept=""
  while IFS= read -r name; do
    if _tool_is_required "$name"; then
      kept="${kept:+$kept, }$name"
    else
      names+=("$name")
    fi
  done < <(_listed_tools)
  _require_sudo unlink ${names[@]+"${names[@]}"}
  _require_tty
  QUIET=true

  ui ""
  if [[ ${#names[@]} -eq 0 ]]; then
    ui "No tools in config.yml to unlink${kept:+ (required: $kept)}."
    return 0
  fi
  ui "Tools in config.yml:"
  for ((n = 0; n < ${#names[@]}; n++)); do
    ui "$(printf '  %2d) %-16s %s' "$((n + 1))" "${names[n]}" "$(_state_text "${names[n]}")")"
  done
  if [[ -n $kept ]]; then
    ui "  Required (not listed; unlink --force <tool>): $kept"
  fi
  while true; do
    _ask "Unlink and remove: numbers (a = all), Enter = nothing: "
    if [[ -z $ANSWER ]]; then
      return 0
    fi
    if _parse_picks "$ANSWER" "${#names[@]}"; then
      break
    fi
  done

  for n in "${PICKS[@]}"; do
    name="${names[n - 1]}"
    CHANGED=false
    if ! _unlink_tool "$name"; then
      ui "  $name: failed (see the messages above)"
      failed=true
    elif [[ $DRY_RUN == true ]]; then
      ui "  Test: unlink $name"
    else
      ui "  $name: unlinked and removed"
    fi
  done
  if [[ $failed == true ]]; then
    exit 1
  fi
}

# ─── wipe: undo everything dotfiles set up on this machine ──────────────

# true = unlink leaves config.yml as it is (wipe).
KEEP_CONFIG=false

# What wipe will do, before it asks. Fills WIPE_REMOVE (packages to remove).
WIPE_REMOVE=""
_wipe_preview() {
  local tool package keep="" count=0
  WIPE_REMOVE=""
  while IFS= read -r tool; do
    _tool_is_used_here "$tool" || continue
    count=$((count + 1))
    package="$(tool_package "$tool")"
    if _tool_is_required "$tool"; then
      keep="${keep:+$keep }$tool"
    elif _tool_is_listed "$tool" && [[ -n $package && $(_tool_installed "$tool") == true ]]; then
      WIPE_REMOVE="${WIPE_REMOVE:+$WIPE_REMOVE, }$tool ($package)"
    fi
  done < <(manifest_tools)
  ui ""
  ui "Wipe: undo everything dotfiles set up on this machine"
  ui "  unlink:  all $count tools used on ${PLATFORM:-this platform} (links and system copies; backups go back)"
  ui "  remove:  packages of the tools in config.yml: ${WIPE_REMOVE:-none}"
  ui "  keep:    required packages: ${keep:-none}"
  ui "  remove:  dotfiles' own link: ~/.local/bin/dotfiles"
  ui "  keep:    $(_tilde "$DOTFILES_CONFIG"), everything in the repo, the log"
  ui ""
}

# Last step: dotfiles' own link. Nothing in the repo is touched, and
# config.yml stays (link sets up the same tools again).
_wipe_self() {
  local src dest
  while IFS=$'\t' read -r src dest; do
    if [[ $(_link_state "$src" "$HOME/$dest") == linked ]]; then
      run_cmd rm "$HOME/$dest"
      if [[ $DRY_RUN != true ]]; then
        log success "dotfiles: removed ~/$dest"
      fi
    fi
  done < <(_self_links)
}

cmd_wipe() {
  _require_config
  if [[ $# -gt 0 ]]; then
    log error "wipe takes no tool names (it undoes everything; unlink takes tools)"
    exit 2
  fi
  local -a tools=()
  local tool host answer failed=""
  while IFS= read -r tool; do
    if _tool_is_used_here "$tool"; then
      tools+=("$tool")
    fi
  done < <(manifest_tools)
  _wipe_preview

  if [[ $DRY_RUN != true ]]; then
    host="$(uname -n)"   # uname (coreutils): minimal systems lack hostname
    host="${host%%.*}"
    if ! { true </dev/tty; } 2>/dev/null; then
      log error "wipe asks you to type the hostname to confirm, and there's no terminal; nothing changed"
      exit 1
    fi
    printf 'This removes the packages and links above. Type the hostname (%s) to continue: ' "$host" >/dev/tty
    read -r answer </dev/tty || answer=""
    if [[ $answer != "$host" ]]; then
      log warn "wipe: hostname didn't match; nothing changed"
      exit 1
    fi
    _log_to_file "INFO" "wipe confirmed"
  fi
  _require_sudo unlink ${tools[@]+"${tools[@]}"}

  KEEP_CONFIG=true
  for tool in ${tools[@]+"${tools[@]}"}; do
    CHANGED=false
    # Packages only for the tools in config.yml (dotfiles didn't install
    # the others), and never the required ones. Keep going when a package
    # can't be removed (pacman refuses packages others depend on): the
    # links still come out.
    if _tool_is_listed "$tool" && ! _tool_is_required "$tool" && ! _remove_package "$tool"; then
      failed="${failed:+$failed, }$tool (package)"
    fi
    if ! _unlink_configs "$tool"; then
      failed="${failed:+$failed, }$tool (links)"
    fi
  done
  _wipe_self

  out ""
  if [[ -n $failed ]]; then
    out "wipe: done, with problems: $failed"
    out "      (packages others depend on stay installed; see the messages above)"
    exit 1
  fi
  if [[ $DRY_RUN == true ]]; then
    out "wipe: dry run, nothing changed"
  else
    out "wipe: done. Set up again with: $DOTFILES/dotfiles.sh link"
  fi
}

# ─── update (plan Section 7) ────────────────────────────────────────────

# Fetch, show what's coming in, then pull --rebase --autostash. A dry run
# fetches (changes no files) and stops before pulling.
PULLED=false   # update: the pull brought new commits
_update_pull() {
  local upstream output incoming count
  if ! upstream="$(git -C "$DOTFILES" rev-parse --abbrev-ref '@{u}' 2>/dev/null)"; then
    log error "the current branch has no upstream to pull from; set one with: git -C \"$DOTFILES\" branch --set-upstream-to origin/<branch>"
    return 1
  fi

  log info "fetching $upstream"
  if ! output="$(git -C "$DOTFILES" fetch 2>&1)"; then
    log error "git fetch failed: $output"
    return 1
  fi
  if [[ -n $output ]]; then
    _log_to_file "DEBUG" "  > $output"
  fi

  # HEAD..@{u} = commits on the upstream that aren't here yet.
  incoming="$(git -C "$DOTFILES" log --oneline 'HEAD..@{u}')"
  if [[ -z $incoming ]]; then
    log success "repo: up to date with $upstream"
    return 0
  fi
  out "Incoming from $upstream:"
  while IFS= read -r output; do
    out "  $output"
  done <<<"$incoming"
  count="$(grep -c '' <<<"$incoming")"

  if [[ $DRY_RUN == true ]]; then
    log info "dry run: the installs and links below use dotfiles.yml as it is now; the pull may change it"
  fi
  if ! run_cmd git -C "$DOTFILES" pull --rebase --autostash; then
    log error "git pull failed. Check: git -C \"$DOTFILES\" status. If a rebase is in progress, fix the files, then git rebase --continue (or git rebase --abort to undo)."
    return 1
  fi
  PULLED=true
  if [[ $DRY_RUN != true ]]; then
    log success "repo: pulled $count commit(s) from $upstream"
  fi
}

cmd_update() {
  _require_config
  if ! command -v git >/dev/null 2>&1; then
    log error "git isn't installed; run: dotfiles.sh doctor"
    exit 1
  fi
  if ! git -C "$DOTFILES" rev-parse --git-dir >/dev/null 2>&1; then
    log error "$DOTFILES isn't a git repo; nothing to pull"
    exit 1
  fi
  if ! _update_pull; then
    exit 1
  fi
  # The pull may have changed dotfiles.yml or the hooks: read them again.
  if [[ $PULLED == true && $DRY_RUN != true ]]; then
    _cfg_reload
  fi
  # Install what's missing (no upgrades) and relink every tool in config.yml.
  local tool good="" bad=""
  _pick_tools update
  if [[ ${#TOOLS[@]} -eq 0 ]]; then
    return 0
  fi
  # After the pull: the new commits decide whether a system file changes.
  _require_sudo link "${TOOLS[@]}"
  local changed=$PULLED
  for tool in "${TOOLS[@]}"; do
    CHANGED=false
    _tool_hold
    if ! _link_tool "$tool" keep; then
      _tool_release
      bad="${bad:+$bad, }$tool"
    else
      _tool_done "$tool"
      if [[ $CHANGED == true ]]; then
        changed=true
        good="${good:+$good, }$(_tool_with_version "$tool")"
      fi
    fi
  done
  _render_theme
  if [[ $THEME_CHANGED == true ]]; then
    changed=true
  fi
  _summary "installed or linked" "$good" "$bad"
  _next_steps
  if [[ $changed != true && -z $bad ]]; then
    log info "update: nothing to change"
  fi
  if [[ -n $bad ]]; then
    exit 1
  fi
}

# ─── first run (plan Section 2) ─────────────────────────────────────────

# The link dotfiles.sh always makes for itself: the command. (Its config
# folder, ~/.config/dotfiles, used to be a link too; it's a real folder
# since #51, holding this machine's config.yml.)
_self_links() {
  printf '%s\t%s\n' "$DOTFILES/dotfiles.sh" ".local/bin/dotfiles"
}

# Git signs commits through 1Password's op-ssh-sign, whose path differs per
# OS, and git's own config can't choose by OS. So dotfiles writes the path
# for this machine into config/git/local.gitconfig (included by .gitconfig,
# gitignored), and rewrites it when it's missing or wrong.
_op_ssh_sign_path() {
  local helper=""
  case "$DOTFILES_OS" in
    linux)   helper="/opt/1Password/op-ssh-sign" ;;
    macos)   helper="/Applications/1Password.app/Contents/MacOS/op-ssh-sign" ;;
    windows) helper="${LOCALAPPDATA:-$HOME/AppData/Local}/1Password/app/8/op-ssh-sign.exe" ;;
  esac
  if [[ -n $helper && -x $helper ]]; then
    echo "$helper"
  fi
}

_setup_git_signing() {
  local helper want file="$DOTFILES/config/git/local.gitconfig"
  helper="$(_op_ssh_sign_path)"
  if [[ -z $helper ]]; then
    log warn "git signing: 1Password's op-ssh-sign isn't installed here, so commits can't be signed until it is"
    return 1
  fi
  want="$(printf '%s\n' \
    "# GENERATED FILE: do not edit. dotfiles writes this for this machine's OS." \
    "# 1Password's ssh signing helper; its path differs per OS." \
    '[gpg "ssh"]' \
    "	program = $helper")"
  if [[ -f $file && $(cat "$file") == "$want" ]]; then
    log debug "git signing: ${file#"$DOTFILES"/} is up to date"
    return 0
  fi
  if [[ $DRY_RUN == true ]]; then
    log info "dry run, would write ${file#"$DOTFILES"/} (gpg.ssh.program = $helper)"
    return 0
  fi
  printf '%s\n' "$want" >"$file"
  log success "git signing: wrote ${file#"$DOTFILES"/} (op-ssh-sign for $DOTFILES_OS)"
}

# Make (or repair) both self links. Returns 1 if one isn't in place.
_setup_self_links() {
  local src dest ok=true
  while IFS=$'\t' read -r src dest; do
    if ! _link_path dotfiles "$src" "$dest"; then
      ok=false
    fi
  done < <(_self_links)
  [[ $ok == true ]]
}

# Say how to put ~/.local/bin (the command's folder, on every OS) on PATH
# when it isn't. Changes no files. Once per run (first run and doctor both
# ask).
PATH_CHECKED=false
_path_check() {
  if [[ $PATH_CHECKED == true ]]; then
    return 0
  fi
  PATH_CHECKED=true
  local bin_dir="$HOME/.local/bin" shown="~/.local/bin"
  case ":$ORIG_PATH:" in
    *":$bin_dir:"*)
      log debug "$shown is on PATH"
      return 0
      ;;
  esac
  local file
  case "${SHELL##*/}" in
    zsh) file="~/.zshenv" ;;
    bash)
      if [[ $DOTFILES_OS == macos ]]; then
        file="~/.bash_profile"
      else
        file="~/.bashrc"
      fi
      ;;
    *) file="your shell's startup file" ;;
  esac
  log warn "$shown isn't on PATH, so the 'dotfiles' command won't be found. Add this line to $file, then open a new terminal:"
  ui "  export PATH=\"\$HOME/${shown#\~/}:\$PATH\""
}

# Running from curl | bash: get git, clone the repo, then run the cloned
# copy instead of this one in memory (plan Section 2).
_bootstrap() {
  local branch="${DOTFILES_BRANCH:-main}" repo="${DOTFILES_REPO:-$DEFAULT_DOTFILES_REPO}"
  if [[ -z ${DOTFILES:-} ]]; then
    local answer=""
    if [[ $DRY_RUN == true ]]; then
      log info "dry run, would ask where to clone (suggestion: $(_tilde "$SUGGESTED_DOTFILES_DIR"))"
    elif { true </dev/tty; } 2>/dev/null; then
      printf 'Clone the dotfiles repo to [%s]: ' "$(_tilde "$SUGGESTED_DOTFILES_DIR")" >/dev/tty
      read -r answer </dev/tty || true
      _log_to_file "INFO" "asked: clone to -> ${answer:-<Enter>}"
    else
      # No terminal to ask (run from a script or over ssh): take the default.
      log info "first run: no terminal to ask where to clone; using the default"
    fi
    answer="${answer/#\~/$HOME}"            # a typed ~ means $HOME
    DOTFILES="${answer:-$SUGGESTED_DOTFILES_DIR}"
    if [[ $DOTFILES != /* ]]; then
      DOTFILES="$PWD/$DOTFILES"               # a relative path is from here
    fi
  fi
  log info "first run: not running from a clone; using $DOTFILES"

  if [[ -d $DOTFILES/.git ]]; then
    log info "found an existing clone at $DOTFILES"
  else
    if ! command -v git >/dev/null 2>&1; then
      _doctor_install git || true
      if [[ $DRY_RUN != true ]] && ! command -v git >/dev/null 2>&1; then
        log error "first run: git is needed to clone the repo and couldn't be installed"
        exit 1
      fi
    fi
    if [[ -e $DOTFILES && -n $(ls -A "$DOTFILES" 2>/dev/null) ]]; then
      log error "first run: $DOTFILES exists, isn't empty, and isn't a git clone; move it or set DOTFILES to another folder"
      exit 1
    fi
    run_cmd mkdir -p "$(dirname "$DOTFILES")"
    if ! run_cmd git clone --branch "$branch" "$repo" "$DOTFILES"; then
      log error "first run: cloning $repo ($branch) failed"
      exit 1
    fi
  fi

  if [[ $DRY_RUN == true ]]; then
    log info "dry run: would continue with $DOTFILES/dotfiles.sh"
    exit 0
  fi
  log info "first run: continuing with the cloned copy, $DOTFILES/dotfiles.sh"
  export DOTFILES
  export DOTFILES_FIRST_RUN=1
  export APT_UPDATED   # the cloned copy doesn't refresh apt's lists again
  PATH="$ORIG_PATH"    # hand over the user's PATH, not this run's
  # exec replaces this process: what runs from here on is the file on disk.
  exec bash "$DOTFILES/dotfiles.sh" ${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}
}

# First run, now from the clone: yq, the self links, the PATH hint. Then
# the requested command runs as usual (interactive install by default).
_first_run_setup() {
  unset DOTFILES_FIRST_RUN
  log info "first run: setting up dotfiles.sh"
  _doctor_yq
  if [[ $YQ_OK != true ]]; then
    log error "first run: yq is needed to read dotfiles.yml; fix the yq problem above, then run: $DOTFILES/dotfiles.sh"
    exit 1
  fi
  load_settings
  if ! _setup_self_links; then
    log warn "first run: the dotfiles command link isn't in place (see above); dotfiles.sh still works from $DOTFILES/dotfiles.sh"
  fi
  _setup_git_signing || true
  _path_check
}

# doctor: the command link and PATH.
_doctor_self_links() {
  if [[ -z $DOTFILES ]]; then
    return 0
  fi
  local src dest state missing=false
  while IFS=$'\t' read -r src dest; do
    state="$(_link_state "$src" "$HOME/$dest")"
    log debug "self link ~/$dest is $state"
    if [[ $state != linked ]]; then
      missing=true
    fi
  done < <(_self_links)

  if [[ $missing != true ]]; then
    _check_ok "self link: $(_self_links | cut -f2 | sed 's|^|~/|' | paste -sd ' ' -)"
  elif _setup_self_links; then
    _check_ok "self link: made (or would make, in a dry run)"
  else
    _check_fail "self link: not in place (see above)"
  fi
  if _setup_git_signing; then
    _check_ok "git signing: $(_op_ssh_sign_path)"
  fi
  _path_check
}

# ─── doctor (plan Section 7) ────────────────────────────────────────────

DOCTOR_FAILED=0
YQ_OK=false

_check_ok()   { log success "$1"; }
# $((x + 1)) instead of ((x++)): ((x++)) returns 1 when x was 0, and
# set -e would end the script right there.
_check_fail() { log error "$1"; DOCTOR_FAILED=$((DOCTOR_FAILED + 1)); }

_doctor_os() {
  case "$DOTFILES_OS" in
    "")
      _check_fail "OS: not supported ($(uname -s))"
      ;;
    linux)
      if [[ -n $DISTRO_ID ]]; then
        _check_ok "OS: linux, $DOTFILES_DISTRO (package manager: $PKG_MANAGER)"
      else
        _check_fail "OS: linux, but this distro isn't supported ($DOTFILES_DISTRO)"
      fi
      ;;
    *)
      _check_ok "OS: $DOTFILES_OS"
      ;;
  esac
}

# Package name of a prerequisite on this OS. Prints nothing (and the
# reason on stderr via log) when there's no native package for it.
_prereq_package() {
  local tool="$1"
  # In the script, not dotfiles.yml: yq is needed to read the config, and
  # git to clone the repo it lives in.
  case "$tool:$PKG_MANAGER" in
    git:winget)  echo "Git.Git" ;;
    git:*)       echo "git" ;;
    yq:pacman)   echo "go-yq" ;;
    yq:dnf)      echo "yq" ;;
    yq:brew)     echo "yq" ;;
    yq:winget)   echo "MikeFarah.yq" ;;
    # yq:apt has no package: apt's yq is the Python one (see _install_yq_release).
  esac
}

# Debian/Ubuntu: apt's yq is the Python one, so get mikefarah/yq from its
# GitHub release into ~/.local/bin, checking the published SHA-256 first.
# The one exception to "native package managers only" (decided 2026-10-12).
_install_yq_release() {
  local arch tag base tmp pos expected actual
  case "$(uname -m)" in
    x86_64)          arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    armv7l)          arch="arm" ;;
    i?86)            arch="386" ;;
    *)
      log error "yq: no release binary for $(uname -m); install mikefarah/yq by hand"
      return 1
      ;;
  esac
  if ! command -v curl >/dev/null 2>&1; then
    pm_install curl || return 1
    hash -r
  fi
  CHANGED=true
  if [[ $DRY_RUN == true ]]; then
    log info "dry run, would download yq_linux_$arch from https://github.com/mikefarah/yq/releases/latest into ~/.local/bin, after checking its SHA-256"
    return 0
  fi

  # Pin one release: "latest" redirects to .../tag/vX.Y.Z.
  if ! tag="$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/mikefarah/yq/releases/latest)"; then
    log error "yq: couldn't reach GitHub to find the latest release"
    return 1
  fi
  tag="${tag##*/}"
  base="https://github.com/mikefarah/yq/releases/download/$tag"
  tmp="$(mktemp -d)"
  log info "yq: downloading $tag (yq_linux_$arch) from GitHub"
  if ! curl -fsSL -o "$tmp/yq" "$base/yq_linux_$arch" ||
    ! curl -fsSL -o "$tmp/checksums" "$base/checksums" ||
    ! curl -fsSL -o "$tmp/order" "$base/checksums_hashes_order"; then
    log error "yq: download failed"
    rm -rf "$tmp"
    return 1
  fi

  # checksums: "<file> <hash> <hash> ..." in the order that
  # checksums_hashes_order lists; field 1 is the file name.
  pos="$(grep -n -x 'SHA-256' "$tmp/order" | cut -d: -f1)"
  expected="$(awk -v file="yq_linux_$arch" -v n="$((${pos:-0} + 1))" '$1 == file { print $n }' "$tmp/checksums")"
  actual="$(sha256sum "$tmp/yq" | cut -d' ' -f1)"
  if [[ -z $expected || $expected != "$actual" ]]; then
    log error "yq: SHA-256 doesn't match (expected ${expected:-none}, got $actual); not installing it"
    rm -rf "$tmp"
    return 1
  fi
  log success "yq: SHA-256 matches ($actual)"

  mkdir -p "$HOME/.local/bin"
  mv "$tmp/yq" "$HOME/.local/bin/yq"
  chmod 755 "$HOME/.local/bin/yq"
  rm -rf "$tmp"
  log success "yq: installed $tag to ~/.local/bin/yq"
}

# Install a missing prerequisite, then look for it again.
_doctor_install() {
  local tool="$1" package
  if [[ $tool == yq && $PKG_MANAGER == apt ]]; then
    log info "yq: not installed; apt's yq is a different tool, so getting it from GitHub"
    _install_yq_release || return 1
    hash -r
    return 0
  fi
  package="$(_prereq_package "$tool")"
  if [[ -z $package ]]; then
    return 1
  fi
  log info "$tool: not installed, installing package $package"
  if ! pm_install "$package"; then
    log error "$tool: installing $package failed"
    return 1
  fi
  # hash -r forgets remembered command locations, so the new one is found.
  hash -r
}

# Why a prerequisite is still missing after _doctor_install.
_missing_reason() {
  if [[ $DRY_RUN == true ]]; then
    echo "not installed (dry run: nothing was installed)"
  else
    echo "not installed"
  fi
}

_doctor_git() {
  if ! command -v git >/dev/null 2>&1; then
    _doctor_install git || true
    if ! command -v git >/dev/null 2>&1; then
      _check_fail "git: $(_missing_reason)"
      return 0
    fi
  fi
  _check_ok "git: $(git --version) at $(command -v git)"
}

# Two different tools are called yq. The plan needs mikefarah/yq (Go, v4);
# the Python one (kislyuk/yq) has a different syntax.
_doctor_yq() {
  if ! command -v yq >/dev/null 2>&1; then
    _doctor_install yq || true
    if ! command -v yq >/dev/null 2>&1; then
      _check_fail "yq: $(_missing_reason) (needs mikefarah/yq v4)"
      return 0
    fi
  fi

  local version
  version="$(yq --version 2>&1 || true)"
  log debug "yq --version: $version"

  case "$version" in
    *mikefarah*)
      YQ_OK=true
      _check_ok "yq: $version at $(command -v yq)"
      ;;
    *)
      # Not replaced automatically: both install a command called yq.
      _check_fail "yq: $(command -v yq) is not mikefarah/yq ($version); remove it, then run doctor again"
      ;;
  esac
}

CONFIG_OK=false

# dotfiles.yml: there, valid YAML, read.
_doctor_config() {
  if [[ -z $DOTFILES ]]; then
    _check_fail "dotfiles.yml: DOTFILES isn't set and the script isn't running from a clone"
    return 0
  fi
  if [[ ! -f $DOTFILES_TOOLS ]]; then
    _check_fail "dotfiles.yml: not found at $DOTFILES_TOOLS"
    return 0
  fi
  if [[ $YQ_OK != true ]]; then
    _check_fail "dotfiles.yml: can't check it without mikefarah/yq"
    return 0
  fi
  # 2>&1 >/dev/null: keep only the error text, throw the parsed output away.
  local err
  if ! err="$(yq eval '.' "$DOTFILES_TOOLS" 2>&1 >/dev/null)"; then
    _check_fail "dotfiles.yml: invalid YAML: $err"
    return 0
  fi
  _cfg_load
  if [[ $CFG_LOADED != true ]]; then
    _check_fail "dotfiles.yml: yq can't read its tools: (is it a map of tools?)"
    return 0
  fi
  CONFIG_OK=true
  local hooks=0 hook
  for hook in "$HOOKS_DIR"/*.sh; do
    [[ -f $hook ]] && hooks=$((hooks + 1))
  done
  _check_ok "dotfiles.yml: valid YAML, $(grep -c . <<<"$CFG_TOOLS") tools, $hooks hooks ($DOTFILES_TOOLS)"
  if [[ -f $DOTFILES/config/dotfiles/config.yaml ]]; then
    log warn "config/dotfiles/config.yaml is the old layout; dotfiles.yml replaced it (#51). Delete it once config.yml is written"
  fi
}

# config.yml: this machine's file (written by load_settings when it was
# missing), valid, and only names of tools used here.
_doctor_machine() {
  if [[ $CONFIG_OK != true ]]; then
    return 0
  fi
  local shown
  shown="$(_tilde "$DOTFILES_CONFIG")"
  if [[ -L $CONFIG_DIR && $(_physical "$CONFIG_DIR") == "$(_physical "$DOTFILES/config/dotfiles")" ]]; then
    if [[ $DRY_RUN == true ]]; then
      log info "config.yml: $(_tilde "$CONFIG_DIR") still links into the repo (dry run; doctor without -d makes it a real folder)"
    else
      _check_fail "config.yml: $(_tilde "$CONFIG_DIR") links into the repo; it must be a real folder"
    fi
    return 0
  fi
  if [[ ! -f $DOTFILES_CONFIG ]]; then
    if [[ $DRY_RUN == true ]]; then
      log info "config.yml: not there yet (dry run; doctor without -d writes it)"
    else
      _check_fail "config.yml: not found at $shown"
    fi
    return 0
  fi
  local err
  if ! err="$(yq eval '.' "$DOTFILES_CONFIG" 2>&1 >/dev/null)"; then
    _check_fail "config.yml: invalid YAML: $err"
    return 0
  fi
  if [[ -n $(yq eval '(.required // [] | select(tag != "!!seq")), (.tools // [] | select(tag != "!!seq"))' "$DOTFILES_CONFIG" 2>/dev/null) ]]; then
    _check_fail "config.yml: required: and tools: must be lists (required: [git, zsh])"
    return 0
  fi
  local name unknown="" elsewhere=""
  while IFS= read -r name; do
    [[ -n $name ]] || continue
    if ! _tool_exists "$name"; then
      unknown="${unknown:+$unknown }$name"
    elif ! _tool_is_used_here "$name"; then
      elsewhere="${elsewhere:+$elsewhere }$name"
    fi
  done <<<"$CFG_REQUIRED$CFG_USED"
  if [[ -n $unknown ]]; then
    log warn "config.yml: not tools (not in dotfiles.yml or hooks/): $unknown"
  fi
  if [[ -n $elsewhere ]]; then
    log warn "config.yml: not used on ${PLATFORM:-this platform}, skipped: $elsewhere"
  fi
  _check_ok "config.yml: $(grep -c . <<<"$CFG_REQUIRED" || true) required, $(grep -c . <<<"$CFG_USED" || true) other tools ($shown)"
}

# Everything in dotfiles.yml that dotfiles would skip or misread: unknown
# fields, unknown platform names, priorities other than high, dests that
# aren't $HOME/…, ~/… or a full path. One yq call, "tool<TAB>problem" lines.
_doctor_yml_problems() {
  _yq '.tools // {} | to_entries | .[] | .key as $t | .value as $v | (
    ($v // {} | keys | .[] | select(. != "priority" and . != "package" and . != "command" and . != "links" and . != "clone") | $t + "\tunknown field " + . + ":"),
    ($v.priority | select(. != null and . != "high") | $t + "\tpriority: " + (. | tostring) + " (only high exists)"),
    (($v.package, $v.command) | select(tag == "!!map") | keys | .[] | select(. != "arch" and . != "debian" and . != "fedora" and . != "mac" and . != "windows" and . != "linux" and . != "all") | $t + "\tunknown platform " + . + ": (arch, debian, fedora, mac, windows, linux, all)"),
    ($v.links | select(tag == "!!map") | to_entries | .[] | .key as $s | .value | select(tag == "!!map") | keys | .[] | select(. != "arch" and . != "debian" and . != "fedora" and . != "mac" and . != "windows" and . != "linux" and . != "all") | $t + "\tlink " + $s + ": unknown platform " + .),
    ($v.links | select(tag == "!!map") | to_entries | .[] | .key as $s | (.value | select(tag == "!!str")), (.value | select(tag == "!!map") | .[] | select(. != null)) | select(test("^(\$HOME/|\$\{HOME\}/|~/|/)") | not) | $t + "\tlink " + $s + ": dest " + . + " must start with $HOME/, ~/ or /"),
    ($v.links | select(. != null and tag != "!!map") | $t + "\tlinks: must be a map (path: dest), not " + (. | tag)),
    ($v.clone | select(. != null and tag != "!!map") | $t + "\tclone: must be a map (owner/repo: dest), not " + (. | tag)) )' 2>/dev/null
}

# One tool on this machine: used here or not, link sources there, the hook
# valid bash. -v shows what each resolves to. Returns the problem count.
_doctor_tool() {
  local tool="$1" problems=0 package src dest count=0 hook="$HOOKS_DIR/$1.sh"
  if ! _tool_is_used_here "$tool"; then
    log debug "$tool: not used on ${PLATFORM:-this platform}"
    return 0
  fi
  package="$(tool_package "$tool")"
  log debug "$tool: package=${package:-<none>} command=$(tool_command "$tool")$(_tool_has_hook "$tool" && echo " hook=hooks/$tool.sh")"
  if [[ -f $hook ]] && ! bash -n "$hook" 2>/dev/null; then
    log error "$tool: hooks/$tool.sh has a syntax error (bash -n $hook)"
    problems=$((problems + 1))
  fi
  while IFS=$'\t' read -r src dest; do
    count=$((count + 1))
    log debug "$tool: link config/${src:-?} -> $(_dest_shown "${dest:-?}")"
    if [[ ! -e $(_src_path "$src") ]]; then
      # Only a tool in config.yml fails: the others aren't linked yet.
      if _tool_is_listed "$tool"; then
        log error "$tool: link source config/$src doesn't exist"
        problems=$((problems + 1))
      else
        log warn "$tool: link source config/$src doesn't exist (not in config.yml)"
      fi
    fi
  done < <(tool_links "$tool")
  if [[ $count -eq 0 ]]; then
    log debug "$tool: nothing to link on ${PLATFORM:-this platform}"
  fi
  return "$problems"
}

_doctor_tools() {
  if [[ $CONFIG_OK != true ]]; then
    return 0
  fi
  local tool count=0 bad=0 unused=0 line problems
  problems="$(_doctor_yml_problems)" || problems=""
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    log error "dotfiles.yml: ${line%%$'\t'*}: ${line#*$'\t'}"
  done <<<"$problems"
  while IFS= read -r tool; do
    count=$((count + 1))
    if ! _tool_is_used_here "$tool"; then
      unused=$((unused + 1))
    fi
    if ! _doctor_tool "$tool"; then
      bad=$((bad + 1))
    fi
  done < <(manifest_tools)
  if [[ -n $problems ]]; then
    bad=$((bad + $(grep -c . <<<"$problems")))
  fi
  if [[ $bad -gt 0 ]]; then
    _check_fail "tools: $bad problem(s) in $count tools on ${PLATFORM:-this platform}"
  else
    _check_ok "tools: all $count resolve on ${PLATFORM:-this platform} ($((count - unused)) used here)"
  fi
}

cmd_doctor() {
  _doctor_os
  _doctor_git
  _doctor_yq
  _doctor_config
  load_settings
  _config_sync
  _doctor_machine
  _doctor_self_links
  _doctor_tools

  if [[ $DOCTOR_FAILED -gt 0 ]]; then
    log error "doctor: $DOCTOR_FAILED check(s) failed"
    exit 1
  fi
  log success "doctor: all checks passed"
}

# ════════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════════

# ─── Banner ─────────────────────────────────────────────────────────────
# "dotfiles" in figlet's fraktur font, drawn once and kept here so a new
# machine shows it before figlet is installed. It fades through the
# terminal's ANSI colours from top to bottom (red, yellow, green, cyan,
# blue, magenta), so the terminal's theme decides the actual colours. Only
# on a terminal at least 84 columns wide (no banner in pipes, logs or
# narrow windows); --no-color shows it without colour.
_banner() {
  if [[ ! -t 1 ]]; then
    return 0
  fi
  local cols="${COLUMNS:-}" art
  if [[ -z $cols ]]; then
    cols="$(tput cols 2>/dev/null)" || cols=80
  fi
  if [[ $cols -lt 84 ]]; then
    return 0
  fi
  IFS= read -r -d '' art <<'EOF' || true
   ..                        s                 .          ..               .x+=:.
 dF                         :8       oec :    @88>  x .d88"               z`    ^%
'88bu.             u.      .88      @88888    %8P    5888R                   .   <k
'*88888bu    ...ue888b    :888ooo   8"*88%     .     '888R        .u       .@8Ned8"
  ^"*8888N   888R Y888r -*8888888   8b.      .@88u    888R     ud8888.   .@^%8888"
 beWE "888L  888R I888>   8888     u888888> ''888E`   888R   :888'8888. x88:  `)8b.
 888E  888E  888R I888>   8888      8888R     888E    888R   d888 '88%" 8888N=*8888
 888E  888E  888R I888>   8888      8888P     888E    888R   8888.+"     %8"    R88
 888E  888F u8888cJ888   .8888Lu=   *888>     888E    888R   8888L        @8Wou 9%
.888N..888   "*888*P"    ^%888*     4888      888&   .888B . '8888c. .+ .888888P`
 `"888*""      'Y"         'Y"      '888      R888"  ^*888%   "88888%   `   ^"F
    ""                               88R       ""      "%       "YP'
                                     88>
                                     48
                                     '8
EOF
  # A blank line above, so it doesn't touch the line before it.
  printf '\n'
  if [[ $NO_COLOR_FLAG == true ]]; then
    printf '%s\n\n' "$art"
    return 0
  fi
  # 15 lines over 6 colours: each colour gets its share of the lines.
  local -a colors=(31 33 32 36 34 35)
  local line i=0 total
  total="$(grep -c '' <<<"$art")"
  while IFS= read -r line; do
    printf '\033[1;%sm%s\033[0m\n' "${colors[i * ${#colors[@]} / total]}" "$line"
    i=$((i + 1))
  done <<<"$art"
  printf '\n'
}

main() {
  ORIG_ARGS=("$@")
  # No need to start dotfiles with sudo: it asks for sudo itself when a
  # tool has system files. Started with sudo anyway: run as the user who ran
  # it, so the clone, links, config.yml and log stay theirs (sudo doesn't
  # ask again). A real root login or a container has no SUDO_USER.
  if [[ $EUID -eq 0 && -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then
    if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
      exec sudo -u "$SUDO_USER" -H bash "${BASH_SOURCE[0]}" "$@"
    fi
    echo "[ERROR] don't run the first run with sudo; run it as $SUDO_USER (curl ... | bash). It asks for sudo by itself when needed." >&2
    exit 1
  fi
  # This run always looks in ~/.local/bin too: dotfiles.sh puts its own
  # command (and yq on Debian/Ubuntu) there. Only for this process.
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
  esac
  init_log
  _log_to_file "DEBUG" "──── run start: dotfiles.sh, args: $*"

  parse_args "$@"
  # "${ARGS[@]}" on an empty array is an "unbound variable" error in
  # Bash < 4.4 under set -u; the ${ARGS[@]+...} form avoids it.
  set -- ${ARGS[@]+"${ARGS[@]}"}

  log debug "flags: dry-run=$DRY_RUN force=$FORCE verbose=$VERBOSE"
  log debug "log file: ${LOG_FILE:-<none>}"

  # No command = the interactive setup (plan Section 7).
  local cmd="${1:-interactive}"
  if [[ $# -gt 0 ]]; then
    shift
  fi
  LOG_CMD="$cmd"
  log debug "command: $cmd, arguments: ${*:-<none>}"

  resolve_dotfiles
  detect_os
  # From curl | bash there is no file on disk: clone first (plan Section 2).
  if [[ $RUNNING_FROM_FILE != true ]]; then
    _bootstrap
  fi
  # After _bootstrap: a first run from curl | bash shows it once, from the clone.
  case "$cmd" in
    interactive | update) _banner ;;
    help | status | doctor) _title ;;
  esac
  if [[ ${DOTFILES_FIRST_RUN:-} == 1 ]]; then
    _first_run_setup
  elif [[ $cmd != doctor ]]; then
    load_settings
  fi
  case "$cmd" in
    help | version) ;;
    *) pkg_cache_load ;;
  esac
  # config.yml follows what's installed (doctor does it after its checks).
  case "$cmd" in
    help | version | doctor) ;;
    *) _config_sync ;;
  esac
  warn_unused_flags "$cmd"

  case "$cmd" in
    interactive) cmd_interactive ;;
    link)      cmd_link "$@" ;;
    unlink)    cmd_unlink "$@" ;;
    update)    cmd_update "$@" ;;
    wipe)      cmd_wipe "$@" ;;
    status)    cmd_status "$@" ;;
    doctor)    cmd_doctor "$@" ;;
    help)      cmd_help "$@" ;;
    version)   cmd_version "$@" ;;
    install | uninstall)
      log error "'$cmd' is gone: use 'dotfiles link' (installs and links) or 'dotfiles unlink' (removes and unlinks)"
      exit 2
      ;;
    default)
      log error "'default' is gone (#51): pick the tools for this machine with 'dotfiles' or 'dotfiles link <tool>'"
      exit 2
      ;;
    *)
      log error "unknown command: $cmd (see: dotfiles.sh help)"
      exit 2
      ;;
  esac
}

main "$@"
