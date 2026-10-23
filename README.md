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
dotfiles link [tool…]     install tools and link their configs (no tool = all enabled)
dotfiles unlink [tool…]   remove tools and their links (no tool = pick from a list)
dotfiles default          install the default: list, link nothing
dotfiles update           pull the repo, install what's missing, relink
dotfiles wipe             undo everything dotfiles set up here (to test again)
dotfiles status [tool]
dotfiles doctor           check (and fix) what dotfiles needs
dotfiles help [command]
```

Flags work anywhere on the line: `-d` dry run, `-v` verbose (combine as `-dv`),
`--force` no questions and no backups. Try anything with `-dv` first.

## Config

Every tool is an entry in [`config/dotfiles/config.yaml`](config/dotfiles/config.yaml):
its configs under `config/`, where they link to, and its package name per
package manager (pacman, apt, dnf, brew, winget) when it differs from the key.
The comments at the top of that file explain each field.

No secrets are committed. Files that need them hold `op://` references and
are filled in by the 1Password CLI (`op inject`) when linked.

Log: `~/.local/state/dotfiles/dotfiles.log`.
