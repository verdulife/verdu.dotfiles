# Pester 3 tests for windows/komorebi/yasb-subscription.ps1.
# Repo-only: the tests ship with the source tree, the module is what gets copied to
# %USERPROFILE% (see MANIFEST.md, like spy-dialog.ps1 these are not deployed as tests).
#
# The fixtures are real yasb.log lines from the two logins that failed (2026-10-18 and
# 2026-10-20), because the whole point of the module is to read THAT log correctly:
# a created pipe that never saw "Komorebi connected" is the silent failure, and any
# other reading of the file is the bug.
#
# The komorebic side is stubbed with a .cmd, not mocked: the module shells out to a
# real executable, so a stub is the only way to prove the exact command line and that
# a healthy session is left untouched. A .cmd is used instead of a .ps1 because the
# machine's execution policy is Restricted (the supervisor runs under -ExecutionPolicy
# Bypass, but the tests must not depend on that).

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'yasb-subscription.ps1'
if (Test-Path $modulePath) { . $modulePath }

$pipe = 'yasb-582ef7b5-ccbb-11f1-a9de-fcaa14e64235'
$pipe2 = 'yasb-2016f0e1-cadd-11f1-9f88-fcaa14e64235'

$banner    = '2026-10-20 21:20:35,566 [INFO] [MainThread] [root/log.py:103]: YASB v2.0.7'
$created   = "2026-10-20 21:20:43,564 [INFO] [Dummy-5] [root/event_listener.py:54]: Created named pipe $pipe"
$connected = "2026-10-20 21:55:49,541 [INFO] [Dummy-5] [root/event_listener.py:147]: Komorebi connected to named pipe: $pipe"
$created2  = "2026-10-18 10:09:35,575 [INFO] [Dummy-7] [root/event_listener.py:54]: Created named pipe $pipe2"

function Write-YasbLog([string]$Path, [string[]]$Lines) {
    [System.IO.File]::WriteAllText($Path, (($Lines -join "`r`n") + "`r`n"))
    $Path
}

# A stand-in for komorebic.exe. It records its own command line (so the tests can pin
# what was invoked, and prove nothing was invoked) and, when asked, appends the
# "Komorebi connected" line komorebi would not write itself: komorebi writes that line
# into yasb.log, the stub has to fake komorebi's side effect, not komorebic's.
function New-KomorebicStub {
    param(
        [string]$Path,
        [string]$MarkerPath,
        [string]$LogPath,
        [switch]$Connect
    )

    $body = "@echo off`r`necho %* >>`"$MarkerPath`"`r`n"
    if ($Connect) {
        $body += "echo 2026-10-20 22:00:00,000 [INFO] [Dummy-9] [root/event_listener.py:147]: Komorebi connected to named pipe: %2 >>`"$LogPath`"`r`n"
    }
    [System.IO.File]::WriteAllText($Path, $body)
    $Path
}

$fast = @{ WaitForPipeSeconds = 1; WaitForConnectSeconds = 1; PollMilliseconds = 50 }

# --- Get-YasbPipeSubscription ------------------------------------------------

Describe 'Get-YasbPipeSubscription' {
    It 'reports a subscribed session as connected' {
        $path = Write-YasbLog (Join-Path $TestDrive 'healthy.log') @($banner, $created, $connected)
        $r = Get-YasbPipeSubscription -Path $path
        $r.Pipe | Should Be $pipe
        $r.Connected | Should Be $true
    }

    It 'reports a created pipe with no connection as connected false' {
        $path = Write-YasbLog (Join-Path $TestDrive 'silent.log') @($banner, $created)
        $r = Get-YasbPipeSubscription -Path $path
        $r.Pipe | Should Be $pipe
        $r.Connected | Should Be $false
    }

    It 'ignores a pipe created by a previous YASB process' {
        # Yesterday's connected session, then a new process that has not created a pipe
        # yet: the old entry must not be mistaken for a healthy current subscription.
        $path = Write-YasbLog (Join-Path $TestDrive 'restarted.log') @(
            $banner, $created, $connected,
            '2026-10-21 09:00:00,000 [INFO] [MainThread] [root/log.py:103]: YASB v2.0.7',
            '2026-10-21 09:00:10,000 [INFO] [MainThread] [root/bar_manager.py:103]: Starting KomorebiEventListener...'
        )
        Get-YasbPipeSubscription -Path $path | Should BeNullOrEmpty
    }

    It 'follows the newest pipe when the listener recreated it' {
        $path = Write-YasbLog (Join-Path $TestDrive 'reconnect.log') @($banner, $created, $connected, $created2)
        $r = Get-YasbPipeSubscription -Path $path
        $r.Pipe | Should Be $pipe2
        $r.Connected | Should Be $false
    }

    It 'does not treat an older connection as proof for a newer pipe' {
        $path = Write-YasbLog (Join-Path $TestDrive 'older.log') @($banner, $created, $connected, $created2)
        $r = Get-YasbPipeSubscription -Path $path
        $r.Connected | Should Be $false
    }

    It 'returns nothing for a missing log' {
        Get-YasbPipeSubscription -Path (Join-Path $TestDrive 'nope.log') | Should BeNullOrEmpty
    }

    It 'returns nothing for an empty log' {
        $path = Write-YasbLog (Join-Path $TestDrive 'empty.log') @()
        Get-YasbPipeSubscription -Path $path | Should BeNullOrEmpty
    }
}

# --- Repair-YasbKomorebiSubscription ----------------------------------------

Describe 'Repair-YasbKomorebiSubscription' {
    It 'leaves a healthy session alone and runs nothing' {
        $log = Write-YasbLog (Join-Path $TestDrive 'ok.log') @($banner, $created, $connected)
        $marker = Join-Path $TestDrive 'ok.marker'
        $stub = New-KomorebicStub -Path (Join-Path $TestDrive 'ok.cmd') -MarkerPath $marker -LogPath $log

        $v = Repair-YasbKomorebiSubscription -Path $log -Komorebic $stub @fast
        $v.Action | Should Be 'ok'
        $v.Pipe | Should Be $pipe
        $v.Attempts | Should Be 0
        Test-Path $marker | Should Be $false
    }

    It 'subscribes the pending pipe and reports it repaired' {
        $log = Write-YasbLog (Join-Path $TestDrive 'repair.log') @($banner, $created)
        $marker = Join-Path $TestDrive 'repair.marker'
        $stub = New-KomorebicStub -Path (Join-Path $TestDrive 'repair.cmd') -MarkerPath $marker -LogPath $log -Connect

        $v = Repair-YasbKomorebiSubscription -Path $log -Komorebic $stub @fast
        $v.Action | Should Be 'repaired'
        $v.Pipe | Should Be $pipe
        $v.Attempts | Should Be 1

        # The exact command YASB itself issues, not a synonym: subscribe-pipe is the
        # documented name, but `subscribe` is the one YASB calls, so if it ever
        # disappears YASB is broken too and this test says so first.
        $calls = @(Get-Content -LiteralPath $marker)
        $calls.Count | Should Be 1
        $calls[0].Trim() | Should Be "subscribe $pipe"
    }

    It 'retries once and then reports the widget offline with the actionable command' {
        $log = Write-YasbLog (Join-Path $TestDrive 'dead.log') @($banner, $created)
        $marker = Join-Path $TestDrive 'dead.marker'
        $stub = New-KomorebicStub -Path (Join-Path $TestDrive 'dead.cmd') -MarkerPath $marker -LogPath $log

        $v = Repair-YasbKomorebiSubscription -Path $log -Komorebic $stub @fast
        $v.Action | Should Be 'offline'
        $v.Attempts | Should Be 2
        $v.Detail | Should Be "komorebic subscribe $pipe"
        @(Get-Content -LiteralPath $marker).Count | Should Be 2
    }

    It 'reports offline naming the pipe that exists now when YASB restarted mid-repair' {
        $log = Write-YasbLog (Join-Path $TestDrive 'moved.log') @($banner, $created)
        $marker = Join-Path $TestDrive 'moved.marker'
        $stub = New-KomorebicStub -Path (Join-Path $TestDrive 'moved.cmd') -MarkerPath $marker -LogPath $log

        # A YASB restart between the read and the repair leaves a new uuid behind; the
        # caller's log line must name the pipe the user can actually subscribe.
        Add-Content -LiteralPath $log -Value $created2
        $v = Repair-YasbKomorebiSubscription -Path $log -Komorebic $stub @fast
        $v.Action | Should Be 'offline'
        $v.Detail | Should Be "komorebic subscribe $pipe2"
    }

    It 'waits for the pipe to appear before deciding anything' {
        # At logon the supervisor asks before YASB's listener has created its pipe; that
        # is not a failure, it is early.
        $log = Write-YasbLog (Join-Path $TestDrive 'early.log') @($banner)
        $marker = Join-Path $TestDrive 'early.marker'
        $stub = New-KomorebicStub -Path (Join-Path $TestDrive 'early.cmd') -MarkerPath $marker -LogPath $log

        Push-Location $TestDrive
        try {
            Start-Job -ScriptBlock {
                param($p, $line)
                Start-Sleep -Milliseconds 400
                Add-Content -LiteralPath $p -Value $line
            } -ArgumentList $log, $created | Out-Null

            $v = Repair-YasbKomorebiSubscription -Path $log -Komorebic $stub -WaitForPipeSeconds 3 -WaitForConnectSeconds 1 -PollMilliseconds 50
        } finally {
            Pop-Location
            Get-Job | Wait-Job -Timeout 10 | Remove-Job -Force
        }

        $v.Pipe | Should Be $pipe
        $v.Action | Should Be 'offline'   # the pipe appeared, but nothing subscribed it
        $v.Attempts | Should Be 2
    }

    It 'reports unknown and runs nothing when there is no log at all' {
        $marker = Join-Path $TestDrive 'nolog.marker'
        $stub = New-KomorebicStub -Path (Join-Path $TestDrive 'nolog.cmd') -MarkerPath $marker -LogPath (Join-Path $TestDrive 'unused.log')

        $v = Repair-YasbKomorebiSubscription -Path (Join-Path $TestDrive 'missing-yasb.log') -Komorebic $stub @fast
        $v.Action | Should Be 'unknown'
        Test-Path $marker | Should Be $false
    }
}
