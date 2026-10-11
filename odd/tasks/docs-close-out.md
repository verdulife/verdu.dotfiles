# Documentation close-out: complete, ordered, and self-consistent

Status: DONE 2026-10-11
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `main`
Date: 2026-10-11
Related: `odd/tasks/komorebi-docs-truth-pass.md`

## Goal

Leave the documentation complete (covers every file), ordered (a reader knows
where to look), and self-consistent (no two documents disagree, and no document
contradicts the repo's own contract).

## Method

Two passes, because reading alone had already missed things twice:

1. **Mechanical**: cross-check the docs against the tracked file list (sources
   named in `MANIFEST.md` exist; every `.md` is reachable; the README tree matches
   the real tree; relative Markdown links resolve).
2. **Read**: every doc read end to end, and every factual claim spot-checked
   against the artifact it describes.

## Findings

Mechanically clean before and after: every source named in `MANIFEST.md` exists
(the two `linux/*/*` rows are explicitly "(once populated)"), no `.md` is
orphaned, and no relative link is broken. The defects were all semantic:

1. **`windows/yasb/README.md`: the widgets table was broken in two.** A section
   heading and three paragraphs sat between `audio_visualizer` and
   `grouper_sysinfo`, so the last eight rows formed a second, headerless table.
2. **`README.md`: the layout tree was incomplete and had one false comment.**
   `windows/nushell/`, `windows/herdr/`, `odd/`,
   `windows/komorebi/spy-dialog.ps1` and `windows/komorebi/tests/` were missing,
   and `shared/nvim/` was described as "vim-plug based" when it is LazyVim
   (`lazy.nvim`, `lazyvim.json`) — as the same README said 100 lines below.
3. **`AGENTS.md`: the fast path was incomplete.** "Where to edit what" omitted
   Windows Terminal, the PowerShell and Nushell profiles and Herdr; "What this
   repo is" omitted Nushell, Herdr and masir.
4. **Health checks omitted `masir`**, so they could not tell "FFM is dead" from
   "all good" — fixed in both `README.md` and `AGENTS.md`.
5. **`linux/README.md` contradicted the repo contract**: it installed with
   `ln -sf` and `rsync` while `README.md` states "no symlink managers: copy is
   the contract" and `AGENTS.md` states "no installers, no symlinks". The two
   placeholder READMEs repeated the symlink instruction.
6. **`windows/win-terminal/README.md` named the wrong key**: it called the pane
   split "the `Super+Enter`-bound split", but `Super+Enter` is the AHK hotkey
   that opens a terminal, and `settings.json` binds `splitPane` to `Alt+Shift+D`.
   Now also says explicitly that the Super hotkeys are `komorebi.ahk`'s, not
   Windows Terminal's.
7. **Nothing explained `odd/`.** Eleven task records sat at the repo root with no
   signpost.

## Plan (all done)

- [x] Fix the yasb widgets table.
- [x] Complete the README tree and health checks.
- [x] Complete `AGENTS.md`.
- [x] Re-align the three Linux docs with the copy contract.
- [x] Fix the Windows Terminal key.
- [x] Add `odd/README.md` and the `MANIFEST.md` note.
- [x] Work-unit commit on `main`.

## Result

The three documents the install path depends on (`MANIFEST.md`, `README.md`,
`AGENTS.md`) now agree with each other, with the tree on disk, and with the
configs; `odd/README.md` states the rules for the process records so they cannot
be mistaken for documentation.

Verified after the edits:

- No `ln -sf` or `rsync` instruction remains anywhere; every remaining
  "symlink"/"symlinks" mention is the contract rule or a note that it is not used.
- `Get-Process komorebi,masir,yasb,AutoHotkey64` in both health checks.
- Every relative Markdown link resolves; every source named in `MANIFEST.md`
  exists; the README tree lists `nushell/`, `herdr/`, `odd/`, `spy-dialog.ps1`
  and `tests/`.
- `windows/yasb/README.md` is a single 11-row table followed by the sections.
- `AGENTS.md` read end to end after its accumulated edits.

## Notes for a future pass

- The docs now describe behaviour, but nothing *tests* the docs: the mechanical
  checks above were ad-hoc shell, not a committed script. A small
  `odd/tools/check-docs.sh` (MANIFEST sources exist, links resolve, tree matches)
  would make this repeatable instead of re-derived each time.
- `linux/` is still a placeholder by design; when the Arch configs land, the
  MANIFEST Linux table grows and those two READMEs should stop saying
  "placeholder".
