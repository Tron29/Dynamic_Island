param([switch]$RefreshCalendar)

$ErrorActionPreference = 'Stop'
$skinRoot = Join-Path $env:LOCALAPPDATA 'Sariyer Widgets\Rainmeter\Skins\SariyerWidgets'
$rainmeterExe = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
if (-not (Test-Path -LiteralPath $rainmeterExe)) { throw 'The existing Rainmeter installation could not be found.' }
if (-not (Test-Path -LiteralPath (Join-Path $skinRoot '@Resources\Prayer.inc'))) {
    throw 'The existing widget installation could not be found. See PROJECT-NOTES.md.'
}

& node (Join-Path $PSScriptRoot 'Rainmeter Widgets\build.js') $skinRoot
if ($LASTEXITCODE -ne 0) { throw 'Widget build failed.' }
Start-Process -FilePath $rainmeterExe -ArgumentList @('!Refresh', '"SariyerWidgets\Prayer"') -WindowStyle Hidden -Wait
# Calendar is rendered only inside the unified island.
Start-Process -FilePath $rainmeterExe -ArgumentList @('!DeactivateConfig', '"SariyerWidgets\Calendar"') -WindowStyle Hidden -Wait
Write-Output 'Widget source built and refreshed.'
