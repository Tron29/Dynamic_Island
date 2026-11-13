# Project working preferences

- Use this folder as the canonical source for Sarıyer Dynamic Island.
- The user wants lower context/token consumption: for architecture, relationships, and navigation, query the existing `graphify-out/graph.json` first, then read only the relevant source sections.
- If the local graph is absent, use targeted lookups; do not build it just to begin routine work.
- For a small edit with a known location, use a targeted search/read when cheaper than graph traversal. Do not rebuild the whole graph for routine questions.
- Verify graph findings against current source before changing code. The graph is a navigation aid with documented unresolved links and incomplete extraction; it is not authoritative runtime evidence.
- After meaningful structural changes, update the affected graph incrementally when useful. Avoid unnecessary semantic re-extraction and repeated full-file reads.
- Keep private runtime backups, calendar feeds and event caches local. Do not include them in graphs or uploads.
- Preserve the installed live prayer mode and existing widgets unless the requested work requires changing them.
