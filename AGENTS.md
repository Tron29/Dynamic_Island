# Project working preferences

- Use this folder as the canonical source for Sarıyer Dynamic Island.
- The user wants lower context/token consumption: for architecture, relationships, and navigation, query the existing `graphify-out/graph.json` first, then read only the relevant source sections.
- If the local graph is absent, use targeted lookups; do not build it just to begin routine work.
- For a small edit with a known location, use a targeted search/read when cheaper than graph traversal. Do not rebuild the whole graph for routine questions.
- Verify graph findings against current source before changing code. The graph is a navigation aid with documented unresolved links and incomplete extraction; it is not authoritative runtime evidence.
- After meaningful structural changes, update the affected graph incrementally when useful. Avoid unnecessary semantic re-extraction and repeated full-file reads.
- Keep private runtime backups, calendar feeds and event caches local. Do not include them in graphs or uploads.
- Preserve the installed live prayer mode and existing widgets unless the requested work requires changing them.

- Future packaging plan (discussed, not authorized to implement yet): migrate the remaining Rainmeter prayer-data and Node.js calendar work into a standalone C#/.NET app, preserving the existing WPF design. Prefer a self-contained Windows installer plus a portable EXE through GitHub Releases, with no separate Rainmeter/Node installation for users. Do not begin this migration until requested.

- Keep future feature ideas in FEATURE-ROADMAP.md; update status when implemented.

- For visual changes to the island panels, use the saved style skill at .agents/skills/island-ui-style/SKILL.md. Its approved reference is the main island; the settings window design is explicitly excluded.
