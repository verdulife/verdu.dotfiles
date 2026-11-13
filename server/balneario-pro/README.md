# balneario-pro (Debian server node)

The one **live** Linux node in this repo. Headless Debian 13 home server
(`balneario-pro`), reached over Tailscale: no desktop, no tiling WM, no Hyprland.
What is worth versioning here is the machinery that must survive a reboot —
systemd **user** units, one per long-running service.

## What ships

| File | Purpose |
| --- | --- |
| `systemd/user/bbctl@.service` | Templated user unit keeping one self-hosted Beeper bridge alive: `bbctl@telegram`, `bbctl@whatsapp`, … |

`bbctl` itself is **not** versioned: it is a single release binary, installed
with a pinned version and a verified checksum.

## Install

Copy, exactly as the rest of the repo does — `MANIFEST.md` holds the destinations:

```bash
mkdir -p ~/.config/systemd/user
cp ~/verdu.dotfiles/linux/balneario-pro/systemd/user/bbctl@.service ~/.config/systemd/user/
systemctl --user daemon-reload
```

## Prerequisites (once, manual — not part of the copy)

```bash
# 1. bbctl: upstream release binary, pinned and checksum-verified
curl -fsSL -O https://github.com/beeper/bridge-manager/releases/download/v0.15.0/bbctl-linux-amd64
curl -fsSL -O https://github.com/beeper/bridge-manager/releases/download/v0.15.0/sha256sums.txt
sha256sum -c <(grep bbctl-linux-amd64 sha256sums.txt)   # must print OK
install -m 0755 bbctl-linux-amd64 ~/.local/bin/bbctl

# 2. what the bridges need at runtime
sudo apt install ffmpeg python3 python3-venv

# 3. account login (interactive, once)
bbctl login
```

Never build from source here: it needs a Go toolchain this server does not carry.

## Run a bridge

```bash
systemctl --user enable --now bbctl@telegram
journalctl --user -u bbctl@telegram -f
```

Then log into the remote network by sending a DM to the bridge bot from any
Beeper client — `@sh-telegrambot:beeper.local` for Telegram. Until that DM is
answered the bridge reports state `UNCONFIGURED`, which is expected, not a fault.

## Why a unit and not tmux

`bbctl run sh-<bridge>` is a foreground process and upstream has no service mode
yet (its docs suggest `tmux`/`screen`). A user unit does the job better:

| | terminal | tmux | user unit |
| --- | --- | --- | --- |
| survives disconnect | no | yes | yes |
| starts at boot | no | no | yes (`Linger`) |
| restarts on crash or network loss | no | no | yes (`Restart=always`) |
| memory bound | no | no | yes (`MemoryMax`) |
| logs | screen | in-session | journal |

Details that are not decoration:

- `Type=simple` matches bbctl: it never forks, so `Type=forking` would report a
  failed start.
- `Environment=PATH` is explicit because user units do not inherit an
  interactive `PATH`, and the bridges spawn `python3`/`ffmpeg`. Without it the
  bridge starts and then fails on the first media message.
- `TimeoutStopSec=30` gives the bridge time to close cleanly; one killed
  mid-write can corrupt its session store (re-authenticating a network means a
  new QR scan).
- The memory caps are a starting point measured on a 3.7 GiB box, not a law.
  Read `systemctl --user show bbctl@<bridge> -p MemoryCurrent` after a day with
  traffic and adjust.
- `loginctl enable-linger` must stay enabled for the unit to start with no
  session open.

## Bridge settings are not overridable by default

`bbctl run` **regenerates `config.yaml` on every start** unless it is told not to.
The unit therefore runs `bbctl run --no-override-config sh-%i`; with that flag the
bridge logs `Config already exists, not overriding` and edits survive restarts
(verified).

That is how the Telegram sync limits are set — the defaults bridge only the 15
most recently active dialogs:

```yaml
tg:
    sync:
        update_limit: -1        # was 0
        create_limit: -1        # was 15
        login_sync_limit: -1    # was 15
    takeout:
        dialog_sync: true       # was false: full chat list via Telegram data export
```

Trade-off, accepted deliberately: a pinned config is not refreshed when the
bridge binary is updated. If a new bridge version needs new keys, delete
`config.yaml`, let `bbctl` regenerate it, and re-apply these four values.

## Never versioned

| Path | Why |
| --- | --- |
| `~/.local/share/bbctl/` | Live session credentials and bridge databases for every connected network |
| `~/.config/bbctl/config.json` | Account access token |

A copy of either is as sensitive as the logins themselves: back them up
encrypted, never into this repo.
