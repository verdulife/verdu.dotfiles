# Keep YASB's komorebi workspaces widget alive across a logon

Status: DONE 2026-10-20 - module and supervisor guard implemented, Pester 13/13 green,
verified against the live `yasb.log`; runtime proof at the next logon.
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `main`
Date: 2026-10-20
Related: `odd/tasks/komorebi-autostart-resilience.md` (the supervisor this extends)
Commit: `44a61c8` (rebased onto f9f88b0) - module, tests, supervisor, README, MANIFEST and this record are one work unit

## Goal

A logon must not leave the YASB `komorebi_workspaces` widget dead while komorebi and the
bar itself are healthy, and a lost subscription must be visible in
`komorebi-autostart.log` instead of silent.

## Non-goals

- No patch to YASB or komorebi: both defects are in the vendor binaries (see Facts).
- No change to the start order (AHK/YASB before komorebi) - that ordering is deliberate.
- No periodic watchdog and no new deployment mechanism: the guard runs once at logon
  inside the existing supervisor, and the new module is deployed per MANIFEST like
  `container-dump.ps1`.

## Request (verbatim, 2026-10-20)

> llevo 2 inicios de sesion en este equipo que komorebi da algun tipo de error silencioso.
> lo unico que detecto es que en yasb no me carga el widget de los workspaces de komorebi
> y en 1 no cargo bien el gestor de ventanas. puedes revisar y me dices?

Follow-ups: "lo corregimos inmediato y te pregunto, no hay una forma nativa para corregir
esto sin tener que usar un ps1?" then "lo que consideres mas robusto".

## Facts (verified 2026-10-20)

| Fact | Evidence |
|---|---|
| Exactly two logins left the widget dead | `yasb.log`: `Created named pipe yasb-...` with no later `Komorebi connected to named pipe` on 2026-10-18 10:09 and 2026-10-20 21:20. Every other login (2026-10-18 12:17, 2026-10-19 21:11) logged the connection. |
| 2026-10-20 cause: komorebi dropped the message | `komorebi.log.2026-10-20`: `19:20:46.132Z WARN komorebi::process_command: could not acquire window manager lock, not processing message: AddSubscriberPipe`, which is 21:20:46 local, 2.5 s after YASB created its pipe (komorebi logs in UTC, local = UTC+2). |
| 2026-10-18 cause: the socket was not up yet | `komorebi.log.2026-10-18`: the first instance logged `creating window manager` at 08:09:21Z and never reached `listening on komorebi.sock`; the second listened at 08:10:01Z. YASB subscribed at 08:09:35Z. `komorebi-autostart.log`: `10:09:43 [warn] komorebi start attempt 1/9 failed (still running but not answering)`. |
| The CLI cannot report the failure | YASB 2.0.7 `core/widgets/services/komorebi/client.py`: `wait_until_subscribed_to_pipe` runs `komorebic subscribe <pipe>` and inspects only stderr and returncode. `event_listener.py` then calls `win32pipe.ConnectNamedPipe(self.pipe, None)` with no timeout and retries only while `returncode != 0`. |
| Nothing is logged at the default level | The only trace is `logging.debug("Waiting for Komorebi to subscribe ...")`, and `config.yaml` sets neither `debug` nor a `komorebi:` block. `hide_if_offline: true` then draws nothing at all. |
| komorebi did not crash | No `Application` event and no `CrashDumps` entry for komorebi in 7 days. `komorebic state` on 2026-10-20: 2 monitors x 5 workspaces, `resize_delta 25`, `mouse_follows_focus false`. |
| The repair is natively available and non-disruptive | `komorebic subscribe <pipe>` (documented as `subscribe-pipe`; `subscribe` is the alias YASB itself uses) returned 0 and revived the pending pipe: `Komorebi connected to named pipe: yasb-582ef7b5-...` at 21:55:49, widget back with no bar restart. |
| No native prevention exists | `komorebic --help` offers only `subscribe-pipe`, `subscribe-socket` and `unsubscribe-*`. The YASB widget schema (`core/validation/widgets/komorebi/workspaces.py`) has no retry or timeout key. `yasbc` offers only `reload`/`stop`/`start`, and a reload restarts the whole bar and can abort on the single-instance guard. |
| The old comment asserted the opposite | `komorebi-autostart.ps1` claimed YASB "reconnects by itself when komorebi appears". That belief is what left two logins broken; it is corrected in this change. |

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | `windows/komorebi/yasb-subscription.ps1`: `Get-YasbPipeSubscription` (pure log read) and `Repair-YasbKomorebiSubscription` (verdict ok/repaired/offline/unknown) | done - Pester 13/13 |
| 2 | `windows/komorebi/tests/yasb-subscription.Tests.ps1`: fixtures built from the two real failing logs; `komorebic` stubbed with a `.cmd` so both the exact command line and the "a healthy session runs nothing" property are pinned | done - RED 0/13 observed first, then GREEN 13/13 |
| 3 | Wire the guard into `komorebi-autostart.ps1` after `[ok] komorebi ready`, guarded dot-source included | done |
| 4 | Correct the obsolete "YASB reconnects by itself" comment with the evidence | done |
| 5 | README Files and Gotchas, MANIFEST row, this record | done |
| 6 | Deploy both files and confirm identity with the repo copy | done |

## Design notes

- **The verdict lives in the module, the log line in the supervisor.** Same contract as
  `Remove-UnsafeContainerDump`: the helper stays silent and returns a record, so it is
  testable and the logon log keeps one voice.
- **The log is the evidence, never the exit code.** Both failure modes exit 0.
- **The newest `Created named pipe` wins and a `YASB v` banner resets the search window**,
  so a previous session's pipe can never be read as the live one.
- **A missing pipe is `unknown`, not a failure**: YASB's listener comes up ~10-15 s after
  the process starts and the supervisor asks as soon as komorebi is ready.
- **One retry, then `[FAIL]` naming the manual command**: a second attempt covers the same
  lock-contention window; a third adds nothing.

## Verification

- `Invoke-Pester windows/komorebi/tests/yasb-subscription.Tests.ps1` -> `Passed: 13
  Failed: 0` (Pester 3.4.0). RED was observed first with the module absent: `Passed: 0
  Failed: 13`.
- `[System.Management.Automation.Language.Parser]::ParseFile` on both scripts: parse OK.
- Live integration against the real `yasb.log` after the manual repair: `Action=ok`,
  `Attempts=0`, i.e. a healthy session is left untouched and `komorebic` is not invoked.
- Not verifiable in this session: the `repaired` and `offline` branches against a real
  logon (they need a komorebi that drops the message). They are pinned by the stubbed
  tests, and the next logon writes the verdict line to `komorebi-autostart.log`.

## Rollback

Delete `%USERPROFILE%\komorebi-yasb-subscription.ps1`; the guarded dot-source skips the
whole guard and logs nothing about it, restoring the previous behaviour. Nothing is
written to disk by the guard itself, so there is nothing else to undo.
