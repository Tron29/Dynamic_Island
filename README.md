# Sarıyer Dynamic Island

Windows desktop prayer island and music player, built with Rainmeter and a native PowerShell/WPF companion.

- Live Sarıyer/Istanbul prayer times, with a compact progress pill and expanded daily timetable.
- Spotify and supported browser media controls, centered artwork, audio-reactive bars and album colors.
- One continuous surface resizes between compact, expanded and song-change notification views.
- Folded island stays on the desktop; hold the pointer at the top center for one second to reveal it over an app.
- Over apps, notifications slide fully in and out through the screen edge.
- Outside clicks immediately close manual panels; notifications use a short delay, with a fresh countdown on each new track.
- Moon & Sound navigation icons, Windows accent colors, and controls excluded from Alt+Tab.
- Choose Prayer, Player or Calendar as the default home view.
- Calendar has a compact next-event view, daily agenda with date navigation, and minimal ten-minute reminders. Click an event to open Google Calendar (event URL when available, otherwise its date).
- Click album artwork to open the playing app/browser. Click or drag the song progress bar to seek when supported.
- Optional separate Google Calendar widget with a local iCal connection.

## Requirements

Windows 10/11, Rainmeter, Node.js, and Windows PowerShell 5.1. Install Rainmeter and Node.js yourself before setup. No Lively installation is needed. Media players must publish Windows media sessions. Sound bars meter active playback outputs and respect their volume/mute settings, so other computer sounds can influence them.

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

`Rainmeter Widgets/` contains the native data-skin generator, Lua timetable logic, WPF island, calendar views and audio meter. `Start-Music.ps1` deploys both `Music-Island.ps1` and `Calendar-Island.ps1` together. `Prayer Wallpaper/` contains the timetable, calendar sync and earlier wallpaper implementation retained as supporting source/history. Desktop wallpaper is not required for the widgets.

## Sharing and privacy

This repository excludes personal runtime backups, private calendar feeds, cached events, generated skins and local settings. Each user connects their own calendar. No audio is recorded and the microphone is not accessed. The original local backup is not part of this repository.

## Known limitations

Windows scaling changes physical dimensions. Exclusive fullscreen/protected windows may cover notifications. Compact visibility follows desktop focus and visible-app detection on the primary screen. The native prayer skin supplies data only; all visible island views share one WPF window. Browser metadata quality depends on the website; generic social-site tab notifications are filtered. The new fresh-install script has been syntax-checked but has not been exercised on a separate clean Windows machine.
