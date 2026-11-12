# Review and self-host Beeper

Status: planned — review first, nothing installed, no server touched
Opened: 2026-11-12
Server candidate: `balneario-server` (Tailscale `100.103.67.114`, idle)
Repo: `~/Projects/verdu.dotfiles`, branch `main`

## Goal

Decide whether Beeper Self-Hosted replaces Ferdium as the single window for
WhatsApp + Telegram, and if it does, run it on our own server inside the
Tailscale tailnet.

## Non-goals

- **No public exposure.** Access stays inside the tailnet; no public DNS, no
  ports opened to the internet.
- No provisioning of a new server: `balneario-server` is the candidate.
- No message-history migration work in this task. If Beeper is adopted, moving
  WhatsApp/Telegram history is its own task.
- Not a decision to drop `telegram-desktop` — that stays a separate call.
- The hosted Beeper subscription is out of scope (see S3).

## Environment facts (verified on the desktop, 2026-11-12)

| Item | State |
|---|---|
| Docker | `docker 1:29.9.2` and `docker-compose 5.6.1` already installed here |
| Tailscale | running; `balneario-server` = `100.103.67.114` (idle), `balneario-pro` active |
| Obsidian | `obsidian 1.14.4`, vault at `~/Documents/Obsidian Vault` — the user reports sync already configured |
| Ferdium | **not installed** on Linux, so nothing has to be torn down to change course |
| `telegram-desktop` | available in `extra` (7.3.2) |
| AUR helper | `yay` present |

Unverified: everything about `balneario-server` itself (OS, Docker, free RAM,
disk, whether it is reachable on the tailnet right now).

## Specs

- **S1** — «ahora quiero que crees una tarea personal para revisar e instalar
  beeper ya que me ha parecido muy interesante. la opcion self hosted ya que
  tenemos nuestro server»
- **S2** — This is a personal, durable record: **review first, install second**.
  The review may legitimately conclude "not worth it".
- **S3** — Self-hosted only. Any conclusion that amounts to "subscribe to
  Beeper" is not answering this task.

## Open questions the review must answer

A "no" here does not cancel the task; it changes the route or ends it.

1. Does the current Beeper self-host distribution still ship a supported Docker
   Compose stack, and which image tags does it pin? Vendor docs, not blog posts.
2. **Does the Linux desktop client accept a self-hosted server address?** If only
   the mobile app can, the desktop half of this plan is impossible and the whole
   premise changes.
3. Can the server live on the tailnet alone — a MagicDNS name or a `100.x`
   address with no public CA — and does the client accept that certificate?
4. Sizing on `balneario-server`: WhatsApp and Telegram bridges are several Node
   processes each. What does the stack need above idle, in RAM and CPU?
5. After a reboot or a tailnet drop: do the bridge sessions survive, or is every
   service re-authenticated by QR?
6. What state must be backed up (postgres plus bridge sessions), and where does
   that backup go?

## Tasks

| ID | Spec | What | Output |
|---|---|---|---|
| T1 | S3 | Read the vendor self-host docs; record the exact supported topology | notes appended here |
| T2 | S1 | Verify desktop-client support for a self-hosted server | go / no-go |
| T3 | S3 | Inspect `balneario-server`: OS, Docker, ports, free RAM, disk | facts table here |
| T4 | S3 | Decide addressing and TLS: MagicDNS name vs `100.x` IP, cert approach | decision recorded |
| T5 | S3 | Write the compose file into the repo (candidate: `linux/beeper/`) with a manifest row — no secrets | files + row |
| T6 | S1 | Install, then first login of the WhatsApp and Telegram bridges | working bridges |
| T7 | S1 | Decide the client: Beeper desktop, Element, or mobile only | decision recorded |
| T8 | — | Only if adopted: record that Ferdium is retired from the plan | note |

## Log

- **L1** (user): «ok. acabo de configurar tailscale y obsidian y ya esta
  sincronizado. ahora quiero que crees una tarea personal para revisar e
  instalar beeper ya que me ha parecido muy interesante. la opcion self hosted
  ya que tenemos nuestro server»
- **L2** (evidence, desktop): Docker + docker-compose present; `balneario-server`
  exists in the tailnet; Ferdium not installed, so nothing is lost by waiting;
  Obsidian 1.14.4 with a vault at `~/Documents/Obsidian Vault`.
- **L3** (scope decision): Tailscale is the transport. A self-hosted messaging
  server holding live WhatsApp/Telegram sessions is exactly the kind of thing
  that must not be reachable from the internet — the tailnet is the reason this
  idea is reasonable at all.
- **L4** (risk note, to carry into T1): the stack will hold **live session
  credentials** for WhatsApp and Telegram. Backups (Q6) are as sensitive as the
  login itself; they must not land in the dotfiles repo.
