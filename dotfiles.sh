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
# ARGUMENTS (plan Section 7)
# ════════════════════════════════════════════════════════════════════════

# Flags can go anywhere on the line. Everything else lands in ARGS.
ARGS=()
parse_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run)    DRY_RUN=true ;;
      --force)      FORCE=true ;;
      -v | --verbose) VERBOSE=true ;;
      -*)
        log error "unknown flag: $arg (see: dotfiles.sh help)"
        exit 2
        ;;
      *) ARGS+=("$arg") ;;
    esac
  done
}

# --dry-run and --force only mean something for these four commands.
warn_unused_flags() {
  local cmd="$1"
  case "$cmd" in
    install | link | unlink | uninstall) return 0 ;;
  esac
  if [[ $DRY_RUN == true ]]; then
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
  doctor                check git, yq, packages.yaml and OS detection
  help [command]        show this help, or help for one command
  version               print the script version

Flags:
  --dry-run             show what would happen, change nothing (install, link, unlink, uninstall)
  --force               no prompts, no backups (install, link, unlink, uninstall)
  -v, --verbose         show debug lines in the terminal

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
cmd_doctor()    { _not_built doctor 3; }

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
