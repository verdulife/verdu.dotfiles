# Linux (Arch + Hyprland)

This side of the repo is ready but not yet populated: the configuration lives
on the Arch machine and will be imported here, then installed via the steps
below. Shared config (`../shared/`) applies to both OSes.

## Layout (target)

```
linux/
├── hyprland/    ← hyprland.conf, env, bindings (coming)
├── waybar/      ← waybar style.conf/config.jsonc (coming)
└── README.md
```

## Install (once populated)

The same contract as Windows: **copy files to their destinations, no symlinks**
(this repo ships no symlink manager and wants none — see `AGENTS.md`, Rules).
`MANIFEST.md`'s Linux table is the source of truth for the destinations; once the
Arch configs land, copy each row:

```bash
git clone <this-repo> ~/verdu.dotfiles
cp ~/verdu.dotfiles/shared/starship.toml ~/.config/starship.toml
cp -r ~/verdu.dotfiles/shared/nvim/. ~/.config/nvim/
mkdir -p ~/.config/hypr ~/.config/waybar
cp ~/verdu.dotfiles/linux/hyprland/* ~/.config/hypr/
cp ~/verdu.dotfiles/linux/waybar/* ~/.config/waybar/
```

## Correspondence with the Windows stack

Super-key-driven tiling → komorebi (Windows). Bar with pill widgets → YASB.
`shared/starship.toml` and `shared/nvim/` are cross-OS. The mental model is the
same; only the tooling differs.