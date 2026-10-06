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

```bash
git clone <this-repo> ~/verdu.dotfiles
ln -sf ~/verdu.dotfiles/shared/starship.toml ~/.config/starship.toml
rsync -a ~/verdu.dotfiles/shared/nvim/ ~/.config/nvim/
ln -sf ~/verdu.dotfiles/linux/hyprland/hyprland.conf ~/.config/hypr/hyprland.conf
ln -sf ~/verdu.dotfiles/linux/waybar/* ~/.config/waybar/   # adjust after import
```

## Correspondence with the Windows stack

Super-key-driven tiling → komorebi (Windows). Bar with pill widgets → YASB.
`shared/starship.toml` and `shared/nvim/` are cross-OS. The mental model is the
same; only the tooling differs.