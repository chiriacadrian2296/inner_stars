# Nomenclature

Galaxy is the visual universe (`SkyScreen`). Sky is the searchable browser
(`SkySearchScreen` / `SkyExplorerView`). These names identify screens, not entities.

| Meaning | Sky and management flows | Galaxy tooltip |
| --- | --- | --- |
| Life domain | Area / Area | Supernova |
| Group of related activities | Project / Progetto | Constellation / Costellazione |
| Completed effort | Victory / Vittoria | Lit star / Stella accesa |
| Future effort | Goal / Obiettivo | Unlit star / Stella da accendere |
| Repeated effort | Habit / Abitudine | Pulsar |
| Unconfigured slot | Opportunity / Opportunità | Nascent star / Stella nascente |
| Archived activity | Archived / Archiviato | Dead star / Stella spenta |

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

## Habit cycles and reward

A habit (pulsar) works in **cycles**. The user picks a cycle length (7, 30 or
90 distinct days, or a custom number) and a **reward**: the habit's intensity,
on the same 1-5 scale as every star. The intensity is earned once, when the
cycle's last needed day is done, and counts in the statistics like a lit star
of that intensity (calendar, constellation and area totals, sorting). There is
no deadline: only reaching the length matters, never how often or how fast.

- One repetition is one distinct day with at least one check-in.
- The habit's frequency (daily/weekly and target) is only the rhythm the user
  would like. It never decides whether the pulsar is lit (any check-in today
  does) and never reduces a reward.
- Reaching the length records a completed cycle (`HabitCycle`) at once, and the
  end-of-cycle reflection page opens when it happens today. The user answers
  optional questions and chooses: start again, change length and reward, or wrap
  the habit up (archive). A reflection left for later stays reachable from the
  pulsar ("Reflect on the Cycle").
- Undoing the check-in that completed a cycle before its reflection was
  finished takes the cycle back; a reflected cycle is never taken back.
- Reactivating an archived habit starts a fresh cycle today but keeps the cycles
  it already completed: a reward that was earned is never removed.
