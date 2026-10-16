# Project terminology

## UI conventions

- Do not add app bars to new pages. Put page titles in the page content,
  following the existing screens.

- In “Vedi”, keep Statistics, Edit and Archive/Delete together. Fly is the
  last action on the right, in its own group, because it returns to Galaxy.

- Group separator dots in “Vedi” use their delayed fade entrance after the
  buttons, without drift.
- Personal activity icons appear in management and statistics cards;
  Galaxy keeps its astronomical glyphs.

- Cancel actions are always secondary and grey (`colors.muted`), including
  their text labels. Never use gold for Cancel.

- Quick Settings are currently hidden and inaccessible. Do not mirror new
  settings there while they remain hidden; add them only to the main Settings
  screen unless Quick Settings are explicitly restored.


- **Galaxy** (formerly called Cosmo; the original name) is the visual
  universe screen implemented by `SkyScreen`: it has the animated star field
  and the main floating menu button. Say Galaxy, not Cosmo, in discussion,
  documentation, and new code comments; older code, strings and tests may
  still say Cosmo until migrated.
- **Sky** is the searchable three-level browser implemented by
  `SkySearchScreen` / `SkyExplorerView` (formerly called Search in the UI).
- Use these names in discussion, documentation, and new code comments even
  where older class names have not yet been migrated.
- Galaxy tooltip entity labels use astronomical names: supernova,
  constellation, lit/unlit star, pulsar, nascent/dead star.
- Sky and management flows use area, project, victory, goal, habit,
  opportunity and archived. Activities is the umbrella for victories,
  goals and habits. See `docs/terminology.md` for the full mapping.
- Archiving an activity is distinct from permanently deleting a project.
  Keep persisted enum values and legacy identifiers compatible.
