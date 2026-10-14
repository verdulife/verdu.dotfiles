# `komorebi.json` is one file per machine

Status: decided and documented on 2026-10-14
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

- The repo still cannot be deployed verbatim onto a machine whose monitors differ from
  the tracked file's. If a **third** machine appears, or if the tracked file's owner
  changes, this decision needs revisiting — the natural next step would be per-machine
  files plus a `MANIFEST.md` row each.
- The deployed file on this machine has no git history of its own; its provenance is
  the note above plus the README subsection. Any future local edit should say so here
  rather than only in the file.
