# config.nu
#
# Installed by:
# version = "0.116.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

# ---------------------------------------------------------------------------
# Line editor — the PSReadLine-like flow
# ---------------------------------------------------------------------------
# Inline hints are Nushell's own autosuggestion: as you type, the most recent
# matching command from history is drawn dimmed after the cursor. Accept the
# whole hint with Right or End, one word of it with Ctrl+Right — the same keys
# the PowerShell profile uses for PSReadLine's inline prediction. The colour is
# PSReadLine's `InlinePrediction` value, so both shells suggest alike.
$env.config.show_hints = true
$env.config.color_config.hints = "#444444"

# History and completion stay Nushell-native here: Up/Down walk the history,
# Ctrl+R opens the history menu, Tab opens the completion menu. Nothing under
# `vendor/autoload` rewrites those keys or the external completer — atuin and
# carapace are deliberately not integrated (see `setup-autoloads.nu`).
