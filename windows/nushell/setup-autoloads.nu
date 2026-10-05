# setup-autoloads.nu — regenerate Nushell vendor/autoload scripts on the target.
# Run once after copying config.nu/env.nu to %APPDATA%\nushell (or after installing
# the CLI tools). These files are tool-generated (@ starship init nu etc.) and embed
# machine-specific paths, so they are NOT stored in the repo.
#
# Requirements on PATH: nu, starship, zoxide, atuin, carapace
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

# --- atuin (history) -------------------------------------------------------
if (which atuin | is-empty) {
    print "⚠️  atuin not found on PATH — skipping atuin.nu"
} else {
    ^atuin init nu | save -f ($autoload | path join "atuin.nu")
    print "✓ atuin.nu"
}

# --- carapace (completions; embeds user cache path, generated per-user) ----
if (which carapace | is-empty) {
    print "⚠️  carapace not found on PATH — skipping carapace.nu"
} else {
    ^carapace _carapace nushell | save -f ($autoload | path join "carapace.nu")
    print "✓ carapace.nu"
}

print "Autoloads regenerated in: " + $autoload