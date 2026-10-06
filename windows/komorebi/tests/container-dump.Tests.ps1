# Pester 3 tests for windows/komorebi/container-dump.ps1.
# Repo-only: the tests ship with the source tree, the module is what gets copied
# to %USERPROFILE% (see MANIFEST.md, like spy-dialog.ps1 these are not deployed).
#
# Fixtures are inline JSON because the point of the module is to survive whatever
# nesting komorebi happens to serialize: the tests pin the SHAPE (window records
# under monitors.elements[].workspaces.elements[].containers.elements[].windows.elements[])
# without importing a sample from the live machine.
#
# The liveness check calls the real Win32 IsWindow, so the "safe" fixtures need a
# handle that is genuinely alive. The desktop window is used: it exists in every
# interactive Windows session and costs nothing to obtain.

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'container-dump.ps1'
if (Test-Path $modulePath) { . $modulePath }

if (-not ('KomorebiDumpTests.Win32' -as [type])) {
    Add-Type -Namespace KomorebiDumpTests -Name Win32 -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern System.IntPtr GetDesktopWindow();
'@
}
$liveHwnd = [KomorebiDumpTests.Win32]::GetDesktopWindow().ToInt64()

function Write-JsonFixture([string]$Path, [string]$Json) {
    [System.IO.File]::WriteAllText($Path, $Json)
    $Path
}

# --- Fixtures ---------------------------------------------------------------
# A clean dump: one real user window on workspace 0 of monitor 0.
$cleanDumpJson = @"
{
  "monitors": { "elements": [
    { "id": 65537, "name": "DISPLAY1", "workspaces": { "elements": [
      { "name": null, "containers": { "elements": [
        { "id": "c1", "locked": false, "windows": { "elements": [
          { "hwnd": $liveHwnd, "title": "WT", "exe": "WindowsTerminal.exe",
            "class": "CASCADIA_HOSTING_WINDOW_CLASS",
            "rect": { "left": 9, "top": 49, "right": 1662, "bottom": 992 } }
        ] } }
      ] } }
    ] } }
  ] }
}
"@

# Same dump, but the window is one of Zen's WS_CHILD helper classes.
$ignoredClassDumpJson = @"
{
  "monitors": { "elements": [
    { "id": 65537, "workspaces": { "elements": [
      { "name": null, "containers": { "elements": [
        { "id": "c1", "windows": { "elements": [
          { "hwnd": $liveHwnd, "title": "ReunionCaptionControlsWindow", "exe": "zen.exe",
            "class": "ReunionWindowingCaptionControls",
            "rect": { "left": 855, "top": 98, "right": 1120, "bottom": 491 } }
        ] } }
      ] } }
    ] } }
  ] }
}
"@

# A window record whose hwnd is not a window (0 is never a valid HWND).
$deadHwndDumpJson = @"
{
  "monitors": { "elements": [
    { "id": 65537, "workspaces": { "elements": [
      { "name": null, "containers": { "elements": [
        { "id": "c1", "windows": { "elements": [
          { "hwnd": 0, "title": "gone", "exe": "old.exe", "class": "SomeClass",
            "rect": { "left": 9, "top": 49, "right": 1662, "bottom": 992 } }
        ] } }
      ] } }
    ] } }
  ] }
}
"@

# komorebi parks a hidden/ghost window at left = -32000 (SM_XVIRTUALSCREEN based).
$offscreenDumpJson = @"
{
  "monitors": { "elements": [
    { "id": 65537, "workspaces": { "elements": [
      { "name": null, "containers": { "elements": [
        { "id": "c1", "windows": { "elements": [
          { "hwnd": $liveHwnd, "title": "parked", "exe": "zen.exe", "class": "MozillaWindowClass",
            "rect": { "left": -32000, "top": -32000, "right": -31000, "bottom": -31000 } }
        ] } }
      ] } }
    ] } }
  ] }
}
"@

# A degenerate rect (right == left) is the same family: a tile nothing can paint into.
$emptyRectDumpJson = @"
{
  "monitors": { "elements": [
    { "id": 65537, "workspaces": { "elements": [
      { "name": null, "containers": { "elements": [
        { "id": "c1", "windows": { "elements": [
          { "hwnd": $liveHwnd, "title": "degenerate", "exe": "zen.exe", "class": "MozillaWindowClass",
            "rect": { "left": 855, "top": 98, "right": 826, "bottom": 491 } }
        ] } }
      ] } }
    ] } }
  ] }
}
"@

# Shape copied from the real `komorebic state` sample: two workspaces, the second
# carrying Zen's child windows next to a real main window.
$stateSampleJson = @"
{
  "monitors": { "elements": [
    { "id": 65537, "name": "DISPLAY1", "workspaces": { "elements": [
      { "name": null, "containers": { "elements": [
        { "id": "c1", "windows": { "elements": [
          { "hwnd": $liveHwnd, "title": "WT", "exe": "WindowsTerminal.exe",
            "class": "CASCADIA_HOSTING_WINDOW_CLASS",
            "rect": { "left": 9, "top": 49, "right": 1662, "bottom": 992 } }
        ] } }
      ] } },
      { "name": null, "containers": { "elements": [
        { "id": "c2", "windows": { "elements": [
          { "hwnd": $liveHwnd, "title": "Zen", "exe": "zen.exe", "class": "MozillaWindowClass",
            "rect": { "left": 9, "top": 49, "right": 826, "bottom": 992 } },
          { "hwnd": $liveHwnd, "title": "ReunionCaptionControlsWindow", "exe": "zen.exe",
            "class": "ReunionWindowingCaptionControls",
            "rect": { "left": 855, "top": 98, "right": 1120, "bottom": 491 } },
          { "hwnd": $liveHwnd, "title": "Non Client Input Sink Window", "exe": "zen.exe",
            "class": "InputNonClientPointerSource",
            "rect": { "left": 855, "top": 599, "right": 1120, "bottom": 991 } }
        ] } }
      ] } }
    ] } }
  ] }
}
"@

$ignored = @('ReunionWindowingCaptionControls', 'InputNonClientPointerSource')

# --- Test-ContainerDump -----------------------------------------------------

Describe 'Test-ContainerDump' {
    It 'reports a clean dump as safe' {
        $path = Write-JsonFixture (Join-Path $TestDrive 'clean.json') $cleanDumpJson
        $r = Test-ContainerDump -Path $path -IgnoredClasses $ignored
        $r.Exists | Should Be $true
        $r.Safe | Should Be $true
        $r.WindowCount | Should Be 1
        @($r.Reasons).Count | Should Be 0
    }

    It 'reports a dump containing an ignored class as unsafe and names the class' {
        $path = Write-JsonFixture (Join-Path $TestDrive 'ignored.json') $ignoredClassDumpJson
        $r = Test-ContainerDump -Path $path -IgnoredClasses $ignored
        $r.Safe | Should Be $false
        @($r.Reasons | Where-Object { $_ -like '*ReunionWindowingCaptionControls*' }).Count | Should Be 1
    }

    It 'reports a dead hwnd as unsafe' {
        $path = Write-JsonFixture (Join-Path $TestDrive 'dead.json') $deadHwndDumpJson
        $r = Test-ContainerDump -Path $path -IgnoredClasses $ignored
        $r.Safe | Should Be $false
        @($r.Reasons | Where-Object { $_ -like 'dead-hwnd*' }).Count | Should Be 1
    }

    It 'reports a rect parked at -32000 as unsafe' {
        $path = Write-JsonFixture (Join-Path $TestDrive 'offscreen.json') $offscreenDumpJson
        $r = Test-ContainerDump -Path $path -IgnoredClasses $ignored
        $r.Safe | Should Be $false
        @($r.Reasons | Where-Object { $_ -like 'offscreen-rect*' }).Count | Should Be 1
    }

    It 'reports a non-positive rect size as unsafe' {
        $path = Write-JsonFixture (Join-Path $TestDrive 'emptyrect.json') $emptyRectDumpJson
        $r = Test-ContainerDump -Path $path -IgnoredClasses $ignored
        $r.Safe | Should Be $false
        @($r.Reasons | Where-Object { $_ -like 'empty-rect*' }).Count | Should Be 1
    }

    It 'reports an unparsable file as unsafe' {
        $path = Write-JsonFixture (Join-Path $TestDrive 'broken.json') '{ this is not json'
        $r = Test-ContainerDump -Path $path -IgnoredClasses $ignored
        $r.Exists | Should Be $true
        $r.Safe | Should Be $false
        @($r.Reasons | Where-Object { $_ -eq 'unparsable' }).Count | Should Be 1
    }

    It 'reports an empty file as unsafe' {
        $path = Write-JsonFixture (Join-Path $TestDrive 'empty.json') ''
        $r = Test-ContainerDump -Path $path -IgnoredClasses $ignored
        $r.Safe | Should Be $false
        @($r.Reasons | Where-Object { $_ -eq 'unparsable' }).Count | Should Be 1
    }

    It 'tolerates a missing file: Exists false and safe' {
        $path = Join-Path $TestDrive 'does-not-exist.json'
        $r = Test-ContainerDump -Path $path -IgnoredClasses $ignored
        $r.Exists | Should Be $false
        $r.Safe | Should Be $true
        $r.WindowCount | Should Be 0
    }
}

# --- Remove-UnsafeContainerDump ---------------------------------------------

Describe 'Remove-UnsafeContainerDump' {
    It 'removes an unsafe dump and returns the unsafe verdict' {
        $path = Write-JsonFixture (Join-Path $TestDrive 'removable.json') $ignoredClassDumpJson
        $r = Remove-UnsafeContainerDump -Path $path -IgnoredClasses $ignored
        $r.Safe | Should Be $false
        Test-Path $path | Should Be $false
    }

    It 'leaves a safe dump in place' {
        $path = Write-JsonFixture (Join-Path $TestDrive 'keep.json') $cleanDumpJson
        $r = Remove-UnsafeContainerDump -Path $path -IgnoredClasses $ignored
        $r.Safe | Should Be $true
        Test-Path $path | Should Be $true
    }
}

# --- Get-KomorebiWindowRecord ------------------------------------------------

Describe 'Get-KomorebiWindowRecord' {
    It 'finds every window record at any nesting depth' {
        $state = $stateSampleJson | ConvertFrom-Json
        $records = @(Get-KomorebiWindowRecord -InputObject $state)
        $records.Count | Should Be 4
        @($records | Where-Object { $_.class -eq 'InputNonClientPointerSource' }).Count | Should Be 1
    }
}

# --- Get-IgnoredClassViolation -----------------------------------------------

Describe 'Get-IgnoredClassViolation' {
    It 'finds the child-class container and reports its workspace index' {
        $state = $stateSampleJson | ConvertFrom-Json
        $violations = @(Get-IgnoredClassViolation -State $state -IgnoredClasses $ignored)
        $violations.Count | Should Be 2
        $ws = @($violations | Where-Object { $_.class -eq 'ReunionWindowingCaptionControls' })
        $ws.Count | Should Be 1
        $ws[0].Workspace | Should Be 1
        $ws[0].hwnd | Should Be $liveHwnd
    }

    It 'returns nothing for a clean state' {
        $state = $cleanDumpJson | ConvertFrom-Json
        @(Get-IgnoredClassViolation -State $state -IgnoredClasses $ignored).Count | Should Be 0
    }
}
