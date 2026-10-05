# env.nu
#
# Installed by:
# version = "0.116.1"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.

# fnm — Node version manager integration
#
# fnm 1.39 has no `--shell nushell` target (only bash, zsh, fish, powershell and
# cmd), and `fnm env --json` deliberately reports only the FNM_* variables, with
# no PATH. This replicates what the supported shells do: load the variables, then
# prepend the per-shell multishell symlink to PATH.
#
# The symlink resolves to fnm's `default` alias, so `node`, `npm` and `npx` in
# Nushell follow `fnm default` / `fnm use`. Switching inside a session keeps
# working with `fnm use`; auto-switching on directory change is not wired here
# (PowerShell gets it through `--use-on-cd`).
let fnm_env = (^fnm env --json | from json)
load-env $fnm_env
let fnm_multishell = $fnm_env.FNM_MULTISHELL_PATH
let fnm_multishell_loaded = ($env.PATH | any {|entry| $entry == $fnm_multishell })
if ($fnm_multishell | is-not-empty) and (not $fnm_multishell_loaded) {
    $env.PATH = ($env.PATH | prepend $fnm_multishell)
}
