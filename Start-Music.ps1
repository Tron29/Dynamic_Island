$ErrorActionPreference = 'Stop'
$destination = Join-Path $env:LOCALAPPDATA 'Sariyer Widgets'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rainmeter Widgets\Music-Island.ps1') -Destination (Join-Path $destination 'Music-Island.ps1')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rainmeter Widgets\AudioMeter.cs') -Destination (Join-Path $destination 'AudioMeter.cs')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rainmeter Widgets\Calendar-Island.ps1') -Destination (Join-Path $destination 'Calendar-Island.ps1')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rainmeter Widgets\Focus-Island.ps1') -Destination (Join-Path $destination 'Focus-Island.ps1')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rainmeter Widgets\FocusRing.cs') -Destination (Join-Path $destination 'FocusRing.cs')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rainmeter Widgets\Island-Settings.ps1') -Destination (Join-Path $destination 'Island-Settings.ps1')
foreach($file in 'Island-Preferences.ps1','Island-Reminders.ps1','Island-Swipe.ps1','TouchpadSwipe.cs','Calendar-Connect.js'){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('Rainmeter Widgets\'+$file)) -Destination (Join-Path $destination $file)}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rainmeter Widgets\Sounds') -Destination $destination -Recurse -Force
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $destination 'Music-Island.ps1') + '"'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'Sariyer Music Island.lnk'))
$shortcut.TargetPath=$powershell
$shortcut.Arguments=$arguments
$shortcut.WindowStyle=7
$shortcut.Save()
$process=Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $destination 'Music-Island-startup.log')
Start-Sleep -Milliseconds 1200
if($process.HasExited -and $process.ExitCode -ne 0){throw ('Island startup failed. See '+(Join-Path $destination 'Music-Island-startup.log'))}
Write-Output 'Music island started and added to Windows sign-in.'
