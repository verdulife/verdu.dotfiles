; komorebi.ahk — Hotkeys for the Komorebi window manager (AutoHotkey v2)
; SUPER (Win key) based scheme mirroring Hyprland.
;
; Windows shortcuts sacrificed BY DESIGN (user-approved):
;   Win+arrows          -> window snap
;   Win+Shift+arrows    -> move window between monitors
;   Win+Ctrl+arrows     -> switch virtual desktop
;   Win+1..8            -> launch taskbar apps
;   Win+Shift+1..8      -> launch new instance of taskbar app
;   Win+F               -> Feedback Hub
; (Alt+arrows in browsers/Explorer are RESTORED: no longer intercepted.)
;
; Adobe Illustrator (Illustrator.exe) is excluded via #HotIf:
; ALL of its shortcuts keep working unchanged while it has focus.

#Requires AutoHotkey v2.0.2
#SingleInstance Force

; Rescue Gecko main windows that missed their Show event (started here, in the
; pure auto-execute section, before the first hotkey). See RescueUnmanagedWindows.
SetTimer(RescueUnmanagedWindows, 500)

Komorebic(cmd) {
    RunWait('"C:\Program Files\komorebi\bin\komorebic.exe" ' cmd, , "Hide")
}

; --- Direction-aware resize ---------------------------------------------
; The arrow always moves the focused window's SHARED (neighbor) edge:
; pointing toward the neighbor grows it, pointing away shrinks it.
; Heuristic: the shared edge is the one NOT flush with the monitor edge.
; Work area obtained directly via WinAPI (DllCall) to avoid AHK monitor
; builtins that this build fails to resolve.
GetWorkArea(&l, &t, &r, &b) {
    hMon := DllCall("user32.dll\MonitorFromWindow", "Ptr", WinGetID("A"), "UInt", 2, "Ptr")
    m := Buffer(40)
    NumPut("UInt", 40, m, 0)               ; MONITORINFO.cbSize
    if (DllCall("user32.dll\GetMonitorInfoW", "Ptr", hMon, "Ptr", m)) {
        l := NumGet(m, 20, "Int")          ; rcWork.left
        t := NumGet(m, 24, "Int")          ; rcWork.top
        r := NumGet(m, 28, "Int")          ; rcWork.right
        b := NumGet(m, 32, "Int")          ; rcWork.bottom
        return
    }
    l := 0
    t := 0
    r := DllCall("user32.dll\GetSystemMetrics", "Int", 78)  ; SM_CXVIRTUALSCREEN
    b := DllCall("user32.dll\GetSystemMetrics", "Int", 79)  ; SM_CYVIRTUALSCREEN
}

GetEdge(axis) {
    WinGetPos(&wx, &wy, &ww, &wh, "A")
    GetWorkArea(&l, &t, &r, &b)
    if (axis = "horizontal") {
        if (r - (wx + ww) > 100)
            return "right"          ; neighbor on the right
        if (wx - l > 100)
            return "left"           ; neighbor on the left
        return ((wx + ww / 2) < (l + r) / 2) ? "right" : "left"  ; fallback by center
    }
    if (b - (wy + wh) > 100)
        return "down"               ; neighbor below
    if (wy - t > 100)
        return "up"                 ; neighbor above
    return ((wy + wh / 2) < (t + b) / 2) ? "down" : "up"         ; fallback by center
}

ResizeDirectional(axis, arrow) {
    edge := GetEdge(axis)
    sizing := (arrow = edge) ? "increase" : "decrease"
    Komorebic("resize-edge " edge " " sizing)
}

; ---- Focus follows mouse (native) -----------------------------------------
; Handled by komorebi itself: the autostart starts komorebi with --ffm and runs
; `focus-follows-mouse enable -i komorebi`. It only focuses komorebi-managed
; windows, so context menus, the desktop and the taskbar are never touched.
; (The previous AHK WinActivate timer broke context menus by activating the
; menu's #32768 popup window - that is why FFM no longer lives here.)
; komorebi's own mouse-follows-focus must stay OFF (the autostart disables it).

; ---- Bindings are inactive while the focused window is Illustrator ----
#HotIf !WinActive("ahk_exe Illustrator.exe")

; Focus windows (Hyprland: SUPER + arrows)
#Right::Komorebic("focus right")
#Left::Komorebic("focus left")
#Up::Komorebic("focus up")
#Down::Komorebic("focus down")

; Move focused window (Hyprland: SUPER + Shift + arrows)
#+Right::Komorebic("move right")
#+Left::Komorebic("move left")
#+Up::Komorebic("move up")
#+Down::Komorebic("move down")

; Resize focused window bigger/smaller (SUPER + Ctrl + arrows, direction-aware)
#^Right::ResizeDirectional("horizontal", "right")
#^Left::ResizeDirectional("horizontal", "left")
#^Up::ResizeDirectional("vertical", "up")
#^Down::ResizeDirectional("vertical", "down")

; Stack focused window (moved to SUPER + Ctrl + Shift + arrows)
#^+Right::Komorebic("stack right")
#^+Left::Komorebic("stack left")
#^+Up::Komorebic("stack up")
#^+Down::Komorebic("stack down")

; Unstack
#^+Space::Komorebic("unstack")

; Cycle focus
#[::Komorebic("cycle-focus previous")
#]::Komorebic("cycle-focus next")

; Workspaces (Hyprland: SUPER + number)
#1::Komorebic("focus-workspace 0")
#2::Komorebic("focus-workspace 1")
#3::Komorebic("focus-workspace 2")
#4::Komorebic("focus-workspace 3")
#5::Komorebic("focus-workspace 4")
#6::Komorebic("focus-workspace 5")
#7::Komorebic("focus-workspace 6")
#8::Komorebic("focus-workspace 7")

; Move window across workspaces (SUPER + Shift + number)
#+1::Komorebic("move-to-workspace 0")
#+2::Komorebic("move-to-workspace 1")
#+3::Komorebic("move-to-workspace 2")
#+4::Komorebic("move-to-workspace 3")
#+5::Komorebic("move-to-workspace 4")
#+6::Komorebic("move-to-workspace 5")
#+7::Komorebic("move-to-workspace 6")
#+8::Komorebic("move-to-workspace 7")

; Window state / management
#w::Komorebic("close")          ; was Win+Q (Win+Q stays free); Win+W replaces Windows Widgets
#+v::Komorebic("toggle-float")  ; Hyprland SUPER+V (real Win+V clipboard stays yours)
; Note: Super+F (was monocle) and Super+M (was maximize) are now app launchers,
; defined in the global section below. Fullscreen/maximize are currently unbound.
#+m::Komorebic("minimize")       ; minimize focused window (restore via Alt+Tab/taskbar)
#+p::Komorebic("toggle-pause")
#+r::Komorebic("retile")

#HotIf

; ---- Global (work also while Illustrator is focused) ----
; Launch Windows Terminal
#Enter::Run("C:\Users\verdu\AppData\Local\Microsoft\WindowsApps\wt.exe")

; ---- App launchers -----------------------------------------------------------
; Super+F -> Ferdium
; Super+B -> default browser (fallback order: Zen, Brave)
; Super+M -> default email client (fallback: Mailspring)
LaunchFirst(paths*) {
    for p in paths
        if (FileExist(p))
            return Run(p)
}
UrlAppExe(protocol) {          ; registered default app executable for http/mailto
    try {
        progId := RegRead("HKCU\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\" protocol "\UserChoice", "ProgId")
        if (!progId)
            return ""
        cmd := Trim(RegRead("HKCU\Software\Classes\" progId "\shell\open\command"))
        if (SubStr(cmd, 1, 1) = '"') {
            end := InStr(cmd, '"', false, 2)
            if (end)
                return SubStr(cmd, 2, end - 2)
        }
        sp := InStr(cmd, A_Space)
        return sp ? SubStr(cmd, 1, sp - 1) : cmd
    } catch
        return ""
}
LaunchDefaultApp(protocol, candidates*) {
    exe := UrlAppExe(protocol)
    if (exe && FileExist(exe)) {
        SplitPath(exe, &exeName)
        if (exeName != "Update.exe")        ; Squirrel updater stub is not launchable
            return Run(exe)
    }
    LaunchFirst(candidates*)
}
#f::{
    LaunchFirst(EnvGet("LocalAppData") . "\Ferdium\Ferdium.exe",
                EnvGet("LocalAppData") . "\Programs\Ferdium\Ferdium.exe",
                EnvGet("ProgramFiles") . "\Ferdium\Ferdium.exe",
                "ferdium.exe")
}
#b::{
    LaunchDefaultApp("http",
        EnvGet("ProgramFiles") . "\Zen Browser\zen.exe",
        EnvGet("LocalAppData") . "\zen\zen.exe",
        EnvGet("ProgramFiles") . "\BraveSoftware\Brave-Browser\Application\brave.exe",
        EnvGet("LocalAppData") . "\BraveSoftware\Brave-Browser\Application\brave.exe",
        "zen.exe", "brave.exe")
}
#m::{
    LaunchDefaultApp("mailto",
        EnvGet("LocalAppData") . "\Mailspring\Mailspring.exe",
        EnvGet("LocalAppData") . "\Programs\mailspring\Mailspring.exe",
        EnvGet("ProgramFiles") . "\Mailspring\Mailspring.exe",
        "mailspring.exe")
}

; ---- Suppress the Start menu on a lone Win press -------------------------
; '~' keeps the Win key's native behaviour, so Win+E, Win+Tab, Win+D, Win+L... still work.
; The dummy vkE8 keystroke makes Windows believe another key was pressed with Win, so a
; lone press/release (typical when Win is used as the window-manager modifier) no longer
; opens the Start menu. Remove these two lines to get the old behaviour back.
~LWin::Send("{Blind}{vkE8}")
~RWin::Send("{Blind}{vkE8}")

; ---- Keep the native taskbar hidden --------------------------------------
; Auto-hide always leaves a 2px sliver at the screen edge, so brushing the bottom edge
; reveals the taskbar. Hide the taskbar window itself and re-hide it whenever something
; (Start menu, notifications, Win key) shows it again. explorer.exe keeps running, so the
; YASB systray widget still receives the tray icons. Delete this timer to restore it.
SetTimer(HideTaskbar, 200)
HideTaskbar() {
    try {
        if (WinExist("ahk_class Shell_TrayWnd"))          ; only found while visible
            WinHide("ahk_class Shell_TrayWnd")
    }
    try {
        for hwnd in WinGetList("ahk_class Shell_SecondaryTrayWnd")   ; secondary monitors
            WinHide("ahk_id " hwnd)
    }
}

; ---- Swallow Win+Alt+arrows (Windows snap-group gesture). ----
; Claimed as no-ops for now; reassign later if useful.
#!Up::return
#!Down::return
#!Left::return
#!Right::return

; ---- Rescue windows that missed their Show event -------------------------
; Gecko browsers (Zen/Firefox) cold-start create their main window WITHOUT a
; Window event Show notification, so komorebi never registers it as a tile
; (only a TitleUpdate arrives) and the window floats until a second open.
; Fast and light: the WinGetList criteria already restrict to zen.exe's
; MozillaWindowClass windows (no per-window process lookup), and everything
; else (active-window capture, handle pruning) is skipped while Zen is absent.
RescueUnmanagedWindows() {
    static seen := Map()
    wins := WinGetList("ahk_class MozillaWindowClass ahk_exe zen.exe")
    if (wins.Length = 0)
        return
    restore := WinGetID("A")
    for hwnd in wins {
        if (!DllCall("user32.dll\IsWindowVisible", "Ptr", hwnd))
            continue
        if (seen.Has(hwnd))
            continue
        ; Only the real main window (has a title); ignore bare splash frames.
        if (WinGetTitle("ahk_id " hwnd) = "")
            continue
        seen[hwnd] := true
        SetTimer(FocusManage.Bind(hwnd, restore), -250)  ; settle briefly
    }
    ; Forget handles that are gone so a recreated window is seen again.
    for hwnd in seen.Clone() {
        if (!WinExist("ahk_id " hwnd))
            seen.Delete(hwnd)
    }
}
FocusManage(hwnd, restore) {
    ; komorebic manage acts on the FOCUSED window, so give it the rescued one,
    ; then put the user's previous window back in front.
    try {
        WinActivate("ahk_id " hwnd)
        Sleep(50)
        Komorebic("manage")
    } catch
        return
    if (WinExist("ahk_id " restore))
        WinActivate("ahk_id " restore)
}