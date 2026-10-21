#!/usr/bin/env bash
#
# dotfiles.sh: install, link and manage the tools in this repo.
# Build spec: plan.md. Written for Bash 3.2 (macOS /bin/bash) and up.

set -euo pipefail
set -o errtrace

# ─── Metadata ───────────────────────────────────────────────────────────
readonly DOTFILES_VERSION="2.0.0"
export DOTFILES_VERSION

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
QUIET=false   # interactive mode: info/success and command output go to the log only
REPORT=false  # link/update: one line per tool at the end instead of the step-by-step log

# ─── Logging state ──────────────────────────────────────────────────────
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
LOG_FILE=""
LOG_CMD="main"

# ════════════════════════════════════════════════════════════════════════
# LOGGING (plan Section 11)
# ════════════════════════════════════════════════════════════════════════

# ISO 8601 time with a colon in the offset: 2026-10-12T16:20:01-04:00.
# BSD date (macOS) has no -I flag, so build it from +%z (-0400).
_timestamp() {
  local ts
  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
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

  # link/update: a tool's first error (else first warning) becomes its line
  # in the report. Shown live only with -v.
  if [[ $REPORT == true && -n $REPORT_TOOL && ( $level == error || $level == warn ) ]]; then
    if [[ $level == error && $REPORT_LEVEL != error ]]; then
      REPORT_LEVEL=error
      REPORT_MSG="${message#"$REPORT_TOOL: "}"
    elif [[ $level == warn && -z $REPORT_LEVEL ]]; then
      REPORT_LEVEL=warn
      REPORT_MSG="${message#"$REPORT_TOOL: "}"
    fi
    if [[ $VERBOSE != true ]]; then
      return 0
    fi
  fi

  case "$level" in
    error | warn)
      printf '[%s] %s\n' "$label" "$message" >&2
      ;;
    debug)
      if [[ $VERBOSE == true ]]; then
        printf '[%s] %s\n' "$label" "$message" >&2
      fi
      ;;
    *)
      if [[ $QUIET != true || $VERBOSE == true ]]; then
        printf '[%s] %s\n' "$label" "$message"
      fi
      ;;
  esac
}

# ─── Report: one line per tool for link and update ──────────────────────
#   ✓ gitlogue(0.12.1)   ~/.config/gitlogue/config.toml
#   ! cspell             not installed: <how to install it>
#   ✗ ssh                op inject failed …
REPORT_TOOL=""    # the tool being handled
REPORT_LEVEL=""   # its worst message so far: "", warn or error
REPORT_MSG=""     # that message, without the "tool: " prefix
REPORT_SYMS=()
REPORT_LABELS=()
REPORT_TEXTS=()   # newline-separated: extra lines line up under the first

_report_start() {
  REPORT_TOOL="$1"
  REPORT_LEVEL=""
  REPORT_MSG=""
}

_report_add() {
  REPORT_SYMS+=("$1")
  REPORT_LABELS+=("$2")
  REPORT_TEXTS+=("$3")
}

# Print the lines, the labels padded to the longest one so the second
# column lines up. Goes to the terminal even when QUIET.
_report_print() {
  local i width=0 first=true line
  for ((i = 0; i < ${#REPORT_LABELS[@]}; i++)); do
    if [[ ${#REPORT_LABELS[i]} -gt $width ]]; then
      width=${#REPORT_LABELS[i]}
    fi
  done
  for ((i = 0; i < ${#REPORT_LABELS[@]}; i++)); do
    first=true
    while IFS= read -r line || [[ -n $line ]]; do
      if [[ $first == true ]]; then
        printf '%s %-*s %s\n' "${REPORT_SYMS[i]}" "$width" "${REPORT_LABELS[i]}" "$line"
        first=false
      else
        printf '  %-*s %s\n' "$width" "" "$line"
      fi
    done <<<"${REPORT_TEXTS[i]}"
    _log_to_file "INFO" "report: ${REPORT_SYMS[i]} ${REPORT_LABELS[i]} ${REPORT_TEXTS[i]//$'\n'/, }"
  done
}

# link/update: from here on, steps go to the log (and to the terminal only
# with -v); the report is printed at the end.
_report_begin() {
  REPORT=true
  QUIET=true
  REPORT_SYMS=()
  REPORT_LABELS=()
  REPORT_TEXTS=()
}

_report_end() {
  REPORT=false
  if [[ $VERBOSE == true && ${#REPORT_LABELS[@]} -gt 0 ]]; then
    printf '\n'
  fi
  _report_print
  if [[ $DRY_RUN == true && ${#REPORT_LABELS[@]} -gt 0 ]]; then
    printf '(dry run: nothing was changed)\n'
  fi
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
  local code="$1"
  log debug "run finished, exit code $code"
}

# Runs when a command fails under set -e, so the log says where it died.
_on_error() {
  local code="$1" line="$2" command="$3"
  log error "command failed (exit $code) at line $line: $command"
}

trap '_on_exit $?' EXIT
trap '_on_error $? $LINENO "$BASH_COMMAND"' ERR

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

  # The config file: ~/.config/dotfiles/config.yaml (linked from the repo),
  # else the repo's own copy (a new machine, before anything is linked).
  local user_config="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/config.yaml"
  if [[ -f $user_config ]]; then
    DOTFILES_CONFIG="$user_config"
  elif [[ -n $DOTFILES ]]; then
    DOTFILES_CONFIG="$DOTFILES/config/dotfiles/config.yaml"
  else
    DOTFILES_CONFIG=""
  fi
  export DOTFILES DOTFILES_CONFIG
  log debug "DOTFILES_CONFIG: ${DOTFILES_CONFIG:-<none>}"
}

# ════════════════════════════════════════════════════════════════════════
# OS DETECTION (plan Section 4)
# ════════════════════════════════════════════════════════════════════════

DOTFILES_OS=""      # macos | linux | windows
DOTFILES_DISTRO=""  # display only, Linux only: "<NAME> <kernel>"
DISTRO_ID=""        # internal, Linux only: debian | pacman | fedora
PKG_MANAGER=""      # internal: pacman | apt | dnf | brew | winget (the keys in config.yaml)

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
    linux:pacman) PKG_MANAGER="pacman" ;;
    linux:debian) PKG_MANAGER="apt" ;;
    linux:fedora) PKG_MANAGER="dnf" ;;
    macos:*)      PKG_MANAGER="brew" ;;
    windows:*)    PKG_MANAGER="winget" ;;
  esac

  export DOTFILES_OS DOTFILES_DISTRO
  log debug "DOTFILES_OS=${DOTFILES_OS:-<unknown>} DOTFILES_DISTRO=${DOTFILES_DISTRO:-<none>} package manager=${PKG_MANAGER:-<none>}"
}

# ════════════════════════════════════════════════════════════════════════
# CONFIG FILE: config/dotfiles/config.yaml (plan Section 18)
# ════════════════════════════════════════════════════════════════════════

BACKUP_SUFFIX=".bak"

# Run one yq query against the config file.
_yq() {
  yq eval "$1" "$DOTFILES_CONFIG"
}

# Settings from the config, once it can be read. Unset = built-in default.
load_settings() {
  if [[ -z $DOTFILES_CONFIG || ! -f $DOTFILES_CONFIG ]] || ! command -v yq >/dev/null 2>&1; then
    return 0
  fi
  local value
  value="$(_yq '.settings.backup_suffix // ""' 2>/dev/null)" || value=""
  if [[ -n $value ]]; then
    BACKUP_SUFFIX="$value"
  fi
  value="$(_yq '.settings.log_file // ""' 2>/dev/null)" || value=""
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

# Every package name under packages:, one per line.
manifest_tools() {
  _yq '.packages // {} | keys | .[]'
}

# True when the name is a key under packages:.
_tool_exists() {
  [[ $(_yq ".packages | has(\"$1\")") == true ]]
}

# A field that is either one value, or a map of values per manager/OS.
# Prints the value for this machine: manager, then OS, then default.
_value_for_machine() {
  local path="$1" key
  case "$(_yq "$path | tag")" in
    '!!null')
      return 0
      ;;
    '!!map')
      for key in "$PKG_MANAGER" "$DOTFILES_OS" default; do
        if [[ -n $key && $(_yq "$path[\"$key\"] | tag") != '!!null' ]]; then
          _yq "$path[\"$key\"]"
          return 0
        fi
      done
      ;;
    *)
      _yq "$path"
      ;;
  esac
}

# Package name on this machine: the manager's own name if one is set,
# else the key. Empty = nothing to install here (a manual-only tool, or
# "none" for this manager).
tool_package() {
  local tool="$1" base=".packages[\"$1\"]" value=""
  if [[ -n $PKG_MANAGER && $(_yq "$base[\"$PKG_MANAGER\"] | tag") != '!!null' ]]; then
    value="$(_yq "$base[\"$PKG_MANAGER\"]")"
  elif [[ $(_yq "$base.manual | tag") == '!!null' ]]; then
    value="$tool"
  fi
  if [[ $value == none ]]; then
    value=""
  fi
  echo "$value"
}

# Command that proves the tool is installed: command:, else the key.
tool_command() {
  local value
  value="$(_value_for_machine ".packages[\"$1\"].command")"
  echo "${value:-$1}"
}

# The manual: message (how to install by hand), or nothing.
tool_manual() {
  _yq ".packages[\"$1\"].manual // \"\""
}

# Links, one "src<TAB>dest" line each, with this OS's dest when the link
# has one (windows:, macos:, linux:). Missing src or dest comes out empty.
# A link with os: is only used on that OS (os: linux for system files).
tool_links() {
  _yq ".packages[\"$1\"].links // [] | .[] | select((.os // \"\") == \"\" or .os == \"${DOTFILES_OS:-none}\") | (.src // \"\") + \"\t\" + (.[\"${DOTFILES_OS:-none}\"] // .dest // \"\")"
}

# One true/false field of the link with this src (inject, copy, enable).
_link_flag() {
  if [[ $(_yq ".packages[\"$1\"].links // [] | .[] | select(.src == \"$2\") | .[\"$3\"] // false" | head -n 1) == true ]]; then
    echo true
  else
    echo false
  fi
}

# copy: true = a system file: dest is an absolute path that gets a
# root-owned copy, never a symlink (root must not run files you can edit).
tool_link_copy() { _link_flag "$1" "$2" copy; }

# enable: true on a copied systemd unit = systemctl enable --now it.
tool_link_enable() { _link_flag "$1" "$2" enable; }

# "true" when the tool has system files on this OS (needs sudo to link).
tool_has_system() {
  local src dest
  while IFS=$'\t' read -r src dest; do
    if [[ $(tool_link_copy "$1" "$src") == true ]]; then
      echo true
      return 0
    fi
  done < <(tool_links "$1")
  echo false
}

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

# "true" when the link with this src has inject: true: the repo file holds
# op:// references, and dest gets a filled-in copy instead of a symlink.
# Repos to clone, one "repo<TAB>dest" line each (dest under $HOME).
tool_clones() {
  _yq ".packages[\"$1\"].clone // [] | .[] | (.repo // \"\") + \"\t\" + (.dest // \"\")"
}

# "true" when a tool has nothing to do on this machine: no package, no
# manual: message and no links for this OS (hypr or limine on macOS,
# komorebi on Linux). link and update skip it; doctor reports it.
tool_unused_here() {
  if [[ -z $(tool_package "$1") && -z $(tool_manual "$1") && -z $(tool_links "$1") ]]; then
    echo true
  else
    echo false
  fi
}

tool_link_inject() { _link_flag "$1" "$2" inject; }

# "true" or "false"; anything else counts as false.
tool_enabled() {
  if [[ $(_yq ".packages[\"$1\"].enabled") == true ]]; then
    echo true
  else
    echo false
  fi
}

# locked: true = unlink never removes this tool's package (only its links).
tool_locked() {
  if [[ $(_yq ".packages[\"$1\"].locked") == true ]]; then
    echo true
  else
    echo false
  fi
}

# Names in the default: list, one per line.
default_list() {
  _yq '.default // [] | .[]'
}

# Package name for a default: entry. A name that is also under packages:
# uses that entry's names; any other name is installed as written.
default_package() {
  if _tool_exists "$1"; then
    tool_package "$1"
  else
    echo "$1"
  fi
}

# Print the installed version of a package, or return 1 if it isn't
# installed. Asks the package manager, because a package name often isn't
# a command (bind provides dig and nslookup).
package_version() {
  local package="$1" output
  case "$PKG_MANAGER" in
    pacman)
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
  local package="$1" output
  case "$PKG_MANAGER" in
    pacman)
      output="$(pacman -Si "$package" 2>/dev/null)" || return 0
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
    if [[ $QUIET != true || $VERBOSE == true ]]; then
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
    install:pacman) cmd=(pacman -S --needed --noconfirm "$package") ;;
    remove:pacman)  cmd=(pacman -R --noconfirm "$package") ;;
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

  # Linux package managers need root. $EUID is 0 when already root (VMs, containers).
  if [[ $DOTFILES_OS == linux && $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      log error "can't $action $package: needs root, and sudo isn't installed"
      return 1
    fi
    cmd=(sudo "${cmd[@]}")
  fi
  # apt needs fresh package lists on a new machine; once per run is enough.
  if [[ $action == install && $PKG_MANAGER == apt && $APT_UPDATED != true ]]; then
    APT_UPDATED=true
    if [[ ${cmd[0]} == sudo ]]; then
      run_cmd sudo apt -o Apt::Cmd::Disable-Script-Warning=true update
    else
      run_cmd apt -o Apt::Cmd::Disable-Script-Warning=true update
    fi
  fi

  run_cmd "${cmd[@]}"
}

pm_install() { _pm install "$1"; }
pm_remove()  { _pm remove "$1"; }

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
    link | unlink | default | update | wipe | doctor | interactive) ;;
    *)
      if [[ $DRY_RUN == true ]]; then
        log warn "--dry-run has no effect on '$cmd'"
      fi
      ;;
  esac
  case "$cmd" in
    link | interactive) ;;
    *)
      if [[ $FORCE == true ]]; then
        log warn "--force has no effect on '$cmd'"
      fi
      ;;
  esac
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
dotfiles link [tool...] [-d] [-v] [--force]

Install tools and link their configs: install the package if its command
is missing, link every config, set enabled: true. No tool = every tool with
enabled: true in config.yaml. A tool with no package here (none, manual:)
is still linked. Repos under clone: are cloned once the links are in place,
only when missing (an existing clone is never touched).

What's in the way of a link:
  nothing                   link it
  already our link          "already linked"
  a real file               ask, back it up to <file>.bak, link it
  a real folder             leave it alone (warn)
  a link to somewhere else  ask, replace it

Never touches anything inside the repo (through a linked folder).

System files (links with copy: true, e.g. omarchy, limine) get a
root-owned copy instead of a symlink, so linking those tools asks for your
sudo password first; refused = nothing changes. A copy that differs from
the repo is replaced after you say y (the old one is kept in
/var/lib/dotfiles/backup).

  -d  show what would happen, change nothing (doesn't ask for sudo)
  -v  show every step
  --force  no questions, no backups: replace files and folders

Examples:
  dotfiles link -dv neovim fd
  dotfiles link -dv
EOF
      ;;
    unlink)
      cat <<'EOF'
dotfiles unlink [tool...] [-d] [-v]

Remove tools: the package, then the config links (backups are put back),
then enabled: false. Doesn't ask before removing the package.

  dotfiles unlink             interactive: pick from the enabled tools
  dotfiles unlink cowsay      that tool

Removes the package only (pacman -R, apt remove, ...), never its
dependencies. If removing fails, the tool stays linked and enabled. A tool
with locked: true in config.yaml, or no package here (none, manual:), is
just unlinked.

  -d  show what would happen, change nothing
  -v  show every step

Example:
  dotfiles unlink -dv cowsay
EOF
      ;;
    interactive)
      cat <<'EOF'
dotfiles [-d] [-v] [--force]

Interactive setup, two screens:
  1. the default: list; Enter installs every missing one
  2. packages:, [x] = enabled; Enter continues, numbers switch tools on/off.
     Switched on = link (install + link), switched off = unlink (unlink +
     remove the package)

Picking in lists: 1 3 5, 2-4, a = all, Enter = continue.

  -d  show what would happen, change nothing
  -v  show every step (quiet otherwise; everything goes to the log)
  --force  no questions, no backups: replace whatever is in the way
EOF
      ;;
    default)
      cat <<'EOF'
dotfiles default [-d] [-v]

Install every package in the default: list of config.yaml, link nothing.
For machines that only need the basics (test VMs). A name that is also
under packages: uses that entry's package names; any other name is
installed as written. Already installed packages are skipped.

  -d  show what would be installed (with versions), change nothing
  -v  show every step

Example:
  dotfiles default -dv
EOF
      ;;
    wipe)
      cat <<'EOF'
dotfiles wipe [-d] [-v]

Undo everything dotfiles set up on this machine, to test it again from
scratch:
  - every tool in config.yaml: remove its links and system copies (backups
    are put back), and for enabled tools its package (unless locked: true)
  - then dotfiles' own links (~/.local/bin/dotfiles, ~/.config/dotfiles)

Kept: locked packages, and everything in the repo: no file in it is
changed or removed (config.yaml keeps its enabled: flags, so
"dotfiles.sh link" sets up the same tools again). The log stays too.
A package others depend on (e.g. Omarchy's) can't be removed: wipe reports
it and carries on.

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
dotfiles update [-d] [-v]

Get the latest repo changes and bring this machine in line with them:
  1. git fetch, and list the incoming commits
  2. git pull --rebase --autostash (your local changes are set aside and
     put back; a conflict stops with how to continue or undo)
  3. install anything missing for enabled tools (never upgrades), relink

  -d  fetch and show what's incoming, pull nothing, change nothing
  -v  show every step

Example:
  dotfiles update -dv
EOF
      ;;
    status)
      cat <<'EOF'
dotfiles status [tool] [-v]

  dotfiles status          every tool: ENABLED, INSTALLED, LINKED (true/false),
                           then the default: list with installed versions
  dotfiles status neovim   one tool: package, command, where it's installed,
                           version, and each link (source, symlink, problem)

ENABLED here means installed and linked on this machine. When config.yaml's
enabled: says otherwise, status adds a note. Changes nothing.

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
  config.yaml, the dotfiles command and config links, PATH, every tool in
  config.yaml, and the default: list.

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
  link, unlink, interactive, default, update, wipe, status, doctor, help, version
EOF
      ;;
    version)
      cat <<'EOF'
dotfiles version

Print this script's version (DOTFILES_VERSION), which is separate from the
repo's release versions.
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
dotfiles $DOTFILES_VERSION: install, link and manage the tools in this repo

Usage: dotfiles [command] [tool...] [flags]
       dotfiles                 interactive setup (help interactive)

Commands:
  link [tool...]        install tools and link their configs (no tool = enabled tools)
  unlink [tool...]      remove tools and their links (no tool = pick from a list)
  default               install the default: list, link nothing
  update                pull the repo, install what's missing, relink
  wipe                  undo everything dotfiles set up here (for re-testing)
  status [tool]         what's installed and linked
  doctor                check (and fix) what dotfiles needs
  help [command]        this overview, or help for one command
  version               print the version

Flags (work anywhere on the line):
  -d, --dry-run         show what would happen, change nothing
  -v, --verbose         show every step
  --force               no questions, no backups (link, interactive)
  Short flags combine: -dv

Files:
  config:  ${DOTFILES_CONFIG:-<not found>}
  log:     ${LOG_FILE:-<not available>}

More: dotfiles help <command>
EOF
}

cmd_version() {
  echo "dotfiles.sh $DOTFILES_VERSION"
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

# Commands that read the config need the file and yq.
_require_config() {
  if [[ -z $DOTFILES_CONFIG || ! -f $DOTFILES_CONFIG ]]; then
    log error "config.yaml not found${DOTFILES_CONFIG:+ at $DOTFILES_CONFIG}; run: dotfiles.sh doctor"
    exit 1
  fi
  if ! command -v yq >/dev/null 2>&1; then
    log error "yq is not installed; run: dotfiles.sh doctor"
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
    if [[ $(_physical "$target") == "$(_physical "$src_path")" ]]; then
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

# State of one config.yaml link. An inject link is a filled-in file, not a
# symlink: "injected" when it's there, "symlink" when an old link is still
# in its place.
_tool_link_state() {
  local tool="$1" src="$2" dest="$3" dest_path
  dest_path="$(_dest_path "$3")"
  if [[ $(tool_link_copy "$tool" "$src") == true ]]; then
    _copy_state "$(_src_path "$src")" "$dest_path"
  elif [[ $(tool_link_inject "$tool" "$src") != true ]]; then
    _link_state "$(_src_path "$src")" "$dest_path"
  elif [[ -L $dest_path ]]; then
    echo "symlink"
  elif [[ -f $dest_path ]]; then
    echo "injected"
  elif [[ -e $dest_path ]]; then
    echo "folder"
  else
    echo "missing"
  fi
}

# The repo's version of a system file with the literal text $HOME and
# $USER filled in for this user. The repo holds no home path or user name;
# the installed copy needs the real ones (it runs as root, where $HOME is
# /root, and systemd unit lines don't expand variables).
_render_copy() {
  sed -e "s|\$HOME|$HOME|g" -e "s|\$USER|$(id -un)|g" "$1"
}

# State of a system file (copy: true):
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
_tool_location() {
  local tool="$1" path package
  if path="$(command -v "$(tool_command "$tool")" 2>/dev/null)"; then
    echo "$path"
    return 0
  fi
  package="$(tool_package "$tool")"
  if [[ -n $package ]] && package_version "$package" >/dev/null; then
    echo "$PKG_MANAGER package $package"
    return 0
  fi
  return 1
}

# "true" when the tool is installed (_tool_location finds it).
_tool_installed() {
  if _tool_location "$1" >/dev/null; then
    echo true
  else
    echo false
  fi
}

# "true" when every link is in place (directly or through a linked parent).
_tool_linked() {
  local tool="$1" src dest state result=true
  while IFS=$'\t' read -r src dest; do
    state="$(_tool_link_state "$tool" "$src" "$dest")"
    log debug "$tool: ~/$dest is $state"
    case "$state" in
      linked | linked-parent | injected | copied) ;;
      *) result=false ;;
    esac
  done < <(tool_links "$tool")
  echo "$result"
}

# A tool counts as enabled when it's installed and linked.
_and() {
  if [[ $1 == true && $2 == true ]]; then echo true; else echo false; fi
}

# One line per tool.
_status_all() {
  local tool installed linked width=4
  # The first column is as wide as the longest tool name.
  while IFS= read -r tool; do
    if [[ ${#tool} -gt $width ]]; then
      width=${#tool}
    fi
  done < <(manifest_tools)
  out "$(printf '%-*s  %-8s %-10s %s' "$width" TOOL ENABLED INSTALLED LINKED)"
  while IFS= read -r tool; do
    installed="$(_tool_installed "$tool")"
    linked="$(_tool_linked "$tool")"
    out "$(printf '%-*s  %-8s %-10s %s' "$width" "$tool" "$(_and "$installed" "$linked")" "$installed" "$linked")"
  done < <(manifest_tools)
  _status_default_packages
}

# The default: list, one row each, with the installed version.
_status_default_packages() {
  local name package version
  out ""
  if [[ -z $(default_list) ]]; then
    out "Default packages: none (add names to default: in config.yaml)"
    return 0
  fi
  out "Default packages (dotfiles.sh default):"
  out "$(printf '%-16s %-16s %-10s %s' NAME PACKAGE INSTALLED VERSION)"
  while IFS= read -r name; do
    package="$(default_package "$name")"
    if [[ -z $package ]]; then
      out "$(printf '%-16s %-16s %-10s %s' "$name" - - "install by hand")"
    elif version="$(package_version "$package")"; then
      out "$(printf '%-16s %-16s %-10s %s' "$name" "$package" true "$version")"
    else
      out "$(printf '%-16s %-16s %-10s %s' "$name" "$package" false -)"
    fi
  done < <(default_list)
}

# Details for one tool.
_status_tool() {
  local tool="$1"
  local command package manual src dest state
  local installed linked enabled why="" selected first=true

  if ! _tool_exists "$tool"; then
    log error "unknown tool: $tool (in config.yaml: $(manifest_tools | paste -sd ' ' -))"
    exit 2
  fi

  command="$(tool_command "$tool")"
  package="$(tool_package "$tool")"
  manual="$(tool_manual "$tool")"
  installed="$(_tool_installed "$tool")"
  linked="$(_tool_linked "$tool")"
  enabled="$(_and "$installed" "$linked")"
  if [[ $installed != true ]]; then why="not installed"; fi
  if [[ $linked != true ]]; then why="${why:+$why, }not linked"; fi
  selected="$(tool_enabled "$tool")"

  out "$tool"
  if [[ $enabled == true ]]; then
    out "  enabled:    true (installed and linked)"
  else
    out "  enabled:    false ($why)"
  fi
  if [[ $selected != "$enabled" ]]; then
    out "  note:       config.yaml has enabled: $selected"
  fi
  if [[ -n $package ]]; then
    out "  package:    $package (${PKG_MANAGER:-no package manager})"
  else
    out "  package:    none here${manual:+: $manual}"
  fi
  out "  command:    $command"
  if [[ $installed == true ]]; then
    out "  installed:  $(_tool_location "$tool")"
    out "  version:    $(_tool_installed_version "$tool")"
  else
    out "  installed:  no"
  fi
  out "  links:"
  while IFS=$'\t' read -r src dest; do
    if [[ $first != true ]]; then
      out ""
    fi
    first=false
    state="$(_tool_link_state "$tool" "$src" "$dest")"
    out "    source:   config/$src"
    if [[ $(tool_link_copy "$tool" "$src") == true ]]; then
      out "    copy:     $dest  (root-owned)"
    elif [[ $(tool_link_inject "$tool" "$src") == true ]]; then
      out "    filled:   ~/$dest  (op inject)"
    else
      out "    symlink:  ~/$dest"
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

# Set enabled: true|false for one tool. Only that one line changes, so
# comments and blank lines stay (yq -i would reformat the file). yq reads
# it back to confirm.
set_enabled() {
  local tool="$1" value="$2" file="$DOTFILES_CONFIG" tmp
  if [[ $(tool_enabled "$tool") == "$value" ]]; then
    log debug "$tool: config.yaml already has enabled: $value"
    return 0
  fi
  if [[ $DRY_RUN == true ]]; then
    log info "dry run, would set enabled: $value for $tool in config.yaml"
    return 0
  fi
  tmp="$file.tmp.$$"
  # In the block under "  <tool>:", replace the first "    enabled: ...".
  # A tool without an enabled: line gets one, right under its name.
  local has_line=false
  if [[ $(_yq ".packages[\"$tool\"] | has(\"enabled\")") == true ]]; then
    has_line=true
  fi
  awk -v prefix="  $tool:" -v value="$value" -v add="$has_line" '
    substr($0, 1, length(prefix)) == prefix && substr($0, length(prefix) + 1) ~ /^[[:space:]]*(#.*)?$/ {
      in_tool = 1; print
      if (add != "true") { print "    enabled: " value; done = 1 }
      next
    }
    in_tool && /^  [^ #]/ { in_tool = 0 }
    in_tool && !done && /^    enabled:/ {
      sub(/enabled:[[:space:]]*[A-Za-z]+/, "enabled: " value); done = 1
    }
    { print }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
  if [[ $(tool_enabled "$tool") != "$value" ]]; then
    log error "$tool: couldn't set enabled: $value in config.yaml (is the tool's name indented 2 spaces under packages:?)"
    return 1
  fi
  log info "$tool: config.yaml now has enabled: $value"
}

# Tools to act on: the ones named, or every tool with enabled: true.
# "true" when linking (link) or unlinking (unlink) a tool would change a
# system file: for link, a copy is missing or differs, or its unit isn't
# enabled yet; for unlink, a copy is there to remove.
_system_needs_root() {
  local tool="$1" mode="$2" src dest state
  while IFS=$'\t' read -r src dest; do
    if [[ $(tool_link_copy "$tool" "$src") != true ]]; then
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
    elif [[ $dest == /etc/systemd/* && $(tool_link_enable "$tool" "$src") == true ]] &&
      command -v systemctl >/dev/null 2>&1 &&
      ! systemctl is-enabled --quiet "$(basename "$dest")" 2>/dev/null; then
      echo true
      return 0
    fi
  done < <(tool_links "$tool")
  echo false
}

# Sets TOOLS. Unknown names stop the run before anything changes.
TOOLS=()
# Tools with system files (copy: true links) need root for them. Before
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
  printf '%s\n' "$need: system files changed; sudo needs your password" >&2
  _log_to_file "INFO" "$need: system files changed; sudo needs your password"
  if ! sudo -v; then
    log error "$need installs system files and sudo was refused; nothing changed"
    exit 1
  fi
}

# Every tool with enabled: true, one per line.
_enabled_tools() {
  local tool
  while IFS= read -r tool; do
    if [[ $(tool_enabled "$tool") == true ]]; then
      echo "$tool"
    fi
  done < <(manifest_tools)
}

_pick_tools() {
  local cmd="$1" tool
  shift
  TOOLS=()
  if [[ $# -gt 0 ]]; then
    for tool in "$@"; do
      if ! _tool_exists "$tool"; then
        log error "unknown tool: $tool (in config.yaml: $(manifest_tools | paste -sd ' ' -))"
        exit 2
      fi
      TOOLS+=("$tool")
    done
  else
    while IFS= read -r tool; do
      if [[ $(tool_enabled "$tool") == true ]]; then
        TOOLS+=("$tool")
      fi
    done < <(manifest_tools)
    if [[ ${#TOOLS[@]} -eq 0 ]]; then
      log info "$cmd: no tool has enabled: true in config.yaml; name one: dotfiles.sh $cmd <tool>"
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

# Link one src/dest pair from config.yaml. Returns 1 when the link isn't
# in place afterwards.
_link_one() {
  local tool="$1" src="$2" dest="$3"
  if [[ -z $src || -z $dest ]]; then
    log error "$tool: a link in config.yaml is missing src or dest"
    return 1
  fi
  if [[ $(tool_link_copy "$tool" "$src") == true ]]; then
    _copy_path "$tool" "$src" "$dest"
  elif [[ $dest == /* ]]; then
    log error "$tool: $dest is a system path; mark that link copy: true in config.yaml"
    return 1
  elif [[ $(tool_link_inject "$tool" "$src") == true ]]; then
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
# ($4 = copied), and enable the unit when the link says enable: true and it
# isn't yet. Containers have no running systemd: warn, don't fail.
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
  if [[ $(tool_link_enable "$tool" "$src") == true ]] && ! systemctl is-enabled --quiet "$unit" 2>/dev/null; then
    if _root_cmd systemctl enable --now "$unit"; then
      log success "$tool: enabled $unit"
    else
      log warn "$tool: couldn't enable $unit"
    fi
  fi
}

# Put a root-owned copy of a system file in place (copy: true). Asks
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
  if [[ $dest_path == /etc/systemd/* && $(tool_link_enable "$tool" "$src") == true ]] &&
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

# Link one tool and set enabled: true. Returns 1 when a link isn't in place.
_link_configs() {
  local tool="$1" src dest repo ok=true
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
  if [[ $ok == true ]] && ! set_enabled "$tool" true; then
    ok=false
  fi
  [[ $ok == true ]]
}

# link [tool...]: install each tool's package if it's missing, link its
# configs, set enabled: true. No tool = every enabled tool.
cmd_link() {
  _require_config
  _pick_tools link "$@"
  _require_sudo link ${TOOLS[@]+"${TOOLS[@]}"}
  _report_begin
  local tool bad=false
  for tool in ${TOOLS[@]+"${TOOLS[@]}"}; do
    CHANGED=false
    if [[ $(tool_unused_here "$tool") == true ]]; then
      log debug "$tool: not used on ${DOTFILES_OS:-this OS} (no package, nothing to link); skipped"
      continue
    fi
    _report_start "$tool"
    if _link_tool "$tool"; then
      _report_tool "$tool" true
    else
      _report_tool "$tool" false
      bad=true
    fi
  done
  _report_end
  if [[ $bad == true ]]; then
    exit 1
  fi
}

# Remove one link and put its .bak back if there is one.
_unlink_one() {
  local tool="$1" src="$2" dest="$3"
  local src_path dest_path state shown
  if [[ $(tool_link_copy "$tool" "$src") == true ]]; then
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

# Unlink one tool and set enabled: false. Returns 1 on failure.
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
  if [[ $ok == true && $KEEP_ENABLED != true ]] && ! set_enabled "$tool" false; then
    ok=false
  fi
  [[ $ok == true ]]
}

# unlink [tool...]: remove each tool's package, unlink its configs, set
# enabled: false. No tool = pick from the enabled tools (never all of them
# at once without asking).
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

# Install one tool's package if it's missing. Sets INSTALL_NOTE to the
# tool's manual: message when there's no package to install here.
INSTALL_NOTE=""
_install_package() {
  local tool="$1" cmd_name package path
  INSTALL_NOTE=""
  cmd_name="$(tool_command "$tool")"
  package="$(tool_package "$tool")"

  if path="$(_tool_location "$tool")"; then
    log success "$tool: already installed: $path ($(_tool_installed_version "$tool"))"
    return 0
  fi
  if [[ -z $package ]]; then
    INSTALL_NOTE="$(tool_manual "$tool")"
    INSTALL_NOTE="${INSTALL_NOTE:-no package for ${PKG_MANAGER:-this OS} in config.yaml}"
    log warn "$tool: not installed: $INSTALL_NOTE"
    return 0
  fi

  log info "$tool: not installed, installing package $package"
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

# Install, link and set enabled: true for one tool. Returns 1 on failure.
# Links even when there was nothing to install (plan Section 18).
_link_tool() {
  local tool="$1"
  if ! _install_package "$tool"; then
    return 1
  fi
  _link_configs "$tool"
}

# "tool (version)": the installed version; for a tool not installed yet
# in a dry run, the version that would be installed.
_tool_with_version() {
  local tool="$1"
  if [[ $(_tool_installed "$tool") == true ]]; then
    _with_version "$tool" "$(_tool_installed_version "$tool")"
  elif [[ $DRY_RUN == true ]]; then
    _with_version "$tool" "$(package_available_version "$(tool_package "$tool")")"
  else
    echo "$tool"
  fi
}

# Add one tool's report line. ok = whether _link_tool succeeded.
# only_changed = true (update): a tool that's fine and didn't change gets
# no line; problems always do.
_report_tool() {
  local tool="$1" ok="$2" only_changed="${3:-false}" version="" text="" src dest
  if [[ $ok != true || $REPORT_LEVEL == error ]]; then
    _report_add "✗" "$tool" "${REPORT_MSG:-failed; run again with -v to see why}"
  elif [[ $REPORT_LEVEL == warn ]]; then
    _report_add "!" "$tool" "$REPORT_MSG"
  elif [[ $only_changed != true || $CHANGED == true ]]; then
    if [[ $(_tool_installed "$tool") == true ]]; then
      version="$(_tool_installed_version "$tool")"
    elif [[ $DRY_RUN == true ]]; then
      version="$(package_available_version "$(tool_package "$tool")")"
    fi
    if [[ $version == unknown ]]; then
      version=""
    fi
    while IFS=$'\t' read -r src dest; do
      text="${text:+$text$'\n'}$(_dest_shown "$dest")"
    done < <(tool_links "$tool")
    _report_add "✓" "$tool${version:+($version)}" "${text:-installed, nothing to link}"
  fi
  REPORT_TOOL=""
}

# Remove one tool's package (no question: unlink always removes it).
# Returns 1 when removing failed, so the tool stays linked and enabled.
_remove_package() {
  local tool="$1" cmd_name package
  cmd_name="$(tool_command "$tool")"
  package="$(tool_package "$tool")"

  if [[ $(tool_locked "$tool") == true ]]; then
    log info "$tool: locked: true in config.yaml; kept the package, removing only the links"
    return 0
  fi
  if [[ -z $package ]]; then
    log warn "$tool: no package to remove here; if you installed it by hand, remove it the same way"
    return 0
  fi
  if [[ $(_tool_installed "$tool") != true ]]; then
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

# Remove the package, unlink, set enabled: false. Returns 1 on failure; a
# failed removal leaves the links and enabled: as they were.
_unlink_tool() {
  local tool="$1"
  if ! _remove_package "$tool"; then
    return 1
  fi
  _unlink_configs "$tool"
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
  local tool="$1" text="" installed linked
  installed="$(_tool_installed "$tool")"
  linked="$(_tool_linked "$tool")"
  if [[ $installed == true ]]; then
    text="installed"
  elif [[ -z $(tool_package "$tool") ]]; then
    text="install by hand"
  fi
  if [[ $linked == true ]]; then
    text="${text:+$text, }linked"
  fi
  echo "${text:--}"
}

# Screen 1: the default: list. Enter = install every missing one.
_screen_defaults() {
  local -a names=() missing=()
  local name package version status i n
  while IFS= read -r name; do
    names+=("$name")
  done < <(default_list)

  ui ""
  if [[ ${#names[@]} -eq 0 ]]; then
    ui "Default packages: none (add names to default: in config.yaml)"
    return 0
  fi
  ui "Default packages:"
  for ((i = 0; i < ${#names[@]}; i++)); do
    package="$(default_package "${names[i]}")"
    if [[ -z $package ]]; then
      status="install by hand"
    elif version="$(package_version "$package")"; then
      status="installed $version"
    else
      status="not installed"
      missing+=("$((i + 1))")
    fi
    ui "$(printf '  %2d) %-16s %s' "$((i + 1))" "${names[i]}" "$status")"
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    ui "  All installed."
    return 0
  fi

  while true; do
    _ask "Install: Enter = all missing, numbers = only those, n = skip: "
    case "$ANSWER" in
      "")    PICKS=("${missing[@]}"); break ;;
      n | N) return 0 ;;
      *)     if _parse_picks "$ANSWER" "${#names[@]}"; then break; fi ;;
    esac
  done

  for n in "${PICKS[@]}"; do
    name="${names[n - 1]}"
    _default_one "$name"
    case "$DEFAULT_RESULT" in
      installed) ui "  $name: installed ($DEFAULT_VERSION)" ;;
      test)      ui "  Test: $(_with_version "$name" "$DEFAULT_VERSION")" ;;
      already)   ui "  $name: already installed" ;;
      manual)    ui "  $name: install by hand: $(tool_manual "$name")" ;;
      failed)    ui "  $name: failed (see the error above)" ;;
    esac
  done
}

# Screen 2: packages: with the enabled ones marked. Enter = continue;
# numbers switch packages on/off. On = link (install and link); switched
# off = unlink (remove the package and the links).
INTERACTIVE_FAILED=false
_screen_packages() {
  local -a names=() selected=() before=()
  local name enabled mark i n

  while IFS= read -r name; do
    enabled="$(tool_enabled "$name")"
    names+=("$name")
    selected+=("$enabled")
    before+=("$enabled")
  done < <(manifest_tools)

  ui ""
  if [[ ${#names[@]} -eq 0 ]]; then
    ui "Packages: none (add them under packages: in config.yaml)"
    return 0
  fi

  while true; do
    ui "Packages ([x] = enabled):"
    for ((i = 0; i < ${#names[@]}; i++)); do
      mark=" "
      if [[ ${selected[i]} == true ]]; then
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
        if [[ ${selected[n - 1]} == true ]]; then
          selected[n - 1]=false
        else
          selected[n - 1]=true
        fi
      done
    fi
    ui ""
  done

  ui ""
  for ((i = 0; i < ${#names[@]}; i++)); do
    name="${names[i]}"
    CHANGED=false
    if [[ ${selected[i]} == true ]]; then
      if ! _link_tool "$name"; then
        ui "  $name: failed (see the messages above)"
        INTERACTIVE_FAILED=true
      elif [[ -n $INSTALL_NOTE ]]; then
        ui "  $name: linked; install by hand: $INSTALL_NOTE"
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
  # shellcheck disable=SC2046
  _require_sudo link $(manifest_tools)
  _require_tty
  QUIET=true
  INTERACTIVE_FAILED=false
  _screen_defaults
  _screen_packages
  if [[ $INTERACTIVE_FAILED == true ]]; then
    exit 1
  fi
}

# dotfiles unlink with no tool: pick from the enabled packages.
_interactive_unlink() {
  _require_config
  # shellcheck disable=SC2046
  _require_sudo unlink $(_enabled_tools)
  _require_tty
  QUIET=true
  local -a names=()
  local name n failed=false
  while IFS= read -r name; do
    if [[ $(tool_enabled "$name") == true ]]; then
      names+=("$name")
    fi
  done < <(manifest_tools)

  ui ""
  if [[ ${#names[@]} -eq 0 ]]; then
    ui "No package has enabled: true in config.yaml; nothing to unlink."
    return 0
  fi
  ui "Enabled packages:"
  for ((n = 0; n < ${#names[@]}; n++)); do
    ui "$(printf '  %2d) %-16s %s' "$((n + 1))" "${names[n]}" "$(_state_text "${names[n]}")")"
  done
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

# true = unlink leaves config.yaml's enabled: flags as they are (wipe).
KEEP_ENABLED=false

# What wipe will do, before it asks. Fills WIPE_REMOVE (packages to remove).
WIPE_REMOVE=""
_wipe_preview() {
  local tool package keep="" count=0
  WIPE_REMOVE=""
  while IFS= read -r tool; do
    count=$((count + 1))
    package="$(tool_package "$tool")"
    if [[ $(tool_locked "$tool") == true ]]; then
      keep="${keep:+$keep }$tool"
    elif [[ $(tool_enabled "$tool") == true && -n $package && $(_tool_installed "$tool") == true ]]; then
      WIPE_REMOVE="${WIPE_REMOVE:+$WIPE_REMOVE, }$tool ($package)"
    fi
  done < <(manifest_tools)
  ui ""
  ui "Wipe: undo everything dotfiles set up on this machine"
  ui "  unlink:  all $count tools in config.yaml (links and system copies; backups go back)"
  ui "  remove:  packages of enabled tools: ${WIPE_REMOVE:-none}"
  ui "  keep:    locked packages: ${keep:-none}"
  ui "  remove:  dotfiles' own links: ~/.local/bin/dotfiles, ~/.config/dotfiles"
  ui "  keep:    everything in the repo (config.yaml unchanged), the log"
  ui ""
}

# Last step: dotfiles' own links (config.yaml is read through
# ~/.config/dotfiles, so this runs after every tool). Nothing in the repo is
# touched.
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
    tools+=("$tool")
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

  KEEP_ENABLED=true
  for tool in ${tools[@]+"${tools[@]}"}; do
    CHANGED=false
    # Packages only for enabled tools (dotfiles didn't install the others).
    # Keep going when a package can't be removed (pacman refuses packages
    # others depend on): the links still come out.
    if [[ $(tool_enabled "$tool") == true ]] && ! _remove_package "$tool"; then
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
    log info "dry run: the installs and links below use config.yaml as it is now; the pull may change it"
  fi
  if ! run_cmd git -C "$DOTFILES" pull --rebase --autostash; then
    log error "git pull failed. Check: git -C \"$DOTFILES\" status. If a rebase is in progress, fix the files, then git rebase --continue (or git rebase --abort to undo)."
    return 1
  fi
  PULLED=true
  if [[ $DRY_RUN == true ]]; then
    _report_add "✓" "repo" "would pull $count commit(s) from $upstream"
  else
    log success "repo: pulled from $upstream"
    _report_add "✓" "repo($(git -C "$DOTFILES" rev-parse --short HEAD))" "pulled $count commit(s) from $upstream"
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
  _report_begin
  if ! _update_pull; then
    exit 1
  fi
  # After the pull: the new commits decide whether a system file changes.
  # shellcheck disable=SC2046
  _require_sudo link $(_enabled_tools)

  # Install what's missing (no upgrades) and relink every enabled package.
  local tool bad=false
  TOOLS=()
  while IFS= read -r tool; do
    if [[ $(tool_enabled "$tool") == true ]]; then
      TOOLS+=("$tool")
    fi
  done < <(manifest_tools)
  if [[ ${#TOOLS[@]} -eq 0 ]]; then
    _report_end
    printf 'update: no tool has enabled: true in config.yaml; nothing to install or link\n'
    return 0
  fi
  local changed=$PULLED
  for tool in "${TOOLS[@]}"; do
    CHANGED=false
    if [[ $(tool_unused_here "$tool") == true ]]; then
      log debug "$tool: not used on ${DOTFILES_OS:-this OS} (no package, nothing to link); skipped"
      continue
    fi
    _report_start "$tool"
    if _link_tool "$tool"; then
      _report_tool "$tool" true true
      if [[ $CHANGED == true ]]; then
        changed=true
      fi
    else
      _report_tool "$tool" false true
      bad=true
    fi
  done
  _report_end
  if [[ $changed != true && $bad != true ]]; then
    printf '✓ dotfiles: everything is up to date\n'
  fi
  if [[ $bad == true ]]; then
    exit 1
  fi
}

# ─── default (plan Section 18): install the default: list, link nothing ──

# Install one entry of the default: list if it's missing. Sets
# DEFAULT_RESULT (installed, test, already, manual, failed) and
# DEFAULT_VERSION.
DEFAULT_RESULT=""
DEFAULT_VERSION=""
_default_one() {
  local name="$1" package version
  DEFAULT_VERSION=""
  package="$(default_package "$name")"
  if [[ -z $package ]]; then
    log warn "$name: no package here${name:+: $(tool_manual "$name")}"
    DEFAULT_RESULT="manual"
  elif version="$(package_version "$package")"; then
    log success "$name: already installed ($package $version)"
    DEFAULT_RESULT="already"
    DEFAULT_VERSION="$version"
  elif log info "$name: not installed, installing package $package" && pm_install "$package"; then
    if [[ $DRY_RUN == true ]]; then
      DEFAULT_RESULT="test"
      DEFAULT_VERSION="$(package_available_version "$package")"
    elif version="$(package_version "$package")"; then
      log success "$name: installed $package $version"
      DEFAULT_RESULT="installed"
      DEFAULT_VERSION="$version"
    else
      log error "$name: installed $package, but the package manager doesn't list it"
      DEFAULT_RESULT="failed"
    fi
  else
    log error "$name: installing $package failed"
    DEFAULT_RESULT="failed"
  fi
}

cmd_default() {
  _require_config
  if [[ -z $(default_list) ]]; then
    log info "default: the default: list in config.yaml is empty; nothing to install"
    return 0
  fi
  local name good="" bad="" manual="" count=0
  while IFS= read -r name; do
    count=$((count + 1))
    _default_one "$name"
    case "$DEFAULT_RESULT" in
      installed | test) good="${good:+$good, }$(_with_version "$name" "$DEFAULT_VERSION")" ;;
      manual)           manual="${manual:+$manual, }$name" ;;
      failed)           bad="${bad:+$bad, }$name" ;;
    esac
  done < <(default_list)

  # Only what changed and what failed; nothing to report = no summary.
  if [[ $count -gt 1 && -n $good$bad$manual ]]; then
    out ""
    out "Summary:"
    if [[ -n $good && $DRY_RUN == true ]]; then
      out "  Test: $good"
    elif [[ -n $good ]]; then
      out "  installed: $good"
    fi
    if [[ -n $bad ]]; then
      out "  failed: $bad"
    fi
    if [[ -n $manual ]]; then
      out "  install by hand: $manual"
    fi
  fi
  if [[ -n $bad ]]; then
    exit 1
  fi
}

# ─── first run (plan Section 2) ─────────────────────────────────────────

# The two links dotfiles.sh always makes for itself: the command, and its
# own config folder (decided 2026-10-12).
_self_links() {
  printf '%s\t%s\n' "$DOTFILES/dotfiles.sh" ".local/bin/dotfiles"
  printf '%s\t%s\n' "$DOTFILES/config/dotfiles" ".config/dotfiles"
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
    log error "first run: yq is needed to read config.yaml; fix the yq problem above, then run: $DOTFILES/dotfiles.sh"
    exit 1
  fi
  load_settings
  if ! _setup_self_links; then
    log warn "first run: a self link isn't in place (see above); dotfiles.sh still works from $DOTFILES/dotfiles.sh"
  fi
  _setup_git_signing || true
  _path_check
}

# doctor: the self links and PATH.
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
    _check_ok "self links: $(_self_links | cut -f2 | sed 's|^|~/|' | paste -sd ' ' - | sed 's/ / and /')"
  elif _setup_self_links; then
    _check_ok "self links: made (or would make, in a dry run)"
  else
    _check_fail "self links: not in place (see above)"
  fi
  if _setup_git_signing; then
    _check_ok "git signing: $(_op_ssh_sign_path)"
  fi
  _path_check
}

# ─── doctor (plan Section 7) ────────────────────────────────────────────

DOCTOR_FAILED=0
DOCTOR_LINKS_ONLY=0   # tools with none on this manager (doctor counts them)
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
  # In the script, not config.yaml: yq is needed to read the config, and
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

_doctor_config() {
  if [[ -z $DOTFILES ]]; then
    _check_fail "config.yaml: DOTFILES isn't set and the script isn't running from a clone"
    return 0
  fi
  if [[ ! -f $DOTFILES_CONFIG ]]; then
    _check_fail "config.yaml: not found at $DOTFILES_CONFIG"
    return 0
  fi
  if [[ $YQ_OK != true ]]; then
    _check_fail "config.yaml: can't check it without mikefarah/yq"
    return 0
  fi
  # 2>&1 >/dev/null: keep only the error text, throw the parsed output away.
  local err
  if err="$(yq eval '.' "$DOTFILES_CONFIG" 2>&1 >/dev/null)"; then
    CONFIG_OK=true
    _check_ok "config.yaml: valid YAML ($DOTFILES_CONFIG)"
  else
    _check_fail "config.yaml: invalid YAML: $err"
  fi
}

# One tool: a package or a manual: message here, and links with src and
# dest. -v shows what each resolves to on this machine.
_doctor_tool() {
  local tool="$1" problems=0 package manual src dest count=0
  package="$(tool_package "$tool")"
  manual="$(tool_manual "$tool")"
  log debug "$tool: package=${package:-<none>} command=$(tool_command "$tool")${manual:+ manual=\"$manual\"}"

  # A missing manager name falls back to the key, so an empty package here
  # is a deliberate none: the tool is linked, nothing is installed.
  local unused
  unused="$(tool_unused_here "$tool")"
  if [[ $unused == true ]]; then
    log info "$tool: not used on ${DOTFILES_OS:-this OS} (no package, nothing to link)"
  elif [[ -z $package && -z $manual ]]; then
    log info "$tool: not available on ${PKG_MANAGER:-this OS} (none); links only"
    DOCTOR_LINKS_ONLY=$((DOCTOR_LINKS_ONLY + 1))
  fi
  while IFS=$'\t' read -r src dest; do
    count=$((count + 1))
    log debug "$tool: link config/${src:-?} -> ~/${dest:-?}"
    if [[ -z $src || -z $dest ]]; then
      log error "$tool: a link is missing src or dest"
      problems=$((problems + 1))
    elif [[ $(tool_link_copy "$tool" "$src") == true && $dest != /* ]]; then
      log error "$tool: config/$src has copy: true, so its dest must be a full system path (got: $dest)"
      problems=$((problems + 1))
    elif [[ $dest == /* && $(tool_link_copy "$tool" "$src") != true ]]; then
      log error "$tool: $dest is a system path; mark that link copy: true"
      problems=$((problems + 1))
    elif [[ ! -e $(_src_path "$src") ]]; then
      # Only an enabled tool fails: a disabled one isn't linked yet.
      if [[ $(tool_enabled "$tool") == true ]]; then
        log error "$tool: link source config/$src doesn't exist"
        problems=$((problems + 1))
      else
        log warn "$tool: link source config/$src doesn't exist (tool is disabled)"
      fi
    fi
  done < <(tool_links "$tool")
  # No links is fine: an install-only tool (the app syncs its own settings),
  # or a tool whose links are all for another OS.
  if [[ $count -eq 0 && $unused == false ]]; then
    if [[ $(_yq ".packages[\"$tool\"].links // [] | length") -gt 0 ]]; then
      log info "$tool: nothing to link on ${DOTFILES_OS:-this OS}"
    else
      log info "$tool: install only, no links"
    fi
  fi
  return "$problems"
}

_doctor_tools() {
  if [[ $CONFIG_OK != true ]]; then
    return 0
  fi
  local tool count=0 bad=0 note=""
  DOCTOR_LINKS_ONLY=0
  while IFS= read -r tool; do
    count=$((count + 1))
    if ! _doctor_tool "$tool"; then
      bad=$((bad + 1))
    fi
  done < <(manifest_tools)
  if [[ $DOCTOR_LINKS_ONLY -gt 0 ]]; then
    note=" ($DOCTOR_LINKS_ONLY links only)"
  fi
  if [[ $bad -gt 0 ]]; then
    _check_fail "packages: $bad of $count have problems on ${PKG_MANAGER:-this OS}$note"
  else
    _check_ok "packages: all $count resolve on ${PKG_MANAGER:-this OS}$note"
  fi
}

# The default: list: which are installed. Missing ones are a warning.
_doctor_default_packages() {
  if [[ $CONFIG_OK != true ]]; then
    return 0
  fi
  local name package version count=0 have=0 missing=""
  while IFS= read -r name; do
    count=$((count + 1))
    package="$(default_package "$name")"
    if [[ -n $package ]] && version="$(package_version "$package")"; then
      have=$((have + 1))
      log debug "default: $name ($package $version)"
    else
      missing="${missing:+$missing }$name"
    fi
  done < <(default_list)
  if [[ $count -eq 0 ]]; then
    log info "default: list is empty"
  elif [[ -n $missing ]]; then
    log warn "default: $have of $count installed; missing: $missing (dotfiles.sh default installs them)"
  else
    _check_ok "default: all $count installed"
  fi
}

cmd_doctor() {
  _doctor_os
  _doctor_git
  _doctor_yq
  _doctor_config
  load_settings
  _doctor_self_links
  _doctor_tools
  _doctor_default_packages

  if [[ $DOCTOR_FAILED -gt 0 ]]; then
    log error "doctor: $DOCTOR_FAILED check(s) failed"
    exit 1
  fi
  log success "doctor: all checks passed"
}

# ════════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════════

main() {
  ORIG_ARGS=("$@")
  # No need to start dotfiles with sudo: it asks for sudo itself when a
  # tool has system files. Started with sudo anyway: run as the user who ran
  # it, so the clone, links, config.yaml and log stay theirs (sudo doesn't
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
  _log_to_file "DEBUG" "──── run start: dotfiles.sh $DOTFILES_VERSION, args: $*"

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
  if [[ ${DOTFILES_FIRST_RUN:-} == 1 ]]; then
    _first_run_setup
  elif [[ $cmd != doctor ]]; then
    load_settings
  fi
  warn_unused_flags "$cmd"

  case "$cmd" in
    interactive) cmd_interactive ;;
    default)   cmd_default "$@" ;;
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
    *)
      log error "unknown command: $cmd (see: dotfiles.sh help)"
      exit 2
      ;;
  esac
}

main "$@"
