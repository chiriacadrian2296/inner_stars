import '../data/constellation_layout.dart' show kMaxConstellationStars;
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../models/life_area.dart';
import '../models/habit.dart';
import '../models/project.dart';
import '../models/star_media.dart';
import '../utils/date_math.dart';

/// How many stars each seed project (by spec index) is filled up to the first
/// time [seedSampleData] runs — deliberately uneven, so the Sky and Cosmo show
/// every density side by side: a few constellations completely full
/// ([kMaxConstellationStars]), a bunch half-grown, and the rest with only a
/// handful of stars. Counts every star on the shape (lit, unlit and dead),
/// history included; a project already at or past its target gains nothing.
const _starTargets = [
  30, 14, 22, 30, 8, 16, 30, 6, 5, //
  12, 4, 18, 6, 30, 10, 3, 26, 8, //
  14, 5, 30, 9, 20, 7,
];

/// Target for a spec index past [_starTargets] (never reached by the current
/// 24 specs, but a longer list shouldn't crash).
const _defaultStarTarget = 8;

int _starTargetFor(int specIndex) => specIndex < _starTargets.length
    ? _starTargets[specIndex]
    : _defaultStarTarget;

/// Picsum-backed photos are attached to four out of every five sample wins.
/// The remaining fifth deliberately stays photo-less so both UI states are
/// represented in the generated data.
String? _samplePhotoUrl(int projectIndex, int winPosition) {
  if ((projectIndex + winPosition) % 5 == 0) return null;
  return 'https://picsum.photos/seed/inner-stars-$projectIndex-$winPosition/'
      '720/1280';
}

const _loremDescriptions = [
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod '
      'tempor incididunt ut labore et dolore magna aliqua.',
  'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi '
      'ut aliquip ex ea commodo consequat.',
  'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum '
      'dolore eu fugiat nulla pariatur.',
  'Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia '
      'deserunt mollit anim id est laborum.',
];

String? _sampleDescription(_WinSeed phrase, int projectIndex, int winPosition) {
  if (phrase.description != null) return phrase.description;
  if ((projectIndex + winPosition) % 6 == 0) return null;
  return _loremDescriptions[(projectIndex * 3 + winPosition) %
      _loremDescriptions.length];
}

/// A small set of the newest sample victories gets a pair of secondary
/// photos, making the media gallery visible near the top of the archive.
List<StarMedia> _sampleSecondaryPhotos({
  required int projectIndex,
  required int winPosition,
  required int dayOffset,
  required DateTime achievedDate,
}) {
  if (dayOffset > 1 || (projectIndex + winPosition) % 3 != 0) return const [];
  return [
    for (var index = 0; index < 2; index++)
      StarMedia(
        id: 'sample-$projectIndex-$winPosition-$index',
        kind: StarMediaKind.photo,
        path:
            'https://picsum.photos/seed/inner-stars-extra-$projectIndex-'
            '$winPosition-$index/720/1280',
        createdAt: achievedDate.add(Duration(milliseconds: index)),
      ),
  ];
}

/// Backdates seeded wins so the dashboard has something to show: day
/// offsets from today (0 = today), hand-chosen — not random — to exercise
/// specific things at a glance once seeded:
/// - 0..5: a live 6-day current streak (today included).
/// - 6..7: a gap, so the streak visibly breaks in the calendar.
/// - 8..10: an older, separate 3-day streak (shorter than the current one,
///   so "longest streak" still correctly reports 6).
/// - 14 (x5) and 20/25/29: a very busy day and a few sparse single days, to
///   cover the heatmap's low/medium/high brightness tiers.
/// Every seed tap re-applies this same pattern from today, so repeat taps
/// pile more wins onto the same days (brighter, not further back) — which
/// suits the dashboard's calendar now only showing the current month.
const _dayOffsets = [
  0, 0, 0, 1, 1, 2, 3, 4, 5, //
  8, 8, 9, 10, //
  14, 14, 14, 14, 14, //
  20, 25, 29,
];

/// Debug helper: grows a fixed set of projects — with plausible, hand-written
/// wins, not random word salad — spread across most areas, so the
/// Sky/constellation UI can be explored without hand-entering data.
///
/// Idempotent on the *project* level — re-running finds each project by name
/// and reuses it instead of creating a duplicate. Which wins get added is
/// fully deterministic: each project's phrase list is cycled through in a
/// fixed order based on how many wins it already has, so running this
/// repeatedly (or on a fresh install) always produces the same sequence of
/// content — nothing here is randomized. Every project is filled up to its
/// own [_starTargets] entry (some completely full, some half-grown, some
/// nearly empty), so one tap gives the whole range of densities and further
/// taps add nothing. Returns how many stars were added. Spiritual is left
/// with no seed project, to exercise that area's empty state.
///
/// [languageCode] picks which translation of the seed content to use (see
/// [_specsFor]) — matching [SettingsController.locale] so the seeded
/// projects read naturally in whichever language the app is already set
/// to, the same way every other piece of app-facing text does.
///
/// Idempotency is keyed on the project's position in the spec list (its
/// index — the same conceptual project across [_specsEn]/[_specsIt]/
/// [_specsRo]), not on its display name alone: a project already seeded
/// under an *older* locale's name is found via [_alternateNamesAt] and
/// renamed to the current locale's name in place (see
/// [ProjectRepository.renameProject]) rather than spawning a same-shaped
/// duplicate next to it. Switching the app's language and re-tapping "seed
/// sample data" is what triggers this — every previously-seeded project
/// just switches language along with the rest of the app instead of
/// leaving stale foreign-language leftovers behind.
Future<int> seedSampleData({
  required StarRepository starRepository,
  required ProjectRepository projectRepository,
  required HabitRepository habitRepository,
  required HabitCompletionRepository habitCompletionRepository,
  required String languageCode,
}) async {
  final starsBefore = starRepository.getAll().length;
  final specs = _specsFor(languageCode);
  final deadStarTitle = _deadStarTitleFor(languageCode);

  assert(
    specs.every((spec) => spec.iconSlug != spec.area.iconSlug),
    'A seed project is using its own area\'s reserved icon.',
  );

  final existingProjects = projectRepository.getAll();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var globalIndex = 0;
  final projectsBySpec = <Project>[];

  for (var specIndex = 0; specIndex < specs.length; specIndex++) {
    final spec = specs[specIndex];

    // Goals/dead stars/habits are only ever seeded the first time a project
    // is created — re-tapping "seed sample data" keeps growing the win
    // count (same as before) without piling up duplicate goals/habits on
    // every tap.
    final alternateNames = _alternateNamesAt(specIndex);
    Project? project;
    for (final candidate in existingProjects) {
      if (alternateNames.contains(candidate.name)) {
        project = candidate;
        break;
      }
    }
    final isNewProject = project == null;

    if (project != null && project.name != spec.name) {
      project = await projectRepository.renameProject(
        projectId: project.id,
        name: spec.name,
      );
    }
    project ??= await projectRepository.add(
      name: spec.name,
      area: spec.area,
      iconSlug: spec.iconSlug,
    );

    projectsBySpec.add(project);
    final hasHistory = starRepository
        .getAllForProject(project.id)
        .any(
          (s) =>
              s.achievedDate != null &&
              s.achievedDate!.isBefore(addDays(today, -_historyStartDays + 1)),
        );

    final target = _starTargetFor(specIndex);
    int remaining() =>
        target - starRepository.getAllForProject(project!.id).length;

    // Fixed content first, so even a tiny constellation keeps its history
    // and goals for the Statistics page; the recent wins fill what's left.
    if (!hasHistory) {
      await _seedStarHistory(
        starRepository: starRepository,
        project: project,
        spec: spec,
        specIndex: specIndex,
        today: today,
        maxCount: remaining(),
      );
    }

    if (isNewProject) {
      for (final goalTitle in spec.goals) {
        if (remaining() <= 0) break;
        await starRepository.add(title: goalTitle, projectId: project.id);
        await Future.delayed(const Duration(milliseconds: 2));
      }

      if (spec.seedDeadStar && remaining() > 0) {
        // Created then immediately deleted, so there's a tombstoned star
        // ready to exercise the "resurrect" flow without the user having to
        // delete one by hand first.
        final deadSeed = await starRepository.add(
          title: deadStarTitle,
          projectId: project.id,
        );
        await Future.delayed(const Duration(milliseconds: 2));
        await starRepository.delete(deadSeed.id);
        await Future.delayed(const Duration(milliseconds: 2));
      }
    }

    final startingCount = starRepository.getAllForProject(project.id).length;
    for (var i = 0; remaining() > 0; i++) {
      final position = startingCount + i;
      final phrase = spec.wins[position % spec.wins.length];
      final dayOffset = _dayOffsets[globalIndex % _dayOffsets.length];
      final hour = 8 + (globalIndex * 3) % 14;
      final minute = (globalIndex * 17) % 60;
      final date = today
          .subtract(Duration(days: dayOffset))
          .add(Duration(hours: hour, minutes: minute));
      globalIndex++;

      await starRepository.add(
        title: phrase.title,
        description: _sampleDescription(phrase, specIndex, position),
        projectId: project.id,
        achievedDate: date,
        intensity: 1 + position % 5,
        photoPath: _samplePhotoUrl(specIndex, position),
        media: _sampleSecondaryPhotos(
          projectIndex: specIndex,
          winPosition: position,
          dayOffset: dayOffset,
          achievedDate: date,
        ),
      );
      // Star ids are millisecondsSinceEpoch; a tight loop without this could
      // mint duplicate ids, which every id-based lookup in the app assumes
      // can't happen.
      await Future.delayed(const Duration(milliseconds: 2));
    }

    if (!isNewProject) continue;

    for (final habitSeed in spec.habits) {
      final habit = await habitRepository.add(
        title: habitSeed.title,
        projectId: project.id,
        intensity: habitSeed.intensity,
      );
      for (final offset in habitSeed.completedDayOffsets) {
        await habitCompletionRepository.markDone(
          habit.id,
          date: today.subtract(Duration(days: offset)),
        );
      }
    }
  }

  await _seedHabitHistory(
    habitRepository: habitRepository,
    habitCompletionRepository: habitCompletionRepository,
    projects: projectsBySpec,
    languageCode: languageCode,
    today: today,
  );

  return starRepository.getAll().length - starsBefore;
}

/// Wins older than this many days mark a project as already holding seeded
/// history, so tapping the seed button again doesn't pile it up a second time.
const _historyStartDays = 36;

/// How many extra backdated wins each project (by spec index) gets, spread
/// over the ~5 months before the recent pattern — deliberately uneven, so
/// the area split, the date-range and area filters and the month paging on
/// the Statistics page all have something to show: Physical and Professional
/// dominate, Philanthropic is almost empty.
const _historyWinsPerProject = [8, 5, 7, 9, 4, 4, 4, 3, 3];

/// Backdated wins for every project past the list above (the extra, smaller
/// constellations).
const _historyWinsDefault = 3;

/// Project index that also receives an unbroken run of wins on the days
/// 50..63 ago — an old streak longer than the live one, so "longest streak"
/// and "current streak" read as two different things.
const _oldStreakProject = 3;
const _oldStreakFromDay = 50;
const _oldStreakLength = 14;

Future<void> _seedStarHistory({
  required StarRepository starRepository,
  required Project project,
  required _ProjectSeed spec,
  required int specIndex,
  required DateTime today,
  required int maxCount,
}) async {
  final count = specIndex < _historyWinsPerProject.length
      ? _historyWinsPerProject[specIndex]
      : _historyWinsDefault;
  final offsets = <int>[
    for (var k = 0; k < count; k++)
      // 36..175 days ago, scattered but deterministic.
      _historyStartDays + (k * 53 + specIndex * 29) % 140,
    if (specIndex == _oldStreakProject)
      for (var k = 0; k < _oldStreakLength; k++) _oldStreakFromDay + k,
  ];
  final startingCount = starRepository.getAllForProject(project.id).length;
  for (var k = 0; k < offsets.length && k < maxCount; k++) {
    final position = startingCount + k;
    final phrase = spec.wins[position % spec.wins.length];
    final date = addDays(today, -offsets[k]).add(
      Duration(hours: 7 + (k * 5 + specIndex) % 15, minutes: (k * 13) % 60),
    );
    await starRepository.add(
      title: phrase.title,
      description: _sampleDescription(phrase, specIndex, position),
      projectId: project.id,
      achievedDate: date,
      intensity: 1 + (position * 3 + specIndex) % 5,
      photoPath: _samplePhotoUrl(specIndex, position),
    );
    await Future.delayed(const Duration(milliseconds: 2));
  }
}

/// Cheap deterministic "randomness" 0..100 from two small ints — pure
/// arithmetic, so it gives the same history on every platform (web ints
/// don't behave like native ones under bit operations).
int _roll(int a, int b) => (a * 7919 + b * 104729 + a * b * 31) % 101;

/// One backdated pulsar for exercising the Statistics page: what it is, how
/// long ago it started, and how many times it was done on each past day.
/// [countOn] gets the number of days ago (0 = today) and that day's weekday
/// (1 = Monday) and returns how many completions to log.
class _HabitHistorySeed {
  const _HabitHistorySeed({
    required this.en,
    required this.it,
    required this.ro,
    required this.projectIndex,
    required this.startedDaysAgo,
    required this.countOn,
    this.frequency = HabitFrequency.daily,
    this.target = 1,
    this.intensity = 3,
    this.endedDaysAgo,
  });

  final String en;
  final String it;
  final String ro;
  final int projectIndex;
  final int startedDaysAgo;
  final int Function(int daysAgo, int weekday) countOn;
  final HabitFrequency frequency;
  final int target;
  final int intensity;

  /// When set, the pulsar is deleted (a dead star in the archive) after its
  /// last completion this many days ago.
  final int? endedDaysAgo;

  Set<String> get allTitles => {en, it, ro};
  String titleFor(String languageCode) => switch (languageCode) {
    'it' => it,
    'ro' => ro,
    _ => en,
  };
}

/// Covers what the pulsar section and pulsar dashboard need to be checked
/// against, one habit each:
/// - a long, mostly-done daily habit that is lit with a live streak
///   (weekends weaker, so the weekday insight has a real best/weakest day);
/// - a daily "3 times a day" habit with partial days (multi-instance counts);
/// - weekly habits: target 3 with some missed weeks, target 1 with a long
///   streak;
/// - a once-great habit that broke 5 days ago (unlit, needs attention);
/// - a brand-new habit (too little history for any pattern);
/// - a deleted habit with history (the archive sheet).
final _habitHistory = <_HabitHistorySeed>[
  _HabitHistorySeed(
    en: 'Evening walk',
    it: 'Passeggiata serale',
    ro: 'Plimbare de seară',
    projectIndex: 0,
    startedDaysAgo: 110,
    countOn: (d, wd) {
      if (d >= 30 && d <= 38) return 0; // a 9-day gap a month ago
      final chance = wd >= 6 ? 45 : (wd == 3 ? 95 : 82);
      return d < 6 || _roll(d, 1) < chance ? 1 : 0;
    },
  ),
  _HabitHistorySeed(
    en: 'Drink water',
    it: 'Bere acqua',
    ro: 'Beau apă',
    projectIndex: 0,
    startedDaysAgo: 60,
    target: 3,
    intensity: 1,
    countOn: (d, wd) => d == 0 ? 2 : (_roll(d, 2) % 5).clamp(0, 4),
  ),
  _HabitHistorySeed(
    en: 'Swim session',
    it: 'Sessione di nuoto',
    ro: 'Sesiune de înot',
    projectIndex: 1,
    startedDaysAgo: 84,
    frequency: HabitFrequency.weekly,
    target: 3,
    intensity: 4,
    countOn: (d, wd) {
      final chance = switch (wd) {
        1 => 70,
        3 => 60,
        6 => 65,
        _ => 0,
      };
      return _roll(d, 3) < chance ? 1 : 0;
    },
  ),
  _HabitHistorySeed(
    en: 'Call family',
    it: 'Chiamare la famiglia',
    ro: 'Sun familia',
    projectIndex: 7,
    startedDaysAgo: 70,
    frequency: HabitFrequency.weekly,
    intensity: 2,
    countOn: (d, wd) => wd == 7 && _roll(d, 4) < 92 ? 1 : 0,
  ),
  _HabitHistorySeed(
    en: 'Journaling',
    it: 'Scrivere il diario',
    ro: 'Scris jurnal',
    projectIndex: 2,
    startedDaysAgo: 45,
    // Done every day until 5 days ago, then nothing: a broken streak.
    countOn: (d, wd) => d >= 5 ? 1 : 0,
  ),
  _HabitHistorySeed(
    en: 'Cold shower',
    it: 'Doccia fredda',
    ro: 'Duș rece',
    projectIndex: 0,
    startedDaysAgo: 2,
    intensity: 5,
    countOn: (d, wd) => d <= 2 ? 1 : 0,
  ),
  _HabitHistorySeed(
    en: 'Learn Spanish',
    it: 'Imparare lo spagnolo',
    ro: 'Învăț spaniola',
    projectIndex: 6,
    startedDaysAgo: 120,
    endedDaysAgo: 40,
    intensity: 2,
    countOn: (d, wd) => d >= 40 && _roll(d, 5) < 70 ? 1 : 0,
  ),
];

Future<void> _seedHabitHistory({
  required HabitRepository habitRepository,
  required HabitCompletionRepository habitCompletionRepository,
  required List<Project> projects,
  required String languageCode,
  required DateTime today,
}) async {
  final existingTitles = {
    for (final habit in habitRepository.getAll()) habit.title,
  };
  for (final seed in _habitHistory) {
    if (seed.allTitles.any(existingTitles.contains)) continue;
    if (seed.projectIndex >= projects.length) continue;

    final habit = await habitRepository.add(
      title: seed.titleFor(languageCode),
      projectId: projects[seed.projectIndex].id,
      intensity: seed.intensity,
      frequency: seed.frequency,
      targetPerPeriod: seed.target,
      createdAt: addDays(today, -seed.startedDaysAgo),
    );
    final days = <DateTime>[];
    final lastDay = seed.endedDaysAgo ?? 0;
    for (var d = seed.startedDaysAgo; d >= lastDay; d--) {
      final day = addDays(today, -d);
      final count = seed.countOn(d, day.weekday);
      for (var i = 0; i < count; i++) {
        days.add(day);
      }
    }
    await habitCompletionRepository.addMany(habit.id, days);
    await Future.delayed(const Duration(milliseconds: 2));
    if (seed.endedDaysAgo != null) await habitRepository.delete(habit.id);
  }
}

/// Consecutive days including today, [length] long — a live, still-growing
/// streak (e.g. 10 gives 0..9), used to seed a habit that's clearly lit with
/// a real streak behind it.
List<int> _activeStreak(int length) => [for (var i = 0; i < length; i++) i];

class _WinSeed {
  const _WinSeed(this.title, [this.description]);
  final String title;
  final String? description;
}

/// A habit to seed, with which days (offsets from today, 0 = today) it's
/// been marked done on — hand-chosen per seed to exercise a different
/// streak state at a glance:
/// - [_activeStreak] gives a live, still-growing streak (lit, growing).
/// - `[1]` (yesterday only) exercises the one-day grace: lit today even
///   though today itself hasn't been marked done yet.
/// - A short burst several days back (e.g. `[4, 5, 6]`) exercises a habit
///   that's gone dark — its streak broke days ago and it hasn't recovered.
class _HabitSeed {
  const _HabitSeed(this.title, this.completedDayOffsets, {this.intensity = 3});
  final String title;
  final List<int> completedDayOffsets;

  /// What keeping this up costs each day, 1-5 — left at the middle of the
  /// scale for most seeds, so a deliberately heavy one (an ice bath) still
  /// stands out against them.
  final int intensity;
}

class _ProjectSeed {
  const _ProjectSeed(
    this.name,
    this.area,
    this.iconSlug,
    this.wins, {
    this.goals = const [],
    this.habits = const [],
    this.seedDeadStar = false,
  });
  final String name;
  final LifeArea area;
  final String iconSlug;
  final List<_WinSeed> wins;

  /// Open-goal titles seeded the first time this project is created — no
  /// target date, so they show up simply as unlit stars ready to be marked
  /// achieved.
  final List<String> goals;
  final List<_HabitSeed> habits;

  /// Whether to seed one tombstoned (deleted) star for this project, so
  /// there's a dead star ready to exercise "resurrect" without the user
  /// deleting one by hand first.
  final bool seedDeadStar;
}

/// Picks [_specsEn]/[_specsIt]/[_specsRo] to match [languageCode] — the
/// same three codes [SettingsScreen]'s own language picker offers ('en',
/// 'it', 'ro'). Any other/unrecognized code falls back to English.
List<_ProjectSeed> _specsFor(String languageCode) {
  switch (languageCode) {
    case 'it':
      return _specsIt;
    case 'ro':
      return _specsRo;
    default:
      return _specsEn;
  }
}

/// Every name [index]'s conceptual project has ever been seeded under,
/// across all three languages — [_specsEn]/[_specsIt]/[_specsRo] are kept
/// in the same order project-for-project, so index `i` in one is always
/// the same project as index `i` in the others, just translated. Used to
/// find an already-seeded project regardless of which language it was
/// seeded in last (see [seedSampleData]'s own doc comment).
Set<String> _alternateNamesAt(int index) => {
  _specsEn[index].name,
  _specsIt[index].name,
  _specsRo[index].name,
};

/// The dead/tombstoned seed star's title (see [_ProjectSeed.seedDeadStar])
/// — translated alongside everything else in [_specsFor], but kept
/// separate since it isn't part of any one project's own win list.
String _deadStarTitleFor(String languageCode) {
  switch (languageCode) {
    case 'it':
      return 'Un tentativo a cui ho rinunciato';
    case 'ro':
      return 'O încercare la care am renunțat';
    default:
      return 'An attempt I gave up on';
  }
}

final _specsEn = [
  _ProjectSeed(
    'Run a 10k',
    LifeArea.physical,
    'sports_gymnastics',
    [
      _WinSeed(
        "Went for a run even though I really didn't want to",
        'It was raining and I almost bailed, but I laced up anyway.',
      ),
      _WinSeed('Finished my first 5k without stopping'),
      _WinSeed(
        'Got up for a 6am run three days in a row',
        'My legs were sore but I did it anyway.',
      ),
      _WinSeed('Ran through a cramp instead of giving up'),
      _WinSeed('Signed up for the 10k race', "Terrified, but I did it."),
      _WinSeed(
        'Ran my personal best pace',
        'Two minutes faster than last month.',
      ),
      _WinSeed('Pushed through the last mile when I wanted to walk'),
      _WinSeed(
        'Went for a run after a really bad day at work',
        'It helped more than I expected.',
      ),
      _WinSeed("Did a hill sprint session I'd been avoiding for weeks"),
      _WinSeed('Ran in the cold without complaining (much)'),
      _WinSeed(
        'Recovered from a minor injury and got back out there',
        'Took it slow but I showed up.',
      ),
      _WinSeed("Beat last week's distance"),
    ],
    goals: ['Run a half marathon', 'Beat 50 minutes on a 10k'],
    habits: [
      _HabitSeed('Morning stretch', _activeStreak(10)),
      _HabitSeed('Ice bath', [4, 5, 6], intensity: 5),
    ],
    seedDeadStar: true,
  ),
  _ProjectSeed('Learn to swim', LifeArea.physical, 'pool', [
    _WinSeed('Put my face in the water without panicking'),
    _WinSeed('Swam a full lap without stopping to catch my breath'),
    _WinSeed(
      'Went to the pool alone for the first time',
      'Nobody to hide behind, just me and the water.',
    ),
    _WinSeed('Tried the deep end', 'Heart was racing but I did it.'),
    _WinSeed('Practiced breathing technique for 20 minutes straight'),
    _WinSeed('Swam two laps without needing to stop'),
  ]),
  _ProjectSeed(
    'Daily meditation',
    LifeArea.psychological,
    'spa',
    [
      _WinSeed(
        'Sat with an uncomfortable feeling instead of scrolling my phone',
      ),
      _WinSeed(
        "Meditated for 10 minutes even though my mind wouldn't quiet down",
        'It still counts.',
      ),
      _WinSeed('Noticed a spiral starting and caught it early'),
      _WinSeed(
        'Did a full week of morning meditation',
        "First time I've kept a streak this long.",
      ),
      _WinSeed(
        'Sat through a panic feeling without running from it',
        'Breathed through it instead.',
      ),
      _WinSeed("Journaled honestly about something I'd been avoiding"),
      _WinSeed(
        'Meditated after a fight instead of stewing',
        'Helped me respond instead of react.',
      ),
      _WinSeed('Noticed my thoughts without judging them, for once'),
      _WinSeed("Took a mental health day and didn't feel guilty"),
      _WinSeed(
        'Practiced sitting in silence for 15 minutes',
        'Was hard, did it anyway.',
      ),
      _WinSeed("Talked myself down from a spiral using what I've learned"),
      _WinSeed(
        'Meditated on a day I really did not feel like it',
        'Showed up anyway.',
      ),
    ],
    goals: ['Complete a 10-day silent retreat'],
    habits: [
      // Completed yesterday only, not yet today — exercises the one-day
      // grace: this should still show up lit.
      _HabitSeed('Evening meditation', [1]),
    ],
  ),
  _ProjectSeed(
    'Build this app',
    LifeArea.professional,
    'rocket_launch',
    [
      _WinSeed('Got the data model working after hours of debugging'),
      _WinSeed(
        'Shipped the first working version',
        "Rough around the edges but it runs.",
      ),
      _WinSeed('Fixed a bug that had been driving me crazy for two days'),
      _WinSeed("Refactored the messy code from last week"),
      _WinSeed('Wrote tests instead of skipping them'),
      _WinSeed(
        "Figured out the animation that wasn't working",
        'Took way longer than it should have.',
      ),
      _WinSeed(
        'Got the build running on the emulator after a frustrating setup',
      ),
      _WinSeed('Pushed through a wall of compiler errors'),
      _WinSeed("Redesigned a screen that wasn't working visually"),
      _WinSeed(
        'Debugged a race condition that only happened sometimes',
        'Finally reproduced it.',
      ),
      _WinSeed('Kept going after a build failed three times in a row'),
      _WinSeed('Wrote documentation instead of putting it off'),
    ],
    goals: ['Ship v2 to the app store', 'Reach 100 users'],
  ),
  _ProjectSeed(
    'Find a new job',
    LifeArea.professional,
    'business_center',
    [
      _WinSeed('Sent out an application even though I felt unqualified'),
      _WinSeed('Made it through a nerve-wracking interview'),
      _WinSeed('Followed up after weeks of silence'),
      _WinSeed('Rewrote my resume instead of avoiding it'),
      _WinSeed(
        'Asked for feedback after a rejection',
        'Stung, but I learned something.',
      ),
    ],
    goals: ['Land 3 interviews this month'],
  ),
  _ProjectSeed(
    'Save for a house',
    LifeArea.financial,
    'home',
    [
      _WinSeed('Skipped an impulse purchase and put the money aside instead'),
      _WinSeed('Made it through the month under budget'),
      _WinSeed(
        'Had an honest look at my spending',
        'Uncomfortable but necessary.',
      ),
      _WinSeed('Said no to a night out to protect my savings'),
      _WinSeed("Hit a savings milestone I'd been working toward"),
      _WinSeed("Cut a subscription I wasn't using"),
    ],
    goals: ['Reach the down payment goal'],
  ),
  _ProjectSeed(
    'Read more books',
    LifeArea.personal,
    'explore',
    [
      _WinSeed("Finished a book I'd been putting down for months"),
      _WinSeed('Read instead of scrolling before bed'),
      _WinSeed('Started a book that intimidated me'),
      _WinSeed('Finished a chapter instead of stopping mid-way'),
    ],
    habits: [_HabitSeed('Read before bed', _activeStreak(7), intensity: 1)],
  ),
  _ProjectSeed('Reconnect with old friends', LifeArea.social, 'chat_bubble', [
    _WinSeed("Reached out to a friend I hadn't spoken to in years"),
    _WinSeed(
      'Made the first move to patch things up',
      'Awkward at first, worth it.',
    ),
    _WinSeed('Showed up to a get-together I almost skipped'),
    _WinSeed('Called instead of just texting'),
    _WinSeed('Said something honest instead of staying quiet'),
    _WinSeed(
      'Reconnected with someone after a long silence',
      "Neither of us apologized, we just moved on.",
    ),
    _WinSeed('Made plans instead of waiting for someone else to'),
  ]),
  _ProjectSeed('Volunteer monthly', LifeArea.philanthropic, 'campaign', [
    _WinSeed('Showed up to volunteer even though I was exhausted'),
    _WinSeed('Organized a small donation drive'),
    _WinSeed(
      'Spent a Saturday helping instead of resting',
      'Tired, but glad I did it.',
    ),
    _WinSeed('Gave up a weekend to help a neighbor move'),
    _WinSeed("Donated instead of buying something I didn't need"),
  ]),
  // The smaller constellations below (index 9 on) keep the Sky well filled
  // with many short constellations rather than a few crowded ones.
  _ProjectSeed(
    'Build strength',
    LifeArea.physical,
    'fitness_center',
    [
      _WinSeed('Lifted heavier than last week'),
      _WinSeed('Went to the gym on a day I wanted to skip'),
      _WinSeed('Learned proper squat form'),
      _WinSeed('Finished a full workout plan week'),
    ],
    goals: ['Deadlift my body weight'],
  ),
  _ProjectSeed('Cycle to work', LifeArea.physical, 'directions_bike', [
    _WinSeed('Biked to work instead of taking the car'),
    _WinSeed('Rode in the rain and enjoyed it'),
    _WinSeed('Fixed a flat tire on my own'),
    _WinSeed('Cycled 30 km on the weekend'),
  ]),
  _ProjectSeed('Keep a journal', LifeArea.psychological, 'edit', [
    _WinSeed('Wrote three pages before breakfast'),
    _WinSeed('Journaled after a hard day instead of bottling it up'),
    _WinSeed('Reread an old entry and saw how far I came'),
    _WinSeed('Wrote every day for a week'),
  ]),
  _ProjectSeed(
    'Sleep better',
    LifeArea.psychological,
    'nightlight',
    [
      _WinSeed('Went to bed before midnight'),
      _WinSeed('Put the phone away an hour before sleep'),
      _WinSeed('Woke up without snoozing the alarm'),
      _WinSeed('Kept a steady sleep schedule all week'),
    ],
    goals: ['Sleep 8 hours for a month'],
  ),
  _ProjectSeed(
    'Finish the online course',
    LifeArea.professional,
    'school',
    [
      _WinSeed('Completed a module I had been postponing'),
      _WinSeed('Passed the first quiz on the first try'),
      _WinSeed('Took notes instead of just watching'),
      _WinSeed('Studied for an hour straight without distractions'),
    ],
    goals: ['Get the certificate'],
  ),
  _ProjectSeed(
    'Launch a side project',
    LifeArea.professional,
    'emoji_objects',
    [
      _WinSeed('Sketched the first idea on paper'),
      _WinSeed('Bought the domain name'),
      _WinSeed('Shipped a tiny prototype'),
      _WinSeed('Showed it to a friend and listened to feedback'),
    ],
    goals: ['Get the first paying customer'],
  ),
  _ProjectSeed(
    'Pay off the credit card',
    LifeArea.financial,
    'account_balance_wallet',
    [
      _WinSeed('Paid more than the minimum'),
      _WinSeed('Tracked every expense for a week'),
      _WinSeed('Cancelled a card I did not need'),
      _WinSeed('Cleared a whole month of the balance'),
    ],
  ),
  _ProjectSeed(
    'Start investing',
    LifeArea.financial,
    'trending_up',
    [
      _WinSeed('Opened my first investment account'),
      _WinSeed('Read a book about index funds'),
      _WinSeed('Set up an automatic monthly deposit'),
      _WinSeed('Resisted checking the balance every day'),
    ],
    goals: ['Reach an emergency fund of six months'],
  ),
  _ProjectSeed('Learn to draw', LifeArea.personal, 'brush', [
    _WinSeed('Drew every day for a week'),
    _WinSeed('Finished a portrait I was afraid to start'),
    _WinSeed('Filled a whole sketchbook page'),
    _WinSeed('Shared a drawing with a friend'),
  ]),
  _ProjectSeed(
    'Learn the piano',
    LifeArea.personal,
    'piano',
    [
      _WinSeed('Played a song hands together'),
      _WinSeed('Practiced scales for twenty minutes'),
      _WinSeed('Learned the intro of a song I love'),
      _WinSeed('Played for a friend without apologizing'),
    ],
    goals: ['Play a full song from memory'],
  ),
  _ProjectSeed('Cook at home', LifeArea.personal, 'restaurant', [
    _WinSeed('Cooked dinner instead of ordering in'),
    _WinSeed('Tried a recipe I had never made'),
    _WinSeed('Prepared lunches for the whole week'),
    _WinSeed('Cooked for friends and they loved it'),
  ]),
  _ProjectSeed(
    'Travel more',
    LifeArea.personal,
    'luggage',
    [
      _WinSeed('Booked a weekend trip'),
      _WinSeed('Explored a city I had never visited'),
      _WinSeed('Travelled light for the first time'),
      _WinSeed('Planned the next trip while still on this one'),
    ],
    goals: ['Visit three new countries'],
  ),
  _ProjectSeed('Date night every week', LifeArea.social, 'favorite', [
    _WinSeed('Planned a surprise evening'),
    _WinSeed('Put the phones away during dinner'),
    _WinSeed('Tried a new restaurant together'),
    _WinSeed('Danced in the living room'),
  ]),
  _ProjectSeed('Call family more', LifeArea.social, 'family_restroom', [
    _WinSeed('Called my parents just to chat'),
    _WinSeed('Visited my grandparents for lunch'),
    _WinSeed('Sent a long message to my sibling'),
    _WinSeed('Remembered a birthday in time'),
  ]),
  _ProjectSeed('Give back to the community', LifeArea.philanthropic, 'redeem', [
    _WinSeed('Donated clothes I no longer wear'),
    _WinSeed('Helped at the neighbourhood food bank'),
    _WinSeed('Taught a free workshop'),
    _WinSeed('Brought supplies to the local shelter'),
  ]),
];

final _specsIt = [
  _ProjectSeed(
    'Correre una 10 km',
    LifeArea.physical,
    'sports_gymnastics',
    [
      _WinSeed(
        'Sono uscito a correre anche se non ne avevo davvero voglia',
        "Pioveva e stavo quasi per rinunciare, ma alla fine mi sono allacciato le scarpe lo stesso.",
      ),
      _WinSeed('Ho finito il mio primo 5 km senza fermarmi'),
      _WinSeed(
        'Mi sono alzato per correre alle 6 del mattino per tre giorni di fila',
        'Avevo le gambe indolenzite ma l\'ho fatto lo stesso.',
      ),
      _WinSeed(
        'Ho continuato a correre nonostante un crampo invece di mollare',
      ),
      _WinSeed(
        'Mi sono iscritto alla gara dei 10 km',
        'Terrorizzato, ma l\'ho fatto.',
      ),
      _WinSeed(
        'Ho corso al mio ritmo migliore di sempre',
        'Due minuti più veloce del mese scorso.',
      ),
      _WinSeed(
        'Ho tenuto duro nell\'ultimo chilometro quando volevo camminare',
      ),
      _WinSeed(
        'Sono uscito a correre dopo una giornata di lavoro davvero pesante',
        'Mi ha aiutato più di quanto pensassi.',
      ),
      _WinSeed(
        'Ho fatto una sessione di scatti in salita che evitavo da settimane',
      ),
      _WinSeed('Ho corso al freddo senza lamentarmi (troppo)'),
      _WinSeed(
        'Mi sono ripreso da un piccolo infortunio e sono tornato a correre',
        'Ci sono andato piano ma mi sono fatto vivo.',
      ),
      _WinSeed('Ho superato la distanza della settimana scorsa'),
    ],
    goals: [
      'Correre una mezza maratona',
      'Scendere sotto i 50 minuti nei 10 km',
    ],
    habits: [
      _HabitSeed('Stretching mattutino', _activeStreak(10)),
      _HabitSeed('Bagno di ghiaccio', [4, 5, 6], intensity: 5),
    ],
    seedDeadStar: true,
  ),
  _ProjectSeed('Imparare a nuotare', LifeArea.physical, 'pool', [
    _WinSeed('Ho messo la faccia in acqua senza farmi prendere dal panico'),
    _WinSeed('Ho nuotato una vasca intera senza fermarmi per riprendere fiato'),
    _WinSeed(
      'Sono andato in piscina da solo per la prima volta',
      'Nessuno dietro cui nascondermi, solo io e l\'acqua.',
    ),
    _WinSeed(
      'Ho provato la parte profonda della piscina',
      'Il cuore mi batteva forte ma l\'ho fatto.',
    ),
    _WinSeed('Ho fatto pratica con la respirazione per 20 minuti di fila'),
    _WinSeed('Ho nuotato due vasche senza aver bisogno di fermarmi'),
  ]),
  _ProjectSeed(
    'Meditazione quotidiana',
    LifeArea.psychological,
    'spa',
    [
      _WinSeed(
        'Sono rimasto con una sensazione scomoda invece di scrollare il telefono',
      ),
      _WinSeed(
        'Ho meditato per 10 minuti anche se la mente non voleva calmarsi',
        'Conta comunque.',
      ),
      _WinSeed('Ho notato una spirale che iniziava e l\'ho bloccata in tempo'),
      _WinSeed(
        'Ho fatto una settimana intera di meditazione mattutina',
        'Prima volta che mantengo una serie così lunga.',
      ),
      _WinSeed(
        'Ho affrontato una sensazione di panico senza scappare',
        'Ho respirato invece di fuggire.',
      ),
      _WinSeed('Ho scritto sinceramente nel diario su qualcosa che evitavo'),
      _WinSeed(
        'Ho meditato dopo un litigio invece di rimuginare',
        'Mi ha aiutato a rispondere invece che reagire d\'istinto.',
      ),
      _WinSeed('Per una volta ho osservato i miei pensieri senza giudicarli'),
      _WinSeed(
        'Mi sono preso un giorno per la salute mentale senza sentirmi in colpa',
      ),
      _WinSeed(
        'Ho fatto pratica stando in silenzio per 15 minuti',
        'È stato difficile, ma l\'ho fatto lo stesso.',
      ),
      _WinSeed(
        'Sono riuscito a calmarmi da una spirale usando quello che ho imparato',
      ),
      _WinSeed(
        'Ho meditato in un giorno in cui non ne avevo proprio voglia',
        'Mi sono fatto vivo lo stesso.',
      ),
    ],
    goals: ['Completare un ritiro silenzioso di 10 giorni'],
    habits: [
      // Completato solo ieri, non ancora oggi — verifica il giorno di
      // tolleranza: deve comunque risultare acceso.
      _HabitSeed('Meditazione serale', [1]),
    ],
  ),
  _ProjectSeed(
    'Costruire questa app',
    LifeArea.professional,
    'rocket_launch',
    [
      _WinSeed('Ho fatto funzionare il modello dati dopo ore di debug'),
      _WinSeed(
        'Ho rilasciato la prima versione funzionante',
        'Grezza qua e là ma funziona.',
      ),
      _WinSeed('Ho risolto un bug che mi faceva impazzire da due giorni'),
      _WinSeed(
        'Ho rifattorizzato il codice disordinato della settimana scorsa',
      ),
      _WinSeed('Ho scritto i test invece di saltarli'),
      _WinSeed(
        'Ho capito perché l\'animazione non funzionava',
        'Ci ho messo molto più tempo del dovuto.',
      ),
      _WinSeed(
        'Ho fatto partire la build sull\'emulatore dopo una configurazione frustrante',
      ),
      _WinSeed('Ho superato un muro di errori del compilatore'),
      _WinSeed('Ho riprogettato una schermata che visivamente non funzionava'),
      _WinSeed(
        'Ho debuggato una race condition che si presentava solo a volte',
        'Finalmente sono riuscito a riprodurla.',
      ),
      _WinSeed('Ho continuato dopo che la build era fallita tre volte di fila'),
      _WinSeed('Ho scritto la documentazione invece di rimandarla'),
    ],
    goals: ['Pubblicare la v2 sullo store', 'Raggiungere 100 utenti'],
  ),
  _ProjectSeed(
    'Trovare un nuovo lavoro',
    LifeArea.professional,
    'business_center',
    [
      _WinSeed(
        'Ho inviato una candidatura anche se mi sentivo poco qualificato',
      ),
      _WinSeed('Sono sopravvissuto a un colloquio da far tremare i polsi'),
      _WinSeed('Ho fatto un follow-up dopo settimane di silenzio'),
      _WinSeed('Ho riscritto il mio curriculum invece di evitarlo'),
      _WinSeed(
        'Ho chiesto un feedback dopo un rifiuto',
        'Ha fatto male, ma ho imparato qualcosa.',
      ),
    ],
    goals: ['Ottenere 3 colloqui questo mese'],
  ),
  _ProjectSeed(
    'Risparmiare per una casa',
    LifeArea.financial,
    'home',
    [
      _WinSeed(
        'Ho rinunciato a un acquisto impulsivo e ho messo da parte i soldi',
      ),
      _WinSeed('Sono arrivato a fine mese restando sotto budget'),
      _WinSeed(
        'Ho dato un\'occhiata sincera alle mie spese',
        'Scomodo ma necessario.',
      ),
      _WinSeed('Ho detto no a una serata fuori per proteggere i miei risparmi'),
      _WinSeed('Ho raggiunto un traguardo di risparmio a cui puntavo da tempo'),
      _WinSeed('Ho cancellato un abbonamento che non usavo'),
    ],
    goals: ['Raggiungere l\'obiettivo per l\'anticipo'],
  ),
  _ProjectSeed(
    'Leggere più libri',
    LifeArea.personal,
    'explore',
    [
      _WinSeed('Ho finito un libro che rimandavo da mesi'),
      _WinSeed('Ho letto invece di scrollare il telefono prima di dormire'),
      _WinSeed('Ho iniziato un libro che mi intimidiva'),
      _WinSeed('Ho finito un capitolo invece di fermarmi a metà'),
    ],
    habits: [
      _HabitSeed('Leggere prima di dormire', _activeStreak(7), intensity: 1),
    ],
  ),
  _ProjectSeed(
    'Riallacciare i rapporti con vecchi amici',
    LifeArea.social,
    'chat_bubble',
    [
      _WinSeed('Ho contattato un amico con cui non parlavo da anni'),
      _WinSeed(
        'Ho fatto il primo passo per chiarire le cose',
        'All\'inizio imbarazzante, ma ne è valsa la pena.',
      ),
      _WinSeed('Mi sono presentato a un ritrovo che stavo per saltare'),
      _WinSeed('Ho chiamato invece di limitarmi a scrivere un messaggio'),
      _WinSeed('Ho detto qualcosa di sincero invece di restare zitto'),
      _WinSeed(
        'Ho ristabilito il contatto con qualcuno dopo un lungo silenzio',
        'Nessuno dei due si è scusato, abbiamo solo ricominciato.',
      ),
      _WinSeed(
        'Ho organizzato qualcosa invece di aspettare che lo facesse qualcun altro',
      ),
    ],
  ),
  _ProjectSeed(
    'Fare volontariato ogni mese',
    LifeArea.philanthropic,
    'campaign',
    [
      _WinSeed('Mi sono presentato per fare volontariato anche se ero esausto'),
      _WinSeed('Ho organizzato una piccola raccolta di donazioni'),
      _WinSeed(
        'Ho passato un sabato ad aiutare invece di riposare',
        'Stanco, ma contento di averlo fatto.',
      ),
      _WinSeed('Ho rinunciato a un weekend per aiutare un vicino a traslocare'),
      _WinSeed(
        'Ho donato invece di comprare qualcosa di cui non avevo bisogno',
      ),
    ],
  ),
  _ProjectSeed(
    'Costruire forza',
    LifeArea.physical,
    'fitness_center',
    [
      _WinSeed('Ho sollevato più della settimana scorsa'),
      _WinSeed('Sono andato in palestra in un giorno in cui volevo saltare'),
      _WinSeed('Ho imparato la tecnica giusta degli squat'),
      _WinSeed('Ho completato una settimana intera di scheda'),
    ],
    goals: ['Fare uno stacco con il mio peso corporeo'],
  ),
  _ProjectSeed(
    'Andare al lavoro in bici',
    LifeArea.physical,
    'directions_bike',
    [
      _WinSeed('Sono andato al lavoro in bici invece che in auto'),
      _WinSeed('Ho pedalato sotto la pioggia e mi è piaciuto'),
      _WinSeed('Ho riparato una foratura da solo'),
      _WinSeed('Ho pedalato 30 km nel weekend'),
    ],
  ),
  _ProjectSeed('Tenere un diario', LifeArea.psychological, 'edit', [
    _WinSeed('Ho scritto tre pagine prima di colazione'),
    _WinSeed(
      'Ho scritto dopo una giornata dura invece di tenermi tutto dentro',
    ),
    _WinSeed('Ho riletto una vecchia pagina e visto quanta strada ho fatto'),
    _WinSeed('Ho scritto ogni giorno per una settimana'),
  ]),
  _ProjectSeed(
    'Dormire meglio',
    LifeArea.psychological,
    'nightlight',
    [
      _WinSeed('Sono andato a letto prima di mezzanotte'),
      _WinSeed('Ho messo via il telefono un\'ora prima di dormire'),
      _WinSeed('Mi sono svegliato senza rimandare la sveglia'),
      _WinSeed('Ho mantenuto orari regolari per tutta la settimana'),
    ],
    goals: ['Dormire 8 ore per un mese'],
  ),
  _ProjectSeed(
    'Finire il corso online',
    LifeArea.professional,
    'school',
    [
      _WinSeed('Ho completato un modulo che rimandavo'),
      _WinSeed('Ho superato il primo quiz al primo tentativo'),
      _WinSeed('Ho preso appunti invece di guardare e basta'),
      _WinSeed('Ho studiato un\'ora di fila senza distrazioni'),
    ],
    goals: ['Ottenere il certificato'],
  ),
  _ProjectSeed(
    'Lanciare un progetto personale',
    LifeArea.professional,
    'emoji_objects',
    [
      _WinSeed('Ho abbozzato la prima idea su carta'),
      _WinSeed('Ho comprato il nome a dominio'),
      _WinSeed('Ho rilasciato un piccolo prototipo'),
      _WinSeed('L\'ho mostrato a un amico e ho ascoltato il suo parere'),
    ],
    goals: ['Avere il primo cliente pagante'],
  ),
  _ProjectSeed(
    'Estinguere la carta di credito',
    LifeArea.financial,
    'account_balance_wallet',
    [
      _WinSeed('Ho pagato più del minimo'),
      _WinSeed('Ho tracciato ogni spesa per una settimana'),
      _WinSeed('Ho chiuso una carta che non mi serviva'),
      _WinSeed('Ho azzerato un intero mese di saldo'),
    ],
  ),
  _ProjectSeed(
    'Iniziare a investire',
    LifeArea.financial,
    'trending_up',
    [
      _WinSeed('Ho aperto il mio primo conto di investimento'),
      _WinSeed('Ho letto un libro sui fondi indicizzati'),
      _WinSeed('Ho impostato un versamento mensile automatico'),
      _WinSeed('Ho resistito alla voglia di controllare il saldo ogni giorno'),
    ],
    goals: ['Costruire un fondo d\'emergenza di sei mesi'],
  ),
  _ProjectSeed('Imparare a disegnare', LifeArea.personal, 'brush', [
    _WinSeed('Ho disegnato ogni giorno per una settimana'),
    _WinSeed('Ho finito un ritratto che avevo paura di iniziare'),
    _WinSeed('Ho riempito un\'intera pagina di schizzi'),
    _WinSeed('Ho mostrato un disegno a un amico'),
  ]),
  _ProjectSeed(
    'Imparare il pianoforte',
    LifeArea.personal,
    'piano',
    [
      _WinSeed('Ho suonato una canzone a mani unite'),
      _WinSeed('Ho fatto scale per venti minuti'),
      _WinSeed('Ho imparato l\'intro di una canzone che amo'),
      _WinSeed('Ho suonato per un amico senza scusarmi'),
    ],
    goals: ['Suonare un brano intero a memoria'],
  ),
  _ProjectSeed('Cucinare a casa', LifeArea.personal, 'restaurant', [
    _WinSeed('Ho cucinato la cena invece di ordinare'),
    _WinSeed('Ho provato una ricetta mai fatta'),
    _WinSeed('Ho preparato i pranzi per tutta la settimana'),
    _WinSeed('Ho cucinato per gli amici e hanno apprezzato'),
  ]),
  _ProjectSeed(
    'Viaggiare di più',
    LifeArea.personal,
    'luggage',
    [
      _WinSeed('Ho prenotato una gita di un weekend'),
      _WinSeed('Ho esplorato una città che non avevo mai visto'),
      _WinSeed('Ho viaggiato leggero per la prima volta'),
      _WinSeed(
        'Ho pianificato il prossimo viaggio mentre ero ancora in questo',
      ),
    ],
    goals: ['Visitare tre nuovi paesi'],
  ),
  _ProjectSeed('Serata di coppia ogni settimana', LifeArea.social, 'favorite', [
    _WinSeed('Ho organizzato una serata a sorpresa'),
    _WinSeed('Abbiamo messo via i telefoni durante la cena'),
    _WinSeed('Abbiamo provato un nuovo ristorante'),
    _WinSeed('Abbiamo ballato in salotto'),
  ]),
  _ProjectSeed(
    'Chiamare di più la famiglia',
    LifeArea.social,
    'family_restroom',
    [
      _WinSeed('Ho chiamato i miei genitori solo per chiacchierare'),
      _WinSeed('Sono andato a pranzo dai nonni'),
      _WinSeed('Ho scritto un lungo messaggio a mio fratello'),
      _WinSeed('Mi sono ricordato di un compleanno in tempo'),
    ],
  ),
  _ProjectSeed(
    'Restituire qualcosa alla comunità',
    LifeArea.philanthropic,
    'redeem',
    [
      _WinSeed('Ho donato i vestiti che non uso più'),
      _WinSeed('Ho dato una mano al banco alimentare del quartiere'),
      _WinSeed('Ho tenuto un laboratorio gratuito'),
      _WinSeed('Ho portato provviste al rifugio locale'),
    ],
  ),
];

final _specsRo = [
  _ProjectSeed(
    'Aleargă un 10k',
    LifeArea.physical,
    'sports_gymnastics',
    [
      _WinSeed(
        'Am ieșit la alergat chiar dacă chiar nu aveam chef',
        'Ploua și era să renunț, dar mi-am legat șireturile oricum.',
      ),
      _WinSeed('Mi-am terminat primul 5k fără să mă opresc'),
      _WinSeed(
        'M-am trezit să alerg la ora 6 dimineața trei zile la rând',
        'Aveam picioarele dureroase, dar am făcut-o oricum.',
      ),
      _WinSeed('Am alergat cu o crampă în loc să renunț'),
      _WinSeed('M-am înscris la cursa de 10k', 'Îngrozit, dar am făcut-o.'),
      _WinSeed(
        'Am alergat în cel mai bun ritm personal',
        'Cu două minute mai repede decât luna trecută.',
      ),
      _WinSeed(
        'Am dus-o până la capăt în ultimul kilometru când voiam să merg la pas',
      ),
      _WinSeed(
        'Am ieșit la alergat după o zi foarte grea la muncă',
        'M-a ajutat mai mult decât mă așteptam.',
      ),
      _WinSeed(
        'Am făcut o sesiune de sprint pe deal pe care o evitam de săptămâni întregi',
      ),
      _WinSeed('Am alergat pe frig fără să mă plâng (prea mult)'),
      _WinSeed(
        'Mi-am revenit după o mică accidentare și am ieșit din nou',
        'Am mers încet, dar m-am prezentat.',
      ),
      _WinSeed('Am depășit distanța din săptămâna trecută'),
    ],
    goals: ['Aleargă un semimaraton', 'Sub 50 de minute la 10k'],
    habits: [
      _HabitSeed('Întindere de dimineață', _activeStreak(10)),
      _HabitSeed('Baie cu gheață', [4, 5, 6], intensity: 5),
    ],
    seedDeadStar: true,
  ),
  _ProjectSeed('Învăț să înot', LifeArea.physical, 'pool', [
    _WinSeed('Mi-am băgat fața în apă fără să intru în panică'),
    _WinSeed(
      'Am înotat un bazin întreg fără să mă opresc să-mi trag răsuflarea',
    ),
    _WinSeed(
      'Am mers singur la piscină pentru prima dată',
      'Nimeni în spatele căruia să mă ascund, doar eu și apa.',
    ),
    _WinSeed(
      'Am încercat partea adâncă',
      'Inima îmi bătea cu putere, dar am făcut-o.',
    ),
    _WinSeed('Am exersat tehnica de respirație timp de 20 de minute în șir'),
    _WinSeed('Am înotat două bazine fără să am nevoie să mă opresc'),
  ]),
  _ProjectSeed(
    'Meditație zilnică',
    LifeArea.psychological,
    'spa',
    [
      _WinSeed(
        'Am stat cu o senzație neplăcută în loc să dau scroll pe telefon',
      ),
      _WinSeed(
        'Am meditat 10 minute chiar dacă mintea nu voia să se liniștească',
        'Tot contează.',
      ),
      _WinSeed('Am observat o spirală care începea și am prins-o din timp'),
      _WinSeed(
        'Am făcut o săptămână întreagă de meditație de dimineață',
        'Prima dată când am reușit o serie atât de lungă.',
      ),
      _WinSeed(
        'Am rezistat unei senzații de panică fără să fug de ea',
        'Am respirat în schimb.',
      ),
      _WinSeed('Am scris sincer în jurnal despre ceva ce evitam'),
      _WinSeed(
        'Am meditat după o ceartă în loc să mă frământ',
        'M-a ajutat să răspund în loc să reacționez.',
      ),
      _WinSeed('Pentru o dată mi-am observat gândurile fără să le judec'),
      _WinSeed(
        'Mi-am luat o zi liberă pentru sănătatea mintală fără să mă simt vinovat',
      ),
      _WinSeed(
        'Am exersat să stau în tăcere timp de 15 minute',
        'A fost greu, dar am făcut-o oricum.',
      ),
      _WinSeed('M-am calmat dintr-o spirală folosind ce am învățat'),
      _WinSeed(
        'Am meditat într-o zi în care chiar nu aveam chef',
        'M-am prezentat oricum.',
      ),
    ],
    goals: ['Finalizează un retreat de tăcere de 10 zile'],
    habits: [
      // Bifat doar ieri, nu încă azi — verifică ziua de grație: tot
      // trebuie să apară aprins.
      _HabitSeed('Meditație de seară', [1]),
    ],
  ),
  _ProjectSeed(
    'Construiesc această aplicație',
    LifeArea.professional,
    'rocket_launch',
    [
      _WinSeed('Am făcut modelul de date să funcționeze după ore de depanare'),
      _WinSeed(
        'Am lansat prima versiune funcțională',
        'Nefinisată pe alocuri, dar merge.',
      ),
      _WinSeed('Am rezolvat un bug care mă înnebunea de două zile'),
      _WinSeed('Am refactorizat codul dezordonat din săptămâna trecută'),
      _WinSeed('Am scris teste în loc să le sar peste'),
      _WinSeed(
        'Am rezolvat animația care nu funcționa',
        'A durat mult mai mult decât ar fi trebuit.',
      ),
      _WinSeed(
        'Am reușit să rulez build-ul pe emulator după o configurare frustrantă',
      ),
      _WinSeed('Am trecut printr-un zid de erori de compilare'),
      _WinSeed('Am reproiectat un ecran care nu arăta bine'),
      _WinSeed(
        'Am depanat o race condition care apărea doar uneori',
        'În sfârșit am reușit s-o reproduc.',
      ),
      _WinSeed('Am continuat după ce build-ul a eșuat de trei ori la rând'),
      _WinSeed('Am scris documentația în loc să o amân'),
    ],
    goals: ['Lansează v2 în app store', 'Ajunge la 100 de utilizatori'],
  ),
  _ProjectSeed(
    'Găsesc un job nou',
    LifeArea.professional,
    'business_center',
    [
      _WinSeed('Am trimis o candidatură chiar dacă mă simțeam nepregătit'),
      _WinSeed('Am trecut printr-un interviu care mă făcea foarte agitat'),
      _WinSeed('Am revenit cu un mesaj după săptămâni de tăcere'),
      _WinSeed('Mi-am rescris CV-ul în loc să evit acest lucru'),
      _WinSeed(
        'Am cerut feedback după un refuz',
        'A durut, dar am învățat ceva.',
      ),
    ],
    goals: ['Obține 3 interviuri luna aceasta'],
  ),
  _ProjectSeed(
    'Economisesc pentru o casă',
    LifeArea.financial,
    'home',
    [
      _WinSeed(
        'Am renunțat la o cumpărătură impulsivă și am pus banii deoparte',
      ),
      _WinSeed('Am terminat luna sub buget'),
      _WinSeed(
        'Am analizat sincer cheltuielile mele',
        'Neplăcut, dar necesar.',
      ),
      _WinSeed('Am spus nu unei ieșiri în oraș ca să-mi protejez economiile'),
      _WinSeed(
        'Am atins un obiectiv de economisire spre care lucram de mult timp',
      ),
      _WinSeed('Am anulat un abonament pe care nu-l foloseam'),
    ],
    goals: ['Atinge obiectivul pentru avans'],
  ),
  _ProjectSeed(
    'Citesc mai multe cărți',
    LifeArea.personal,
    'explore',
    [
      _WinSeed('Am terminat o carte pe care o tot amânam de luni de zile'),
      _WinSeed('Am citit în loc să dau scroll pe telefon înainte de culcare'),
      _WinSeed('Am început o carte care mă intimida'),
      _WinSeed('Am terminat un capitol în loc să mă opresc la jumătate'),
    ],
    habits: [
      _HabitSeed('Citesc înainte de culcare', _activeStreak(7), intensity: 1),
    ],
  ),
  _ProjectSeed('Reconectez cu vechi prieteni', LifeArea.social, 'chat_bubble', [
    _WinSeed('Am contactat un prieten cu care nu mai vorbisem de ani de zile'),
    _WinSeed(
      'Am făcut primul pas ca să repar lucrurile',
      'Stânjenitor la început, dar a meritat.',
    ),
    _WinSeed('M-am prezentat la o întâlnire pe care era să o ratez'),
    _WinSeed('Am sunat în loc să trimit doar un mesaj'),
    _WinSeed('Am spus ceva sincer în loc să tac'),
    _WinSeed(
      'Am reluat legătura cu cineva după o tăcere lungă',
      'Niciunul dintre noi nu și-a cerut scuze, am mers mai departe.',
    ),
    _WinSeed('Am făcut planuri în loc să aștept ca altcineva să o facă'),
  ]),
  _ProjectSeed('Fac voluntariat lunar', LifeArea.philanthropic, 'campaign', [
    _WinSeed('M-am prezentat la voluntariat chiar dacă eram epuizat'),
    _WinSeed('Am organizat o mică campanie de donații'),
    _WinSeed(
      'Mi-am petrecut o sâmbătă ajutând în loc să mă odihnesc',
      'Obosit, dar mulțumit că am făcut-o.',
    ),
    _WinSeed('Am renunțat la un weekend ca să ajut un vecin să se mute'),
    _WinSeed('Am donat în loc să cumpăr ceva de care nu aveam nevoie'),
  ]),
  _ProjectSeed(
    'Construiesc forță',
    LifeArea.physical,
    'fitness_center',
    [
      _WinSeed('Am ridicat mai mult decât săptămâna trecută'),
      _WinSeed('Am mers la sală într-o zi în care voiam să sar peste'),
      _WinSeed('Am învățat forma corectă pentru genuflexiuni'),
      _WinSeed('Am terminat o săptămână întreagă de antrenament'),
    ],
    goals: ['Ridic greutatea corpului la îndreptări'],
  ),
  _ProjectSeed(
    'Merg cu bicicleta la serviciu',
    LifeArea.physical,
    'directions_bike',
    [
      _WinSeed('Am mers cu bicicleta la muncă în loc de mașină'),
      _WinSeed('Am pedalat în ploaie și mi-a plăcut'),
      _WinSeed('Mi-am reparat singur o pană'),
      _WinSeed('Am pedalat 30 km în weekend'),
    ],
  ),
  _ProjectSeed('Țin un jurnal', LifeArea.psychological, 'edit', [
    _WinSeed('Am scris trei pagini înainte de micul dejun'),
    _WinSeed('Am scris după o zi grea în loc să țin totul în mine'),
    _WinSeed('Am recitit o pagină veche și am văzut cât am progresat'),
    _WinSeed('Am scris în fiecare zi timp de o săptămână'),
  ]),
  _ProjectSeed(
    'Dorm mai bine',
    LifeArea.psychological,
    'nightlight',
    [
      _WinSeed('M-am culcat înainte de miezul nopții'),
      _WinSeed('Am lăsat telefonul deoparte cu o oră înainte de somn'),
      _WinSeed('M-am trezit fără să amân alarma'),
      _WinSeed('Am ținut un program de somn constant toată săptămâna'),
    ],
    goals: ['Dorm 8 ore timp de o lună'],
  ),
  _ProjectSeed(
    'Termin cursul online',
    LifeArea.professional,
    'school',
    [
      _WinSeed('Am terminat un modul pe care îl amânam'),
      _WinSeed('Am trecut primul test din prima încercare'),
      _WinSeed('Am luat notițe în loc să mă uit doar'),
      _WinSeed('Am studiat o oră fără pauze sau distrageri'),
    ],
    goals: ['Obțin certificatul'],
  ),
  _ProjectSeed(
    'Lansez un proiect personal',
    LifeArea.professional,
    'emoji_objects',
    [
      _WinSeed('Am schițat prima idee pe hârtie'),
      _WinSeed('Am cumpărat numele de domeniu'),
      _WinSeed('Am lansat un mic prototip'),
      _WinSeed('L-am arătat unui prieten și i-am ascultat părerea'),
    ],
    goals: ['Primul client plătitor'],
  ),
  _ProjectSeed(
    'Achit cardul de credit',
    LifeArea.financial,
    'account_balance_wallet',
    [
      _WinSeed('Am plătit mai mult decât minimul'),
      _WinSeed('Mi-am notat fiecare cheltuială timp de o săptămână'),
      _WinSeed('Am închis un card de care nu aveam nevoie'),
      _WinSeed('Am șters soldul unei luni întregi'),
    ],
  ),
  _ProjectSeed(
    'Încep să investesc',
    LifeArea.financial,
    'trending_up',
    [
      _WinSeed('Mi-am deschis primul cont de investiții'),
      _WinSeed('Am citit o carte despre fonduri index'),
      _WinSeed('Am setat o depunere lunară automată'),
      _WinSeed('Am rezistat tentației de a verifica soldul în fiecare zi'),
    ],
    goals: ['Fond de urgență pentru șase luni'],
  ),
  _ProjectSeed('Învăț să desenez', LifeArea.personal, 'brush', [
    _WinSeed('Am desenat în fiecare zi timp de o săptămână'),
    _WinSeed('Am terminat un portret de care mi-era teamă'),
    _WinSeed('Am umplut o pagină întreagă de schițe'),
    _WinSeed('I-am arătat un desen unui prieten'),
  ]),
  _ProjectSeed(
    'Învăț pianul',
    LifeArea.personal,
    'piano',
    [
      _WinSeed('Am cântat o melodie cu ambele mâini'),
      _WinSeed('Am exersat game timp de douăzeci de minute'),
      _WinSeed('Am învățat introducerea unei melodii pe care o ador'),
      _WinSeed('Am cântat pentru un prieten fără să-mi cer scuze'),
    ],
    goals: ['Cânt o piesă întreagă din memorie'],
  ),
  _ProjectSeed('Gătesc acasă', LifeArea.personal, 'restaurant', [
    _WinSeed('Am gătit cina în loc să comand'),
    _WinSeed('Am încercat o rețetă pe care nu o făcusem niciodată'),
    _WinSeed('Am pregătit prânzurile pentru toată săptămâna'),
    _WinSeed('Am gătit pentru prieteni și le-a plăcut'),
  ]),
  _ProjectSeed(
    'Călătoresc mai mult',
    LifeArea.personal,
    'luggage',
    [
      _WinSeed('Am rezervat o escapadă de weekend'),
      _WinSeed('Am explorat un oraș în care nu fusesem niciodată'),
      _WinSeed('Am călătorit ușor pentru prima dată'),
      _WinSeed('Am planificat următoarea călătorie încă fiind în aceasta'),
    ],
    goals: ['Vizitez trei țări noi'],
  ),
  _ProjectSeed(
    'Seară în doi în fiecare săptămână',
    LifeArea.social,
    'favorite',
    [
      _WinSeed('Am organizat o seară-surpriză'),
      _WinSeed('Am lăsat telefoanele deoparte la cină'),
      _WinSeed('Am încercat un restaurant nou împreună'),
      _WinSeed('Am dansat în sufragerie'),
    ],
  ),
  _ProjectSeed('Sun mai des familia', LifeArea.social, 'family_restroom', [
    _WinSeed('Mi-am sunat părinții doar ca să vorbim'),
    _WinSeed('Am luat prânzul la bunici'),
    _WinSeed('I-am scris un mesaj lung fratelui meu'),
    _WinSeed('Mi-am amintit la timp de o zi de naștere'),
  ]),
  _ProjectSeed('Dau înapoi comunității', LifeArea.philanthropic, 'redeem', [
    _WinSeed('Am donat hainele pe care nu le mai port'),
    _WinSeed('Am ajutat la banca de alimente din cartier'),
    _WinSeed('Am ținut un atelier gratuit'),
    _WinSeed('Am dus provizii la adăpostul local'),
  ]),
];
