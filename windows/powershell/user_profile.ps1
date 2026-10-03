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





