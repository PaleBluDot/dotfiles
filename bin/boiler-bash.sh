#!/usr/bin/env bash
#
# boilerplate.sh — Bash template: subcommands, short+long options with
#                  bundling (-vF), glued values (-fconfig, --file=config),
#                  logging, and per-command --help.
#
# Usage:
#   ./boilerplate.sh [global options] <command> [command options] [args]
#
# Examples:
#   ./boilerplate.sh -vf config.txt add widget      # bundled: -v + -f config.txt
#   ./boilerplate.sh -vfconfig.txt add widget       # same, value glued to -f
#   ./boilerplate.sh add -F widget gadget
#   ./boilerplate.sh add --help
#   ./boilerplate.sh help add
#
# Compatibility: Bash 3.2+ (macOS default), Linux, WSL.
# No getopts (short-only), no getopt (GNU-only, broken on macOS).
#
# Architecture:
#   1. _normalize_args expands bundled/glued short options into canonical
#      "-x" / "-x value" tokens (this is the same job getopts does internally).
#   2. A plain while/case loop then parses the canonical tokens.
#   Each parsing stage (global, per-command) declares its own option spec.

# ------------------------------------------------------------------------------
# Safety settings
# ------------------------------------------------------------------------------
# -e  : exit immediately if any command fails
# -u  : treat unset variables as an error (catches typos in variable names)
# -o pipefail : a pipeline fails if ANY command in it fails, not just the last
set -euo pipefail

# ------------------------------------------------------------------------------
# Script metadata
# ------------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="0.3.0"

# ------------------------------------------------------------------------------
# Defaults (overridden by flags)
# ------------------------------------------------------------------------------
VERBOSE=0                 # -v / --verbose → 1, and DEBUG logs become visible
CONFIG_FILE=""            # -f / --file <path>
LOG_LEVEL="INFO"          # minimum level printed: DEBUG < INFO < WARN < ERROR

# ==============================================================================
# LOGGING
# ==============================================================================

# Map a level name to a number so levels can be compared.
# (A case statement instead of an associative array keeps Bash 3.2 compat.)
_log_level_num() {
  case "$1" in
    DEBUG) echo 0 ;;
    INFO)  echo 1 ;;
    WARN)  echo 2 ;;
    ERROR) echo 3 ;;
    *)     echo 1 ;;
  esac
}

# Core logger. Everything goes to stderr so stdout stays clean for real
# output — this lets you pipe your script's results without log noise.
_log() {
  local level="$1"; shift
  local msg="$*"

  local want have
  want="$(_log_level_num "$level")"
  have="$(_log_level_num "$LOG_LEVEL")"
  [ "$want" -lt "$have" ] && return 0

  # Color only when stderr is a terminal (not when redirected to a file)
  local color="" reset=""
  if [ -t 2 ]; then
    reset="\033[0m"
    case "$level" in
      DEBUG) color="\033[0;36m" ;;  # cyan
      INFO)  color="\033[0;32m" ;;  # green
      WARN)  color="\033[0;33m" ;;  # yellow
      ERROR) color="\033[0;31m" ;;  # red
    esac
  fi

  printf "%b[%s] %-5s%b %s\n" \
    "$color" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$reset" "$msg" >&2
}

log_debug() { _log DEBUG "$@"; }
log_info()  { _log INFO  "$@"; }
log_warn()  { _log WARN  "$@"; }
log_error() { _log ERROR "$@"; }

# Log an error and exit. Optional second arg sets the exit code.
die() {
  log_error "$1"
  exit "${2:-1}"
}

# ==============================================================================
# CLEANUP
# ==============================================================================

# Runs on ANY exit — success, failure, or Ctrl+C.
cleanup() {
  local exit_code=$?
  log_debug "Cleanup running (exit code: ${exit_code})"
  # rm -f "$TMP_FILE" 2>/dev/null || true
}
trap cleanup EXIT

# ==============================================================================
# OPTION NORMALIZER
# ==============================================================================
# Expands bundled short options into canonical one-flag-per-token form so the
# parse loops stay dead simple. This is exactly the preprocessing getopts does
# internally — we just do it ourselves so long options can coexist.
#
#   -vF           →  -v -F
#   -vf conf.txt  →  -v -f conf.txt
#   -vfconf.txt   →  -v -f conf.txt      (value glued to the last flag)
#   --file=x      →  passed through untouched (the parse loop splits '=')
#   -- a b        →  passed through untouched (end-of-options marker)
#
# Arguments:
#   $1   option spec, getopts-style: letters, ':' after any flag that takes a
#        value. Example: "f:vhV" = -f takes a value; -v -h -V are booleans.
#   $2   mode:
#          "stop"  → stop normalizing at the first positional token (used for
#                    the GLOBAL stage, where the first positional is the
#                    command and its args belong to a DIFFERENT spec)
#          "mixed" → normalize the whole line (used inside commands, where
#                    options and positionals may be freely interleaved)
#   $@   the arguments to normalize
#
# Output: sets the global array NORMALIZED_ARGS. (Bash 3.2 has no namerefs,
# so a well-known global is the portable way to "return" an array.)
_normalize_args() {
  local spec="$1" mode="$2"
  shift 2
  NORMALIZED_ARGS=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --)
        # End-of-options: keep the marker and everything after it verbatim
        NORMALIZED_ARGS+=("$@")
        break
        ;;
      --*)
        # Long option: pass through; the parse loop handles --opt=value
        NORMALIZED_ARGS+=("$1"); shift
        ;;
      -?*)
        # One or more short flags in a single token. Peel one char at a time.
        local bundle="${1#-}"; shift
        while [ -n "$bundle" ]; do
          local flag="${bundle:0:1}"
          bundle="${bundle:1}"
          case "$spec" in
            *"${flag}:"*)
              # This flag takes a value.
              if [ -n "$bundle" ]; then
                # Rest of the token IS the value: -fconf.txt
                NORMALIZED_ARGS+=("-${flag}" "$bundle")
                bundle=""
              else
                # Value must be the next token: -f conf.txt
                # Emit the flag; the parse loop consumes (and validates) it.
                NORMALIZED_ARGS+=("-${flag}")
              fi
              ;;
            *"${flag}"*)
              # Boolean flag — emit and continue peeling the bundle
              NORMALIZED_ARGS+=("-${flag}")
              ;;
            *)
              # Unknown flag. Emit it anyway; the parse loop owns error
              # reporting so all "unknown option" messages look identical.
              NORMALIZED_ARGS+=("-${flag}")
              ;;
          esac
        done
        ;;
      *)
        # Positional token (includes a bare '-', the stdin convention)
        if [ "$mode" = "stop" ]; then
          # Global stage: this is the command — its args are not ours to touch
          NORMALIZED_ARGS+=("$@")
          break
        fi
        NORMALIZED_ARGS+=("$1"); shift
        ;;
    esac
  done
}

# ==============================================================================
# HELP / USAGE
# ==============================================================================

usage() {
  cat <<EOF
${SCRIPT_NAME} v${VERSION}

Usage:
  ${SCRIPT_NAME} [global options] <command> [command options] [args]

Global options:
  -f, --file <path>   Path to config file (also: --file=<path>, -f<path>)
  -v, --verbose       Verbose output (show DEBUG logs)
  -h, --help          Show this help
  -V, --version       Show version

Short flags may be bundled: -vf config.txt

Commands:
  help [command]      Show help (optionally for a specific command)
  add <item>          Add an item
  version             Show version

Run '${SCRIPT_NAME} <command> --help' for command-specific options.
EOF
}

# ==============================================================================
# COMMANDS
# ==============================================================================
# Conventions:
#   cmd_<name>       — the command itself; normalizes + parses its OWN options
#   cmd_<name>_help  — that command's help text, reachable two ways:
#                        ./script <name> --help
#                        ./script help <name>

# --- help ---------------------------------------------------------------------

cmd_help() {
  # 'help' with an argument shows that command's help; bare 'help' shows global.
  if [ $# -ge 1 ]; then
    case "$1" in
      add)     cmd_add_help ;;
      version) echo "Usage: ${SCRIPT_NAME} version — prints the version." ;;
      help)    echo "Very meta. Usage: ${SCRIPT_NAME} help [command]" ;;
      *)       die "No help available: unknown command '$1'" ;;
    esac
  else
    usage
  fi
}

# --- version ------------------------------------------------------------------

cmd_version() {
  echo "${SCRIPT_NAME} v${VERSION}"
}

# --- add ----------------------------------------------------------------------

cmd_add_help() {
  cat <<EOF
Usage:
  ${SCRIPT_NAME} add [options] <item> [<item>...]

Add one or more items.

Options:
  -F, --force    Overwrite if the item already exists
  -h, --help     Show this help

Short flags may be bundled: -Fh

Examples:
  ${SCRIPT_NAME} add widget
  ${SCRIPT_NAME} add -F widget gadget
EOF
}

cmd_add() {
  # Expand any bundles against THIS command's spec ("Fh": both boolean),
  # then reset the positional parameters to the canonical form.
  _normalize_args "Fh" "mixed" "$@"
  set -- ${NORMALIZED_ARGS[@]+"${NORMALIZED_ARGS[@]}"}

  local force=0
  local items=()

  # Options and positional args can be freely mixed (add widget -F works).
  while [ $# -gt 0 ]; do
    case "$1" in
      -F|--force) force=1; shift ;;
      -h|--help)  cmd_add_help; exit 0 ;;
      --)         shift; items+=("$@"); break ;;   # everything after -- is positional
      -*)         die "Unknown option for 'add': $1 (see '${SCRIPT_NAME} add --help')" ;;
      *)          items+=("$1"); shift ;;
    esac
  done

  # NOTE: ${items[@]+"${items[@]}"} instead of "${items[@]}".
  # Under 'set -u', Bash 3.2 treats an EMPTY array as unset and errors out.
  # This expansion idiom means: "expand the array only if it has elements."
  if [ "${#items[@]}" -eq 0 ]; then
    die "add requires at least one item. See '${SCRIPT_NAME} add --help'"
  fi

  log_debug "cmd_add: force=${force}, items=${#items[@]}"

  if [ -n "$CONFIG_FILE" ]; then
    log_debug "Using config file: ${CONFIG_FILE}"
    [ -f "$CONFIG_FILE" ] || die "Config file not found: ${CONFIG_FILE}"
  fi

  local item
  for item in ${items[@]+"${items[@]}"}; do
    # --- actual work goes here ---
    if [ "$force" -eq 1 ]; then
      log_info "Added (forced): ${item}"
    else
      log_info "Added: ${item}"
    fi
  done
}

# ==============================================================================
# GLOBAL ARGUMENT PARSING + DISPATCH
# ==============================================================================

main() {
  # --- 1. Normalize, then parse GLOBAL options ---
  # Spec "f:vhV": -f takes a value; -v, -h, -V are booleans.
  # Mode "stop": don't touch anything from the command onward — the command
  # normalizes its own args against its own spec.
  _normalize_args "f:vhV" "stop" "$@"
  set -- ${NORMALIZED_ARGS[@]+"${NORMALIZED_ARGS[@]}"}

  while [ $# -gt 0 ]; do
    case "$1" in
      -f|--file)
        # Value in the NEXT argument: --file config.txt / -f config.txt
        [ $# -ge 2 ] || die "Option $1 requires a value."
        CONFIG_FILE="$2"
        shift 2
        ;;
      --file=*)
        # Value glued on with '=': --file=config.txt
        # ${1#*=} strips everything up to and including the first '='
        CONFIG_FILE="${1#*=}"
        shift
        ;;
      -v|--verbose)
        VERBOSE=1
        LOG_LEVEL="DEBUG"
        shift
        ;;
      -h|--help)
        usage; exit 0
        ;;
      -V|--version)
        cmd_version; exit 0
        ;;
      --)
        # Explicit end-of-options marker
        shift; break
        ;;
      -*)
        die "Unknown global option: $1. Run '${SCRIPT_NAME} help' for usage."
        ;;
      *)
        # First non-option token = the command. Stop parsing globals here.
        break
        ;;
    esac
  done

  log_debug "Verbose mode on (VERBOSE=${VERBOSE})"
  log_debug "Args after global parsing: $*"

  # --- 2. Require a command ---
  if [ $# -eq 0 ]; then
    log_error "No command given."
    usage
    exit 1
  fi

  local command="$1"; shift   # $@ now belongs to the command

  # --- 3. Dispatch ---
  case "$command" in
    help)    cmd_help "$@" ;;
    add)     cmd_add "$@" ;;
    version) cmd_version "$@" ;;
    *)       die "Unknown command: '${command}'. Run '${SCRIPT_NAME} help' for usage." ;;
  esac
}

main "$@"