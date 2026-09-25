import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/photo_storage.dart';
import '../data/project_repository.dart';
import '../data/reader_entries.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../theme/app_colors.dart';
import '../utils/app_modals.dart';
import '../tutorials/tour_intro_target.dart';
import '../tutorials/tour_step_card.dart';
import '../utils/habit_stats.dart';
import '../utils/page_settled.dart';
import '../utils/responsive.dart';
import '../widgets/intensity_bolts.dart';
import '../widgets/logo_watermark.dart';
import '../widgets/photo_image.dart';
import '../widgets/photo_picker.dart';
import '../widgets/reader_entry_content.dart';
import '../widgets/responsive_content.dart';
import '../widgets/shareable_lit_star_card.dart';
import '../widgets/staggered_entrance.dart';
import 'photo_crop_screen.dart';
import 'star_form_screen.dart';

/// Moving to another star is a fade-through: the one leaving fades out
/// completely first, then the next one's blocks fade in. [_kContentSwapDuration]
/// is the fade-out; [_kContentEntranceLead] is how many cascade steps
/// (40 ms each) the arrival waits, sized to start right as the fade-out ends
/// so the empty beat between them stays as short as it can be.
const _kContentSwapDuration = Duration(milliseconds: 300);
const _kContentEntranceLead = 8;

/// Shows one star at a time, with looping prev/next navigation, its content
/// switching by whether the star is lit, still unlit, or dead.
///
/// Used two ways:
/// - From the Nightlight flow, browsing everything starting at the most
///   recent star ([allowEdit] false — pure reflection, no editing).
/// - From a tap on a specific card/star ([allowEdit] true — adds an edit
///   button that reuses [StarFormScreen], which requires
///   [projectRepository] and [refreshStars] too, since editing can move a
///   star to a different constellation).
class StarReaderScreen extends StatefulWidget {
  const StarReaderScreen({
    super.key,
    required this.repository,
    this.initialStars,
    this.initialEntries,
    required this.startIndex,
    required this.projectsById,
    this.allowEdit = false,
    this.projectRepository,
    this.starsShapeRepository,
    this.refreshStars,
    this.refreshEntries,
    this.habitRepository,
    this.habitCompletionRepository,
    this.onNavigateTo,
  }) : assert(
         initialStars != null || initialEntries != null,
         'Either initialStars or initialEntries is required.',
       ),
       assert(
         !allowEdit ||
             (projectRepository != null &&
                 starsShapeRepository != null &&
                 (refreshStars != null || refreshEntries != null)),
         'projectRepository, starsShapeRepository, and refreshStars/refreshEntries are required when allowEdit is true.',
       );

  final StarRepository repository;

  /// What this reader browses: either plain stars ([initialStars] — the
  /// flows that only ever deal in real stars) or every kind of star a
  /// constellation holds ([initialEntries] — pulsars and empty slots too,
  /// which also need [habitRepository]/[habitCompletionRepository]).
  final List<Star>? initialStars;
  final List<ReaderEntry>? initialEntries;
  final int startIndex;

  /// Resolves each star's project (and, through it, its area) for display.
  /// A star whose id isn't in here (stale data) still renders — just
  /// without that context row.
  final Map<int, Project> projectsById;
  final bool allowEdit;

  final ProjectRepository? projectRepository;
  final StarsShapeRepository? starsShapeRepository;

  /// Re-derives this reader's star list the same way [initialStars] was
  /// originally scoped — called after an edit/achieve/delete/resurrect so
  /// prev/next keeps browsing the right set.
  final List<Star> Function()? refreshStars;

  /// [refreshStars]' counterpart for [initialEntries].
  final List<ReaderEntry> Function()? refreshEntries;

  /// Needed only when the entries include pulsars.
  final HabitRepository? habitRepository;
  final HabitCompletionRepository? habitCompletionRepository;

  /// Set only when opened from the Sky's search popup — shows a
  /// "take me there" button that closes both this reader and the popup,
  /// handing the current star's project *and* id back to the sky camera
  /// to jump to — the id is what lets it land on that exact star's own
  /// tooltip rather than just the constellation's (see `SkyStarTarget`).
  final void Function(Project project, int starId)? onNavigateTo;

  @override
  State<StarReaderScreen> createState() => _StarReaderScreenState();
}

class _StarReaderScreenState extends State<StarReaderScreen> {
  @override
  void initState() {
    super.initState();
    // The "star-reader" tour — see its steps in [build]. Only for the real
    // browsing flow, not the Nightlight's read-only one.
    if (widget.allowEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        whenPageSettled(context, () {
          Tour.read(context).start('star-reader');
        });
      });
    }
  }

  late List<ReaderEntry> _entries =
      widget.initialEntries ?? starEntries(widget.initialStars!);
  late int _index = widget.startIndex;

  final _shareKey = GlobalKey();
  bool _sharing = false;

  /// Tap-to-hide-everything-but-the-photo, on a lit star's own image. Reset
  /// on prev/next so browsing to another star always lands back on its data.
  bool _photoOnly = false;

  /// Whether [_StarContent] plays its staggered entrance. Off only for a
  /// refresh after an edit, where it's the same star and nothing should
  /// replay.
  bool _animateContent = true;

  /// How the next star's blocks arrive: rising from below the first time the
  /// reader opens, then sliding in from the side the person moved toward
  /// (next from the end edge, previous from the start edge) so the motion
  /// follows their swipe.
  Axis _contentAxis = Axis.vertical;
  bool _contentReverse = false;

  /// Bumped when a move lands on a star that looks the same to the
  /// watermark as the one it left (same color and size), so the logo glides
  /// instead of staying perfectly still.
  int _watermarkPulse = 0;

  void _pulseWatermarkIfSame(int next) {
    final colors = context.colors;
    final from = _entries[_index];
    final to = _entries[next];
    final fromLit = _isLit(from);
    final toLit = _isLit(to);
    // The same look means the same color and size, whatever the kinds —
    // an unlit star and a dark pulsar share one, a lit star and a burning
    // pulsar another.
    if (logoWatermarkColor(colors, from.kind, lit: fromLit) ==
            logoWatermarkColor(colors, to.kind, lit: toLit) &&
        logoWatermarkScale(from.kind, lit: fromLit) ==
            logoWatermarkScale(to.kind, lit: toLit)) {
      _watermarkPulse++;
    }
  }

  void _showPrevious() {
    setState(() {
      _pulseWatermarkIfSame((_index - 1 + _entries.length) % _entries.length);
      _index = (_index - 1 + _entries.length) % _entries.length;
      _photoOnly = false;
      _animateContent = true;
      _contentAxis = Axis.horizontal;
      _contentReverse = true;
    });
  }

  void _showNext() {
    setState(() {
      _pulseWatermarkIfSame((_index + 1) % _entries.length);
      _index = (_index + 1) % _entries.length;
      _photoOnly = false;
      _animateContent = true;
      _contentAxis = Axis.horizontal;
      _contentReverse = false;
    });
  }

  void _togglePhotoOnly() => setState(() => _photoOnly = !_photoOnly);

  /// The current star's photo (or plain nightlight background), keyed by
  /// [_index] so [AnimatedSwitcher] crossfades between stars.
  ///
  /// Every star photo is baked to a fixed 9:16 portrait crop (see
  /// `photo_crop_screen.dart`) — covering a phone's own portrait screen
  /// with it barely crops anything, but covering a wide PC/web window
  /// would slice away almost all of its height. Past the wide-layout
  /// breakpoint, show it at its own shape instead, centered, with the same
  /// night gradient filling the margins so they read as more sky rather
  /// than a seam.
  Widget _buildPhotoLayer(
    BuildContext context,
    AppColors colors,
    String? photoPath,
  ) {
    final photo = Stack(
      fit: StackFit.expand,
      children: [
        if (photoPath != null)
          PhotoImage(
            photoPath: photoPath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        AnimatedOpacity(
          // Only the photo's own darkening veil fades away in photo-only
          // mode — a star with no photo has nothing to reveal underneath,
          // so its plain [nightlightGradient] background never toggles.
          opacity: photoPath != null && _photoOnly ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          child: Container(
            decoration: BoxDecoration(
              gradient: photoPath == null
                  ? colors.nightlightGradient
                  : RadialGradient(
                      center: const Alignment(0, -0.6),
                      radius: 1.2,
                      colors: [
                        colors.nightlightGradientCenter.withValues(
                          alpha: 0.55,
                        ),
                        colors.nightlightGradientMid.withValues(alpha: 0.75),
                        colors.nightlightGradientOuter.withValues(alpha: 0.9),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
            ),
          ),
        ),
      ],
    );
    if (photoPath == null || !isWideLayout(context)) {
      return Stack(
        key: ValueKey(_index),
        fit: StackFit.expand,
        children: [photo],
      );
    }
    return Stack(
      key: ValueKey(_index),
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(gradient: colors.nightlightGradient),
        ),
        Center(child: AspectRatio(aspectRatio: 9 / 16, child: photo)),
      ],
    );
  }

  Future<void> _shareCurrent() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('toByteData returned null');
      if (!mounted) return;
      final shareFile = XFile.fromData(
        byteData.buffer.asUint8List(),
        name: 'star_${DateTime.now().microsecondsSinceEpoch}.png',
        mimeType: 'image/png',
      );
      await SharePlus.instance.share(
        ShareParams(files: [shareFile], text: (_entries[_index] as StarEntry).star.title),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.strings.shareStarError)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Re-reads what this reader browses and stays on [anchor]: matched by
  /// identity, or — for a nascent slot that was just filled — by the slot it
  /// now holds a star on.
  void _refreshFrom(ReaderEntry anchor) {
    final refreshed = widget.refreshEntries != null
        ? widget.refreshEntries!()
        : starEntries(widget.refreshStars!());
    if (refreshed.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    var refreshedIndex = refreshed.indexWhere((e) => e.key == anchor.key);
    if (refreshedIndex == -1 && anchor.slot != null) {
      refreshedIndex = refreshed.indexWhere(
        (e) => e.projectId == anchor.projectId && e.slot == anchor.slot,
      );
    }
    setState(() {
      _entries = refreshed;
      _index = refreshedIndex == -1
          ? _index.clamp(0, refreshed.length - 1)
          : refreshedIndex;
      _animateContent = false;
    });
  }

  Future<void> _editOrResurrectCurrent() async {
    switch (_entries[_index]) {
      case StarEntry(:final star):
        await _editOrResurrectStar(star);
      case PulsarEntry(:final habit):
        await _editOrResurrectPulsar(habit);
      case NascentEntry():
        break;
    }
  }

  /// Fills the empty slot the current page is: the same form the sky opens
  /// for a nascent star, locked to this constellation and slot, with the
  /// pulsar option off (a pulsar never sits on the shape).
  Future<void> _configureNascent(NascentEntry entry) async {
    final project = widget.projectsById[entry.projectId];
    if (project == null) return;
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          lockedProject: project,
          slotSequence: entry.slot,
          allowPulsar: false,
        ),
      ),
    );
    if (result is! StarFormResult) return;
    await widget.repository.add(
      title: result.title,
      description: result.description,
      projectId: result.projectId,
      slotSequence: result.slotSequence,
      targetDate: result.targetDate,
      achievedDate: result.achievedDate,
      intensity: result.intensity,
      photoPath: result.photoPath,
    );
    _refreshFrom(entry);
  }

  /// The pulsar counterparts of the star flows: same edit form, same
  /// tombstone-on-delete, and a dead pulsar comes back as a pulsar only.
  Future<void> _editOrResurrectPulsar(Habit habit) async {
    final habits = widget.habitRepository;
    final completions = widget.habitCompletionRepository;
    if (habits == null || completions == null) return;
    final anchor = PulsarEntry(habit);

    if (habit.dead) {
      final result = await Navigator.of(context).push<Object>(
        MaterialPageRoute(
          builder: (_) => StarFormScreen(
            existingHabit: habit,
            contextProject: widget.projectsById[habit.projectId],
            projectRepository: widget.projectRepository,
            starsShapeRepository: widget.starsShapeRepository,
            hideDelete: true,
          ),
        ),
      );
      if (result is! StarFormResult) return;
      await habits.resurrect(
        habit.id,
        title: result.title,
        description: result.description,
        projectId: result.projectId,
        intensity: result.intensity ?? habit.intensity,
        frequency: result.habitFrequency ?? habit.frequency,
        targetPerPeriod: result.habitTargetPerPeriod ?? habit.targetPerPeriod,
        reminderHour: result.reminderHour,
        reminderMinute: result.reminderMinute,
        completionRepository: completions,
      );
      _refreshFrom(anchor);
      return;
    }

    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          existingHabit: habit,
          contextProject: widget.projectsById[habit.projectId],
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (result == null) return;
    if (result is StarFormDeleteRequested) {
      await habits.delete(habit.id);
      _refreshFrom(anchor);
      return;
    }
    final formResult = result as StarFormResult;
    await habits.update(
      id: habit.id,
      title: formResult.title,
      description: formResult.description,
      projectId: formResult.projectId,
      intensity: formResult.intensity ?? habit.intensity,
      frequency: formResult.habitFrequency ?? habit.frequency,
      targetPerPeriod: formResult.habitTargetPerPeriod ?? habit.targetPerPeriod,
      reminderHour: formResult.reminderHour,
      reminderMinute: formResult.reminderMinute,
    );
    _refreshFrom(anchor);
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// The binary "kept it today" toggle (a weekly habit's own day is still a
  /// plain yes/no, and so is a daily one whose target is 1).
  Future<void> _toggleToday(Habit habit, bool done) async {
    final completions = widget.habitCompletionRepository!;
    if (done) {
      await completions.unmarkDone(habit.id, _today);
    } else {
      await completions.markDone(habit.id);
    }
    if (mounted) setState(() => _animateContent = false);
  }

  /// The stepper for a daily habit with a target above 1 — each tap logs one
  /// more instance, with no cap on exceeding the target.
  Future<void> _logInstance(Habit habit) async {
    await widget.habitCompletionRepository!.logInstance(habit.id);
    if (mounted) setState(() => _animateContent = false);
  }

  Future<void> _unlogInstance(Habit habit) async {
    await widget.habitCompletionRepository!.unlogLastInstance(
      habit.id,
      _today,
    );
    if (mounted) setState(() => _animateContent = false);
  }

  /// Whether the page is giving light right now — a lit star, or a pulsar
  /// that's kept its rhythm.
  bool _isLit(ReaderEntry entry) => switch (entry) {
    StarEntry(:final star) => star.isLit,
    PulsarEntry(:final habit) =>
      !habit.dead &&
          isHabitLit(
            habit,
            habitCompletionCountsByDay(
              widget.habitCompletionRepository?.getAllForHabit(habit.id) ??
                  const [],
            ),
          ),
    NascentEntry() => false,
  };

  Future<void> _editOrResurrectStar(Star current) async {
    if (current.dead) {
      final result = await Navigator.of(context).push<Object>(
        MaterialPageRoute(
          builder: (_) => StarFormScreen(
            existingStar: current,
            contextProject: widget.projectsById[current.projectId],
            projectRepository: widget.projectRepository,
            starsShapeRepository: widget.starsShapeRepository,
            hideDelete: true,
          ),
        ),
      );
      if (result is! StarFormResult) return;
      await widget.repository.resurrect(
        current.id,
        title: result.title,
        description: result.description,
        projectId: result.projectId,
        targetDate: result.targetDate,
        achievedDate: result.achievedDate,
        intensity: result.intensity,
        photoPath: result.photoPath,
      );
      _refreshFrom(StarEntry(current));
      return;
    }

    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          existingStar: current,
          contextProject: widget.projectsById[current.projectId],
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (result == null) return;

    if (result is StarFormDeleteRequested) {
      await widget.repository.delete(current.id);
      _refreshFrom(StarEntry(current));
      return;
    }

    final addResult = result as StarFormResult;
    await widget.repository.update(
      id: current.id,
      title: addResult.title,
      description: addResult.description,
      projectId: addResult.projectId,
      targetDate: addResult.targetDate,
      achievedDate: addResult.achievedDate,
      intensity: addResult.intensity,
      photoPath: addResult.photoPath,
    );
    _refreshFrom(StarEntry(current));
  }

  Future<void> _markAchieved() async {
    final current = (_entries[_index] as StarEntry).star;
    final result = await showMarkAchievedSheet(context);
    if (result == null) return;
    await widget.repository.markAchieved(
      current.id,
      intensity: result.intensity,
      photoPath: result.photoPath,
    );
    _refreshFrom(StarEntry(current));
  }

  /// The fade-through both the page and the bottom bar use when moving to
  /// another star: the one leaving fades out and slips away toward the swipe
  /// (next toward the start edge, previous toward the end edge); the arriving
  /// one is drawn as-is, its own blocks doing the fading in.
  Widget _swapTransition(Widget child, Animation<double> animation) {
    if (child.key == ValueKey(_index)) return child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final away = (_contentReverse ? 1.0 : -1.0) * (rtl ? -1.0 : 1.0);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0.12 * away, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  /// [_swapTransition]'s counterpart for the bottom bar: the one leaving
  /// drops down as it fades instead of slipping sideways.
  Widget _sinkTransition(
    Widget child,
    Animation<double> animation,
    Key currentKey,
  ) {
    if (child.key == currentKey) return child;
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  /// The pulsar's page, with its live numbers read straight from the
  /// completions so a toggle or step below shows up right away.
  Widget _pulsarContent(
    Habit habit,
    Project? project,
    ReaderEntrance entrance,
  ) {
    final countsByDay = habitCompletionCountsByDay(
      widget.habitCompletionRepository?.getAllForHabit(habit.id) ?? const [],
    );
    // Its place among the constellation's pulsars, dead ones included (they
    // keep theirs), in order of creation.
    final siblings = [
      ...?widget.habitRepository?.getAllForProject(habit.projectId),
    ]..sort((a, b) {
        final byDate = a.createdAt.compareTo(b.createdAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    final position = siblings.indexWhere((h) => h.id == habit.id);
    return PulsarReaderContent(
      key: ValueKey(_index),
      habit: habit,
      project: project,
      number: position == -1 ? null : position + 1,
      lit: !habit.dead && isHabitLit(habit, countsByDay),
      streak: habitCurrentStreak(habit, countsByDay),
      weekProgress: habit.frequency == HabitFrequency.weekly
          ? habitWeeklyProgress(habit, countsByDay)
          : 0,
      entrance: entrance,
    );
  }

  /// Every button the bottom bar offers for [entry]: the kind's own primary
  /// action first, then whatever is common — share (a lit star), take me
  /// there, edit and delete.
  List<_ReaderAction> _actionsFor(ReaderEntry entry, Project? project) {
    final strings = context.strings;
    final canEdit = widget.allowEdit;
    final canRefresh =
        widget.refreshEntries != null || widget.refreshStars != null;
    final actions = <_ReaderAction>[];

    switch (entry) {
      case NascentEntry():
        actions.add(
          _ReaderAction(
            icon: Icons.settings_suggest,
            label: strings.nascentStarQuickLookConfigureAction,
            onTap: () => _configureNascent(entry),
          ),
        );
      case StarEntry(:final star):
        if (star.dead) {
          if (canEdit) {
            actions.add(
              _ReaderAction(
                icon: Icons.model_training,
                label: strings.actionReignite,
                onTap: _editOrResurrectCurrent,
                off: true,
              ),
            );
          }
        } else if (star.isLit) {
          actions.add(
            _ReaderAction(
              icon: Icons.share_outlined,
              label: strings.starQuickLookShareAction,
              onTap: _sharing ? null : _shareCurrent,
              loading: _sharing,
            ),
          );
        } else if (canRefresh) {
          // Lights the star. Drawn dark, like a pulsar that isn't burning:
          // the star is off, and this is what switches it on.
          actions.add(
            _ReaderAction(
              icon: Icons.power_settings_new,
              label: strings.actionLight,
              onTap: _markAchieved,
              off: true,
            ),
          );
        }
        if (widget.onNavigateTo != null && project != null) {
          actions.add(_takeMeThere(project, star.id));
        }
        if (canEdit && !star.dead) {
          actions.add(_editAction());
          actions.add(_deleteAction());
        }
      case PulsarEntry(:final habit):
        final completions = widget.habitCompletionRepository;
        if (habit.dead) {
          if (canEdit) {
            actions.add(
              _ReaderAction(
                icon: Icons.model_training,
                label: strings.actionReignite,
                onTap: () => _editOrResurrectPulsar(habit),
                off: true,
              ),
            );
          }
          break;
        }
        if (completions != null) {
          final countsByDay = habitCompletionCountsByDay(
            completions.getAllForHabit(habit.id),
          );
          final isWeekly = habit.frequency == HabitFrequency.weekly;
          if (!isWeekly && habit.targetPerPeriod > 1) {
            // A daily habit with a target above 1 steps up and down.
            final todayCount = habitDailyProgress(habit, countsByDay);
            actions.add(
              _ReaderAction(
                icon: Icons.add,
                label: strings.habitProgressToday(
                  todayCount,
                  habit.targetPerPeriod,
                ),
                onTap: () => _logInstance(habit),
              ),
            );
            actions.add(
              _ReaderAction(
                icon: Icons.remove,
                label: strings.undoHabitTodayAction,
                onTap: todayCount > 0 ? () => _unlogInstance(habit) : null,
              ),
            );
          } else {
            final done = countsByDay.containsKey(_today);
            actions.add(
              _ReaderAction(
                icon: Icons.local_fire_department,
                // The flame shows the pulsar's state: gold while it's burning
                // (done today), dark while it isn't.
                off: !done,
                label: done ? strings.actionTurnOff : strings.actionLight,
                onTap: () => _toggleToday(habit, done),
              ),
            );
          }
        }
        if (canEdit) {
          actions.add(_editAction());
          actions.add(_deleteAction());
        }
    }
    return actions;
  }

  _ReaderAction _takeMeThere(Project project, int starId) => _ReaderAction(
    icon: Icons.navigation,
    label: context.strings.actionFly,
    onTap: () {
      Navigator.of(context).pop();
      widget.onNavigateTo!(project, starId);
    },
  );

  _ReaderAction _editAction() => _ReaderAction(
    icon: Icons.edit_outlined,
    label: context.strings.starQuickLookEditAction,
    onTap: _editOrResurrectCurrent,
  );

  _ReaderAction _deleteAction() => _ReaderAction(
    icon: Icons.delete_outline,
    label: context.strings.deleteStarAction,
    onTap: _deleteCurrent,
  );

  /// Asks first, then deletes: a star or pulsar isn't erased, it stays in the
  /// sky as a dead star (see [Star.dead]).
  Future<void> _deleteCurrent() async {
    final entry = _entries[_index];
    final strings = context.strings;
    final colors = context.colors;
    final isPulsar = entry is PulsarEntry;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isPulsar
              ? strings.deletePulsarConfirmTitle
              : strings.deleteStarConfirmTitle,
        ),
        content: Text(
          isPulsar
              ? strings.deletePulsarConfirmBody
              : strings.deleteStarConfirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: colors.muted),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: Text(strings.deleteStarAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    switch (entry) {
      case StarEntry(:final star):
        await widget.repository.delete(star.id);
      case PulsarEntry(:final habit):
        await widget.habitRepository?.delete(habit.id);
      case NascentEntry():
        return;
    }
    _refreshFrom(entry);
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entries[_index];
    final star = entry is StarEntry ? entry.star : null;
    final project = widget.projectsById[entry.projectId];
    final colors = context.colors;
    final strings = context.strings;

    final photoPath = star != null && star.isLit ? star.photoPath : null;
    // The bar is identified by which buttons it holds (their icons), so it
    // only re-enters when that set changes.
    final barActions = _actionsFor(entry, project);
    final barSignature = [
      for (final a in barActions) a.icon.codePoint,
    ].join(',');
    final entrance = ReaderEntrance(
      animate: _animateContent,
      axis: _contentAxis,
      reverse: _contentReverse,
      lead: _kContentEntranceLead,
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (star != null && star.isLit)
            RepaintBoundary(
              key: _shareKey,
              child: ShareableLitStarCard(star: star, project: project),
            ),
          // Opaque floor over the share card above: that card holds every
          // detail of the star and must never show through the background.
          //
          // Every child of this Stack is keyed. Which of them exist varies
          // from star to star (the share card only when lit, the tap layer
          // only with a photo), and unkeyed children are matched by position:
          // one appearing or vanishing above would shift the rest, and
          // Flutter would rebuild the whole chrome from scratch — losing the
          // switchers' state, so nothing could animate out.
          Positioned.fill(
            key: const ValueKey('reader-floor'),
            child: ColoredBox(color: colors.night),
          ),
          // The tour's centered intro card (order 1) — an invisible target, so
          // it draws nothing of its own.
          Positioned.fill(
            key: const ValueKey('reader-tour-intro'),
            child: TourIntroTarget(
              tour: 'star-reader',
              order: 1,
              title: strings.starReaderTourIntroTitle,
              description: strings.starReaderTourIntroBody,
            ),
          ),
          Positioned.fill(
            key: const ValueKey('reader-photo'),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, animation) {
                // Only the background arriving fades in. The one leaving
                // stays fully opaque under it until it's gone: fading both
                // would dip the pair to partly see-through mid-swap, and the
                // share card's data (hidden behind the background) would
                // show through.
                if (child.key != ValueKey(_index)) return child;
                final scale = Tween<double>(
                  begin: 0.94,
                  end: 1.0,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: scale, child: child),
                );
              },
              child: _buildPhotoLayer(context, colors, photoPath),
            ),
          ),
          // A photo-less star's logo watermark. Its own steady layer, not
          // part of the per-star one above (which scales in with each star),
          // so between stars the logo stays put and only its color changes.
          Positioned.fill(
            key: const ValueKey('reader-watermark'),
            child: AnimatedOpacity(
              opacity: photoPath == null ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: LogoWatermark(
                pulse: _watermarkPulse,
                // The way the finger moved: next is a swipe toward the start
                // edge, previous toward the end edge (mirrored for RTL).
                pulseDirection:
                    (_contentReverse ? 1.0 : -1.0) *
                    (Directionality.of(context) == TextDirection.rtl
                        ? -1.0
                        : 1.0),
                scale: logoWatermarkScale(entry.kind, lit: _isLit(entry)),
                color: logoWatermarkColor(
                  colors,
                  entry.kind,
                  lit: _isLit(entry),
                ),
              ),
            ),
          ),
          if (photoPath != null)
            // Catches the tap that brings everything back once the chrome
            // below is [IgnorePointer]d in photo-only mode — translucent so
            // it never steals a tap from an actual button when the chrome
            // is showing (see the [IgnorePointer] below for why those still
            // win first).
            Positioned.fill(
              key: const ValueKey('reader-photo-tap'),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _togglePhotoOnly,
              ),
            ),
          IgnorePointer(
            key: const ValueKey('reader-chrome'),
            ignoring: photoPath != null && _photoOnly,
            child: AnimatedOpacity(
              opacity: photoPath != null && _photoOnly ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    children: [
                      ResponsiveContent(
                        child: Row(
                          children: [
                            StaggeredEntrance(
                              index: 0,
                              axis: Axis.horizontal,
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: colors.nightlightMuted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: StaggeredEntrance(
                                  index: 1,
                                  axis: Axis.horizontal,
                                  child: Text(
                                    strings.indexOfCount(
                                      _index + 1,
                                      _entries.length,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.nightlightMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            StaggeredEntrance(
                              index: 2,
                              axis: Axis.horizontal,
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(
                                  Icons.close,
                                  color: colors.nightlightMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: photoPath != null ? _togglePhotoOnly : null,
                          onHorizontalDragEnd: (details) {
                            final velocity = details.primaryVelocity ?? 0;
                            if (velocity < -200) {
                              _showNext();
                            } else if (velocity > 200) {
                              _showPrevious();
                            }
                          },
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: ResponsiveContent(
                                // Fade-through: the star leaving fades out
                                // and slips away toward the swipe; only then
                                // does the next one's cascade begin (see
                                // `_kContentEntranceLead`). The arriving one
                                // is drawn as-is here — its own blocks do the
                                // fading in.
                                child: AnimatedSwitcher(
                                  duration: _kContentSwapDuration,
                                  // Eased both ends, so the old text
                                  // visibly dwindles all the way to 0 instead
                                  // of dropping off at the start.
                                  switchOutCurve: Curves.easeInOut,
                                  transitionBuilder: _swapTransition,
                                  child: switch (entry) {
                                    StarEntry(:final star) => StarReaderContent(
                                      key: ValueKey(_index),
                                      star: star,
                                      project: project,
                                      entrance: entrance,
                                    ),
                                    PulsarEntry(:final habit) =>
                                      _pulsarContent(
                                        habit,
                                        project,
                                        entrance,
                                      ),
                                    NascentEntry(:final slot) =>
                                      NascentReaderContent(
                                        key: ValueKey(_index),
                                        slot: slot,
                                        project: project,
                                        entrance: entrance,
                                      ),
                                  },
                                ),
                              ),
                            ),
                          ),
                              ),
                              // Phones: invisible strips down both edges, like
                              // tapping through stories — left goes to the
                              // previous star, right to the next. Translucent,
                              // so a scroll that starts on one still scrolls
                              // the page beneath it.
                              if (!isWideLayout(context)) ...[
                                _TapStrip(
                                  onTap: _showPrevious,
                                  start: true,
                                  tourOrder: 2,
                                  title: strings.starReaderTourPrevTitle,
                                  description: strings.starReaderTourPrevBody,
                                ),
                                _TapStrip(
                                  onTap: _showNext,
                                  start: false,
                                  tourOrder: 3,
                                  title: strings.starReaderTourNextTitle,
                                  description: strings.starReaderTourNextBody,
                                ),
                              ],
                              // The tour's "middle of the page" step (order
                              // 4): an invisible target over the space
                              // between the two strips (the whole page when
                              // there are none).
                              PositionedDirectional(
                                top: 0,
                                bottom: 0,
                                start: isWideLayout(context)
                                    ? 0
                                    : MediaQuery.sizeOf(context).width *
                                          _TapStrip.widthFraction,
                                end: isWideLayout(context)
                                    ? 0
                                    : MediaQuery.sizeOf(context).width *
                                          _TapStrip.widthFraction,
                                child: IgnorePointer(
                                  child: HintTarget(
                                    tour: 'star-reader',
                                    order: 4,
                                    showArrow: false,
                                    pulse: false,
                                    contentBuilder: appTourStepCard,
                                    title: strings.starReaderTourCenterTitle,
                                    description:
                                        strings.starReaderTourCenterBody,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Room for the dock (see [_ReaderDock]) that sits over
                      // the bottom of the page.
                      SizedBox(
                        height:
                            _ReaderDock.height +
                            MediaQuery.paddingOf(context).bottom,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _ReaderDock(
            key: const ValueKey('reader-dock'),
            hidden: photoPath != null && _photoOnly,
            child:
                ResponsiveContent(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isWideLayout(context))
                        StaggeredEntrance(
                          index: 6,
                          axis: Axis.horizontal,
                          child: HintTarget(
                            tour: 'star-reader',
                            order: 2,
                            showArrow: true,
                            contentBuilder: appTourStepCard,
                            title: strings.starReaderTourPrevTitle,
                            description: strings.starReaderTourPrevArrowBody,
                            child: _NavCircleButton(
                              icon: Icons.chevron_left,
                              onTap: _showPrevious,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          child: HintTarget(
                            tour: 'star-reader',
                            order: 5,
                            showArrow: true,
                            direction: HintDirection.top,
                            contentBuilder: appTourStepCard,
                            title: strings.starReaderTourDockTitle,
                            description: strings.starReaderTourDockBody,
                            child: Center(
                            // Only a different set of buttons animates: the
                            // old set sinks and fades out, then the new one
                            // rises one button after another from below.
                            // Moving to a star with the same buttons leaves
                            // the bar alone.
                            child: AnimatedSwitcher(
                              duration: _kContentSwapDuration,
                              switchOutCurve: Curves.easeInOut,
                              transitionBuilder: (child, animation) =>
                                  _sinkTransition(
                                    child,
                                    animation,
                                    ValueKey(barSignature),
                                  ),
                              child: _ReaderActionBar(
                                key: ValueKey(barSignature),
                                actions: barActions,
                                entrance: entrance.risingFromBelow(),
                                // Swiping right (previous) runs the
                                // cascade right to left, so the last button
                                // up is the leftmost one; swiping left, and
                                // the first opening, keep it left to right.
                                reverseOrder:
                                    _contentAxis == Axis.horizontal &&
                                    _contentReverse !=
                                        (Directionality.of(context) ==
                                            TextDirection.rtl),
                              ),
                            ),
                          ),
                          ),
                        ),
                      ),
                      if (isWideLayout(context))
                        StaggeredEntrance(
                          index: 8,
                          axis: Axis.horizontal,
                          child: HintTarget(
                            tour: 'star-reader',
                            order: 3,
                            showArrow: true,
                            contentBuilder: appTourStepCard,
                            title: strings.starReaderTourNextTitle,
                            description: strings.starReaderTourNextArrowBody,
                            child: _NavCircleButton(
                              icon: Icons.chevron_right,
                              onTap: _showNext,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// The bottom of the reader: a black band with the arrows and the actions,
/// pinned to the bottom edge with a black shadow thrown up over the page
/// above it — so however long a star's title or description runs, it fades
/// out behind the buttons instead of running into them, and the buttons get
/// room to breathe. Like the rest of the chrome it hides in photo-only mode.
class _ReaderDock extends StatelessWidget {
  const _ReaderDock({super.key, required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  /// Its height without the system inset: the black band above the buttons,
  /// the buttons themselves, and the margin below.
  static const _bandAbove = 24.0;
  static const _below = 28.0;
  static const height = _bandAbove + 48 + _below;

  @override
  Widget build(BuildContext context) {
    // [Positioned] must stay the outermost widget here: it's only meaningful
    // as a direct child of the enclosing [Stack].
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.9),
                  blurRadius: 32,
                  spreadRadius: 6,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                _bandAbove,
                12,
                _below + MediaQuery.paddingOf(context).bottom,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  const _NavCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.nightlightMuted.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: context.colors.text),
        ),
      ),
    );
  }
}

/// One button in the reader's bottom bar.
class _ReaderAction {
  const _ReaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.off = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  /// Drawn dark instead of gold — the button that switches something off.
  final bool off;
}

/// An invisible tap target down one edge of the page — see the strips in
/// [_StarReaderScreenState.build]. [start] is the leading edge (left in LTR).
class _TapStrip extends StatelessWidget {
  const _TapStrip({
    required this.onTap,
    required this.start,
    required this.tourOrder,
    required this.title,
    required this.description,
  });

  final VoidCallback onTap;
  final bool start;

  /// This strip's step in the "star-reader" tour.
  final int tourOrder;
  final String title;
  final String description;

  /// How much of the width each strip covers.
  static const widthFraction = 0.25;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: 0,
      bottom: 0,
      start: start ? 0 : null,
      end: start ? null : 0,
      width: MediaQuery.sizeOf(context).width * widthFraction,
      child: HintTarget(
        tour: 'star-reader',
        order: tourOrder,
        showArrow: false,
        pulse: false,
        contentBuilder: appTourStepCard,
        title: title,
        description: description,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// The reader's bottom bar between the two arrows: every action available
/// for the page, all in the same gold pill. With room, each shows its icon
/// and label; short of it, the first (the kind's own main action) keeps its
/// label and the rest go icon-only; and if even that doesn't fit, all of
/// them are icon-only.
class _ReaderActionBar extends StatelessWidget {
  const _ReaderActionBar({
    super.key,
    required this.actions,
    required this.entrance,
    this.reverseOrder = false,
  });

  final List<_ReaderAction> actions;

  /// Runs the cascade from the last button to the first.
  final bool reverseOrder;

  /// How each button arrives — see [ReaderEntrance].
  final ReaderEntrance entrance;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        double labeledWidth(_ReaderAction action) {
          final painter = TextPainter(
            text: TextSpan(text: action.label, style: _ActionButton.labelStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          return _ActionButton.labeledPadding * 2 +
              _ActionButton.iconSize +
              _ActionButton.iconGap +
              painter.width;
        }

        double total(List<double> widths) =>
            widths.fold<double>(0, (sum, w) => sum + w) +
            _gap * (widths.length - 1);

        const compact = _ActionButton.compactWidth;
        final allLabeled = total([for (final a in actions) labeledWidth(a)]);
        final firstLabeled = total([
          labeledWidth(actions.first),
          for (var i = 1; i < actions.length; i++) compact,
        ]);

        // Text only where there's room for it: never on a phone, and on a
        // wide screen as many labels as fit.
        final labeledCount = !isWideLayout(context)
            ? 0
            : allLabeled <= constraints.maxWidth
            ? actions.length
            : (firstLabeled <= constraints.maxWidth ? 1 : 0);

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (var i = 0; i < actions.length; i++)
              entrance(
                7 + (reverseOrder ? actions.length - 1 - i : i),
                _ActionButton(
                  icon: actions[i].icon,
                  label: actions[i].label,
                  onTap: actions[i].onTap,
                  loading: actions[i].loading,
                  off: actions[i].off,
                  compact: i >= labeledCount,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The gold pill every action shares — an icon and label together inside one
/// [StadiumBorder], or just the icon when [compact].
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.compact = false,
    this.off = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool compact;

  /// Dark and muted instead of gold.
  final bool off;

  static const iconSize = 20.0;
  static const iconGap = 8.0;
  static const labeledPadding = 16.0;
  static const _verticalPadding = 14.0;

  /// Icon-only: the icon plus the same padding all round.
  static const compactWidth = iconSize + _verticalPadding * 2;

  static const labelStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 15,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = off ? colors.muted : colors.onGold;
    final leading = loading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foreground,
            ),
          )
        : Icon(icon, color: foreground, size: iconSize);
    final fill = off ? colors.nightBorder : colors.gold;
    final pill = Material(
      color: onTap == null && !loading ? fill.withValues(alpha: 0.4) : fill,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: compact
              ? const EdgeInsets.all(_verticalPadding)
              : const EdgeInsets.symmetric(
                  horizontal: labeledPadding,
                  vertical: _verticalPadding,
                ),
          child: compact
              ? leading
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    leading,
                    const SizedBox(width: iconGap),
                    Text(
                      label,
                      maxLines: 1,
                      style: labelStyle.copyWith(color: foreground),
                    ),
                  ],
                ),
        ),
      ),
    );
    return compact ? Tooltip(message: label, child: pill) : pill;
  }
}

/// What the "mark achieved" sheet collects before handing control back to
/// [_StarReaderScreenState._markAchieved].
/// Asks for what lighting a goal needs — intensity and an optional photo —
/// and returns it, or null if dismissed. Shared by the reader and the Search
/// cards' quick menu.
Future<MarkAchievedResult?> showMarkAchievedSheet(BuildContext context) {
  return showAppSheet<MarkAchievedResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const MarkAchievedSheet(),
  );
}

class MarkAchievedResult {
  const MarkAchievedResult({required this.intensity, this.photoPath});
  final int intensity;
  final String? photoPath;
}

/// Quick "log it now" sheet for a goal — lighter than the full edit form,
/// but still covers the one thing a goal is missing next to a plain
/// victory: intensity and an optional photo, exactly like [AddStarScreen]'s
/// achieved fields.
class MarkAchievedSheet extends StatefulWidget {
  const MarkAchievedSheet({super.key});

  @override
  State<MarkAchievedSheet> createState() => _MarkAchievedSheetState();
}

class _MarkAchievedSheetState extends State<MarkAchievedSheet> {
  int _intensity = 3;
  String? _photoPath;

  Future<void> _pickPhoto() async {
    final colors = context.colors;
    final strings = context.strings;

    final source = await showAppSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StaggeredEntrance(
                index: 0,
                child: ListTile(
                  leading: Icon(
                    Icons.photo_camera_outlined,
                    color: colors.gold,
                  ),
                  title: Text(
                    strings.takePhotoOption,
                    style: TextStyle(color: colors.text),
                  ),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
              ),
              StaggeredEntrance(
                index: 1,
                child: ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: colors.gold,
                  ),
                  title: Text(
                    strings.choosePhotoOption,
                    style: TextStyle(color: colors.text),
                  ),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final croppedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => PhotoCropScreen(imageFile: picked)),
      );
      if (croppedBytes == null || !mounted) return;

      final savedPath = await PhotoStorage.saveBytes(croppedBytes);
      if (!mounted) return;
      setState(() => _photoPath = savedPath);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.photoPickError)));
    }
  }

  void _removePhoto() => setState(() => _photoPath = null);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Text(
                strings.markAchievedSheetTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(height: 18),
            StaggeredEntrance(
              index: 1,
              child: IntensityBolts(
                intensity: _intensity,
                size: 26,
                spacing: 6,
                emphasizeLast: true,
                emphasizedScale: 1.6,
              ),
            ),
            StaggeredEntrance(
              index: 1,
              child: Slider(
                value: _intensity.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: (v) => setState(() => _intensity = v.round()),
              ),
            ),
            const SizedBox(height: 6),
            StaggeredEntrance(
              index: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.photoLabel,
                  style: TextStyle(fontSize: 13, color: colors.muted),
                ),
              ),
            ),
            const SizedBox(height: 6),
            StaggeredEntrance(
              index: 2,
              child: PhotoPicker(
                photoPath: _photoPath,
                onPick: _pickPhoto,
                onRemove: _removePhoto,
              ),
            ),
            const SizedBox(height: 16),
            StaggeredEntrance(
              index: 3,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(
                    MarkAchievedResult(
                      intensity: _intensity,
                      photoPath: _photoPath,
                    ),
                  ),
                  child: Text(strings.markAchievedConfirm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
