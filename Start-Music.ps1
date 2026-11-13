$ErrorActionPreference = 'Stop'
$destination = Join-Path $env:LOCALAPPDATA 'Sariyer Widgets'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rainmeter Widgets\Music-Island.ps1') -Destination (Join-Path $destination 'Music-Island.ps1')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rainmeter Widgets\AudioMeter.cs') -Destination (Join-Path $destination 'AudioMeter.cs')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rainmeter Widgets\Calendar-Island.ps1') -Destination (Join-Path $destination 'Calendar-Island.ps1')
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $destination 'Music-Island.ps1') + '"'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'Sariyer Music Island.lnk'))
$shortcut.TargetPath=$powershell
$shortcut.Arguments=$arguments
$shortcut.WindowStyle=7
$shortcut.Save()
Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden
Write-Output 'Music island started and added to Windows sign-in.'
