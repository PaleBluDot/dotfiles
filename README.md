# Dotfiles

Configs for the tools I use on Linux, macOS and Windows, and `dotfiles.sh`,
the script that installs those tools and links their configs into place.

## Install

Linux and macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/PaleBluDot/dotfiles/main/dotfiles.sh | bash
```

Windows (PowerShell; installs Git for Windows first, then runs the same script in Git Bash):

```powershell
irm https://raw.githubusercontent.com/PaleBluDot/dotfiles/main/bootstrap.ps1 | iex
```

The first run asks where to clone the repo, links itself as `dotfiles`
(`~/.local/bin`), then opens the interactive setup.
To skip the question: `curl … | DOTFILES=<path> bash`.

`dotfiles.sh` runs on Bash 3.2 and newer, so macOS's own `/bin/bash` works
before Homebrew is installed.

On Windows, turn on Developer Mode first (Settings > System > For developers),
or the config symlinks can't be made.

## Use

```text
dotfiles                  interactive setup
dotfiles link [tool…]     install tools and link their configs (no tool = all in config.yml)
dotfiles unlink [tool…]   remove tools and their links (no tool = pick from a list)
dotfiles update           pull the repo, install what's missing, relink
dotfiles wipe             undo everything dotfiles set up here (to test again)
dotfiles status [tool]
dotfiles doctor           check (and fix) what dotfiles needs
dotfiles help [command]
```

Flags work anywhere on the line: `-d` dry run, `-v` verbose (combine as `-dv`),
`--force` no questions and no backups (on `unlink`: also required tools),
`--required` (on `link`: keep the tool on this machine). Try anything with
`-dv` first.

## Config

| File | Where | Holds |
|---|---|---|
| [`config/dotfiles/dotfiles.yml`](config/dotfiles/dotfiles.yml) | repo | every tool: its package per platform, its links, repos to clone |
| [`config/dotfiles/hooks/<tool>.sh`](config/dotfiles/hooks) | repo | extra steps for a tool (optional) |
| `~/.config/dotfiles/config.yml` | each machine, never committed | `settings:`, `required:`, `tools:` |

```yaml
# dotfiles.yml
tools:
  fd:
    package:
      all: fd              # every platform not listed
      debian: fd-find
      windows: sharkdp.fd  # no all: = only the listed platforms
    command:
      debian: fdfind       # the command that shows it's installed
    links:
      fd/ignore: $HOME/.config/fd/ignore
```

Platforms: `arch`, `debian`, `fedora`, `mac`, `windows`, and `linux` (all
three). `~` as a package = used there, nothing to install (part of the OS).
A link outside `$HOME` becomes a root-owned copy, and a file with `op://`
references is filled in from 1Password; nothing to write for either. The
comments at the top of `dotfiles.yml` explain each field.

A hook runs after its tool's package and links (`link`, `update`, the
interactive setup), gets `--dry-run`, `--verbose` and `--force`, and prints
nothing when there's nothing to do. A line `next: <text>` goes to the
**Next steps** list at the end of the run. A tool with a hook is used on
every platform (the hook covers the ones `package:` doesn't list).

`config.yml` lists what this machine uses: `required:` tools are never
removed by `unlink` (only `unlink --force`) or the interactive setup;
`tools:` are the rest. `dotfiles` rewrites only those two lists
(alphabetical) and keeps everything else in the file. The first run after
the old `config.yaml` writes it from that file's `enabled:` / `locked:`
values.

It follows what's installed, every run: a tool from `dotfiles.yml`
installed here goes into `tools:`, and one removed outside dotfiles comes
off. A tool you add by hand stays until `link` installs it, and moving one
between the lists by hand is kept (`~/.local/state/dotfiles/installed`
remembers what was installed last run, to tell the two apart). To stop
using an installed tool, `dotfiles unlink` it.

Run order: `priority: high` tools first, then the required ones, then the
rest.

No secrets are committed. Files that need them hold `op://` references and
are filled in by the 1Password CLI (`op inject`) when linked.

Log: `~/.local/state/dotfiles/dotfiles.log`.
