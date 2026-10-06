# container-dump.ps1 - sanitize komorebi's serialized state dump before it is replayed.
#
# WHY this exists: `komorebic stop` writes %TEMP%\komorebi.state.json and komorebi
# re-applies that dump on the next start. A container restore deliberately BYPASSES
# the ignore rules, so a dump written while a child window was (wrongly) managed
# resurrects it even after the class is added to `ignore-rule` - the fix "looks
# applied" and the layout hole comes back (README gotcha 19). The autostart deletes an
# unsafe dump before starting komorebi instead of trusting the rules alone.
#
# Dot-sourceable, no top-level side effects: every function is pure apart from
# Remove-UnsafeContainerDump, which only deletes the file it was explicitly handed.
# Safe to dot-source twice (the Win32 type registration is probed, not assumed).

function Get-KomorebiWindowRecord {
    # Collect every object that carries an `hwnd` property, at ANY nesting depth.
    # Deliberately schema-agnostic: the dump's real layout ("monitors.elements[].
    # workspaces.elements[].containers.elements[].windows.elements[]") is komorebi's
    # private business and has already changed shape across releases, so walking by
    # shape would silently stop finding windows after an upgrade.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowNull()]
        $InputObject
    )

    $records = New-Object System.Collections.ArrayList
    $queue   = New-Object System.Collections.Queue
    $queue.Enqueue($InputObject)

    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue()
        if ($null -eq $node) { continue }

        # Containers are walked, never emitted as records. Strings are IEnumerable
        # too, so they are excluded explicitly; a .NET string has no hwnd anyway.
        if ($node -is [System.Collections.IDictionary] -or
            (($node -is [System.Collections.IEnumerable]) -and ($node -isnot [string]))) {
            foreach ($item in $node) { $queue.Enqueue($item) }
            continue
        }

        $props = $null
        try { $props = $node.PSObject.Properties } catch { $props = $null }
        if ($null -eq $props) { continue }

        # PSObject property lookup is case-insensitive, so `hwnd` / `Hwnd` / `HWND`
        # all resolve here.
        $hwndProp = $props['hwnd']
        if ($null -ne $hwndProp) {
            $record = [pscustomobject]@{
                hwnd  = $hwndProp.Value
                class = $null
                exe   = $null
                rect  = $null
                title = $null
            }
            foreach ($name in 'class', 'exe', 'rect', 'title') {
                $prop = $props[$name]
                if ($null -ne $prop) { $record.$name = $prop.Value }
            }
            [void]$records.Add($record)
        }

        foreach ($prop in $props) {
            $value = $prop.Value
            if ($null -eq $value) { continue }
            if ($value -is [System.Collections.IDictionary] -or
                (($value -is [System.Collections.IEnumerable]) -and ($value -isnot [string])) -or
                ($value -is [System.Management.Automation.PSCustomObject])) {
                $queue.Enqueue($value)
            }
        }
    }

    # Emit the records one by one rather than as a single wrapped array: callers use
    # @(...) to force an array, and a `,`-wrapped array would nest instead of flatten,
    # making a 4-window dump look like a 1-element result.
    $records.ToArray()
}

function Test-ContainerDump {
    # Verdict on a state dump: is it safe for komorebi to replay it?
    # UNSAFE when any window record
    #   - has a `class` the rules ask komorebi to ignore, or
    #   - points at an hwnd that no longer exists, or
    #   - carries a rect parked off-screen (left = -32000) or with a non-positive size.
    # All three mean "the dump describes state komorebi should not restore": deleting
    # the dump only costs window-to-workspace placement, which the layout pass redoes.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [string[]]$IgnoredClasses = @()
    )

    $verdict = [pscustomobject]@{
        Exists      = $false
        Safe        = $true
        Reasons     = @()
        WindowCount = 0
    }

    # Missing file: nothing will be replayed, so there is nothing to sanitize and the
    # caller must stay silent about it (no log noise at every logon).
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $verdict
    }
    $verdict.Exists = $true

    $raw = $null
    try { $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop } catch { $raw = $null }
    $state = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try { $state = $raw | ConvertFrom-Json } catch { $state = $null }
    }
    # An unparsable or empty dump cannot be inspected, so it cannot be trusted: a dump
    # komorebi wrote but we cannot read is exactly the case where the rules are blind.
    if ($null -eq $state) {
        $verdict.Safe    = $false
        $verdict.Reasons = @('unparsable')
        return $verdict
    }

    # Register IsWindow lazily: Add-Type throws "type already exists" on a second call,
    # so the type is probed first and dot-sourcing this module twice stays harmless.
    if (-not ('KomorebiDump.Win32' -as [type])) {
        Add-Type -Namespace KomorebiDump -Name Win32 -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool IsWindow(System.IntPtr hWnd);
'@
    }

    $ignored = @($IgnoredClasses | Where-Object { $_ })
    $records = @(Get-KomorebiWindowRecord -InputObject $state)
    $verdict.WindowCount = $records.Count

    $reasons = New-Object System.Collections.ArrayList
    foreach ($record in $records) {
        $hwnd = $record.hwnd

        if ($record.class -and $ignored.Count -gt 0 -and ($ignored -contains $record.class)) {
            [void]$reasons.Add("ignored-class:$($record.class)")
        }

        if ($null -ne $hwnd) {
            $alive = $false
            try { $alive = [KomorebiDump.Win32]::IsWindow([System.IntPtr][int64]$hwnd) } catch { $alive = $false }
            if (-not $alive) {
                [void]$reasons.Add("dead-hwnd:$hwnd")
            }
        }

        $rect = $record.rect
        if ($null -ne $rect) {
            $rectProps = $null
            try { $rectProps = $rect.PSObject.Properties } catch { $rectProps = $null }
            if ($null -ne $rectProps) {
                if ($rectProps['left'] -and [int]$rectProps['left'].Value -eq -32000) {
                    [void]$reasons.Add("offscreen-rect:$hwnd")
                }
                $degenerate = $false
                if ($rectProps['left'] -and $rectProps['right'] -and
                    ([int]$rectProps['right'].Value - [int]$rectProps['left'].Value) -le 0) {
                    $degenerate = $true
                }
                if ($rectProps['top'] -and $rectProps['bottom'] -and
                    ([int]$rectProps['bottom'].Value - [int]$rectProps['top'].Value) -le 0) {
                    $degenerate = $true
                }
                if ($degenerate) {
                    [void]$reasons.Add("empty-rect:$hwnd")
                }
            }
        }
    }

    $verdict.Reasons = @($reasons | Select-Object -Unique)
    $verdict.Safe    = ($verdict.Reasons.Count -eq 0)
    return $verdict
}

function Remove-UnsafeContainerDump {
    # Delete the dump ONLY when the verdict says it is unsafe; return that verdict so
    # the caller can log one line about what happened. The whole file goes rather than
    # a surgical rewrite: the serialized shape is komorebi's private business and a
    # hand-edited dump risks failing to deserialize at start.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [string[]]$IgnoredClasses = @()
    )

    $verdict = Test-ContainerDump -Path $Path -IgnoredClasses $IgnoredClasses

    $removed = $false
    if ($verdict.Exists -and -not $verdict.Safe) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        $removed = -not (Test-Path -LiteralPath $Path)
    }
    $verdict | Add-Member -NotePropertyName Removed -NotePropertyValue $removed -Force
    return $verdict
}

function Get-IgnoredClassViolation {
    # After a fresh start, report every container whose class is on the ignore list:
    # those are the containers that slipped in despite the rules (stale dump, or a
    # forced manage acting on the focused child window). Returned records carry the
    # zero-based monitor and workspace index so the caller can name the culprit.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowNull()]
        $State,

        [Parameter(Mandatory = $true, Position = 1)]
        [string[]]$IgnoredClasses
    )

    $ignored = @($IgnoredClasses | Where-Object { $_ })
    if ($null -eq $State -or $ignored.Count -eq 0) { return }

    if ($State -is [string]) {
        try { $State = $State | ConvertFrom-Json } catch { return }
    }
    if ($null -eq $State.monitors -or $null -eq $State.monitors.elements) { return }

    $monitorIndex = 0
    foreach ($monitor in @($State.monitors.elements)) {
        if ($null -eq $monitor.workspaces -or $null -eq $monitor.workspaces.elements) {
            $monitorIndex++
            continue
        }
        $wsIndex = 0
        foreach ($workspace in @($monitor.workspaces.elements)) {
            if ($null -ne $workspace.containers -and $null -ne $workspace.containers.elements) {
                foreach ($container in @($workspace.containers.elements)) {
                    foreach ($record in @(Get-KomorebiWindowRecord -InputObject $container)) {
                        if ($record.class -and ($ignored -contains $record.class)) {
                            [pscustomobject]@{
                                Monitor   = $monitorIndex
                                Workspace = $wsIndex
                                hwnd      = $record.hwnd
                                class     = $record.class
                                exe       = $record.exe
                                rect      = $record.rect
                                title     = $record.title
                            }
                        }
                    }
                }
            }
            $wsIndex++
        }
        $monitorIndex++
    }
}
