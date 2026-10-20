# yasb-subscription.ps1 - verify, and repair, YASB's komorebi event subscription.
#
# WHY this exists: the YASB komorebi widgets are fed by a subscription YASB cannot
# verify. It creates a pipe named `yasb-<uuid1>`, runs `komorebic subscribe <pipe>` and
# then blocks in ConnectNamedPipe with no timeout. That command is fire-and-forget:
# komorebic exits 0 without any confirmation that komorebi accepted the message, so a
# lost subscription is indistinguishable from a good one until the widget is missing.
# Nothing retries, and the only trace is a DEBUG-level line that the default log level
# never writes. `hide_if_offline: true` then draws nothing at all, so the bar simply has
# no workspaces pill. Observed twice, both at logon:
#
#   2026-10-18 10:09  YASB subscribed ~14 s before komorebi was listening on
#                     komorebi.sock (its init stalled ~40 s and the supervisor killed
#                     and restarted it), so the message went to a dead instance.
#   2026-10-20 21:20  komorebi WAS up and healthy: `komorebi.log.2026-10-20` has
#                     "WARN could not acquire window manager lock, not processing
#                     message: AddSubscriberPipe" 2.5 s after YASB created its pipe.
#                     The logon window storm held the state lock and the message was
#                     dropped without a reply.
#
# Neither side is retried by either tool, and neither tool has an option to make it so
# (`komorebic` offers only subscribe-pipe / subscribe-socket / unsubscribe-*; YASB's
# widget schema has no retry or timeout key). So the logon supervisor verifies it.
#
# The signal is yasb.log, not the exit code: the newest "Created named pipe yasb-<uuid>"
# emitted by the current YASB process must be followed by
# "Komorebi connected to named pipe: <same uuid>".
#
# Dot-sourceable, no top-level side effects. Get-YasbPipeSubscription only reads a log;
# Repair-YasbKomorebiSubscription runs `komorebic subscribe` and nothing else, and only
# when the log proves the subscription is missing.

function Get-YasbPipeSubscription {
    # Read the current YASB instance's pipe out of yasb.log and say whether komorebi
    # connected to it. Returns $null when the current process has not created a pipe yet
    # (it does ~10-15 s after start, with the bar): that is "too early to tell", not a
    # failure, and the caller must not act on it.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        # Only the tail is read: the file grows for the life of the session and every
        # poll would otherwise re-read megabytes by the end of the day. 2000 lines is far
        # more than a logon writes before the supervisor asks.
        [int]$TailLines = 2000
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    $lines = @()
    try {
        $lines = @(Get-Content -LiteralPath $Path -Tail $TailLines -Encoding utf8 -ErrorAction Stop)
    } catch {
        return $null
    }
    if ($lines.Count -eq 0) { return $null }

    # "YASB v..." marks a process start. Anything before the newest banner belongs to an
    # earlier session, so a pipe left there can never be mistaken for the live one: that
    # is the difference between "this session is subscribed" and "some session was".
    $startIdx = 0
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match '\[root/log\.py:\d+\].*YASB v') {
            $startIdx = $i
            break
        }
    }

    $pipe    = $null
    $pipeIdx = -1
    for ($i = $lines.Count - 1; $i -ge $startIdx; $i--) {
        if ($lines[$i] -match 'Created named pipe (yasb-[0-9a-fA-F-]+)') {
            $pipe    = $Matches[1]
            $pipeIdx = $i
            break
        }
    }
    if (-not $pipe) { return $null }

    # The connection must be for THIS pipe name and come after its creation: a reconnect
    # recreates the pipe under the same name, and an older "connected" line proves
    # nothing about the subscription that exists now.
    $connected = $false
    $needle    = "Komorebi connected to named pipe: $pipe"
    for ($i = $pipeIdx + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Contains($needle)) {
            $connected = $true
            break
        }
    }

    [pscustomobject]@{
        Pipe      = $pipe
        Connected = $connected
    }
}

function Repair-YasbKomorebiSubscription {
    # Wait for YASB's pipe, verify komorebi connected to it, and re-subscribe when it did
    # not. Returns a verdict object; the caller owns the log line (same contract as
    # Remove-UnsafeContainerDump) so this module stays silent and testable.
    #   Action 'ok'       - the subscription is present, nothing was run
    #   Action 'repaired' - it was missing and komorebi accepted the new subscription
    #   Action 'offline'  - it is still missing after every attempt; Detail is the exact
    #                       command that would fix it by hand
    #   Action 'unknown'  - yasb.log has no pipe for the current process; nothing to check
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Komorebic,

        # The supervisor reaches this right after `[ok] komorebi ready`, which can be
        # before YASB's listener has created its pipe at all. Waiting here is what keeps
        # the check from being a race of its own. Measured on this machine: YASB creates
        # the pipe ~10-15 s after the process starts, and the supervisor gets here ~10 s
        # in, so 25 s bounds a healthy-but-slow logon without stalling a broken one.
        [int]$WaitForPipeSeconds = 25,

        # komorebi accepts a subscription immediately when it is not busy, and the
        # "connected" line is written by YASB the moment the pipe handshake completes.
        [int]$WaitForConnectSeconds = 15,

        # A second attempt costs nothing and covers the case where the first one landed
        # inside the same lock contention window that caused the problem.
        [int]$Attempts = 2,

        [int]$PollMilliseconds = 500
    )

    $verdict = [pscustomobject]@{
        Pipe     = $null
        Action   = 'unknown'
        Detail   = 'no pipe from the current YASB instance in yasb.log'
        Attempts = 0
    }

    $pollMs = [Math]::Max($PollMilliseconds, 1)
    $polls  = [int]([Math]::Max($WaitForPipeSeconds, 0) * 1000 / $pollMs)

    $sub = $null
    for ($i = 0; $i -le $polls -and -not $sub; $i++) {
        $sub = Get-YasbPipeSubscription -Path $Path
        if (-not $sub) { Start-Sleep -Milliseconds $pollMs }
    }
    if (-not $sub) { return $verdict }

    $verdict.Pipe = $sub.Pipe
    if ($sub.Connected) {
        $verdict.Action = 'ok'
        $verdict.Detail = 'subscription present'
        return $verdict
    }

    $connectPolls = [int]([Math]::Max($WaitForConnectSeconds, 0) * 1000 / $pollMs)
    for ($attempt = 1; $attempt -le [Math]::Max($Attempts, 1); $attempt++) {
        $verdict.Attempts = $attempt

        # `subscribe` (not the documented `subscribe-pipe`) on purpose: it is the exact
        # command YASB itself issues, so if the alias is ever removed YASB breaks too and
        # the tests below say so first. stderr is dropped because komorebic writes a
        # harmless "there is no container/window"-class noise to it; the verdict comes
        # from the log, never from the exit code.
        try { & $Komorebic subscribe $sub.Pipe 2>$null | Out-Null } catch { }

        for ($i = 0; $i -le $connectPolls; $i++) {
            Start-Sleep -Milliseconds $pollMs
            $now = Get-YasbPipeSubscription -Path $Path
            if ($now -and $now.Connected -and $now.Pipe -eq $sub.Pipe) {
                $verdict.Action = 'repaired'
                $verdict.Detail = 'subscription re-established'
                return $verdict
            }
        }
    }

    # Name the pipe that exists NOW: a YASB restart in the middle of a repair gives the
    # listener a new uuid, and the log line the user reads must name the live pipe.
    $current = Get-YasbPipeSubscription -Path $Path
    if ($current -and $current.Pipe) { $verdict.Pipe = $current.Pipe }

    $verdict.Action = 'offline'
    $verdict.Detail = "komorebic subscribe $($verdict.Pipe)"
    return $verdict
}
