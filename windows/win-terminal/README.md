# Windows Terminal

`settings.json` is the live Windows Terminal configuration (profiles, key
bindings — pane split on `Alt+Shift+D` — and fonts).

Notes:
- `Super+Enter` opening a terminal is **not** a Windows Terminal binding: it is
  the AHK hotkey in `windows/komorebi/komorebi.ahk`. Windows Terminal's own
  bindings are the `actions`/`keybindings` in this file.
- Profiles reference locally-installed fonts (e.g. `JetBrainsMono NF`) — make
  sure the Nerd Font package (DEVCOM.JetBrainsMonoNerdFont) is installed first.
- Per-machine bits (window layout, launch size, default profiles) may need a
  trim when porting; the terminal-specific essentials are the colour scheme,
  font, and `actions` (split/find/paste).

Location on a fresh machine (the file that matters):
`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`