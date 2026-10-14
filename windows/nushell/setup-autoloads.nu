# setup-autoloads.nu — regenerate Nushell vendor/autoload scripts on the target.
# Run once after copying config.nu/env.nu to %APPDATA%\nushell (or after installing
# the CLI tools). These files are tool-generated (@ starship init nu etc.) and embed
# machine-specific paths, so they are NOT stored in the repo.
#
# Requirements on PATH: nu, starship, zoxide
#
# Usage:  nu setup-autoloads.nu

let data_dir = ($nu.data-dir | path expand)
let autoload = ($data_dir | path join "vendor/autoload")
mkdir $autoload

# --- starship prompt (official init) --------------------------------------
if (which starship | is-empty) {
    print "⚠️  starship not found on PATH — skipping starship.nu"
} else {
    ^starship init nu | save -f ($autoload | path join "starship.nu")
    print "✓ starship.nu"
}

# --- zoxide (hook + z/zi aliases) -----------------------------------------
if (which zoxide | is-empty) {
    print "⚠️  zoxide not found on PATH — skipping zoxide.nu"
} else {
    ^zoxide init nushell | save -f ($autoload | path join "zoxide.nu")
    print "✓ zoxide.nu"
}

# --- (no atuin, no carapace) -----------------------------------------------
# Deliberately absent: atuin re-bound Ctrl+R and Up to its own TUI and carapace
# replaced the external completer, which moved the editing flow away from
# PSReadLine's. Nushell's native history menu, history walk and completion menu
# are what `config.nu` documents. See odd/tasks/nushell-native-line-editor.md.

print "Autoloads regenerated in: " + $autoload