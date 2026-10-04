# spy-dialog.ps1 — Discover the window class of a dialog so it can be floated.
# Repo-only utility (not deployed, not in MANIFEST).
#
# Usage:
#   powershell -File spy-dialog.ps1            # snapshot: list all visible top-level windows
#   powershell -File spy-dialog.ps1 -Watch 90  # watch for the next 90s, print NEW visible
#                      windows as they appear (open your dialog while it is watching)
#
# When you have the class of a dialog, float it by adding an ignore-rule to
# komorebi-autostart.ps1:
#   komorebic ignore-rule class "<CLASS>"

param([int]$Watch = 0)

Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class WinSpy {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    public delegate bool EnumWindowsProc(IntPtr h, IntPtr lp);
}
'@

function Get-TopWindows {
    $out = [System.Collections.ArrayList]::new()
    $cb = [WinSpy+EnumWindowsProc]{ param($h, $lp)
        $wpid = 0
        [WinSpy]::GetWindowThreadProcessId($h, [ref]$wpid) | Out-Null
        $t = [System.Text.StringBuilder]::new(256); [WinSpy]::GetWindowText($h, $t, 256) | Out-Null
        $c = [System.Text.StringBuilder]::new(256); [WinSpy]::GetClassName($h, $c, 256) | Out-Null
        $vis = [WinSpy]::IsWindowVisible($h)
        $exe = (Get-Process -Id $wpid -ErrorAction SilentlyContinue).ProcessName
        $out.Add([pscustomobject]@{ Handle = ('0x{0:X}' -f $h.ToInt64()); Visible = $vis; Class = $c.ToString(); Title = $t.ToString(); Exe = $exe }) | Out-Null
        return $true
    }
    [WinSpy]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
    return $out
}

if ($Watch -gt 0) {
    $known = @{}
    (Get-TopWindows) | ForEach-Object { $known[$_.Handle] = $true }
    Write-Host "Watching for NEW top-level windows for $Watch s - open the dialog now..."
    $deadline = (Get-Date).AddSeconds($Watch)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 400
        foreach ($w in (Get-TopWindows)) {
            if (-not $known.ContainsKey($w.Handle)) {
                $known[$w.Handle] = $true
                if ($w.Visible -and $w.Class -ne '') {
                    Write-Host "--- NEW WINDOW ---"
                    $w | Format-List Class, Title, Exe, Handle | Out-String | Write-Host
                }
            }
        }
    }
    Write-Host "Watch finished."
} else {
    Get-TopWindows | Where-Object Visible | Sort-Object Exe | Format-Table -AutoSize Class, Title, Exe, Handle
}