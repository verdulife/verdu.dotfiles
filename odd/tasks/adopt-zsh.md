# Adopt zsh on the Omarchy machine

Status: blocked — config committed and copied; the install and `chsh` need the
user's own terminal (`sudo` is refused in the agent sandbox: "no new privileges
flag is set")
Repo: `~/Projects/verdu.dotfiles`, branch `main`
Date: 2026-11-12

## Goal

Make zsh the login shell on the Omarchy machine, with Starship's
`pastel-powerline` preset and zsh-autosuggestions, carrying over every PATH and
environment decision that currently lives in bash.

## Non-goals

- No change to the Windows side: `shared/starship.toml` keeps its
  catppuccin-powerline prompt and is untouched.
- No port of Omarchy's whole bash rc chain (`default/bash/{envs,shell,functions}`);
  it is bash-only and would break under zsh.
- No package install, no `chsh` from this session — handed to the user.
- No push: stays the user's decision.

## Environment facts (verified)

| Item | State |
|---|---|
| Current shell | `/usr/bin/bash` (`getent passwd verdu`) |
| `zsh` | **not installed**; no `~/.zshrc` before this work |
| `sudo` in this session | refused: `The "no new privileges" flag is set` |
| `/etc/zprofile`, `/etc/zsh/` | do not exist → `/etc/profile.d/omarchy.sh` never reaches zsh |
| Omarchy zsh support | none: `/usr/share/omarchy/default/zsh` absent; only `default/bash/*` |
| `env-bootstrap` | POSIX sh, sets `OMARCHY_PATH`, mise command-wrappers, mise shims, `~/.local/bin` |
| `default/bash/init` | `mise activate bash`, `starship init bash`, `zoxide init bash`, fzf key-bindings |
| `~/.bashrc` extras | `brew shellenv bash` (Linuxbrew at `/home/linuxbrew/.linuxbrew`) |
| starship binary | `/usr/bin/starship` (packaged); `pastel-powerline` exists in `starship preset --list` |
| `~/.config/starship.toml` before | stock Omarchy file, text-identical to the packaged default |

## Specs

- **S1** — zsh is the interactive and login shell for the user.
- **S2** — Starship uses the `pastel-powerline` preset on Linux.
- **S3** — zsh-autosuggestions is active, accepting with the right arrow.
- **S4** — Every PATH/environment decision that bash had keeps working: `OMARCHY_PATH`,
  mise activation (command-wrappers + shims), `~/.local/bin`, Linuxbrew, zoxide, fzf keys.
- **S5** — The repo stays the source of truth: `linux/zsh/zshrc` → `~/.zshrc` and
  `linux/starship.toml` → `~/.config/starship.toml`, both with manifest rows.
- **S6** — Windows is not touched.

## Decisions

1. **Linux and Windows now use different Starship configs.** The preset replaces
   the prompt, so keeping the manifest row pointing at `shared/starship.toml`
   would make the contract false. Instead `linux/starship.toml` is the Linux
   destination and `shared/starship.toml` stays the Windows one. Unifying them
   is a later, explicit decision.
2. **Do not source Omarchy's bash rc chain from zsh.** Only `env-bootstrap` is
   sourced (it is POSIX). mise/starship/zoxide/fzf get their zsh-native `init`
   commands, and the handful of Omarchy aliases are spelled out in the zshrc.
3. **Package set** handed to the user: `zsh`, `zsh-autosuggestions`,
   `zsh-completions`, `zsh-syntax-highlighting` (highlighting is optional but
   already wired with a `-r` guard).

## Tasks

| ID | Spec | What | Commit |
|---|---|---|---|
| T1 | S5 | `linux/zsh/zshrc` written and copied to `~/.zshrc` | `pending` |
| T2 | S2, S5 | `starship preset pastel-powerline` → `linux/starship.toml` → `~/.config/starship.toml` | `pending` |
| T3 | S5 | MANIFEST rows + `linux/README.md` shell section | `pending` |
| T4 | S1, S3, S4 | Install packages and `chsh` — **user only** | `pending` |
| T5 | S1-S4 | Verify: `zsh -n ~/.zshrc`, new login shell, PATH parity, autosuggestion visible | `pending` |

## Log

- **L1** (user): «primero quiero instalar zsh y que esta sea mi shell por defecto,
  ademas quiero que tenga starship con pastel powerline preset y el
  autosuggestion. revisa si hay cosas de path o similares que esten en bash ya
  que quiero que todo funcione ok en zsh»
- **L2** (evidence): `~/.bashrc` is three lines of substance — Omarchy
  `env-bootstrap`, the Omarchy bash rc chain, and `brew shellenv bash`. Nothing
  else of the user's lives there.
- **L3** (evidence): no `/etc/zprofile` and no `/etc/zsh`, so zsh will not pick up
  `/etc/profile.d/omarchy.sh`; the zshrc sources `env-bootstrap` itself.
- **L4** (blocker): `sudo` refuses to run here ("no new privileges" flag), so the
  install and `chsh` are handed to the user's terminal.
