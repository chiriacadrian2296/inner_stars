# Project terminology

## UI conventions

- Cancel actions are always secondary and grey (`colors.muted`), including
  their text labels. Never use gold for Cancel.


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
  constellation, lit/unlit star, pulsar, nascent/extinguished star.
- Sky and management flows use life area, project, victory, goal, habit,
  opportunity and archived. Activities is the umbrella for victories,
  goals and habits. See `docs/terminology.md` for the full mapping.
- Archiving an activity is distinct from permanently deleting a project.
  Keep persisted enum values and legacy identifiers compatible.
