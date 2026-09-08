#!/usr/bin/env python3
"""Boilerplate for a small automation CLI with subcommands.

Usage:
    ./cli.py --help
    ./cli.py greet Pavel --upper
    ./cli.py sync ./src ./dest --exclude .git --exclude node_modules --dry-run
    ./cli.py clean ~/tmp --older-than 30 -vv
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

__version__ = "0.1.0"

log = logging.getLogger("cli")


# --------------------------------------------------------------------------
# Command handlers
# Each one receives the parsed args namespace and returns an exit code.
# --------------------------------------------------------------------------

def cmd_greet(args: argparse.Namespace) -> int:
    message = f"Hello, {args.name}!"
    if args.upper:
        message = message.upper()
    for _ in range(args.repeat):
        print(message)
    return 0


def cmd_sync(args: argparse.Namespace) -> int:
    log.debug("source=%s dest=%s exclude=%s", args.source, args.dest, args.exclude)

    if not args.source.exists():
        log.error("Source does not exist: %s", args.source)
        return 1

    if args.dry_run:
        log.info("[dry-run] would sync %s -> %s", args.source, args.dest)
        return 0

    log.info("Syncing %s -> %s", args.source, args.dest)
    # ... real work here ...
    return 0


def cmd_clean(args: argparse.Namespace) -> int:
    log.info("Cleaning %s (older than %d days)", args.target, args.older_than)
    if args.dry_run:
        log.info("[dry-run] nothing was deleted")
    return 0


# --------------------------------------------------------------------------
# Parser construction
# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    # Flags every command shares. add_help=False keeps it from fighting with
    # the real -h on each subparser.
    # default=SUPPRESS is load-bearing: without it the subparser writes its own
    # defaults over anything parsed before the subcommand name.
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "-v", "--verbose",
        action="count",
        default=argparse.SUPPRESS,
        help="increase verbosity (-v info, -vv debug)",
    )
    common.add_argument(
        "-q", "--quiet",
        action="store_true",
        default=argparse.SUPPRESS,
        help="suppress all but errors",
    )
    common.add_argument(
        "-n", "--dry-run",
        action="store_true",
        default=argparse.SUPPRESS,
        help="show what would happen without doing it",
    )

    parser = argparse.ArgumentParser(
        prog="cli",
        description="Small automation helper.",
        parents=[common],
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )

    sub = parser.add_subparsers(
        dest="command",
        metavar="COMMAND",
        required=True,
    )

    # --- greet ---
    p_greet = sub.add_parser(
        "greet",
        parents=[common],
        help="print a greeting",
    )
    p_greet.add_argument("name", help="who to greet")
    p_greet.add_argument(
        "-u", "--upper",
        action="store_true",
        help="shout it",
    )
    p_greet.add_argument(
        "-r", "--repeat",
        type=int,
        default=1,
        metavar="N",
        help="print N times (default: %(default)s)",
    )
    p_greet.set_defaults(func=cmd_greet)

    # --- sync ---
    p_sync = sub.add_parser(
        "sync",
        parents=[common],
        help="copy one tree to another",
    )
    p_sync.add_argument("source", type=Path)
    p_sync.add_argument("dest", type=Path)
    p_sync.add_argument(
        "-e", "--exclude",
        action="append",
        default=[],
        metavar="PATTERN",
        help="skip paths matching PATTERN (repeatable)",
    )
    p_sync.add_argument(
        "--mode",
        choices=("mirror", "additive"),
        default="additive",
        help="sync strategy (default: %(default)s)",
    )
    p_sync.set_defaults(func=cmd_sync)

    # --- clean ---
    p_clean = sub.add_parser(
        "clean",
        parents=[common],
        help="remove stale files",
    )
    p_clean.add_argument("target", type=Path)
    p_clean.add_argument(
        "--older-than",
        type=int,
        default=30,
        metavar="DAYS",
        help="age threshold in days (default: %(default)s)",
    )
    p_clean.set_defaults(func=cmd_clean)

    return parser


def setup_logging(verbose: int, quiet: bool) -> None:
    if quiet:
        level = logging.ERROR
    elif verbose >= 2:
        level = logging.DEBUG
    elif verbose == 1:
        level = logging.INFO
    else:
        level = logging.WARNING

    logging.basicConfig(
        level=level,
        format="%(levelname)s: %(message)s",
        stream=sys.stderr,
    )


# Because the shared flags use SUPPRESS, an unused flag is simply absent from
# the namespace. Fill in the real defaults here instead.
GLOBAL_DEFAULTS = {"verbose": 0, "quiet": False, "dry_run": False}


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    for key, value in GLOBAL_DEFAULTS.items():
        if not hasattr(args, key):
            setattr(args, key, value)

    setup_logging(args.verbose, args.quiet)

    try:
        return args.func(args)
    except KeyboardInterrupt:
        log.error("Interrupted")
        return 130
    except Exception as exc:  # noqa: BLE001
        log.error("%s", exc)
        log.debug("Traceback:", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())