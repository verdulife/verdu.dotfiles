# Word and Excel frames are never tiled by komorebi

Status: done — applied and verified live on 2026-10-14 (one leftover below)
Repo: `C:\Users\verdu\verdu.dotfiles`, branch `main` (personal repo — commits land on `main` directly, no feature branches)
Date: 2026-10-14
Related: `odd/tasks/corel-window-not-managed.md` (the *other* komorebi lever: a frame that arrives with a `Show` but has no `WS_CAPTION`), `odd/tasks/komorebi-static-config-hybrid.md` (why the rules live in `komorebi.json`), `odd/tasks/nushell-native-line-editor.md` (the same session's other work unit)

## Request (verbatim)

> vamos a hacer otro fix luego lo commiteamos y hacemos push de todo junto. las apps
> de la suit de office como word, excel (ahora abiertos) no se integran con los tiles
> de komorebi, podemos revisarlo?

## Symptom

Word and Excel windows — documents open, several of them — did not appear in
`komorebic state` at all: not tiled, not floating, not minimised, simply absent.
`komorebic state` listed only WindowsTerminal, Ferdium/Zen and Illustrator.

## Diagnosis (measured, then proven in source)

**Not the CorelDRAW case.** The Office frames are eligible by komorebi's own gate:

| Window | class | `style` | `ex_style` | CAPTION | WEDGE | DLGMODALFRAME | LAYERED | cloaked |
|---|---|---|---|---|---|---|---|---|
| Word document frame | `OpusApp` | `0x16cf0000` (minimised: `0x36cf0000`) | `0x00000110` | yes | yes | no | no | 0 |
| Excel frame | `XLMAIN` | `0x16cf0000` | `0x00000110` | yes | yes | no | no | 0 |

Measured with a P/Invoke enumeration (`EnumWindows` + `GetWindowLongW(GWL_STYLE,
GWL_EXSTYLE)` + `DwmGetWindowAttribute(DWMWA_CLOAKED)`), script kept in `%TEMP%`,
out of the repo. So `window_is_eligible` passes and the problem is not the style.

**What is missing is the event.** For a cold start the log shows only
`event="TitleUpdate" winevent="ObjectNameChange"` for the real frame:

```
14:57:52Z TitleUpdate ObjectNameChange  hwnd=134396  "Abriendo - Word"   class: MsoSplash
14:58:04Z TitleUpdate ObjectNameChange  hwnd=135218  "Abriendo - Excel"  class: MsoSplash
14:58:04Z Show        ObjectShow        hwnd=135218  "Abriendo - Excel"  class: MsoSplash
14:58:05Z TitleUpdate ObjectNameChange  hwnd=265874  "Excel"             class: XLMAIN
```

The only `Show`/`ObjectShow` in an Office launch belongs to the `MsoSplash` window.
Office creates the real frame already visible, so Windows never reports
`EVENT_OBJECT_SHOW` for it — komorebi's `should_manage` is never called and the
window is dropped before anything is logged. `komorebic state` at 15:33Z had no
Office window; `komorebic manage` would not have helped either.

**Why the window *sometimes* tiled.** Restoring a minimised frame does emit
`Show/SystemMinimizeEnd`, and komorebi manages the window then (spans
`focus_window{idx=0}` / `focus_container{idx=1}` for `hwnd=200076` at 15:41:19Z).
Minimised windows are not in the state, which is why the user's open documents
looked "not integrated" while they sat in the taskbar. The inconsistency was the
tell: same window, tiled or not depending on how it got there.

**The lever, from v0.1.41 source** (`komorebi/src/window_manager_event.rs`):

```rust
WinEvent::ObjectNameChange => {
    let mut should_trigger_show = should_act(title, exe_name, class, path,
        &OBJECT_NAME_CHANGE_ON_LAUNCH, &regex_identifiers).is_some();
    ...
    if should_trigger_show && !window.is_miminized() {
        Option::from(Self::Show(winevent, window))   // -> should_manage runs
    } else {
        Option::from(Self::TitleUpdate(winevent, window))
    }
}
```

`object_name_change_applications` in `komorebi.json` populates
`OBJECT_NAME_CHANGE_ON_LAUNCH` (upstream ships `firefox.exe`, `idea64.exe`; the repo
already used it for `zen.exe`), and `should_act` matches on **any** identifier kind,
so a class rule works.

`manage_rules` is the wrong lever here: `managed_override` is consulted *inside*
`window_is_eligible`, i.e. only once a `Show` has already arrived. No `Show` → the
gate is never reached → a manage rule would change nothing. That is exactly the
opposite of CorelDRAW, where the `Show` arrives and `WS_CAPTION` is missing.

## Fix

`object_name_change_applications` gains two class rules (kept in `komorebi.json`,
the single source of truth):

```json
{ "kind": "Class", "id": "OpusApp", "matching_strategy": "Equals" },
{ "kind": "Class", "id": "XLMAIN",  "matching_strategy": "Equals" }
```

**By class, never by exe.** `WINWORD.EXE` also owns `MsoSplash`, `_WwB`, `_WwO`,
`OleDdeWndClass`, `MsoStdCompMgr`, `AcroStubUnloadWClass`,
`OfficePowerManagerWindow`, `HardwareMonitorWindowClass`, `MSCTFIME UI`, `IME` and
`ARC Event Window 00`; `EXCEL.EXE` owns `ComboLBox` and its own helpers. An exe-wide
rule would feed all of them to the gate.

Files: `windows/komorebi/komorebi.json` (rules) and `windows/komorebi/README.md`
(the shipped-values list, the file summary and a new gotcha).

## Applied and verified live

- `komorebic check` clean on both the deployed and the repo copy (the repo copy was
  checked with `KOMOREBI_CONFIG_HOME` pointed at a `%TEMP%` mirror, to validate it
  without touching the deployed file).
- `komorebic replace-configuration "$HOME\komorebi.json"` → rc 0 on the running
  instance; no logon needed.
- **Proof**: a throwaway `%TEMP%\office-tile-probe.rtf` opened with Word created a new
  `OpusApp` frame (`hwnd=2950992`, `0x2d0750`). The log shows the new path:
  `event="Show" winevent="ObjectNameChange" hwnd=2950992` at 16:02:13Z with
  `focus_container{idx=1}`, and `komorebic state` lists it tiled at 840×999:
  `2950992 WINWORD.EXE OpusApp | office-tile-probe.rtf - Modo de compatibilidad - Word`.
  Before the change that same `ObjectNameChange` stayed a `TitleUpdate`.
- Cleanup: the probe window and its `.rtf` are gone; the user's documents were
  untouched (no document was opened, closed, saved or focused by this work).

## Leftover (not fixed, needs the user's confirmation)

- **A frame showing Office's start screen (no document) still receives no event at
  all.** Observed at ~16:03Z: a Word frame (`hwnd=199890`, title `Word`) and an Excel
  frame (`hwnd=723580`) exist, are visible and eligible, and have **zero** log lines;
  neither is managed. Hypothesis, not proven: Office creates those frames cloaked or
  minimised and never re-titles them, so neither the `ObjectNameChange` conversion
  (blocked by `!is_miminized()`) nor the `Show` path fires. A document window is the
  real workflow and that case is proven above; the user should confirm in their own
  flow that opening a document tiles it.

## Pre-existing drift this work uncovered (needs a decision)

`windows/komorebi/komorebi.json` in the repo and `%USERPROFILE%\komorebi.json` on
**this** machine are not the same file, and the difference is the monitors:

| | repo file | this machine's deployed file |
|---|---|---|
| `display_index_preferences` | `{ "0": "CNK51707R2", "1": "CNK6180S06" }` | `{ "0": "CZK83705DT" }` |
| monitor blocks | 2 (workspaces `I`–`V` and `1`–`5`) | 1 (workspaces `I`–`V`) |
| origin | committed in `4d72837` (the home machine's dual-monitor fix) | machine-adapted, mtime 2026-10-13 10:17, no ODD record |

This machine's live monitor is `device HWP26FC`, `device_id
HWP26FC-5&19f65d6f&0&UID781`, **`serial_number_id CZK83705DT`** (Radeon RX 580,
single monitor) — i.e. the *deployed* file matches the hardware here and the repo
file matches the other machine. A literal "copy per `MANIFEST.md`" would therefore
overwrite this machine's monitor mapping with the other machine's.

Consequence for this work unit: the two Office rules were written into **both**
files; nothing else in the deployed file was touched. Reconciling the drift (two
per-machine configs, or a documented local override) is a separate decision and was
deliberately not taken here.

## Method notes worth keeping

- **`komorebi.log.<date>` is UTC and lags ~40 s behind real time.** A "no events for
  this hwnd" conclusion must be re-read a minute later, or it will be wrong.
- **HWNDs are recycled.** Correlating a log line to a window by hwnd alone produced a
  wrong early conclusion here (`hwnd=200076` at 15:41Z was the same digits as an
  earlier, unrelated window). Bound every hwnd query by time.
- The komorebi log embeds ANSI escapes inside fields
  (`hwnd<ESC>[0m<ESC>[2m=<ESC>[0m200076`): strip `\x1b\[[0-9;]*m` before grepping, or
  every `hwnd=` search silently returns nothing.
- `nu -i -c '…'`-style shortcuts do not apply here, but the analogous trap exists in
  komorebi: `komorebic check` validates only `$HOME\komorebi.json`; point
  `KOMOREBI_CONFIG_HOME` at a mirror to validate a different copy.
