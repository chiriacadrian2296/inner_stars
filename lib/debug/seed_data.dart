import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../models/life_area.dart';
import '../models/habit.dart';
import '../models/project.dart';
import '../utils/date_math.dart';

/// How many wins each seed project gains every time [seedSampleData] runs.
const winsPerSeedTap = 12;

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
/// content — nothing here is randomized. "Build this app" has a shorter
/// phrase list that repeats sooner, so it's the one that reaches its
/// constellation's slot capacity (~160) after enough taps and exercises the
/// overflow fallback. Spiritual is left with no seed project, to exercise
/// that area's empty state.
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
Future<void> seedSampleData({
  required StarRepository starRepository,
  required ProjectRepository projectRepository,
  required HabitRepository habitRepository,
  required HabitCompletionRepository habitCompletionRepository,
  required String languageCode,
}) async {
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

    final startingCount = starRepository.getAllForProject(project.id).length;

    for (var i = 0; i < winsPerSeedTap; i++) {
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
        description: phrase.description,
        projectId: project.id,
        achievedDate: date,
        intensity: 1 + position % 5,
      );
      // Star ids are millisecondsSinceEpoch; a tight loop without this could
      // mint duplicate ids, which every id-based lookup in the app assumes
      // can't happen.
      await Future.delayed(const Duration(milliseconds: 2));
    }

    if (!hasHistory) {
      await _seedStarHistory(
        starRepository: starRepository,
        project: project,
        spec: spec,
        specIndex: specIndex,
        today: today,
      );
    }

    if (!isNewProject) continue;

    for (final goalTitle in spec.goals) {
      await starRepository.add(title: goalTitle, projectId: project.id);
      await Future.delayed(const Duration(milliseconds: 2));
    }

    if (spec.seedDeadStar) {
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
}

/// Wins older than this many days mark a project as already holding seeded
/// history, so tapping the seed button again doesn't pile it up a second time.
const _historyStartDays = 36;

/// How many extra backdated wins each project (by spec index) gets, spread
/// over the ~5 months before the recent pattern — deliberately uneven, so
/// the area split, the date-range and area filters and the month paging on
/// the Statistics page all have something to show: Physical and Professional
/// dominate, Philanthropic is almost empty.
const _historyWinsPerProject = [30, 14, 26, 34, 8, 10, 12, 9, 5];

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
}) async {
  final count = specIndex < _historyWinsPerProject.length
      ? _historyWinsPerProject[specIndex]
      : 0;
  final offsets = <int>[
    for (var k = 0; k < count; k++)
      // 36..175 days ago, scattered but deterministic.
      _historyStartDays + (k * 53 + specIndex * 29) % 140,
    if (specIndex == _oldStreakProject)
      for (var k = 0; k < _oldStreakLength; k++) _oldStreakFromDay + k,
  ];
  final startingCount = starRepository.getAllForProject(project.id).length;
  for (var k = 0; k < offsets.length; k++) {
    final position = startingCount + k;
    final phrase = spec.wins[position % spec.wins.length];
    final date = addDays(today, -offsets[k]).add(
      Duration(hours: 7 + (k * 5 + specIndex) % 15, minutes: (k * 13) % 60),
    );
    await starRepository.add(
      title: phrase.title,
      description: phrase.description,
      projectId: project.id,
      achievedDate: date,
      intensity: 1 + (position * 3 + specIndex) % 5,
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
  _ProjectSeed(
    'Reconnect with old friends',
    LifeArea.social,
    'chat_bubble',
    [
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
    ],
  ),
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
      _WinSeed('Ho continuato a correre nonostante un crampo invece di mollare'),
      _WinSeed('Mi sono iscritto alla gara dei 10 km', 'Terrorizzato, ma l\'ho fatto.'),
      _WinSeed(
        'Ho corso al mio ritmo migliore di sempre',
        'Due minuti più veloce del mese scorso.',
      ),
      _WinSeed('Ho tenuto duro nell\'ultimo chilometro quando volevo camminare'),
      _WinSeed(
        'Sono uscito a correre dopo una giornata di lavoro davvero pesante',
        'Mi ha aiutato più di quanto pensassi.',
      ),
      _WinSeed('Ho fatto una sessione di scatti in salita che evitavo da settimane'),
      _WinSeed('Ho corso al freddo senza lamentarmi (troppo)'),
      _WinSeed(
        'Mi sono ripreso da un piccolo infortunio e sono tornato a correre',
        'Ci sono andato piano ma mi sono fatto vivo.',
      ),
      _WinSeed('Ho superato la distanza della settimana scorsa'),
    ],
    goals: ['Correre una mezza maratona', 'Scendere sotto i 50 minuti nei 10 km'],
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
    _WinSeed('Ho provato la parte profonda della piscina', 'Il cuore mi batteva forte ma l\'ho fatto.'),
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
      _WinSeed('Mi sono preso un giorno per la salute mentale senza sentirmi in colpa'),
      _WinSeed(
        'Ho fatto pratica stando in silenzio per 15 minuti',
        'È stato difficile, ma l\'ho fatto lo stesso.',
      ),
      _WinSeed('Sono riuscito a calmarmi da una spirale usando quello che ho imparato'),
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
      _WinSeed('Ho rifattorizzato il codice disordinato della settimana scorsa'),
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
      _WinSeed('Ho inviato una candidatura anche se mi sentivo poco qualificato'),
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
      _WinSeed('Ho rinunciato a un acquisto impulsivo e ho messo da parte i soldi'),
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
    habits: [_HabitSeed('Leggere prima di dormire', _activeStreak(7), intensity: 1)],
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
      _WinSeed('Ho organizzato qualcosa invece di aspettare che lo facesse qualcun altro'),
    ],
  ),
  _ProjectSeed('Fare volontariato ogni mese', LifeArea.philanthropic, 'campaign', [
    _WinSeed('Mi sono presentato per fare volontariato anche se ero esausto'),
    _WinSeed('Ho organizzato una piccola raccolta di donazioni'),
    _WinSeed(
      'Ho passato un sabato ad aiutare invece di riposare',
      'Stanco, ma contento di averlo fatto.',
    ),
    _WinSeed('Ho rinunciato a un weekend per aiutare un vicino a traslocare'),
    _WinSeed('Ho donato invece di comprare qualcosa di cui non avevo bisogno'),
  ]),
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
      _WinSeed('Am dus-o până la capăt în ultimul kilometru când voiam să merg la pas'),
      _WinSeed(
        'Am ieșit la alergat după o zi foarte grea la muncă',
        'M-a ajutat mai mult decât mă așteptam.',
      ),
      _WinSeed('Am făcut o sesiune de sprint pe deal pe care o evitam de săptămâni întregi'),
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
    _WinSeed('Am înotat un bazin întreg fără să mă opresc să-mi trag răsuflarea'),
    _WinSeed(
      'Am mers singur la piscină pentru prima dată',
      'Nimeni în spatele căruia să mă ascund, doar eu și apa.',
    ),
    _WinSeed('Am încercat partea adâncă', 'Inima îmi bătea cu putere, dar am făcut-o.'),
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
      _WinSeed('Mi-am luat o zi liberă pentru sănătatea mintală fără să mă simt vinovat'),
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
      _WinSeed('Am renunțat la o cumpărătură impulsivă și am pus banii deoparte'),
      _WinSeed('Am terminat luna sub buget'),
      _WinSeed(
        'Am analizat sincer cheltuielile mele',
        'Neplăcut, dar necesar.',
      ),
      _WinSeed('Am spus nu unei ieșiri în oraș ca să-mi protejez economiile'),
      _WinSeed('Am atins un obiectiv de economisire spre care lucram de mult timp'),
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
    habits: [_HabitSeed('Citesc înainte de culcare', _activeStreak(7), intensity: 1)],
  ),
  _ProjectSeed(
    'Reconectez cu vechi prieteni',
    LifeArea.social,
    'chat_bubble',
    [
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
    ],
  ),
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
];
