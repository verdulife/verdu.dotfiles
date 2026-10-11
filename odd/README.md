# ODD work records

Process history, **not** documentation of how the repo works today.

Each file in `tasks/` is one unit of work recorded while it happened: the goal,
the decision and why it was taken, what was actually verified, and what was left
open. They exist so a later session can answer "why is this like this?" without
re-deriving it from `git log` — which matters most for the configs whose current
shape looks arbitrary until you know which failure they came from.

## Rules

- **Never deployed.** `MANIFEST.md` does not copy `odd/`, and nothing reads it at
  runtime. It is not part of the copy contract.
- **A log, not a source of truth.** If a record disagrees with the config or with
  `README.md`, the config wins and the record is the thing to fix. A record
  describes the world as of its own date, and the world moves.
- **Append, do not rewrite.** Superseding something is a new record that says so;
  the old reasoning is the useful part.
- One file per unit of work, named after the feature (`komorebi-static-config-hybrid.md`).

## Finding things

- By topic: `grep -rl "masir" odd/tasks/`
- By date and order: `git log --oneline -- odd/tasks/`
- By what changed: `git log --follow odd/tasks/<feature>.md`

## Related

`README.md` and `AGENTS.md` are authoritative for how the repo works;
`MANIFEST.md` is authoritative for where files go. Those three are the only
documents the install path depends on.
