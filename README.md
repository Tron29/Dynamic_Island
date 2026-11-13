# Sarıyer Dynamic Island

Windows desktop prayer island and music player, built with Rainmeter and a native PowerShell/WPF companion.

- Live Sarıyer/Istanbul prayer times, with a compact progress pill and expanded daily timetable.
- Spotify and supported browser media controls, centered artwork, audio-reactive bars and album colors.
- Compact, expanded and song-change notification views; outside-click dismissal.
- Choose Prayer or Player as the default home view.
- Optional separate Google Calendar widget with a local iCal connection.

## Requirements

Windows 10/11, Rainmeter, Node.js, and Windows PowerShell 5.1. Install Rainmeter and Node.js yourself before setup. No Lively installation is needed. Media players must publish Windows media sessions. Sound bars meter the default playback output, so other computer sounds can influence them.

## First installation

Download this repository as a ZIP and extract it, or clone it. Close Rainmeter before setup. Run `Install.ps1` in PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

The installer is for a fresh Rainmeter profile. It stops if an existing Rainmeter configuration is found, to avoid replacing another setup. Existing Rainmeter users should build the skins into their skin folder manually and adapt the helper paths; do not replace an existing configuration blindly.

Setup creates the skins and helper under `%LOCALAPPDATA%\Sariyer Widgets`, starts the prayer/music widgets, and adds sign-in shortcuts. Demo mode is off. Location and timetable are currently fixed to Istanbul/Sarıyer. Prayer data is refreshed from the timetable API, with the bundled schedule as fallback; future coverage depends on data availability.

## Updating

Edit sources in this folder. `Update-Widget.ps1` builds and refreshes the native prayer skin while preserving installed settings. Add `-RefreshCalendar` to refresh the calendar skin. To update music, stop the PowerShell process whose command line ends in `Music-Island.ps1`, then run `Start-Music.ps1`. Sync/connection helper changes must be copied to the local helper folder separately.

## Calendar

Calendar integration is optional and disabled until you supply your own iCal feed. Run the local helper's `calendar-setup.js` using Node.js to connect your calendar. Feed addresses and cached events stay on your machine. Activate `SariyerWidgets\Calendar` through Rainmeter if desired.

## Sources

`Rainmeter Widgets/` contains the native skin generator, Lua behavior, WPF player and audio meter. `Prayer Wallpaper/` contains the timetable, calendar sync and earlier wallpaper implementation retained as supporting source/history. Desktop wallpaper is not required for the widgets.

## Sharing and privacy

This repository excludes personal runtime backups, private calendar feeds, cached events, generated skins and local settings. Each user connects their own calendar. No audio is recorded and the microphone is not accessed. The original local backup is not part of this repository.

## Known limitations

Windows scaling changes physical dimensions. Exclusive fullscreen/protected windows may cover notifications. The compact WPF player is a regular non-topmost window; it does not yet enforce Rainmeter's desktop-only placement. Browser metadata quality depends on the website; generic social-site tab notifications are filtered. The new fresh-install script has been syntax-checked but has not been exercised on a separate clean Windows machine.
