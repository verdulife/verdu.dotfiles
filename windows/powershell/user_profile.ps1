Import-Module Terminal-Icons
Import-Module PSReadLine

$env:HERDR_WINDOWS_CONPTY = "system"

function Get-ScriptDirectory { Split-Path $MyInvocation.ScriptName }
Invoke-Expression (&starship init powershell)
fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression

function sudo() {
  if ($args.Length -eq 1) { start-process $args[0] -verb "runAs" }
  if ($args.Length -gt 1) { start-process $args[0] -ArgumentList $args[1..$args.Length] -verb "runAs" }
}

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Chord "Ctrl+RightArrow" -Function ForwardWord
Set-PSReadLineOption -Colors @{ InlinePrediction = '#444444'}

Set-Alias vim nvim
Set-Alias ll ls
Set-Alias g git
Set-Alias grep findstr
Set-Alias tig 'C:\Program Files\Git\usr\bin\tig.exe'
Set-Alias less 'C:\Program Files\Git\usr\bin\less.exe'

if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected) {
  $ascii = @'
    _/\/\__/\/\____/\/\/\____/\/\__/\/\________/\/\__/\/\__/\/\_
   _/\/\__/\/\__/\/\/\/\/\__/\/\/\/\______/\/\/\/\__/\/\__/\/\_
  ___/\/\/\____/\/\________/\/\________/\/\__/\/\__/\/\__/\/\_
 _____/\________/\/\/\/\__/\/\__________/\/\/\/\____/\/\/\/\_
'@
  $colors = @('Cyan', 'DarkCyan', 'Magenta', 'DarkMagenta')
  $i = 0
  foreach ($line in $ascii -split "`r?`n") {
    if ($line.Trim()) { Write-Host $line -ForegroundColor $colors[$i % $colors.Count] }
    $i++
  }
  Remove-Variable ascii, colors, i
}






# --- Migrated from this machine's previous profile (dotfiles port) -----------
# These blocks lived only on this machine, not in the repo profile. They are kept
# so that adopting the repo profile loses no local functionality.

# godot: launcher for the WinGet-installed Godot editor.
# NOTE: Godot is not currently installed on this machine; this path is stale.
function godot {
    & "C:\Users\verdu\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe" @args
}

# yazi: cd to the last visited directory on exit; pass yazi subcommands through
function ya {
  if ($args.Length -gt 0 -and $args[0] -in @('pkg', 'pack', 'help', 'h', '--help', '-h', '--version', '-V')) {
    ya.exe @args
    return
  }
  $tmp = Join-Path $env:TEMP ("yazi-cwd-{0}.tmp" -f [guid]::NewGuid().ToString("N"))
  yazi @args "--cwd-file=$tmp"
  if (Test-Path $tmp) {
    $cwd = (Get-Content -Raw $tmp).Trim()
    if ($cwd -and $cwd -ne (Get-Location).Path) { Set-Location -LiteralPath $cwd }
    Remove-Item -Force $tmp -ErrorAction SilentlyContinue
  }
}

# herdr: auto-attach if the server has active panes. Kept last on purpose, so the
# banner above has already been printed before herdr takes over the console.
if ($Host.Name -eq 'ConsoleHost' -and -not $env:HERDR_ENV) {
    $srv = herdr status server --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($srv.running) {
        $wsList = herdr workspace list 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($wsList.result.workspaces | Where-Object { $_.pane_count -gt 0 }) {
            herdr
        }
    }
}
