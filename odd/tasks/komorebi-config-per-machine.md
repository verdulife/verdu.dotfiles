# `komorebi.json` is one file per machine

Status: superseded on 2026-10-22 — both machines now have a tracked file; see
"Superseded 2026-10-22" at the end of this record. (Originally: decided and documented
on 2026-10-14.)
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `main` (personal repo — commits land on `main` directly, no feature branches)
Date: 2026-10-14
Related: `odd/tasks/office-window-not-managed.md` (the work unit that uncovered the drift), `odd/tasks/komorebi-static-config-hybrid.md` (why the rules live in `komorebi.json` at all), `odd/tasks/apply-home-machine-yasb-update.md` and `odd/tasks/port-work-machine-corrections-to-home.md` (the two directions of cross-machine porting)

## Question

The Office work found that the tracked `windows/komorebi/komorebi.json` and this
machine's deployed `%USERPROFILE%\komorebi.json` are not the same file, and that the
difference is the monitors — the one part of the file that cannot be shared between
two machines. The repo's contract (`MANIFEST.md`: "copy the source to the destination,
never more, never less") implicitly assumes they are identical. Decision needed:
reconcile, split, or document.

## Decision (the owner's answer, verbatim)

> A. Dejarlo como está y documentarlo

The tracked file stays the **home** machine's configuration. This **work** machine
keeps its own deployed file. The distinction is documented in
`windows/komorebi/README.md` (new subsection "One file per machine — read this before
copying") so that a future session does not "fix" the difference by copying.

## Evidence (measured 2026-10-14)

| | tracked file (repo) | deployed file (this machine) |
|---|---|---|
| `display_index_preferences` | `{ "0": "CNK51707R2", "1": "CNK6180S06" }` | `{ "0": "CZK83705DT" }` |
| monitor blocks | 2 (workspaces `I`–`V` and `1`–`5`) | 1 (workspaces `I`–`V`) |
| mtime | committed 2026-10-11 in `4d72837` ("the dual-monitor fix") | 2026-10-13 10:17, no ODD record |
| matches which hardware | the two-monitor machine | the live monitor here |

This machine's live monitor, from `komorebic state`:

```
device=HWP26FC  device_id=HWP26FC-5&19f65d6f&0&UID781  serial_number_id=CZK83705DT
GPU: Radeon RX 580 Series   monitors: 1   autostart log: "config applied: … monitors=1"
```

So the deployed file is the one that agrees with the hardware here, and the tracked
file is not a stale copy of it: they describe two different machines.

## Rule this establishes

- **Shared keys** — `ignore_rules`, `manage_rules`, `object_name_change_applications`,
  paddings, borders, colours, `resize_delta`, `border_style` — belong in **both**
  copies. Changing one without the other is the defect.
- **`display_index_preferences` and the `monitors` blocks** follow the destination's
  hardware and are edited by hand on each machine. A verbatim copy of the tracked file
  onto the other machine would rewrite its monitor mapping (it would not crash — the
  unknown serial simply never matches — but the local mapping would be lost silently).
- `komorebic check` validates only `$HOME\komorebi.json`. To validate another copy,
  point `KOMOREBI_CONFIG_HOME` at a directory holding it (used here to check the
  tracked file without touching the deployed one).

## Left open

- ~~The repo still cannot be deployed verbatim onto a machine whose monitors differ from
  the tracked file's.~~ **Resolved 2026-10-22**: each machine has its own tracked
  variant, so the copy is verbatim again. Still open, in the same direction: a **third**
  machine, or a second panel at work, adds a third variant plus its own `MANIFEST.md`
  row — it must not be folded into either existing variant.
- ~~The deployed file on this machine has no git history of its own; its provenance is
  the note above plus the README subsection.~~ **Resolved 2026-10-22**:
  `windows/komorebi/komorebi.work.json` is the tracked source of the deployed file, so
  local edits have history and the drift gate now.

## Superseded 2026-10-22: both machines get a tracked file

Status: supersedes the 2026-10-14 decision above (measured 2026-10-22)
Date: 2026-10-22
Related: `windows/komorebi/tests/config-variants.Tests.ps1`, `MANIFEST.md` and
`windows/komorebi/README.md` (the artifacts this decision adds or rewrites)

Owner's answer, verbatim:

> creamos 2 y dejamos anotado para que el agente sepa cual aplicar, pero si necesito que ambas esten actualizadas

Why the earlier answer stopped holding: keeping one tracked file and documenting the
drift meant every work-machine rule (Office, VectorCraft) had to be ported into the home
variant by hand, and nothing proved the two matched. "Dejarlo como está y documentarlo"
documented the difference; it did not keep both files current, which is now a
requirement.

### Mechanism chosen

Two tracked variants plus a repo-only drift gate, still copy-only:

| repo file | destination | machine |
|---|---|---|
| `windows/komorebi/komorebi.home.json` | `%USERPROFILE%\komorebi.json` | two-monitor home |
| `windows/komorebi/komorebi.work.json` | `%USERPROFILE%\komorebi.json` | single-monitor work |

- `git mv windows/komorebi/komorebi.json windows/komorebi/komorebi.home.json` keeps the
  history of the home variant, whose content did not change. `komorebi.work.json` is a
  byte-faithful copy of the deployed `C:\Users\verdu\komorebi.json` (LF, no trailing
  newline); the repo has no `.gitattributes`, so it is committed as that machine is
  actually configured rather than reformatted.
- `windows/komorebi/tests/config-variants.Tests.ps1` is the gate: both files parse, the
  top-level key sets are equal, every key except `display_index_preferences` and
  `monitors` is deep-equal as **data** (`ConvertTo-Json -Depth 20 -Compress`), both
  per-machine keys are present, and those two differ. It names the offending key on
  failure: injecting `resize_delta: 30` failed `keeps shared key 'resize_delta'
  identical in both variants` (expected 30, was 25), and renaming `Window Class` inside
  the composite VectorCraft rule failed on `manage_rules`, which proves the nested rule
  list is compared as data and not as text.
- Copy-only survives: `AGENTS.md` says install = copy, no installers, no symlinks. A
  merge script, a generator or placeholders in the JSON were therefore rejected — each
  adds a build step to a repo whose install path is "copy the file in `MANIFEST.md`".
  The selection rule lives in `MANIFEST.md` and in `windows/komorebi/README.md`
  ("Two variants, one per machine").

### Evidence (measured 2026-10-22)

`diff -u --strip-trailing-cr windows/komorebi/komorebi.json "C:\Users\verdu\komorebi.json"`
differed in exactly three places:

1. `display_index_preferences` — `{ "0": "CNK51707R2", "1": "CNK6180S06" }` vs `{ "0": "CZK83705DT" }`;
2. the second `monitors` block (workspaces `1`–`5`), absent from the work file;
3. a trailing newline — the repo file ends with a newline, the deployed file does not.

Every other key was identical, including `ignore_rules`, `manage_rules` (with the
composite `class "Window Class"` + `exe vectorcraft.exe` rule added in `708d315`), the
`object_name_change_applications`, `border*`, `resize_delta`, `mouse_follows_focus` and
`$schema`. That shared remainder is what a drift gate can compare.

Contrary to the note in "Rule this establishes" above, `komorebic check -k
<path>` validates an arbitrary file (`-k`/`--komorebi-config`), so both variants were
checked in place on 2026-10-22 (`exit 0` each) without touching the deployed file;
`KOMOREBI_CONFIG_HOME` is not needed for a single file. `Invoke-Pester
windows/komorebi/tests` is green under Windows PowerShell with a per-process
`-ExecutionPolicy Bypass` (the machine policy is Restricted).
