# Manifest — where every file goes

Copy-based dotfiles: each repo file maps to exactly one destination on the
target machine. **This file is the contract.** Copiar = `copy` the source to
the destination; never more, never less. No installer, no symlinks.

## Windows

Prerequisites (install once, manually, via winget — not part of the copy):

```
winget install -e --id LGUG2Z.komorebi
winget install -e --id LGUG2Z.masir
winget install -e --id AutoHotkey.AutoHotkey
winget install -e --id AmN.yasb
winget install -e --id DEVCOM.JetBrainsMonoNerdFont
winget install -e --id Nushell.Nushell --scope user
winget install -e --id Schniz.fnm
winget install -e --id ajeetdsouza.zoxide
winget install -e --id junegunn.fzf
winget install -e --id sharkdp.bat
winget install -e --id jqlang.jq
winget install -e --id JesseDuffield.lazygit
winget install -e --id Neovim.Neovim
```

The PowerShell profile also imports a module that winget does not provide:

```powershell
Install-Module -Name Terminal-Icons -Scope CurrentUser -Force
```

| Repo file | Destination (Windows) |
|---|---|
| `windows/komorebi/komorebi.home.json` | `%USERPROFILE%\komorebi.json` (two-monitor machine only) |
| `windows/komorebi/komorebi.work.json` | `%USERPROFILE%\komorebi.json` (single-monitor machine only) |
| `windows/komorebi/komorebi.ahk` | `%USERPROFILE%\komorebi.ahk` |
| `windows/komorebi/komorebi-autostart.ps1` | `%USERPROFILE%\komorebi-autostart.ps1` |
| `windows/komorebi/container-dump.ps1` | `%USERPROFILE%\komorebi-container-dump.ps1` |
| `windows/komorebi/yasb-subscription.ps1` | `%USERPROFILE%\komorebi-yasb-subscription.ps1` |
| `windows/autostart/komorebi-autostart.vbs` | `%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\komorebi-autostart.vbs` |
| `windows/yasb/config.yaml` | `%USERPROFILE%\.config\yasb\config.yaml` |
| `windows/yasb/styles.css` | `%USERPROFILE%\.config\yasb\styles.css` |
| `windows/yasb/opencode_go.py` | `%USERPROFILE%\.config\yasb\opencode_go.py` |
| `windows/yasb/pi_agents.py` | `%USERPROFILE%\.config\yasb\pi_agents.py` |
| `windows/yasb/ssd_busy.py` | `%USERPROFILE%\.config\yasb\ssd_busy.py` |
| `windows/yasb/pi-logo.png` | `%USERPROFILE%\.config\yasb\pi-logo.png` |
| `windows/yasb/opencode-logo.png` | `%USERPROFILE%\.config\yasb\opencode-logo.png` |
| `windows/win-terminal/settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| `windows/powershell/Microsoft.PowerShell_profile.ps1` | `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |
| `windows/powershell/user_profile.ps1` | `%USERPROFILE%\.config\powershell\user_profile.ps1` |
| `shared/starship.toml` | `%USERPROFILE%\.config\starship.toml` |
| `shared/nvim/` (recursive) | `%LOCALAPPDATA%\nvim\` (Neovim's config dir on Windows — NOT `~/.config/nvim`) |
| `windows/nushell/config.nu` | `%APPDATA%\nushell\config.nu` |
| `windows/nushell/env.nu` | `%APPDATA%\nushell\env.nu` |
| `windows/herdr/config.toml` | `%APPDATA%\herdr\config.toml` |
| `windows/herdr/plugins.json` | `%APPDATA%\herdr\plugins.json` |
| `windows/herdr-app/mods/files/` (recursive) | `%USERPROFILE%\.config\herdr-app\mods\files\` |
| `windows/herdr-app/mods/changes/` (recursive) | `%USERPROFILE%\.config\herdr-app\mods\changes\` |
| `windows/herdr-app/layouts/pixel.json` | `%USERPROFILE%\.config\herdr-app\layouts\pixel.json` |
| `windows/herdr-app/mods/pixel-spaces/` (recursive) | `%USERPROFILE%\.config\herdr-app\mods\pixel-spaces\` |
| `windows/herdr-app/mods/pixel-agents/` (recursive) | `%USERPROFILE%\.config\herdr-app\mods\pixel-agents\` |
| `windows/herdr-app/mods/pixel-tabs/` (recursive) | `%USERPROFILE%\.config\herdr-app\mods\pixel-tabs\` |
| `windows/herdr-app/mods/pixel-pane/` (recursive) | `%USERPROFILE%\.config\herdr-app\mods\pixel-pane\` |
| `windows/herdr-app/mods/pixel-status/` (recursive) | `%USERPROFILE%\.config\herdr-app\mods\pixel-status\` |
| `windows/herdr-app/mods/pixel-chrome/` (recursive) | `%USERPROFILE%\.config\herdr-app\mods\pixel-chrome\` |
| `windows/herdr-app/layouts/main-pixel.json` | `%USERPROFILE%\.config\herdr-app\layouts\main-pixel.json` |
| `windows/herdr-app/mods/main-pixel-spaces/` (recursive) | `%USERPROFILE%\.config\herdr-app\mods\main-pixel-spaces\` |
| `windows/herdr-app/mods/main-pixel-chrome/` (recursive) | `%USERPROFILE%\.config\herdr-app\mods\main-pixel-chrome\` |
| `windows/herdr-app/mods/pixel-picker/` (recursive) | `%USERPROFILE%\.config\herdr-app\mods\pixel-picker\` |
| `windows/herdr-app/programs.json` | `%USERPROFILE%\.config\herdr-app\programs.json` |
| `windows/herdr-app/pixel-icons/` (recursive) | `%USERPROFILE%\.config\herdr-app\pixel-icons\` |
| `shared/wallpapers/beach-house-in-japan.1920x1080.mp4` | `%USERPROFILE%\Pictures\Wallpapers\beach-house-in-japan.1920x1080.mp4` |

> **Copy exactly one komorebi configuration.** `komorebi.home.json` on the two-monitor
> (home) machine, `komorebi.work.json` on the single-monitor (work) machine — both to
> `%USERPROFILE%\komorebi.json` — and **never the other one**. Tell the machines apart
> with `komorebic state`: `serial_number_id=CZK83705DT` is the work machine, the home
> machine maps `CNK51707R2` + `CNK6180S06`. Every key except `display_index_preferences`
> and `monitors` is shared and must stay identical in both variants;
> `windows/komorebi/tests/` fails when they drift. Details, including how to run it:
> `windows/komorebi/README.md`.

> The two Herdr app layout bundles (`pixel`, `main-pixel`) are third-party code,
> pinned by commit in `windows/herdr-app/README.md`. `windows/herdr-app/licenses/`
> and `windows/herdr-app/keys.pixel-picker.merge.json` are repo-only: no row, never
> copied — `keys.json` is machine-local and is merged by hand, not overwritten.

> `windows/herdr/plugins.json` is Herdr's plugin registry (installed plugins and
> their `enabled` flag). It stores **absolute** `manifest_path` / `plugin_root`
> paths, so on another machine copy it and then reinstall the plugins there
> rather than expecting the recorded paths to resolve.

> `shared/wallpapers/` ships **assets, not a live configuration**: Lively keeps
> its own virtualized copy of the active wallpaper (MSIX redirect — see
> `windows/wallpapers/README.md`, which documents the engine), so copy the media
> file and add it in the app. The media lives in `shared/` because Linux plays the
> same file through OWE.

> `windows/nushell/setup-autoloads.nu` is NOT copied; run it once after copying,
> from a shell where `nu`, `starship` and `zoxide` are on PATH, to regenerate
> `%APPDATA%\nushell\vendor\autoload\*.nu` (tool-generated, embeds per-machine
> paths). atuin and carapace are deliberately not integrated — see
> `odd/tasks/nushell-native-line-editor.md`:
>
> ```powershell
> nu "<path-to-the-clone>\windows\nushell\setup-autoloads.nu"
> ```

After copying: sign out and in once (or run `%USERPROFILE%\komorebi-autostart.ps1`
once) so komorebi, the AHK hotkeys and YASB take effect. New Windows Terminal
tabs open Nushell (the default profile). See README → Verification.

## Linux

Prerequisites (install once, manually, via pacman — not part of the copy):

```bash
sudo pacman -S --needed zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting
chsh -s /usr/bin/zsh   # log out and back in
```

These require root, so they are never part of a copy: an agent-driven session
runs with `NoNewPrivs=1`, where the kernel refuses `sudo` and `pkexec` outright.
Run them yourself, from a terminal that can prompt for the password — the same
shape as the Windows `winget` block above.

| Repo file | Destination (Linux) |
|---|---|
| `linux/starship.toml` | `~/.config/starship.toml` (Linux prompt — `pastel-powerline`) |
| `linux/zsh/zshrc` | `~/.zshrc` |
| `shared/nvim/` (recursive) | `~/.config/nvim/` |
| `shared/wallpapers/beach-house-in-japan.1920x1080.mp4` | `~/Wallpapers/beach-house-in-japan.1920x1080.mp4` |
| `linux/omarchy-shell/shell.json` | `~/.config/omarchy/shell.json` |
| `linux/omarchy-shell/shell.toml` | `~/.config/omarchy/shell.toml` |
| `linux/omarchy-shell/language` | `~/.config/omarchy/language` |
| `linux/omarchy-shell/defaults/agent` | `~/.config/omarchy/defaults/agent` |
| `linux/omarchy-shell/defaults/dictation` | `~/.config/omarchy/defaults/dictation` |
| `linux/omarchy-shell/branding/about.txt` | `~/.config/omarchy/branding/about.txt` |
| `linux/omarchy-shell/branding/screensaver.txt` | `~/.config/omarchy/branding/screensaver.txt` |
| `linux/omarchy-shell/hooks/theme-set.d/10-owe-sync` | `~/.config/omarchy/hooks/theme-set.d/10-owe-sync` (keep it executable) |
| `linux/hyprland/bindings.lua` | `~/.config/hypr/bindings.lua` |
| `linux/hyprland/monitors.lua` | `~/.config/hypr/monitors.lua` |
| `linux/xdg-terminal-exec/hyprland-xdg-terminals.list` | `~/.config/xdg-terminal-exec/hyprland-xdg-terminals.list` |
| `linux/herdr/config.toml` | `~/.config/herdr/config.toml` |

> **The prompt is no longer shared.** Windows keeps `shared/starship.toml` (a
> customised catppuccin-powerline); Linux now uses `linux/starship.toml`, the
> `pastel-powerline` preset. Unifying them is an explicit decision, never a
> side effect — the two rows are deliberately different files.

> **`linux/hyprland/` holds only the modules that carry a personal decision:**
> `bindings.lua` (the two chord overrides) and `monitors.lua` (which output is the
> left screen). Every other module in
> `~/.config/hypr/` is byte-identical to `/usr/share/omarchy/config/hypr/`, so the
> package owns it: copying them would freeze defaults while adding no personal
> decision. `bindings.lua` earns its row because it now carries overrides
> (`SUPER + RETURN` → Herdr, `SUPER + CTRL + RETURN` → the plain terminal). If you
> edit another module, copy **that file only** and add its row. There is no waybar
> on this machine — the bar is `omarchy-shell`. See `linux/README.md`.

> `linux/omarchy-shell/README.md` is documentation. It sits next to the config
> files, so copy **only the rows above**, never the folder wholesale.

> `linux/omarchy-shell/shell.json` is a full user copy, not a sparse patch, pinned
> to Omarchy `4.0.0.alpha`. Upstream default changes will not reach it after an
> update; re-diff and merge by hand. Its three deltas are listed in
> `linux/omarchy-shell/README.md`.

> `defaults/dictation.lock`, the `hooks/*.sample` files, `extensions/omarchy-menu.jsonc`,
> `themes/` and `plugins/superwhisper-panel/` are **never copied**: generated,
> stock, Aether-managed or package-symlinked (`/opt/superwhisper/`).

## Server (headless Linux)

`server/balneario-pro/` is not a placeholder: it is the live Debian home server
(`balneario-pro`, reached over Tailscale). Its versioned artifacts are systemd
**user** units — no desktop, so nothing of the Windows or Hyprland stack applies
here. `bbctl` itself is not versioned: it is a release binary with a pinned
version and a verified checksum, installed by hand once (see that folder's
README).

| Repo file | Destination (balneario-pro) |
|---|---|
| `server/balneario-pro/systemd/user/bbctl@.service` | `~/.config/systemd/user/bbctl@.service` |

## Revert

Delete the destination files listed above. Nothing here changes what was on the
machine before.

## Notes for agents

- Destinations are exact; do not invent paths. `%USERPROFILE%` = the home dir.
- On Windows, Neovim reads `%LOCALAPPDATA%\nvim`, NOT `~/.config/nvim`; the
  manifest maps `shared/nvim/` there.
- The `windows/` mappings apply ONLY on Windows; `linux/` on Linux. `shared/` on both.
- `shared/nvim/` is a recursive copy; every other entry is a single file.
- `windows/nushell/setup-autoloads.nu` regenerates tool-generated files; it is
  run, not copied.
- After a config change in the repo, re-copy only the affected file.
- `odd/` is ODD work records (process history): never deployed, and never a source
  of truth — if a record disagrees with a config or with `README.md`, the config
  or `README.md` wins. The three documents the install path depends on are
  `MANIFEST.md` (where files go), `README.md` (what they do) and `AGENTS.md`.
- `windows/komorebi/spy-dialog.ps1`, `windows/komorebi/snapshot-wm.ps1` and
  `windows/komorebi/tests/` are **repo-only** tools (window-class spy, layout
  measuring, Pester tests for the deployed helpers and the drift gate that keeps the
  two komorebi variants' shared keys identical); they are never copied. The
  `windows/komorebi/` rows in the table above are the only komorebi files that get
  deployed.
- `windows/komorebi/komorebi.home.json` and `windows/komorebi/komorebi.work.json` are
  komorebi's **configuration** variants — one per machine, selected by the note under
  the table — and are applied by komorebi itself (`komorebi.exe --config`);
  `komorebi-autostart.ps1` is only the logon supervisor and does not re-apply them.
- `windows/win-terminal/settings.json` is a full snapshot that carries
  per-machine dynamic profiles (WSL distro names, Visual Studio versions) and a
  machine-local `defaultProfile` GUID. On a different machine, **merge** it —
  add the Nushell profile and point `defaultProfile` at it — instead of copying
  it wholesale, or stale profiles come back. See README → Gotchas.
- `windows/powershell/user_profile.ps1` is dot-sourced by
  `Microsoft.PowerShell_profile.ps1`. Its destination directory
  (`%USERPROFILE%\.config\powershell\`) is not created by anything else, so
  create it first if the copy fails.
- `server/balneario-pro/systemd/user/bbctl@.service` is a **user** unit
  (`systemctl --user`), not a system one: it runs as `verdu`, needs
  `loginctl enable-linger` to start at boot, and after copying requires
  `systemctl --user daemon-reload` before `enable --now bbctl@<bridge>`. It is
  templated on purpose — one instance per bridge, never one file per bridge.
  `~/.local/share/bbctl/` (live session credentials) and
  `~/.config/bbctl/config.json` (access token) are never versioned.