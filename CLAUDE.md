# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A symlink-based dotfiles manager for macOS (primary), Linux, and Windows. Configurations live in `config/<tool>/` and are linked into `~/` via `config/symlinks.yml`.

## Install / Uninstall

```bash
# Install dotfiles (symlinks) and OS packages
./dotfiles.sh install -d -p

# Dotfiles only
./dotfiles.sh install -d

# Packages only (macOS: Homebrew Brewfile; Linux: apt)
./dotfiles.sh install -p

# Uninstall
./dotfiles.sh uninstall -d -p

# Update (git pull + package upgrade)
./dotfiles.sh update -p

# Help
./dotfiles.sh help
```

One-liner bootstrap (from a fresh machine):
```bash
curl -s -L https://raw.githubusercontent.com/PaleBluDot/dotfiles/main/dotfiles.sh | bash -s
```

## Commit Conventions

Commits must follow Commitizen conventions defined in `commitizen.config.js`:

**Types:** `ci`, `chore`, `docs`, `feat`, `fix`, `refactor`, `revert`
**Scopes:** `alias`, `config`, `function`, `lib`, `script`, `settings`, `symlink`, `workflow`

Use the npm script for interactive commit prompts:
```bash
npm run commit   # runs git cz
```

Semantic release is automated via GitHub Actions on push to `main` or `dev`.

## Adding a New Tool's Dotfiles

1. Create `config/<toolname>/` directory.
2. Add config files.
3. Add an entry to `config/symlinks.yml`.

**Cross-platform tool** (installs to `~/` on all OSes):
```yaml
toolname:
  enabled: true
  symlinks:
    .toolrc: .toolrc
    settings.json: .config/tool/settings.json
```

**OS-specific install paths** — use `darwin`/`linux`/`windows` keys with a `path` (install location) and `symlinks` relative to that path:
```yaml
toolname:
  enabled: true
  darwin:
    path: ~/Library/Application Support/toolname
    symlinks:
      .: .           # link entire config dir
  linux:
    path: ~/.config/toolname
    symlinks:
      .: .
  windows:
    path: ~/AppData/Roaming/toolname
    symlinks:
      .: .
```

**Disabling a tool** without removing its config files:
```yaml
toolname:
  enabled: false
  ...
```

4. The `install_dotfiles()` function in `dotfiles.sh` picks this up automatically via `yq`.

## Architecture

```
dotfiles.sh                 # Main orchestrator — OS detection, symlinking, package install
bin/                        # Utility shell/python scripts (welcome.sh, myip, etc.)
config/
  zsh/                      # .zshrc, .zshenv, .zprofile, .aliases (primary shell config)
  git/                      # .gitconfig, .gitignore
  npm/                      # .npmrc, .nvmrc, npm-globals.txt
  espanso/                  # Text expansion: match/*.yml, config/
  os-only/macos/Brewfile    # Homebrew packages and casks
  os-only/linux/            # apt package list
  vscode/                   # VS Code settings.json
  ssh/                      # SSH config and authorized keys templates
  symlinks.yml              # All symlink mappings (source → target) for every tool
  [18 more tool dirs]
.releaserc.json             # semantic-release config (branches: main, dev)
commitizen.config.js        # Commit type/scope enforcement
.github/workflows/          # release.yml, dry-release.yml, semantic.yml
```

## Shell Aliases (config/zsh/.aliases)

Key aliases relevant when modifying this repo:
- `dotfiles` — `cd` to this repo
- `refresh` / `fresh` — reload shell config
- `aliasUpdate` — re-source aliases without full reload

## Release Process

Releases are fully automated:
```bash
npm run release      # production release (runs semantic-release)
npm run dry-release  # dry run — preview what would be released
```

CI requires secrets: `NPM_TOKEN`, `GH_TOKEN`, `GIT_NAME`, `GIT_EMAIL`.
