# Nushell line editor: drop atuin and carapace, keep the PSReadLine-like flow

Status: done — applied and verified live on 2026-10-14
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `main` (personal repo — commits land on `main` directly, no feature branches)
Date: 2026-10-14
Related: `odd/tasks/apply-dotfiles.md` (the port that introduced the Nushell stack), `odd/tasks/apply-home-machine-yasb-update.md` (same machine, same pattern of applying a repo change live)

## Goal

Remove the two Nushell autoload integrations that changed the editing flow — atuin
(history) and carapace (external completions) — and leave the line editor in the
shape the user was fast and comfortable with in PowerShell.

## Request (verbatim)

> en la conf de verdu.dotfiles añadimos algunas apps/extensiones de terminal com
> atuin, zoxide entre otros. el problema es que el autocompletado y autosugestion
> que yo tenia me hacian ir mas rapido y esteticamente me gustaban mas, y con estas
> apps nuevas no me acostumbro, no se si porque estan mal acosumbradas o porque
> generan un flujo diferente. me puedes decir que app son y para que es cada cosa y
> te digo si las quitamos y volvemos a lo anteiror?

> la B y ademas añadir el autosugestion como teniamos en powershell

Option B was "stay in Nushell, remove atuin and carapace, keep starship and zoxide".

## Diagnosis

The installed stack was not misconfigured; it replaced two Nushell-native
mechanisms with its own:

| Piece | What it does | Effect on the flow |
|---|---|---|
| atuin | history search TUI: re-binds `Ctrl+R` and `Up` | replaces Nushell's history menu and history walk; `enter_accept = true` (the only uncommented line in `~/.config/atuin/config.toml`) runs the selected command on `Enter` instead of inserting it |
| carapace | external-command completer | replaces Nushell's own external completion on `Tab`, and prepends `%APPDATA%\carapace\bin` to `PATH` |
| zoxide | `z`/`zi` + a `cd` hook | additive only |
| starship | prompt | already present before Nushell |

The inline hint ("autosuggestion") was **never** missing: Reedline, Nushell's line
editor, draws the most recent matching history command in
`$env.config.color_config.hints` after the cursor by default (`show_hints = true`).

## Decision

Keep Nushell as the default Windows Terminal profile and restore its native editing
flow; do not revert the default profile to PowerShell.

- No atuin, no carapace: `Ctrl+R` opens Nushell's history menu, `Up`/`Down` walk the
  history, `Tab` opens Nushell's completion menu.
- The hint is made explicit in `config.nu` and coloured with PSReadLine's
  `InlinePrediction` value (`#444444`), so Nushell and the PowerShell profile suggest
  with the same dim grey. Accept the whole hint with `Right`/`End`, one word with
  `Ctrl+Right` — the same keys PSReadLine uses.
- starship and zoxide stay.
- atuin and carapace remain installed (nothing was uninstalled); they are no longer
  prerequisites of this repo and no longer generated as autoloads.

## Changes

Repo:

- `windows/nushell/config.nu` — explicit `show_hints` + `color_config.hints`, and a
  comment block stating which keys are native from now on.
- `windows/nushell/setup-autoloads.nu` — atuin and carapace generation removed;
  `Requirements on PATH` is now `nu, starship, zoxide`.
- `MANIFEST.md` — `Atuinsh.Atuin` and `rsteube.Carapace` dropped from the winget
  prerequisites; the autoload note now names atuin/carapace as deliberately absent.
- `README.md` — the `windows/nushell/` bullet now lists `(starship/zoxide)`.

Machine (per `MANIFEST.md`, the file→destination contract):

- Deleted `%APPDATA%\nushell\vendor\autoload\atuin.nu` and `carapace.nu`.
- Copied `windows/nushell/config.nu` → `%APPDATA%\nushell\config.nu`
  (the live file had no local drift before the copy).

## Verification

Config file, loaded explicitly (`nu --config ... --env-config ... -c`):

```
color=#444444 show_hints=true
nu_exit=0
```

Live REPL, driven through a real pty (`winpty -Xallow-non-tty -- nu`), **before**:

- `$env.Path | first` → `C:/Users/verdu/AppData/Roaming/carapace/bin` (carapace loaded)
- `$env.config.keybindings | length` → `10` (8 native + atuin's `Ctrl+R` and `Up`)
- `Ctrl+R` → atuin's TUI (command list with `2s 40s ago` timestamps)
- `openc` → hint `ode -c` (the hint worked with atuin installed)

**After**:

- `$env.Path | first` → `C:\Users\verdu\AppData\Local\fnm_multishells\...` (carapace gone)
- `$env.config.keybindings | length` → `8` (native only)
- `Ctrl+R` → Nushell's history menu (`? openc`, numbered records, `Page 1: records 0 - 9 total: 65`)
- `pi u` → hint `pdate --extensions`, rendered in the hint style
  (`ESC[0;37;90m` — the pty reports limited colour, so `#444444` is approximated to
  bright black; a truecolor terminal renders the exact value)
- `$env.config.color_config.hints` → `#444444` inside the REPL

Note: `nu -i -c '...'` does **not** load `config.nu` or `vendor/autoload` — it
reported the defaults (`dark_gray`, 8 bindings) and made a first "after" check look
wrong. Only a real interactive REPL (the pty probe) proves the deployed state.

## Left open

- `Atuinsh.Atuin` and `rsteube.Carapace` are still installed; the atuin history
  database in `%USERPROFILE%\.local\share\atuin` is untouched. Uninstalling is a
  separate decision.
- `~/.config/atuin/config.toml` (including `enter_accept = true`) stays on disk,
  inert while the autoload is absent. It becomes relevant again only if atuin comes
  back.
- The hint colour degrades to bright black in terminals that do not advertise
  truecolor; no further action unless the user reports it as too faint.
