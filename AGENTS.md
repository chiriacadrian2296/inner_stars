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

# Workflow

- `main` is production: every push to it publishes the web app and the
  landing. **Never work on `main`** (no edits, no commits, no direct pushes),
  not even for a one-line fix or a docs change. The only exception is the user
  explicitly saying to work on `main`.
- **Before changing any file, every time:** check the current branch
  (`git branch --show-current`) and tell the user which one you are on. Then
  ask the user what the work is about so the branch can be named before any
  edit. Proposing a name is fine; wait for the answer. If branches with
  ongoing work exist (`git branch`), name them and ask whether to continue on
  one of those instead of starting a new one.
- Once the user has answered, create the branch from an up-to-date `main` (or
  switch to the chosen branch), say so in one line, and only then start
  editing. Commit and push on that branch, and merge the whole branch into
  `main` only when the user says it is finished and tested. Do not
  cherry-pick individual commits.
- Pushing a branch only runs the `Checks` workflow (analyze and tests); it
  publishes nothing. The web deploy also runs analyze and tests first.
- **Local checks are targeted, not the whole suite.** After an edit run
  `flutter analyze --no-pub` and `flutter test <the test files for the code you
  touched>` (tests named after the file, or the tests that import it). Do not
  run the full suite (600+ tests) or web/APK builds for small or UI-only
  changes: the `Checks` workflow runs everything on every branch push and before
  every deploy. Run the full suite locally only when you touch shared code that
  can break things far away (models, sync, theme, localization strings,
  repositories) or when the user asks. Say which tests you ran.
- **Keep each change lean.** Fewer steps per edit means less waiting: format
  and analyze only the files you touched (`dart format <files>`,
  `flutter analyze --no-pub <files>`), not all of `lib`; prefer small targeted
  edits over long patch or replace scripts; locate with a search and read only
  the line ranges you need instead of whole large files; run independent
  commands together; do not repeat a check that already passed. Keep replies
  short.
- Synced models only get new optional fields; never rename or remove existing
  ones, because app versions and cloud data coexist.
- Development tools stay behind `kDevTools`. An unfinished user-facing
  feature stays on its branch. See `docs/workflow.md`.
