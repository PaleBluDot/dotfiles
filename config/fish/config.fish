# fish: the starter config. The environment is the same ~/.zshenv that zsh
# and bash read (config/shell/env, written for bash and zsh): bash runs it
# and fish takes over every variable, so there's one env file for every
# shell. PATH comes over as fish's list (it splits on ":").
if test -r ~/.zshenv; and command -q bash
    bash -c 'source ~/.zshenv >/dev/null 2>&1; env -0' | while read -lz line
        set -l kv (string split -m 1 = -- $line)
        # Only real variable names, and not the ones each shell keeps itself.
        string match -qr '^[A-Za-z_][A-Za-z0-9_]*$' -- $kv[1]; or continue
        contains -- $kv[1] PWD OLDPWD SHLVL _; and continue
        set -gx $kv[1] $kv[2]
    end
end

if status is-interactive
    command -q starship; and starship init fish | source
end
