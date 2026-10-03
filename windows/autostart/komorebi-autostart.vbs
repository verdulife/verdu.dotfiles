' Komorebi setup autostart launcher (windowless).
' Remove this file (and C:\Users\verdu\komorebi-autostart.ps1) to disable autostart.
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""C:\Users\verdu\komorebi-autostart.ps1""", 0, False