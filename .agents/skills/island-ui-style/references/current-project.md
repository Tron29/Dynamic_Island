# Current project reference

Canonical source: `C:/Users/islam/OneDrive/Документы/ChatGPT/apps creation/Sariyer Dynamic Island`.

- `Rainmeter Widgets/Music-Island.ps1`: shared WPF window, black surface, panel header, prayer/player presentations, resizing and content transitions.
- `Rainmeter Widgets/Focus-Island.ps1`: timer presentation and saved countdown state, editable name, presets/custom entry, nested break rings.
- `Rainmeter Widgets/FocusRing.cs`: remaining-ratio circular renderer. Ratio 1 is full and 0 is empty. Use double precision when calculating intermediate values in PowerShell; integer Math.Min/Max overloads previously rounded progress incorrectly.
- `Rainmeter Widgets/Calendar-Island.ps1`: calendar compact/expanded/notification views on the shared surface.
- `Rainmeter Widgets/Island-Settings.ps1`: functional settings, but its appearance is not an approved style reference.
- `Start-Music.ps1`: installs current source into `%LOCALAPPDATA%/Sariyer Widgets` and launches it. The source directory remains authoritative.

Read the project's `AGENTS.md` before changing it. Use targeted reads for known edits; use the existing graph for broad navigation. Do not recreate the legacy Rainmeter prayer pill or standalone calendar widget.

Existing physical sizes are expressed in logical WPF units, with an oversized transparent host window. Common black-surface widths: Player compact 296, Focus compact 336, Calendar compact 336, Prayer compact 428. Heights and expanded widths vary by content; verify the current source rather than copying these blindly.

Preserve UTF-8 BOM on Windows PowerShell scripts. The island is a nonactivating tool window, absent from Alt-Tab. Deliberate text-field interaction temporarily enables keyboard activation; exiting editing restores nonactivation. Do not break name/custom-time editing while changing templates.

The local `graphify-out/` folder contains disposable WPF regression harnesses and rendered previews. They are not authoritative design assets and can contain older source snapshots. Refresh a harness against current source before treating a passing result as verification of a new change.
