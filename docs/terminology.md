# Nomenclature

Galaxy is the visual universe (`SkyScreen`). Sky is the searchable browser
(`SkySearchScreen` / `SkyExplorerView`). These names identify screens, not entities.

| Meaning | Sky and management flows | Galaxy tooltip |
| --- | --- | --- |
| Life domain | Life area / Area di vita | Supernova |
| Group of related activities | Project / Progetto | Constellation / Costellazione |
| Completed effort | Victory / Vittoria | Lit star / Stella accesa |
| Future effort | Goal / Obiettivo | Unlit star / Stella da accendere |
| Repeated effort | Habit / Abitudine | Pulsar |
| Unconfigured slot | Opportunity / Opportunità | Nascent star / Stella nascente |
| Archived activity | Archived / Archiviato | Extinguished star / Stella spenta |

Use domain names in forms, readers, statistics, search, filters and counts.
“Activities” / “Attività” is the umbrella for victories, goals and habits.
Galaxy tooltip entity labels use the celestial names. Shape editors and graphic
settings also name the celestial objects they manipulate. Onboarding and the
metaphor guide explicitly explain the mapping; narrative copy may use the metaphor.

Archiving keeps the existing record and its location in Galaxy. Reactivation
follows the existing lifecycle: an archived habit restarts as a new habit with a
fresh streak and clears its old completions on reactivation. Archiving alone
retains that history. This terminology does not change storage or behavior.
Deleting a project remains a permanent deletion and must
retain its distinct action and confirmation.

Use `StarKind.label` / `plural` for domain labels and `StarKind.galaxyLabel` for
Galaxy tooltip labels. Do not reuse `areaLabel` or `projectLabel` in Galaxy tooltips;
use `galaxyAreaLabel` and `galaxyProjectLabel`. Legacy model names, localization
keys and persisted enum values remain compatible and can be renamed separately.

An archived item's type label includes its original type icon immediately to the
right, in the text's color (including accessibility text scaling). Detail labels
use the text's font size for the icon. Compact uppercase labels use an icon at
1.4 times that size, raised by 0.1 times the font size for optical alignment.
This applies to Sky cards, readers, Galaxy tooltips, gallery and project maps.
Galaxy keeps the celestial label while showing the same original-type icon.
