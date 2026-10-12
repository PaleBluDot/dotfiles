#!/usr/bin/env bash
#
# dotfiles.sh: install, link and manage the tools in this repo.
# Build spec: plan.md. Written for Bash 3.2 (macOS /bin/bash) and up.

set -euo pipefail
set -o errtrace

# ─── Metadata ───────────────────────────────────────────────────────────
readonly DOTFILES_VERSION="2.0.0"
export DOTFILES_VERSION

# ─── Flags (internal, never exported) ───────────────────────────────────
DRY_RUN=false
FORCE=false
VERBOSE=false

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
      printf '[%s] %s\n' "$label" "$message"
      ;;
  esac
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
  if [[ -n ${DOTFILES:-} ]]; then
    log debug "DOTFILES from the environment: $DOTFILES"
    if [[ ! -d $DOTFILES ]]; then
      log warn "DOTFILES is set to $DOTFILES, but that folder doesn't exist"
    fi
  else
    local src="${BASH_SOURCE[0]:-}"
    local target
    if [[ -n $src && -f $src ]]; then
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

  DOTFILES_PACKAGES_FILE="${DOTFILES:+$DOTFILES/config/packages.yaml}"
  export DOTFILES DOTFILES_PACKAGES_FILE
  log debug "DOTFILES_PACKAGES_FILE: ${DOTFILES_PACKAGES_FILE:-<none>}"
}

# ════════════════════════════════════════════════════════════════════════
# OS DETECTION (plan Section 4)
# ════════════════════════════════════════════════════════════════════════

DOTFILES_OS=""      # macos | linux | windows
DOTFILES_DISTRO=""  # display only, Linux only: "<NAME> <kernel>"
DISTRO_ID=""        # internal, Linux only: debian | pacman | fedora

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
    MINGW* | MSYS* | CYGWIN*) DOTFILES_OS="windows" ;;
    *) log warn "unsupported OS: $kernel" ;;
  esac

  export DOTFILES_OS DOTFILES_DISTRO
  log debug "DOTFILES_OS=${DOTFILES_OS:-<unknown>} DOTFILES_DISTRO=${DOTFILES_DISTRO:-<none>} distro id=${DISTRO_ID:-<none>}"
}

# ════════════════════════════════════════════════════════════════════════
# MANIFEST: config/packages.yaml (plan Section 5)
# ════════════════════════════════════════════════════════════════════════

# Run one yq query against packages.yaml.
_yq() {
  yq eval "$1" "$DOTFILES_PACKAGES_FILE"
}

# Every tool name in packages.yaml, one per line.
manifest_tools() {
  _yq '.packages | keys | .[]'
}

# The tiers to search for a tool, most specific first, as yq paths.
# ["name"] instead of .name, so any folder name works as a key.
_tiers() {
  local base=".packages[\"$1\"]"
  case "$DOTFILES_OS" in
    linux)
      if [[ -n $DISTRO_ID ]]; then
        echo "$base.os.linux.$DISTRO_ID"
      fi
      echo "$base.os.linux"
      ;;
    macos | windows)
      echo "$base.os.$DOTFILES_OS"
      ;;
  esac
  echo "$base.default"
}

# Print the yq path of the tier that sets <field> for <tool>, or nothing.
# The value "default" jumps straight to the default tier.
tool_field_tier() {
  local tool="$1" field="$2"
  local tier
  while IFS= read -r tier; do
    if [[ $(_yq "$tier.$field | tag") == '!!null' ]]; then
      continue
    fi
    if [[ $(_yq "$tier.$field") == default ]]; then
      # log debug writes to stderr, so it never ends up in the captured path.
      log debug "$tool: $field is \"default\" in $(_tier_label "$tier"), so it comes from default"
      echo ".packages[\"$tool\"].default"
    else
      echo "$tier"
    fi
    return 0
  done < <(_tiers "$tool")
}

# Print the merged value of a plain field (check_cmd, package, ...).
# Prints nothing when no tier sets it.
tool_field() {
  local tool="$1" field="$2"
  local tier
  tier="$(tool_field_tier "$tool" "$field")"
  if [[ -z $tier || $(_yq "$tier.$field | tag") == '!!null' ]]; then
    return 0
  fi
  _yq "$tier.$field"
}

# Print the merged links, one "src<TAB>dest" line each. A missing src or
# dest comes out empty, so callers can spot it.
tool_links() {
  local tool="$1"
  local tier
  tier="$(tool_field_tier "$tool" links)"
  if [[ -z $tier ]]; then
    return 0
  fi
  _yq "$tier.links[] | (.src // \"\") + \"\t\" + (.dest // \"\")"
}

# "true" or "false"; anything else counts as false.
tool_enabled() {
  if [[ $(_yq ".packages[\"$1\"].enabled") == true ]]; then
    echo true
  else
    echo false
  fi
}

# A tier path without the ".packages["tool"]." prefix, for messages.
_tier_label() {
  local tier="$1"
  tier="${tier#*\"]}"
  echo "${tier#.}"
}

# ════════════════════════════════════════════════════════════════════════
# RUNNING COMMANDS AND INSTALLING PACKAGES
# Bare bones, so doctor can install its prerequisites. Step 7 builds the
# full install/uninstall on top of this.
# ════════════════════════════════════════════════════════════════════════

# Run a command that changes the system. Its output shows in the terminal
# and goes into the log file line by line. Honors --dry-run.
run_cmd() {
  if [[ $DRY_RUN == true ]]; then
    log info "dry run, would run: $*"
    return 0
  fi
  log info "running: $*"
  local line
  # With pipefail, the pipeline's exit code is the command's, not the loop's.
  "$@" 2>&1 | while IFS= read -r line || [[ -n $line ]]; do
    printf '%s\n' "$line"
    _log_to_file "DEBUG" "  > $line"
  done
}

# Install one package with this OS's package manager.
pm_install() {
  local package="$1"
  local -a cmd

  case "$DOTFILES_OS:$DISTRO_ID" in
    linux:pacman) cmd=(pacman -S --needed --noconfirm "$package") ;;
    linux:debian) cmd=(apt-get install -y "$package") ;;
    linux:fedora) cmd=(dnf install -y "$package") ;;
    macos:*)
      if ! command -v brew >/dev/null 2>&1; then
        log error "can't install $package: Homebrew isn't installed (https://brew.sh)"
        return 1
      fi
      cmd=(brew install "$package")
      ;;
    windows:*)
      cmd=(winget install -e --accept-package-agreements --accept-source-agreements --id "$package")
      ;;
    *)
      log error "can't install $package: no package manager for ${DOTFILES_OS:-this OS}${DISTRO_ID:+ ($DISTRO_ID)}"
      return 1
      ;;
  esac

  # Linux package managers need root. $EUID is 0 when already root (VMs, containers).
  if [[ $DOTFILES_OS == linux && $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      log error "can't install $package: needs root, and sudo isn't installed"
      return 1
    fi
    cmd=(sudo "${cmd[@]}")
    # apt needs fresh package lists on a new machine.
    if [[ $DISTRO_ID == debian ]]; then
      run_cmd sudo apt-get update
    fi
  elif [[ $DISTRO_ID == debian ]]; then
    run_cmd apt-get update
  fi

  run_cmd "${cmd[@]}"
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

# --dry-run means something for these five commands, --force for four.
warn_unused_flags() {
  local cmd="$1"
  case "$cmd" in
    install | link | unlink | uninstall) return 0 ;;
  esac
  if [[ $DRY_RUN == true && $cmd != doctor ]]; then
    log warn "--dry-run has no effect on '$cmd'"
  fi
  if [[ $FORCE == true ]]; then
    log warn "--force has no effect on '$cmd'"
  fi
}

# ════════════════════════════════════════════════════════════════════════
# COMMANDS
# ════════════════════════════════════════════════════════════════════════

cmd_help() {
  local topic="${1:-}"
  if [[ -n $topic ]]; then
    case "$topic" in
      install | link | unlink | uninstall | update | status | doctor | help | version)
        echo "dotfiles.sh help $topic: detailed help comes in Step 13."
        return 0
        ;;
      *)
        log error "no help for unknown command: $topic"
        exit 2
        ;;
    esac
  fi

  cat <<EOF
dotfiles.sh $DOTFILES_VERSION

Usage: dotfiles.sh [command] [tool...] [flags]
       dotfiles.sh            with no command: interactive install/uninstall

Commands:
  install [tool...]     install packages and link their configs (no tool = interactive)
  uninstall [tool...]   remove packages and unlink their configs (no tool = interactive)
  link [tool...]        create symlinks only (no tool = all enabled tools)
  unlink [tool...]      remove symlinks (no tool = all enabled tools)
  update                git pull, install missing packages, relink
  status [tool]         show tools, links and default-packages
  doctor                check git, yq, packages.yaml and OS detection; installs missing git/yq
  help [command]        show this help, or help for one command
  version               print the script version

Flags:
  -d, --dry-run         show what would happen, change nothing (install, link, unlink, uninstall, doctor)
  --force               no prompts, no backups (install, link, unlink, uninstall)
  -v, --verbose         show debug lines in the terminal
  Short flags combine: -dv = --dry-run --verbose

Log file: ${LOG_FILE:-<not available>}
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
cmd_interactive() { _not_built "interactive install/uninstall" 9; }
cmd_install()   { _not_built install "7 and 9"; }
cmd_uninstall() { _not_built uninstall "7 and 9"; }
cmd_link()      { _not_built link 6; }
cmd_unlink()    { _not_built unlink 6; }
cmd_update()    { _not_built update 10; }
cmd_status()    { _not_built status 5; }
# ─── doctor (plan Section 7): checks only, changes nothing ──────────────

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
        _check_ok "OS: linux, $DOTFILES_DISTRO (package family: $DISTRO_ID)"
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
  case "$tool:$DOTFILES_OS:$DISTRO_ID" in
    git:windows:*)     echo "Git.Git" ;;
    git:*)             echo "git" ;;
    yq:linux:pacman)   echo "go-yq" ;;
    yq:linux:fedora)   echo "yq" ;;   # unverified: confirm in a Fedora VM
    yq:macos:*)        echo "yq" ;;
    yq:windows:*)      echo "MikeFarah.yq" ;;
    yq:linux:debian)
      log error "yq: apt's 'yq' package is the Python one; install mikefarah/yq from https://github.com/mikefarah/yq/releases"
      ;;
  esac
}

# Install a missing prerequisite, then look for it again.
_doctor_install() {
  local tool="$1" package
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

_doctor_packages_file() {
  if [[ -z $DOTFILES ]]; then
    _check_fail "packages.yaml: DOTFILES isn't set and the script isn't running from a clone"
    return 0
  fi
  if [[ ! -f $DOTFILES_PACKAGES_FILE ]]; then
    _check_fail "packages.yaml: not found at $DOTFILES_PACKAGES_FILE"
    return 0
  fi
  if [[ $YQ_OK != true ]]; then
    _check_fail "packages.yaml: can't check it without mikefarah/yq"
    return 0
  fi

  # 2>&1 >/dev/null: keep only the error text, throw the parsed output away.
  local err
  if err="$(yq eval '.' "$DOTFILES_PACKAGES_FILE" 2>&1 >/dev/null)"; then
    PACKAGES_FILE_OK=true
    _check_ok "packages.yaml: valid YAML ($DOTFILES_PACKAGES_FILE)"
  else
    _check_fail "packages.yaml: invalid YAML: $err"
  fi
}

# Every tool must resolve on this OS: check_cmd, plus a package or an
# err_install_msg, and each link needs src and dest. -v shows each merged
# field and the tier it came from.
PACKAGES_FILE_OK=false

_doctor_tool() {
  local tool="$1"
  local problems=0 field tier value src dest
  local check_cmd="" package="" err_install_msg=""

  # One lookup per field: find the tier, then read the value from it.
  for field in check_cmd package err_install_msg; do
    tier="$(tool_field_tier "$tool" "$field")"
    value=""
    if [[ -n $tier && $(_yq "$tier.$field | tag") != '!!null' ]]; then
      value="$(_yq "$tier.$field")"
      log debug "$tool: $field = $value (from $(_tier_label "$tier"))"
    else
      log debug "$tool: $field = <unset>"
    fi
    case "$field" in
      check_cmd)       check_cmd="$value" ;;
      package)         package="$value" ;;
      err_install_msg) err_install_msg="$value" ;;
    esac
  done

  if [[ -z $check_cmd ]]; then
    log error "$tool: no check_cmd"
    problems=$((problems + 1))
  fi
  if [[ -z $package && -z $err_install_msg ]]; then
    log error "$tool: needs a package or an err_install_msg for $DOTFILES_OS${DISTRO_ID:+ ($DISTRO_ID)}"
    problems=$((problems + 1))
  fi

  tier="$(tool_field_tier "$tool" links)"
  if [[ -n $tier ]]; then
    log debug "$tool: links from $(_tier_label "$tier")"
  fi
  while IFS=$'\t' read -r src dest; do
    log debug "$tool: link config/$tool/${src:-?} -> ~/${dest:-?}"
    if [[ -z $src || -z $dest ]]; then
      log error "$tool: a link is missing src or dest"
      problems=$((problems + 1))
    elif [[ ! -e $DOTFILES/config/$tool/$src ]]; then
      # Only an enabled tool fails: a disabled one isn't linked yet.
      if [[ $(tool_enabled "$tool") == true ]]; then
        log error "$tool: link source config/$tool/$src doesn't exist"
        problems=$((problems + 1))
      else
        log warn "$tool: link source config/$tool/$src doesn't exist (tool is disabled)"
      fi
    fi
  done < <(tool_links "$tool")

  return "$problems"
}

_doctor_tools() {
  if [[ $PACKAGES_FILE_OK != true ]]; then
    return 0
  fi
  local tool count=0 bad=0
  while IFS= read -r tool; do
    count=$((count + 1))
    if ! _doctor_tool "$tool"; then
      bad=$((bad + 1))
    fi
  done < <(manifest_tools)

  if [[ $bad -gt 0 ]]; then
    _check_fail "tools: $bad of $count don't resolve on $DOTFILES_OS${DISTRO_ID:+ ($DISTRO_ID)}"
  else
    _check_ok "tools: all $count resolve on $DOTFILES_OS${DISTRO_ID:+ ($DISTRO_ID)}"
  fi
}

cmd_doctor() {
  _doctor_os
  _doctor_git
  _doctor_yq
  _doctor_packages_file
  _doctor_tools
  log warn "default-packages: not checked yet (Step 8)"

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
  init_log
  _log_to_file "DEBUG" "──── run start: dotfiles.sh $DOTFILES_VERSION, args: $*"

  parse_args "$@"
  # "${ARGS[@]}" on an empty array is an "unbound variable" error in
  # Bash < 4.4 under set -u; the ${ARGS[@]+...} form avoids it.
  set -- ${ARGS[@]+"${ARGS[@]}"}

  log debug "flags: dry-run=$DRY_RUN force=$FORCE verbose=$VERBOSE"
  log debug "log file: ${LOG_FILE:-<none>}"

  # No command = the interactive install/uninstall flow (plan Section 7).
  local cmd="${1:-interactive}"
  if [[ $# -gt 0 ]]; then
    shift
  fi
  LOG_CMD="$cmd"
  log debug "command: $cmd, arguments: ${*:-<none>}"

  resolve_dotfiles
  detect_os
  warn_unused_flags "$cmd"

  case "$cmd" in
    interactive) cmd_interactive ;;
    install)   cmd_install "$@" ;;
    uninstall) cmd_uninstall "$@" ;;
    link)      cmd_link "$@" ;;
    unlink)    cmd_unlink "$@" ;;
    update)    cmd_update "$@" ;;
    status)    cmd_status "$@" ;;
    doctor)    cmd_doctor "$@" ;;
    help)      cmd_help "$@" ;;
    version)   cmd_version "$@" ;;
    *)
      log error "unknown command: $cmd (see: dotfiles.sh help)"
      exit 2
      ;;
  esac
}

main "$@"
