# snapshot-wm.ps1 — one point-in-time evidence bundle for the komorebi layout.
# Repo-only diagnostic tool (not deployed, not in MANIFEST).
#
# Why it exists: three diagnostic rounds were wasted by inspecting komorebi's state
# after the offending window was already gone. This tool takes one measurement of the
# whole story at once, so "before" and "after" are compared as numbers.
#
# Usage:
#   powershell -File snapshot-wm.ps1 [-Label before] [-OutDir <dir>]
#
# It writes into <OutDir>\<timestamp>-<label>\:
#   summary.txt        human table + the verdict lines to read first
#   windows.json       every container/float window, enriched with live Win32 facts
#   state.json         raw `komorebic state`
#   visible-windows.json, global-state.json
#   state-dump.json    copy of %TEMP%\komorebi.state.json when present
#
# Absolute output path is printed last. Evidence stays OUTSIDE the repository on purpose:
# window titles carry client names and must never reach a commit.

param(
    [string]$Label = 'snapshot',
    [string]$OutDir = "$env:USERPROFILE\komorebi-evidence"
)

$ErrorActionPreference = 'Stop'
$komorebic = 'C:\Program Files\komorebi\bin\komorebic.exe'
if (-not (Test-Path $komorebic)) { $komorebic = 'komorebic' }

if (-not ([System.Management.Automation.PSTypeName]'KomorebiSnapshot.Win32').Type) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public static string ClassOf(IntPtr h) {
        var sb = new StringBuilder(256);
        GetClassName(h, sb, 256);
        return sb.ToString();
    }
    public static string RectOf(IntPtr h) {
        RECT r;
        if (!GetWindowRect(h, out r)) { return ""; }
        return string.Format("{0},{1},{2},{3}", r.Left, r.Top, r.Right, r.Bottom);
    }
}
'@
}

# Write UTF-8 WITHOUT a byte-order mark. `Set-Content -Encoding utf8` on Windows PowerShell
# 5.1 silently prepends a BOM, which breaks every downstream reader that is not .NET
# (python's json.load, jq) for no benefit at all.
function Write-TextFile([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-KomorebicJson([string]$Command) {
    $raw = (& $komorebic $Command 2>$null) -join "`n"
    if (-not $raw) { return $null }
    try { return ($raw | ConvertFrom-Json) } catch { return $null }
}

# Walk any JSON shape and collect every object that carries an `hwnd`: komorebi's window
# records nest differently per container kind, and a class-based filter needs them all.
function Get-WindowRecord($Node, [System.Collections.ArrayList]$Acc) {
    if ($null -eq $Node) { return }
    if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) {
        foreach ($item in $Node) { Get-WindowRecord -Node $item -Acc $Acc }
        return
    }
    if ($Node -isnot [System.Management.Automation.PSCustomObject]) { return }
    if (@($Node.PSObject.Properties.Name) -contains 'hwnd') { $Acc.Add($Node) | Out-Null }
    foreach ($p in $Node.PSObject.Properties) {
        $v = $p.Value
        if ($v -is [System.Management.Automation.PSCustomObject] -or
            ($v -is [System.Collections.IEnumerable] -and $v -isnot [string])) {
            Get-WindowRecord -Node $v -Acc $Acc
        }
    }
}

$state = Invoke-KomorebicJson 'state'
if (-not $state) { Write-Error "komorebic state did not answer; is komorebi running?"; exit 1 }
$globalState = Invoke-KomorebicJson 'global-state'
$visible = Invoke-KomorebicJson 'visible-windows'

$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$dir = Join-Path $OutDir "$stamp-$Label"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

Write-TextFile "$dir\state.json" ($state | ConvertTo-Json -Depth 100)
Write-TextFile "$dir\global-state.json" ((& $komorebic global-state 2>$null) -join "`n")
Write-TextFile "$dir\visible-windows.json" ((& $komorebic visible-windows 2>$null) -join "`n")

# The dump is the resurrection path: record whether it exists and whether it is dirty.
$dumpPath = "$env:TEMP\komorebi.state.json"
$dumpExists = Test-Path $dumpPath
if ($dumpExists) { Copy-Item $dumpPath "$dir\state-dump.json" -Force }

$ignoredClasses = @()
if ($globalState -and $globalState.ignore_identifiers) {
    $ignoredClasses = @($globalState.ignore_identifiers | Where-Object { $_.kind -eq 'Class' } | ForEach-Object { $_.id })
}

$records = New-Object System.Collections.ArrayList
$summary = New-Object System.Collections.ArrayList
$violations = New-Object System.Collections.ArrayList

foreach ($mon in $state.monitors.elements) {
    $wa = $mon.work_area_size
    $waW = $wa.right - $wa.left
    $waH = $wa.bottom - $wa.top
    $summary.Add(("monitor {0} {1} work_area {2}x{3} @{4},{5}" -f $mon.id, $mon.name, $waW, $waH, $wa.left, $wa.top)) | Out-Null

    $wsIndex = -1
    foreach ($ws in $mon.workspaces.elements) {
        $wsIndex++
        $containers = @($ws.containers.elements)
        $floating = @($ws.floating_windows.elements)
        $liveWindows = @($containers | ForEach-Object { @($_.windows.elements) }) | Where-Object { $_ }

        $acc = New-Object System.Collections.ArrayList
        Get-WindowRecord -Node $ws.containers -Acc $acc
        $before = $records.Count

        foreach ($rec in $acc) {
            $hwnd = [IntPtr][int64]$rec.hwnd
            $alive = [Win32]::IsWindow($hwnd)
            $iconic = $false; $vis = $false; $liveClass = ''; $liveRect = ''; $root = 0
            if ($alive) {
                $iconic = [Win32]::IsIconic($hwnd)
                $vis = [Win32]::IsWindowVisible($hwnd)
                $liveClass = [Win32]::ClassOf($hwnd)
                $liveRect = [Win32]::RectOf($hwnd)
                $root = [Win32]::GetAncestor($hwnd, 2).ToInt64()   # GA_ROOT
            }
            $sr = $rec.rect
            $stateW = $sr.right - $sr.left
            $stateH = $sr.bottom - $sr.top

            $records.Add([pscustomobject]@{
                hwnd        = [int64]$rec.hwnd
                exe         = $rec.exe
                class       = $rec.class
                title       = $rec.title
                state_rect  = "$($sr.left),$($sr.top),$($sr.right),$($sr.bottom)"
                state_size  = "${stateW}x${stateH}"
                state_left  = $sr.left
                state_w     = $stateW
                state_h     = $stateH
                alive       = $alive
                minimized   = $iconic
                visible     = $vis
                live_class  = $liveClass
                live_rect   = $liveRect
                is_child    = if ($alive) { $root -ne [int64]$rec.hwnd } else { $null }
                ga_root     = $root
            }) | Out-Null

            $summary.Add(("  ws[{0}] hwnd={1} {2} [{3}] {4}x{5} @{6},{7} alive={8} min={9} vis={10} child={11}" -f `
                $wsIndex, $rec.hwnd, $rec.exe, $rec.class, $stateW, $stateH, $sr.left, $sr.top, `
                $alive, $iconic, $vis, ($root -ne [int64]$rec.hwnd))) | Out-Null

            if ($ignoredClasses -contains $rec.class) {
                $violations.Add("ws[$wsIndex] container class '$($rec.class)' is in the ignore list (hwnd=$($rec.hwnd))") | Out-Null
            }
            if (-not $alive) {
                $violations.Add("ws[$wsIndex] container hwnd=$($rec.hwnd) ($($rec.class)) no longer exists: ghost container") | Out-Null
            }
            if ($stateW -le 0 -or $stateH -le 0) {
                $violations.Add("ws[$wsIndex] container hwnd=$($rec.hwnd) has a degenerate rect $($stateW)x${stateH}: parked, not laid out") | Out-Null
            }
            if ($alive -and $root -ne [int64]$rec.hwnd) {
                $violations.Add("ws[$wsIndex] container hwnd=$($rec.hwnd) is a WS_CHILD of $root and cannot paint in a tile") | Out-Null
            }
        }

        # The reported symptom is not "many containers": it is ONE user window squeezed by
        # containers that are not user windows (child helpers, ghosts, parked windows). The
        # number that must go up after a fix is this share of the work-area width.
        $wsRecords = @($records | Select-Object -Skip $before)
        # A minimized window is not on screen, so it must not count as "a user window you
        # can see": when komorebi keeps its container (upstream #1730) the visible window is
        # squeezed by something the user cannot see, and that is the symptom to measure.
        $userWindows = @($wsRecords | Where-Object { $_.alive -and -not $_.is_child -and -not $_.minimized })
        if ($userWindows.Count -eq 1 -and $waW -gt 0) {
            $only = $userWindows[0]
            $pct = [math]::Round(100 * $only.state_w / $waW)
            $summary.Add(("  ws[{0}] ONE user window {1} holds {2}% of the work-area width ({3} containers total)" -f `
                $wsIndex, $only.exe, $pct, $wsRecords.Count)) | Out-Null
            if ($pct -lt 95) {
                $violations.Add("ws[$wsIndex] the only visible user window ($($only.exe) hwnd=$($only.hwnd)) holds ${pct}% of the work-area width: $($wsRecords.Count - 1) other container(s) ($(@($wsRecords | Where-Object { $_.hwnd -ne $only.hwnd } | ForEach-Object { "$($_.exe)/min=$($_.minimized)" }) -join ', ')) steal the rest") | Out-Null
            }
        } elseif ($wsRecords.Count -gt 1) {
            $summary.Add(("  ws[{0}] {1} containers, {2} floating" -f $wsIndex, $wsRecords.Count, $floating.Count)) | Out-Null
        }
    }
}

Write-TextFile "$dir\windows.json" ($records | ConvertTo-Json -Depth 6)

$lines = New-Object System.Collections.ArrayList
$lines.Add("komorebi layout snapshot - $stamp - label=$Label") | Out-Null
$lines.Add("state dump: $(if ($dumpExists) { "present ($dumpPath)" } else { 'absent' })") | Out-Null
$lines.Add("ignore-list classes: $($ignoredClasses -join ', ')") | Out-Null
$lines.Add("manage-list: $(if ($globalState) { (@($globalState.manage_identifiers) | ForEach-Object { "$($_.kind)=$($_.id)" }) -join ', ' })") | Out-Null
$lines.Add('') | Out-Null
$lines.AddRange($summary) | Out-Null
$lines.Add('') | Out-Null
if ($violations.Count -eq 0) {
    $lines.Add('VERDICT: clean - every container is a live top-level window holding its work area') | Out-Null
} else {
    $lines.Add("VERDICT: $($violations.Count) violation(s)") | Out-Null
    foreach ($v in $violations) { $lines.Add("  - $v") | Out-Null }
}
Write-TextFile "$dir\summary.txt" ($lines -join "`r`n")

$lines | Write-Output
Write-Output ""
Write-Output "bundle: $dir"
