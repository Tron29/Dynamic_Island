$ErrorActionPreference='Stop'
$rainmeter=Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
if(-not(Test-Path -LiteralPath $rainmeter)){throw 'Install Rainmeter first.'}
if(-not(Get-Command node -ErrorAction SilentlyContinue)){throw 'Install Node.js first.'}
if(Get-Process Rainmeter -ErrorAction SilentlyContinue){throw 'Close Rainmeter before setup.'}
$profilePath=Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
if(Test-Path -LiteralPath $profilePath){throw 'An existing Rainmeter profile was found. See README.md for manual setup.'}
$helper=Join-Path $env:LOCALAPPDATA 'Sariyer Widgets'
$skins=Join-Path $helper 'Rainmeter\Skins'
$skin=Join-Path $skins 'SariyerWidgets'
New-Item -ItemType Directory -Path $skin -Force | Out-Null
& node (Join-Path $PSScriptRoot 'Rainmeter Widgets\build.js') $skin
if($LASTEXITCODE -ne 0){throw 'Skin build failed.'}
foreach($file in 'calendar-sync.js','package.json','package-lock.json'){
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('Prayer Wallpaper\'+$file)) -Destination (Join-Path $helper $file)
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Rainmeter Widgets\calendar-setup.js') -Destination (Join-Path $helper 'calendar-setup.js')
Push-Location -LiteralPath $helper
try{ & npm.cmd ci --omit=dev; if($LASTEXITCODE -ne 0){throw 'Calendar dependency setup failed.'} }finally{Pop-Location}
@{dataPath=(Join-Path $skin '@Resources\CalendarData.lua')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $helper 'rainmeter-target.json') -Encoding utf8
New-Item -ItemType Directory -Path (Split-Path $profilePath) -Force | Out-Null
@"
[Rainmeter]
SkinPath=$skins\
[SariyerWidgets\Prayer]
Active=1
WindowX=0
WindowY=0
Draggable=0
AlwaysOnTop=-2
"@ | Set-Content -LiteralPath $profilePath -Encoding unicode
$shell=New-Object -ComObject WScript.Shell
$startup=[Environment]::GetFolderPath('Startup')
$link=$shell.CreateShortcut((Join-Path $startup 'Rainmeter.lnk'));$link.TargetPath=$rainmeter;$link.Save()
$vbs=Join-Path $helper 'watch-calendar.vbs'
$node=(Get-Command node).Source
('CreateObject("WScript.Shell").Run """'+$node+'"" ""'+(Join-Path $helper 'calendar-sync.js')+'""", 0, False') | Set-Content -LiteralPath $vbs -Encoding unicode
$link=$shell.CreateShortcut((Join-Path $startup 'Sariyer Calendar Sync.lnk'));$link.TargetPath=(Join-Path $env:SystemRoot 'System32\wscript.exe');$link.Arguments='"'+$vbs+'"';$link.Save()
Start-Process -FilePath $rainmeter -WindowStyle Hidden
Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\wscript.exe') -ArgumentList ('"'+$vbs+'"') -WindowStyle Hidden
& (Join-Path $PSScriptRoot 'Start-Music.ps1')
Write-Output 'Setup complete. Prayer is live; calendar connection is optional.'
