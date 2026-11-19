-- Personal keybinding overrides for Omarchy (Hyprland Lua config).
--
-- Defaults load first (`require("default.hypr.omarchy")` in hyprland.lua) and
-- this file last, so every `o.rebind` / `hl.unbind` below overrides a default.
--
-- Design rule: this file mirrors the Windows komorebi scheme
-- (windows/komorebi/komorebi.ahk) wherever Omarchy can express the same
-- action. Windows is the reference; nothing here asks Windows to change.
--
-- Caveat that shapes the style below: Hyprland's `hl.unbind()` drops every
-- binding on a chord, including personal ones, so a replacement always uses
-- `o.rebind()` (which unbinds then binds) and never `unbind` + `bind`.
--
-- See current bindings and descriptions: `omarchy menu keybindings --print`.

-- --- Launchers --------------------------------------------------------------

-- SUPER + RETURN opens the Herdr desktop app (the GPUI window), not the herdr
-- TUI in a terminal — `omarchy terminal-herdr` runs `omarchy-launch-terminal
-- herdr`, which is the terminal flavour and is NOT what this chord is for.
o.rebind("SUPER + RETURN", "Herdr app", { launch = "herdr-app" })

-- ...and the plain terminal moves to SUPER + CTRL + RETURN, the chord Herdr
-- used to hold, so one chord still opens a single shell. SUPER + ALT + RETURN
-- keeps the tmux workspace.
o.rebind("SUPER + CTRL + RETURN", "Terminal", o.launch_terminal())

-- Browsers: SUPER + B is the default browser (Zen), SUPER + SHIFT + B is the
-- second one (Brave Origin, /usr/bin/brave-origin). The default
-- SUPER + SHIFT + RETURN also opened the browser; it is dropped to keep one
-- chord per action.
--
-- `focus` is not a plain regex: `omarchy-launch-or-focus` wraps it as
-- `\b<pattern>\b` and tests it case-insensitively against the window `class`
-- and `title`, so anchors (`^...$`) can only match a class that is literally
-- equal to the pattern and silently turn focus back into a plain launch. These
-- apps report namespaced classes — `md.obsidian.Obsidian`,
-- `org.mozilla.Thunderbird` — so the bare word is what matches.
o.bind("SUPER + B", "Browser", { omarchy = "browser" })
o.rebind("SUPER + SHIFT + B", "Browser 2", { launch = "brave-origin", focus = "brave-origin" })
hl.unbind("SUPER + SHIFT + RETURN")

-- Ferdium on SUPER + F (Windows: Win + F). This frees SUPER + SHIFT + F for
-- real fullscreen, which is what Windows binds there; the default file manager
-- on that chord moves to SUPER + E, mirroring the native Win + E the Windows
-- side keeps untouched.
o.rebind("SUPER + F", "Ferdium", { launch = "ferdium", focus = "ferdium" })
o.rebind("SUPER + SHIFT + F", "Fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
o.bind("SUPER + E", "File manager", { omarchy = "nautilus" })

-- Obsidian on SUPER + O (Windows: Win + O) and window pop on SUPER + SHIFT + O
-- (Windows: Win + Shift + O). The defaults had exactly these two swapped.
o.rebind("SUPER + O", "Obsidian", { launch = "obsidian", focus = "obsidian" })
o.rebind("SUPER + SHIFT + O", "Pop window out", "omarchy-hyprland-window-pop")

-- Mail: SUPER + M opens Thunderbird (Windows: Win + M). The default SUPER + M
-- no longer minimized anything here: `omarchy-hyprland-window-minimize` is a
-- silent no-op unless the workspace layout is "floating", which none is.
o.rebind("SUPER + M", "Thunderbird", { launch = "thunderbird", focus = "thunderbird" })

-- --- Resize with the arrows -------------------------------------------------

-- Hyprland ships no arrow-based resize, so SUPER + CTRL + arrows resizes the
-- focused window toward the arrow, using the same relative-delta model as
-- Omarchy's own SUPER + apostrophe / exclamdown bindings. The group-focus
-- bindings that occupied LEFT and RIGHT are replaced here; window groups stay
-- reachable through SUPER + ALT + TAB, SUPER + ALT + wheel and SUPER + ALT + 1..5.
o.rebind("SUPER + CTRL + LEFT", "Resize to the left", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
o.rebind("SUPER + CTRL + RIGHT", "Resize to the right", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
o.rebind("SUPER + CTRL + UP", "Resize up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
o.rebind("SUPER + CTRL + DOWN", "Resize down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))

-- --- Capture, colour and OCR ------------------------------------------------

-- This keyboard has no PRINT key, so every PRINT-based default is unreachable
-- and the SUPER + SHIFT namespace takes over: S = screenshot with the slurp
-- selector, C = colour picker, T = OCR text capture.
o.rebind("SUPER + SHIFT + S", "Screenshot (select region)", "omarchy-capture-screenshot region")
o.rebind("SUPER + SHIFT + C", "Color picker", "pkill hyprpicker || hyprpicker -a")
o.rebind("SUPER + SHIFT + T", "Capture text (OCR)", "omarchy-capture-text")
hl.unbind("PRINT")
hl.unbind("SUPER + PRINT")
hl.unbind("SUPER + CTRL + PRINT")
hl.unbind("SUPER + CTRL + ALT + C")

-- --- Activity monitor -------------------------------------------------------

-- btop moves from SUPER + SHIFT + T to SUPER + T. The default SUPER + T
-- (toggle window floating/tiling) is not used on this machine and is dropped
-- with it; SUPER + SHIFT + O still pops a window out of the layout.
o.rebind("SUPER + T", "Activity", { tui = "btop" })

-- --- Dead preinstalled bindings ---------------------------------------------

-- Every default `{ webapp = ... }` binding launches through
-- `omarchy-launch-webapp`, which forces Chromium; Chromium is not installed and
-- the default browser is Zen, so those chords are dead. The uninstalled native
-- apps are listed for the same reason. They are unbound one by one instead of
-- setting `omarchy_preinstalled_bindings = false`, because that flag would also
-- drop Herdr, Tmux, Obsidian, the calculator, Omawrite, cliamp and btop.
local dead_bindings = {
  "SUPER + SHIFT + A",        -- ChatGPT (webapp)
  "SUPER + SHIFT + ALT + A",  -- Grok (webapp)
  "SUPER + SHIFT + E",        -- Email / app.hey.com (webapp)
  "SUPER + SHIFT + ALT + E",  -- New email (webapp)
  "SUPER + SHIFT + Y",        -- YouTube (webapp)
  "SUPER + SHIFT + ALT + G",  -- WhatsApp (webapp)
  "SUPER + SHIFT + CTRL + G", -- Google Messages (webapp)
  "SUPER + SHIFT + P",        -- Google Photos (webapp)
  "SUPER + SHIFT + X",        -- X (webapp)
  "SUPER + SHIFT + ALT + X",  -- X post (webapp)
  "SUPER + SHIFT + M",        -- Spotify (not installed)
  "SUPER + SHIFT + SLASH",    -- 1Password (not installed)
  "SUPER + ALT + SHIFT + F",  -- File manager in cwd (not used)
}

for _, chord in ipairs(dead_bindings) do
  hl.unbind(chord)
end
