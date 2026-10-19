import '../models/display_text.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../widgets/area_icon.dart';

import 'package:hint_kit/hint_kit.dart';
import 'package:image_picker/image_picker.dart';

import '../data/constellation_layout.dart';
import '../data/custom_constellation_repository.dart';
import '../data/habit_repository.dart';
import '../data/photo_storage.dart';
import '../data/star_repository.dart';
import '../data/star_media_storage.dart';
import '../data/project_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../models/star_media.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_style.dart';
import '../tutorials/tour_step_card.dart';
import '../tutorials/tutorial_replay.dart';
import '../utils/app_modals.dart';
import '../utils/app_date_picker.dart';
import '../utils/app_time_picker.dart';
import '../utils/date_format.dart';
import '../utils/icon_for_slug.dart';
import '../utils/page_settled.dart';
import '../widgets/app_field.dart';
import '../widgets/cycle_length_field.dart';
import '../widgets/area_picker.dart';
import '../widgets/photo_picker.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/project_picker.dart';
import '../widgets/responsive_content.dart';
import '../widgets/form_kind_tiles.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/victory_fields.dart';
import 'new_project_screen.dart';
import 'photo_crop_screen.dart';

/// What the user entered, handed back to whoever pushed this screen.
/// Trimming and blank-to-null normalization for [description] happen in the
/// repositories, not here, so that logic lives in one place regardless of
/// whether this was an add or an edit.
class StarFormResult {
  const StarFormResult({
    required this.kind,
    required this.title,
    this.iconSlug = '',
    this.description,
    required this.projectId,
    this.slotSequence,
    this.targetDate,
    this.achievedDate,
    this.intensity,
    this.photoPath,
    this.media = const [],
    this.reminderHour,
    this.reminderMinute,
    this.habitFrequency,
    this.habitTargetPerPeriod,
    this.habitCycleLength,
  });

  /// Which kind of star was chosen — always one of [kCreatableStarKinds].
  /// A [StarKind.pulsar] result belongs to [HabitRepository]; the other two
  /// belong to [StarRepository]. Callers switch on this rather than
  /// inspecting which optional fields happen to be filled in.
  final StarKind kind;

  final String title;
  final String iconSlug;
  final String? description;
  final String projectId;

  /// Set only when this form was opened by tapping a *nascent* star — the
  /// exact slot on the constellation's shape the new star has to land on.
  /// Null everywhere else, meaning "append to the end".
  final int? slotSequence;

  /// [StarKind.unlit] only — the optional date it's aimed at.
  final DateTime? targetDate;

  /// [StarKind.lit] only — when the effort was actually made.
  final DateTime? achievedDate;

  /// The intensity of the effort, 1-5. Set for [StarKind.lit] and
  /// [StarKind.pulsar]; null for [StarKind.unlit], whose real cost isn't
  /// knowable until it's lit.
  final int? intensity;

  /// Already-saved app-private path (see [PhotoStorage]), or null for no
  /// photo — never a raw picker path. [StarKind.lit] only.
  final String? photoPath;

  /// Optional extras (voice notes, photos, videos, links), already stored
  /// by [StarMediaStorage]. [StarKind.lit] only.
  final List<StarMedia> media;

  /// [StarKind.pulsar] only. Both null = inherits the app's single global
  /// reminder time.
  final int? reminderHour;
  final int? reminderMinute;

  /// [StarKind.pulsar] only — see [Habit.frequency]/[Habit.targetPerPeriod]
  /// for what each means. Null for every other kind.
  final HabitFrequency? habitFrequency;
  final int? habitTargetPerPeriod;

  /// [StarKind.pulsar] only — how many distinct days complete one cycle
  /// (see [Habit.cycleLength]); [intensity] is the reward for completing it.
  final int? habitCycleLength;
}

/// Popped instead of [StarFormResult] when editing and the user deleted the
/// star instead of saving changes to it — see [StarRepository.delete] /
/// [HabitRepository.delete]: both tombstone rather than erase.
class StarFormDeleteRequested {
  const StarFormDeleteRequested();
}

enum _CreateFlowDiscardChoice { chooseAnother, exit }

/// The one place any star is created or edited, whichever kind it is — a
/// lit star (a past victory), a pulsar (a present habit), or an unlit star
/// (a future goal). They're all the same thing at heart, *one effort*, so
/// they share one form and one switch between them rather than a separate
/// page per kind.
///
/// Also doubles as the edit screen: pass [existingStar] or [existingHabit]
/// to pre-fill every field. Editing never lets the kind switch across the
/// star/pulsar line (that would mean converting one stored entity into
/// another) — a star can still move between lit and unlit, which is just
/// its own [Star.achievedDate] changing.
///
/// A project must be resolved one of two ways:
/// - [lockedProject]: the project is already known (e.g. opened from that
///   constellation's own screen) and isn't user-selectable here.
/// - [projectRepository]: no project is implied yet, so [pickProject] lets
///   the user choose an existing constellation or create a new one inline.
///   Required whenever [lockedProject] isn't given — including when
///   editing, since the picker is how a star gets moved to another
///   constellation.
class StarFormScreen extends StatefulWidget {
  const StarFormScreen({
    super.key,
    this.existingStar,
    this.existingHabit,
    this.lockedProject,
    this.projectRepository,
    this.starsShapeRepository,
    this.contextProject,
    this.initialDate,
    this.initialKind = StarKind.lit,
    this.slotSequence,
    this.allowPulsar = true,
    this.hideDelete = false,
    this.allowConstellation = false,
    this.startAsConstellation = false,
    this.startWithoutSelection = false,
    this.presetArea,
  }) : assert(
         existingStar == null || existingHabit == null,
         'A form edits either a star or a pulsar, never both.',
       ),
       assert(
         lockedProject != null ||
             (projectRepository != null && starsShapeRepository != null),
         'Provide lockedProject (pre-scoped, no picker) or both projectRepository and starsShapeRepository (picker, for add or edit).',
       );

  final Star? existingStar;
  final Habit? existingHabit;
  final Project? lockedProject;
  final ProjectRepository? projectRepository;

  /// Required alongside [projectRepository] whenever [lockedProject] isn't
  /// given — the constellation picker offers an inline "create new" action
  /// that needs it (see [pickProject]).
  final StarsShapeRepository? starsShapeRepository;

  /// The existing star's current constellation, resolved by the caller —
  /// seeds the picker's initial selection when editing.
  final Project? contextProject;

  /// Pre-fills the date when lighting a star directly (e.g. opened from a
  /// specific day on the dashboard calendar) — ignored when editing or when
  /// the form doesn't start on [StarKind.lit].
  final DateTime? initialDate;

  /// Which kind a brand new star starts as — set by whichever entry point
  /// opened this form. Ignored when editing, since that always derives the
  /// kind from what's actually stored.
  final StarKind initialKind;

  /// Set when this form was opened by tapping a nascent star: the slot that
  /// star occupies on its constellation's shape, handed straight back in
  /// the result so the new star lands exactly there. Also switches the
  /// header over to "configure this star" wording, since that's what's
  /// really happening — the star already exists in the sky, it's being
  /// given a meaning.
  final int? slotSequence;

  /// Whether the pulsar option is offered. False when configuring a nascent
  /// star: that slot belongs to the constellation's own shape, and a pulsar
  /// doesn't sit on the shape at all — it scatters around it.
  final bool allowPulsar;

  /// Hides the delete button — used when this form is really a "reignite a
  /// dead star" flow, since a dead star has nothing further to delete.
  final bool hideDelete;

  /// Adds a fourth tile, "Constellation", to the kind switch: choosing it
  /// swaps the star fields for the constellation form, and saving pops a
  /// [Project] instead of a [StarFormResult]. Only for creating (never
  /// editing), and needs [projectRepository] and [starsShapeRepository].
  final bool allowConstellation;

  /// Opens on the constellation tile. Ignored without [allowConstellation].
  final bool startAsConstellation;

  /// Starts with no creation tile selected and no form visible. Intended for
  /// the global create entry point, where no kind is implied yet. Editing and
  /// [startAsConstellation] always keep their explicit initial selection.
  final bool startWithoutSelection;

  /// Pre-fills the area, for both the star and the constellation form.
  final LifeArea? presetArea;

  bool get isEditing => existingStar != null || existingHabit != null;

  @override
  State<StarFormScreen> createState() => _StarFormScreenState();
}

class _StarFormScreenState extends State<StarFormScreen> {
  late String _iconSlug =
      widget.existingHabit?.iconSlug ?? widget.existingStar?.iconSlug ?? '';

  Future<void> _pickActivityIcon() async {
    final selected = await pickIconSlug(
      context,
      selected: _iconSlug.isEmpty ? null : _iconSlug,
      area: _selectedArea,
    );
    if (selected != null && mounted) setState(() => _iconSlug = selected);
  }

  /// The compact icon field beside the area field, the same one the
  /// constellation form uses, for every kind of star.
  Widget _buildActivityIconField(AppStrings strings) => AppPickerField(
    key: const ValueKey('activity-icon-field'),
    label: strings.iconLabel,
    hint: strings.iconLabel,
    requirement: FieldRequirement.required,
    icon: _iconSlug.isEmpty ? Icons.apps_outlined : iconForSlug(_iconSlug),
    text: _iconSlug.isEmpty ? null : _iconSlug,
    onReset: () => setState(() => _iconSlug = ''),
    onTap: _pickActivityIcon,
    iconOnly: true,
  );

  /// With the project already decided (area and project fields hidden), the
  /// icon field sits to the right of the title, as it does beside the area
  /// field everywhere else.
  Widget _withIconBeside(AppStrings strings, Widget title) {
    if (widget.lockedProject == null) return title;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: title),
        const SizedBox(width: 12),
        Expanded(flex: 1, child: _buildActivityIconField(strings)),
      ],
    );
  }

  late final _titleController = TextEditingController(text: _initialTitle);
  late final _descriptionController = TextEditingController(
    text: _initialDescription,
  );

  late StarKind _kind = _resolveInitialKind();

  bool get _canCreateConstellation =>
      widget.allowConstellation &&
      !widget.isEditing &&
      widget.projectRepository != null &&
      widget.starsShapeRepository != null;

  /// The constellation tile is selected: the star fields give way to the
  /// embedded constellation form.
  late bool _constellationMode =
      _canCreateConstellation && widget.startAsConstellation;

  /// The global create page can begin as a neutral chooser. [_kind] still
  /// carries the eventual default internally so all kind-specific state can
  /// stay non-null, but it is not selected and its fields stay hidden.
  late bool _hasKindSelection =
      !widget.startWithoutSelection ||
      widget.isEditing ||
      widget.startAsConstellation;

  /// The embedded form is only built once first needed (it starts its own
  /// tour then), and kept alive after, so switching away and back keeps
  /// what was typed.
  late bool _constellationBuilt = _constellationMode;

  /// The star tutorial is deferred until a star kind is first chosen from a
  /// neutral page; the constellation form owns its separate tutorial.
  late bool _starFormWasOpened = _hasKindSelection && !_constellationMode;

  /// The global chooser leaves the center in two beats: its question fades,
  /// then the tiles rise to their normal form position. Fields wait for the
  /// second beat so they do not appear underneath moving controls.
  bool _chooserQuestionVisible = true;
  bool _chooserTransitioning = false;
  late bool _chooserSettled = _hasKindSelection;
  bool _embeddedConstellationDirty = false;
  int _constellationFormEpoch = 0;

  /// Bumped only when the person picks a kind themselves, so everything
  /// below the switch plays its entrance again for the new kind. The tour
  /// changes `_kind` too (priming and following its steps), and must not
  /// re-run the cascade under its own spotlight.
  int _kindEpoch = 0;
  late Project? _selectedProject =
      widget.lockedProject ?? widget.contextProject;

  /// The supernova field's own selection — purely a picker convenience,
  /// never saved on its own (a star only ever stores a project id, never
  /// an area). It is still tracked as form state so choosing only an area
  /// counts as an unsaved change. Seeded from whichever project already
  /// applies, same as that field; [_openAreaPicker]/[_openProjectPicker]
  /// are what keep the two in sync afterward.
  late LifeArea? _selectedArea = _selectedProject?.area ?? widget.presetArea;
  late int _intensity =
      widget.existingStar?.intensity ?? widget.existingHabit?.intensity ?? 3;

  /// Whether the intensity holds a value the person chose in this form.
  /// Until then the bolts and slider sit inactive, like an empty field,
  /// and saving is held back — also when editing: the slider then starts
  /// on the saved value, shown inactive, so it says where it was but still
  /// has to be chosen again.
  bool _intensityTouched = false;

  /// An existing activity's saved intensity, shown inactive until chosen.
  bool get _hasSavedIntensity =>
      widget.existingStar?.intensity != null ||
      widget.existingHabit?.intensity != null;

  /// Null until the user actually picks a date (or, when editing a lit
  /// star, seeded from the date it was lit on).
  ///
  /// Date and time are independent: this holds the day only (midnight), and
  /// [_time] the time of day. Each is set and reset on its own; an unset one
  /// falls back to today / now when saving.
  late DateTime? _date = _dayOnly(
    widget.existingStar?.achievedDate ??
        (_kind == StarKind.lit ? widget.initialDate : null),
  );
  late TimeOfDay? _time = widget.existingStar?.achievedDate == null
      ? null
      : TimeOfDay.fromDateTime(widget.existingStar!.achievedDate!);

  static DateTime? _dayOnly(DateTime? value) =>
      value == null ? null : DateTime(value.year, value.month, value.day);
  late DateTime? _targetDate = widget.existingStar?.targetDate;
  late String? _photoPath = widget.existingStar?.photoPath;
  late List<StarMedia> _media = widget.existingStar?.media ?? const [];
  late final List<StarMedia> _initialMedia = _media;
  late bool _victoryDetailsExpanded = _photoPath != null || _media.isNotEmpty;
  bool _saved = false;

  /// Set once the person carried on in a new constellation because the one
  /// this form opened on was full.
  bool _movedToNewConstellation = false;
  late bool _customReminder = widget.existingHabit?.reminderHour != null;
  late int _reminderHour = widget.existingHabit?.reminderHour ?? 9;
  late int _reminderMinute = widget.existingHabit?.reminderMinute ?? 0;
  late HabitFrequency _habitFrequency =
      widget.existingHabit?.frequency ?? HabitFrequency.daily;
  late int _habitTargetPerPeriod = widget.existingHabit?.targetPerPeriod ?? 1;
  late int _cycleLength =
      widget.existingHabit?.cycleLength ?? kDefaultCycleLength;

  /// Whether the "Custom" length chip is the selected one: either picked
  /// explicitly, or because the length being edited isn't one of the presets.
  late bool _cycleCustom = !kCyclePresets.contains(_cycleLength);

  // What the form above started out as — captured once, alongside it, so
  // _hasUnsavedChanges has something to compare against regardless of
  // whether this is a blank new-star form or one seeded from something that
  // already exists. Deliberately mirrors each field's own initializer.
  late final String? _initialProjectId =
      (widget.lockedProject ?? widget.contextProject)?.id;
  late final LifeArea? _initialArea = _selectedArea;
  late final StarKind _initialKind = _kind;
  late final int _initialIntensity = _intensity;
  late final DateTime? _initialDateValue = _date;
  late final TimeOfDay? _initialTimeValue = _time;
  late final DateTime? _initialTargetDate = widget.existingStar?.targetDate;
  late final String? _initialPhotoPath = widget.existingStar?.photoPath;
  late final bool _initialCustomReminder = _customReminder;
  late final int _initialReminderHour = _reminderHour;
  late final int _initialReminderMinute = _reminderMinute;
  late final HabitFrequency _initialHabitFrequency = _habitFrequency;
  late final int _initialHabitTargetPerPeriod = _habitTargetPerPeriod;
  late final int _initialCycleLength = _cycleLength;
  late final bool _initialCycleCustom = _cycleCustom;

  String get _initialTitle =>
      widget.existingStar?.title ?? widget.existingHabit?.title ?? '';
  String get _initialDescription =>
      widget.existingStar?.description ??
      widget.existingHabit?.description ??
      '';

  /// Which kinds this particular form is allowed to switch between — see
  /// the class doc: editing never crosses the star/pulsar line, and a
  /// nascent slot can only become a star.
  List<StarKind> get _availableKinds {
    if (widget.existingHabit != null) return const [StarKind.pulsar];
    if (widget.existingStar != null) {
      return const [StarKind.lit, StarKind.unlit];
    }
    if (!widget.allowPulsar) return const [StarKind.lit, StarKind.unlit];
    return kCreatableStarKinds;
  }

  StarKind _resolveInitialKind() {
    if (widget.existingHabit != null) return StarKind.pulsar;
    if (widget.existingStar case final star?) {
      return star.isLit ? StarKind.lit : StarKind.unlit;
    }
    if (!widget.allowPulsar && widget.initialKind == StarKind.pulsar) {
      return StarKind.lit;
    }
    return widget.initialKind;
  }

  /// `_kind` as it was before [_primeKindDependentTourSteps] (or
  /// [_syncKindToTour]) ever touched it for the sake of the tour — restored
  /// once the tour ends (see [_handleTourChanged]), so walking through
  /// every kind's own steps never leaves the form quietly switched to a
  /// different kind than the one the user actually opened it for.
  StarKind? _kindBeforeTour;
  TourController? _tourBeingWatched;

  @override
  void initState() {
    super.initState();
    // The "star-form" tour — see its steps on `_StarKindSwitch`'s Unlit
    // tile and below in this file's own `build`. Only for a brand new star:
    // editing an existing one isn't the "how do I add a goal" moment this
    // tour is for, and `Tour.start` itself already no-ops once the user has
    // seen it (see `PrefsTourStorage`).
    if (!widget.isEditing && _starFormWasOpened) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) whenPageSettled(context, _maybeStartTour);
      });
    }
  }

  Future<void> _maybeStartTour() async {
    if (!mounted) return;
    final TourController tour = Tour.read(context);
    // Mirrors the check `tour.start` itself makes — skip the priming dance
    // below entirely when the tour won't actually run (already seen, or
    // tutorials are switched off; see `PrefsTourStorage`), so returning
    // users never see the brief kind flip this needs.
    if (await tour.storage.isCompleted('star-form')) return;
    if (!mounted) return;
    await _primeKindDependentTourSteps();
    if (!mounted) return;
    _tourBeingWatched = tour..addListener(_handleTourChanged);
    unawaited(startTourAuto(tour, 'star-form'));
  }

  /// Briefly visits every kind (Pulsar, Unlit, then back to Lit) before the
  /// tour's first step ever shows, so every kind-gated step's `HintTarget`
  /// mounts — and registers its `order` with `hint_kit`'s `TourScope` — at
  /// least once, landing on Lit specifically because that's where the tour
  /// itself always starts (see [_syncKindToTour]) regardless
  /// of which kind the screen actually opened on.
  ///
  /// Without this, an order that has never registered doesn't just get
  /// skipped: `TourScope.orderAt` resolves the tour's raw step counter
  /// against however many orders happen to be registered *so far*, so a
  /// step registering late (the user manually switching kind mid-tour, say)
  /// retroactively changes which order every *later* index pointed at —
  /// confirmed live, this is exactly what made Habit Frequency show up
  /// scrolled to a wrong, half-broken position after switching kind by
  /// hand. Priming once up front means the mapping is complete and stable
  /// before the tour ever reads it, so nothing has to reshuffle later — see
  /// [_syncKindToTour] for the other half, which then drives `_kind` itself
  /// to whatever each step needs as the tour actually reaches it.
  Future<void> _primeKindDependentTourSteps() async {
    _kindBeforeTour = _kind;
    for (final probe in [StarKind.pulsar, StarKind.unlit, StarKind.lit]) {
      if (!mounted) return;
      setState(() => _kind = probe);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  /// Auto-drives `_kind` to whatever the active `star-form` step actually
  /// needs, so the tour walks through every field on its own instead of
  /// waiting for the user to switch kind by hand — the same idea as
  /// `SkyExplorerView`'s own `_syncModeToTour` for `search-stars`, but
  /// across three kinds instead of two modes. The fixed order the tour
  /// walks (see the `order:` on each `HintTarget` below): the kind switch
  /// itself (forced to Lit, so every run starts from the same place
  /// regardless of which kind the screen actually opened on), then every
  /// Lit field including the photo, then Pulsar's own fields, then Unlit's
  /// one exclusive field, then Save — which restores whatever kind the
  /// screen actually started on (see [_handleTourChanged] for the same
  /// restore when the tour ends some other way, e.g. skipped early).
  ///
  /// Safe to key off [TourScope.orderAt] here (unlike when it would be
  /// resolving against an incomplete set) because
  /// [_primeKindDependentTourSteps] already guarantees every order this
  /// tour has is registered before the tour starts.
  void _syncKindToTour(BuildContext context) {
    if (!_hasKindSelection || _constellationMode) return;
    final TourController controller = Tour.of(context);
    if (controller.activeTour != 'star-form') return;
    final int? order = TourScope.of(context)
        .orderAt('star-form', controller.index);
    final StarKind? needed = switch (order) {
      1 || 2 => StarKind.lit,
      _ => null,
    };
    if (needed == null || needed == _kind) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _kind = needed);
    });
  }

  /// Stops watching once the tour leaves `star-form` (finished or skipped)
  /// and puts `_kind` back to what it was before the tour touched it —
  /// otherwise finishing the tour could silently leave a "set a goal" flow
  /// sitting on Lit or Pulsar instead of the Unlit the user actually opened
  /// this screen for.
  void _handleTourChanged() {
    final TourController? controller = _tourBeingWatched;
    if (controller == null || controller.activeTour == 'star-form') return;
    controller.removeListener(_handleTourChanged);
    _tourBeingWatched = null;
    final StarKind? original = _kindBeforeTour;
    if (original != null && original != _kind && mounted) {
      setState(() => _kind = original);
    }
  }

  @override
  void dispose() {
    if (!_saved) _discardUnsavedMedia();
    _tourBeingWatched?.removeListener(_handleTourChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Whether the form has drifted from how it started — true for a new star
  /// as soon as the user's typed or picked anything, not just when editing
  /// one that already existed. Drives whether leaving the page needs a
  /// confirmation first.
  /// What the last build used for the back-gesture guard. Typing only needs a
  /// rebuild of the whole form when this flips, not on every keystroke.
  bool _builtDirty = false;

  /// A victory's intensity or a habit's reward not chosen yet: the slider's
  /// starting value — or, when editing, the old value it starts on — isn't
  /// an answer.
  bool get _intensityMissing => _kind != StarKind.unlit && !_intensityTouched;

  /// A victory logged for today at a time that hasn't come yet.
  bool get _victoryTimeInFuture =>
      _kind == StarKind.lit && _combinedDateTime().isAfter(DateTime.now());

  void _onTextEdited() {
    if (_hasUnsavedChanges != _builtDirty) setState(() {});
  }

  bool get _hasUnsavedChanges {
    if (!_hasKindSelection) return false;
    if (_constellationMode) return _embeddedConstellationDirty;
    final trimmedDescription = _descriptionController.text.trim();
    final normalizedDescription = trimmedDescription.isEmpty
        ? null
        : trimmedDescription;
    final normalizedInitialDescription = _initialDescription.isEmpty
        ? null
        : _initialDescription;
    return _iconSlug !=
            (widget.existingHabit?.iconSlug ??
                widget.existingStar?.iconSlug ??
                '') ||
        _titleController.text.trim() != _initialTitle ||
        normalizedDescription != normalizedInitialDescription ||
        _selectedArea != _initialArea ||
        _selectedProject?.id != _initialProjectId ||
        (!widget.startWithoutSelection && _kind != _initialKind) ||
        (_kind != StarKind.unlit && _intensity != _initialIntensity) ||
        (_kind == StarKind.lit &&
            (_date != _initialDateValue ||
                _time != _initialTimeValue ||
                _photoPath != _initialPhotoPath ||
                !listEquals(_media, _initialMedia))) ||
        (_kind == StarKind.unlit && _targetDate != _initialTargetDate) ||
        (_kind == StarKind.pulsar &&
            (_habitFrequency != _initialHabitFrequency ||
                _habitTargetPerPeriod != _initialHabitTargetPerPeriod ||
                _cycleLength != _initialCycleLength ||
                _customReminder != _initialCustomReminder ||
                (_customReminder &&
                    (_reminderHour != _initialReminderHour ||
                        _reminderMinute != _initialReminderMinute))));
  }

  /// Shared by the back button and the system back gesture: leaving with
  /// unsaved changes needs confirmation first, everything else pops right
  /// away.
  Future<void> _handleBack() async {
    if (widget.startWithoutSelection && _hasKindSelection) {
      if (!_hasUnsavedChanges) {
        _returnToKindChooser();
        return;
      }
      final choice = await _showCreateFlowDiscardDialog();
      if (!mounted || choice == null) return;
      if (choice == _CreateFlowDiscardChoice.chooseAnother) {
        _returnToKindChooser();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await _confirm(
      title: context.strings.discardChangesConfirmTitle,
      body: context.strings.discardChangesConfirmBody,
      confirmLabel: context.strings.discardChangesAction,
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  Future<_CreateFlowDiscardChoice?> _showCreateFlowDiscardDialog() {
    final strings = context.strings;
    final colors = context.colors;
    return showAppDialog<_CreateFlowDiscardChoice>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: Text(strings.discardChangesConfirmTitle),
        content: Text(strings.discardChangesConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: colors.muted),
            child: AppButtonLabel(strings.continueEditingAction),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext)
                    .pop(_CreateFlowDiscardChoice.chooseAnother),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: AppButtonLabel(strings.discardAndChooseAnotherAction),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_CreateFlowDiscardChoice.exit),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: AppButtonLabel(strings.discardAndExitAction),
          ),
        ],
      ),
    );
  }

  void _returnToKindChooser() {
    _discardUnsavedMedia();
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _iconSlug =
          widget.existingHabit?.iconSlug ?? widget.existingStar?.iconSlug ?? '';
      _kind = _initialKind;
      _hasKindSelection = false;
      _constellationMode = false;
      _constellationBuilt = false;
      _embeddedConstellationDirty = false;
      _constellationFormEpoch++;
      _chooserQuestionVisible = true;
      _chooserTransitioning = false;
      _chooserSettled = false;
      _selectedProject = widget.lockedProject ?? widget.contextProject;
      _selectedArea = _selectedProject?.area ?? widget.presetArea;
      _intensity = _initialIntensity;
      _intensityTouched = false;
      _date = _initialDateValue;
      _time = _initialTimeValue;
      _targetDate = _initialTargetDate;
      _photoPath = _initialPhotoPath;
      _media = _initialMedia;
      _victoryDetailsExpanded =
          _initialPhotoPath != null || _initialMedia.isNotEmpty;
      _movedToNewConstellation = false;
      _customReminder = _initialCustomReminder;
      _reminderHour = _initialReminderHour;
      _reminderMinute = _initialReminderMinute;
      _habitFrequency = _initialHabitFrequency;
      _habitTargetPerPeriod = _initialHabitTargetPerPeriod;
      _cycleLength = _initialCycleLength;
      _cycleCustom = _initialCycleCustom;
      _kindEpoch++;
      _builtDirty = false;
    });
  }

  Future<void> _confirmAndDelete() async {
    final strings = context.strings;
    final isPulsar = _kind == StarKind.pulsar;
    final confirmed = await _confirm(
      title: isPulsar
          ? strings.deletePulsarConfirmTitle
          : strings.deleteStarConfirmTitle,
      body: isPulsar
          ? strings.deletePulsarConfirmBody
          : strings.deleteStarConfirmBody,
      confirmLabel: strings.archiveAction,
      destructive: true,
    );
    if (confirmed && mounted) {
      Navigator.of(context).pop(const StarFormDeleteRequested());
    }
  }

  /// Shared confirmation; callers declare whether the confirming action is
  /// destructive so its color follows meaning rather than location.
  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final strings = context.strings;
    return showAppConfirmation(
      context: context,
      title: title,
      body: body,
      cancelLabel: strings.cancel,
      confirmLabel: confirmLabel,
      tone: destructive
          ? AppConfirmationTone.destructive
          : AppConfirmationTone.standard,
    );
  }

  /// Whether saving would put one more star (or pulsar) into a constellation
  /// that is already at its cap. Editing something in place never adds to
  /// its constellation, so only a new entry or a move to another one counts.
  Future<bool> _targetIsFull(Project project) async {
    final isPulsar = _kind == StarKind.pulsar;
    final existingProjectId =
        widget.existingStar?.projectId ?? widget.existingHabit?.projectId;
    if (existingProjectId == project.id) return false;
    return isPulsar
        ? (await HabitRepository.create()).isFull(project.id)
        : (await StarRepository.create()).isFull(project.id);
  }

  /// Tells the person the constellation can take no more of this kind, and
  /// offers to carry on in a brand new one in the same area — the form, with
  /// everything typed so far, then saves straight into it. Returns whether
  /// the target was switched.
  Future<bool> _offerNewConstellation(Project full) async {
    final strings = context.strings;
    final colors = context.colors;
    final isPulsar = _kind == StarKind.pulsar;
    final createNew = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: Text(strings.constellationFullTitle),
        content: Text(
          isPulsar
              ? strings.constellationFullPulsars(kMaxConstellationPulsars)
              : strings.constellationFullStars(kMaxConstellationStars),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: colors.muted),
            child: AppButtonLabel(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.gold,
              foregroundColor: colors.onGold,
              shape: const StadiumBorder(),
            ),
            child: AppButtonLabel(
              strings.constellationFullCreateNew,
              color: colors.onGold,
            ),
          ),
        ],
      ),
    );
    if (createNew != true || !mounted) return false;

    // The form may have been opened already scoped to one constellation, in
    // which case it holds no repositories of its own for the picker.
    final projectRepository =
        widget.projectRepository ?? await ProjectRepository.create();
    final starsShapeRepository =
        widget.starsShapeRepository ?? await StarsShapeRepository.create();
    if (!mounted) return false;
    final created = await Navigator.of(context).push<Project>(
      MaterialPageRoute(
        builder: (_) => NewProjectScreen(
          projectRepository: projectRepository,
          starsShapeRepository: starsShapeRepository,
          presetArea: full.area,
        ),
      ),
    );
    if (created == null || !mounted) return false;
    setState(() {
      _selectedProject = created;
      _selectedArea = created.area;
      _movedToNewConstellation = true;
    });
    return true;
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final project = _selectedProject;
    if (title.isEmpty || project == null || _iconSlug.isEmpty) return;

    if (await _targetIsFull(project)) {
      if (!mounted) return;
      // Saved straight away once the new constellation exists.
      if (await _offerNewConstellation(project)) await _save();
      return;
    }
    if (!mounted) return;

    _saved = true;
    Navigator.of(context).pop(
      StarFormResult(
        kind: _kind,
        title: title,
        iconSlug: _iconSlug,
        description: _descriptionController.text,
        projectId: project.id,
        // A slot belongs to the constellation it was tapped on.
        slotSequence: _movedToNewConstellation ? null : widget.slotSequence,
        targetDate: _kind == StarKind.unlit ? _targetDate : null,
        achievedDate: _kind == StarKind.lit ? _combinedDateTime() : null,
        intensity: _kind == StarKind.unlit ? null : _intensity,
        photoPath: _kind == StarKind.lit ? _photoPath : null,
        media: _kind == StarKind.lit ? _media : const [],
        reminderHour: _kind == StarKind.pulsar && _customReminder
            ? _reminderHour
            : null,
        reminderMinute: _kind == StarKind.pulsar && _customReminder
            ? _reminderMinute
            : null,
        habitFrequency: _kind == StarKind.pulsar ? _habitFrequency : null,
        habitTargetPerPeriod: _kind == StarKind.pulsar
            ? _habitTargetPerPeriod
            : null,
        habitCycleLength: _kind == StarKind.pulsar ? _cycleLength : null,
      ),
    );
  }

  /// Offers camera vs. gallery, sends whatever's picked through
  /// [PhotoCropScreen] to force it into 9:16, and copies the cropped result
  /// into app-private storage (see [PhotoStorage]).
  Future<void> _pickPhoto() async {
    final strings = context.strings;
    final source = await showPhotoSourceSheet(context);
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

  /// Extras picked during this form session live on disk straight away, so
  /// leaving without saving has to clean them up (the ones the star already
  /// owned stay).
  void _discardUnsavedMedia() {
    final keptIds = {for (final m in _initialMedia) m.id};
    unawaited(
      StarMediaStorage.deleteAll(_media.where((m) => !keptIds.contains(m.id))),
    );
  }

  void _onMediaChanged(List<StarMedia> next) {
    // An item added in this session and removed again is on disk but was
    // never saved anywhere — free it now.
    final keptIds = {for (final m in _initialMedia) m.id};
    final nextIds = {for (final m in next) m.id};
    unawaited(
      StarMediaStorage.deleteAll(
        _media.where((m) => !keptIds.contains(m.id) && !nextIds.contains(m.id)),
      ),
    );
    setState(() => _media = next);
  }

  void _removePhoto() {
    setState(() => _photoPath = null);
  }

  /// The day and time the person set, each defaulting on its own to today /
  /// now when left empty.
  DateTime _combinedDateTime() {
    final now = DateTime.now();
    final day = _date ?? DateTime(now.year, now.month, now.day);
    final time = _time ?? TimeOfDay.fromDateTime(now);
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _date;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current == null || current.isAfter(today) ? today : current,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final picked = await showAppTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.fromDateTime(now),
    );
    if (picked == null) return;
    setState(() => _time = picked);
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _targetDate;
    // A goal looks forward: today included, nothing earlier. A target that
    // has already slipped into the past opens on today.
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current == null || current.isBefore(today) ? today : current,
      firstDate: today,
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (picked == null) return;
    setState(() => _targetDate = picked);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked == null) return;
    setState(() {
      _customReminder = true;
      _reminderHour = picked.hour;
      _reminderMinute = picked.minute;
    });
  }

  /// The supernova field's own picker — a plain [pickArea], no constellation
  /// step (that's [_openProjectPicker]'s job). Changing to an area the
  /// current constellation doesn't belong
  /// to clears it rather than leaving the two fields disagreeing about
  /// which supernova the star is actually under.
  Future<void> _openAreaPicker() async {
    final picked = await pickArea(
      context,
      selected: _selectedArea,
      // A constellation always sits under a supernova, so resetting the
      // supernova resets the constellation with it.
      onCleared: () => setState(() {
        _selectedArea = null;
        _selectedProject = null;
      }),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedArea = picked;
      if (_selectedProject != null && _selectedProject!.area != picked) {
        _selectedProject = null;
      }
    });
  }

  Future<void> _openProjectPicker() async {
    final repository = widget.projectRepository;
    final starsShapeRepository = widget.starsShapeRepository;
    if (repository == null || starsShapeRepository == null) return;
    final picked = await pickProject(
      context,
      repository,
      starsShapeRepository,
      area: _selectedArea,
      selected: _selectedProject,
      onCleared: () => setState(() => _selectedProject = null),
    );
    if (picked != null && mounted) {
      // The constellation is authoritative for its area: choosing one from
      // another area updates the supernova field as well, so the two fields
      // can never disagree.
      setState(() {
        _selectedProject = picked;
        _selectedArea = picked.area;
      });
    }
  }

  /// The tiles at the top: the constellation (when this form can create one)
  /// and the kinds of star it offers.
  Widget _kindTiles(
    List<StarKind> kinds, {
    double verticalOffset = 0,
    double dividerOpacity = 1,
  }) {
    final focused = widget.startWithoutSelection && _hasKindSelection;
    return FormKindTiles(
      tileOffset: Offset(0, verticalOffset),
      dividerOpacity: dividerOpacity,
      tileEntranceAxis: focused ? Axis.vertical : Axis.horizontal,
      animateDividerEntrance:
          widget.startWithoutSelection &&
          !_hasKindSelection &&
          _chooserQuestionVisible,
      leading: [
        if (_canCreateConstellation && (!focused || _constellationMode))
          FormKindTile.constellation(
            context,
            selected: _constellationMode,
            onTap: focused ? null : () => _selectCreationKind(),
          ),
      ],
      trailing: [
        for (final kind in kinds)
          if (!focused || (!_constellationMode && kind == _kind))
            FormKindTile.star(
              context,
              kind,
              selected:
                  _hasKindSelection && !_constellationMode && kind == _kind,
              onTap: focused || kinds.length <= 1
                  ? null
                  : () => _selectCreationKind(starKind: kind),
            ),
      ],
    );
  }

  Future<void> _selectCreationKind({StarKind? starKind}) async {
    if (_chooserTransitioning) return;
    final risesFromCenter = !_hasKindSelection && widget.startWithoutSelection;
    if (risesFromCenter) {
      setState(() {
        _chooserTransitioning = true;
        _chooserQuestionVisible = false;
      });
      await Future<void>.delayed(motionDuration(context, kMotionBase));
      if (!mounted) return;
    }

    final shouldStartTour = starKind != null && !_starFormWasOpened;
    setState(() {
      _hasKindSelection = true;
      _chooserTransitioning = false;
      if (risesFromCenter) _chooserSettled = false;
      if (starKind == null) {
        _constellationMode = true;
        _constellationBuilt = true;
      } else {
        _starFormWasOpened = true;
        _constellationMode = false;
        _kind = starKind;
      }
      _kindEpoch++;
    });
    if (shouldStartTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) whenPageSettled(context, _maybeStartTour);
      });
    }
  }

  Widget _kindChooser(
    List<StarKind> kinds,
    AppStrings strings, {
    double verticalOffset = 0,
    double dividerOpacity = 1,
  }) {
    final tiles = _kindTiles(
      kinds,
      verticalOffset: verticalOffset,
      dividerOpacity: dividerOpacity,
    );
    if (widget.startWithoutSelection ||
        (kinds.length <= 1 && !_canCreateConstellation)) {
      return tiles;
    }
    return HintTarget(
      key: const ValueKey('star-form-kind'),
      tour: 'star-form',
      order: 1,
      showArrow: true,
      contentBuilder: appTourStepCard,
      title: strings.starTourKindTitle,
      description: strings.starTourKindBody,
      child: tiles,
    );
  }

  // One running example carried across every kind — see
  // [AppStrings.litTitleHint]'s own doc comment.
  String _titleHint(AppStrings strings) => switch (_kind) {
    StarKind.lit => strings.litTitleHint,
    StarKind.unlit => strings.unlitTitleHint,
    StarKind.pulsar => strings.pulsarTitleHint,
    StarKind.nascent || StarKind.dead => strings.litTitleHint,
  };

  String _detailsHint(AppStrings strings) => switch (_kind) {
    StarKind.lit => strings.litDetailsHint,
    StarKind.unlit => strings.unlitDetailsHint,
    StarKind.pulsar => strings.pulsarDetailsHint,
    StarKind.nascent || StarKind.dead => strings.litDetailsHint,
  };

  /// Swiping steps through the tiles in the order shown: the constellation
  /// first (when the form offers it), then the kinds of star.
  void _switchKindBySwipe(DragEndDetails details) {
    if (!_hasKindSelection) return;
    const minimumVelocity = 180.0;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < minimumVelocity) return;
    final kinds = _availableKinds;
    final offset = _canCreateConstellation ? 1 : 0;
    final currentIndex = _constellationMode ? 0 : offset + kinds.indexOf(_kind);
    final nextIndex = currentIndex + (velocity.isNegative ? 1 : -1);
    if (nextIndex < 0 || nextIndex >= offset + kinds.length) return;
    setState(() {
      if (nextIndex < offset) {
        _constellationMode = true;
        _constellationBuilt = true;
      } else {
        _constellationMode = false;
        _kind = kinds[nextIndex - offset];
      }
      _kindEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncKindToTour(context);
    final colors = context.colors;
    final strings = context.strings;
    final kinds = _availableKinds;

    final scaffold = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _switchKindBySwipe,
      // Claims vertical drags too. A page too short to scroll (Goal) does not
      // compete for them, so the slightest sideways drift in an up/down drag
      // used to be the only gesture left and read as a swipe between tiles.
      onVerticalDragUpdate: (_) {},
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_hasKindSelection)
                      SizedBox(
                        width: double.infinity,
                        height: viewport.maxHeight > 40
                            ? viewport.maxHeight - 40
                            : 0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedOpacity(
                              key: const ValueKey('create-chooser-question'),
                              opacity: _chooserQuestionVisible ? 1 : 0,
                              duration: motionDuration(context, kMotionBase),
                              curve: kMotionExit,
                              child: Text(
                                strings.createChooserQuestion,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 21,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            _kindChooser(
                              kinds,
                              strings,
                              dividerOpacity: _chooserQuestionVisible ? 1 : 0,
                            ),
                          ],
                        ),
                      )
                    else ...[
                      const SizedBox(height: 16),
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: _chooserSettled
                              ? 0
                              : viewport.maxHeight * 0.42,
                          end: 0,
                        ),
                        duration: motionDuration(context, kMotionSlow),
                        curve: kMotionEnter,
                        onEnd: () {
                          if (!_chooserSettled && mounted) {
                            setState(() => _chooserSettled = true);
                          }
                        },
                        builder: (context, offset, child) => _kindChooser(
                          kinds,
                          strings,
                          verticalOffset: offset,
                          dividerOpacity: _chooserSettled ? 1 : 0,
                        ),
                      ),
                      const SizedBox(height: kFormTilesGap),
                    ],
                    if (_chooserSettled && _constellationBuilt)
                      Offstage(
                        offstage: !_constellationMode,
                        child: TickerMode(
                          enabled: _constellationMode,
                          child: NewProjectScreen(
                            key: ValueKey(_constellationFormEpoch),
                            embedded: true,
                            projectRepository: widget.projectRepository!,
                            starsShapeRepository: widget.starsShapeRepository!,
                            presetArea: widget.presetArea,
                            onDirtyChanged: (dirty) {
                              if (_embeddedConstellationDirty != dirty &&
                                  mounted) {
                                setState(
                                  () => _embeddedConstellationDirty = dirty,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    if (_chooserSettled &&
                        _hasKindSelection &&
                        !_constellationMode) ...[
                      if (widget.lockedProject == null) ...[
                        StaggeredEntrance(
                          index: 3,
                          replayKey: _kindEpoch,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: AppPickerField(
                                  label: strings.areaLabel,
                                  onReset: () => setState(() {
                                    _selectedArea = null;
                                    _selectedProject = null;
                                  }),
                                  // Not checked by `canSave`: picking a
                                  // constellation fills it in on its own (see
                                  // [_openProjectPicker]), so it can be skipped.
                                  requirement: FieldRequirement.optional,
                                  hint: strings.selectASupernova,
                                  icon: _selectedArea?.icon ?? Icons.flare,
                                  leading: _selectedArea == null
                                      ? null
                                      : AreaIcon(
                                          area: _selectedArea!,
                                          size: 20,
                                        ),
                                  text: _selectedArea?.displayName(strings),
                                  onTap: _openAreaPicker,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: _buildActivityIconField(strings),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        StaggeredEntrance(
                          index: 4,
                          replayKey: _kindEpoch,
                          child: AppPickerField(
                            label: strings.projectLabel,
                            onReset: () =>
                                setState(() => _selectedProject = null),
                            requirement: FieldRequirement.required,
                            hint: strings.selectAProject,
                            icon: _selectedProject == null
                                ? Icons.insights
                                : iconForSlug(_selectedProject!.iconSlug),
                            text: _selectedProject?.displayName,
                            onTap: _openProjectPicker,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      StaggeredEntrance(
                        index: 5,
                        replayKey: _kindEpoch,
                        child: _withIconBeside(
                          strings,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppFieldLabel(
                                strings.titleFieldLabel,
                                onReset: () => setState(_titleController.clear),
                                requirement: FieldRequirement.required,
                                counterController: _titleController,
                                counterMax: kTitleMaxLength,
                              ),
                              const SizedBox(height: kFieldLabelGap),
                              AppTextField(
                                controller: _titleController,
                                maxLength: kTitleMaxLength,
                                showCounter: false,
                                textInputAction: TextInputAction.next,
                                hintText: _titleHint(strings),
                                onChanged: (_) => _onTextEdited(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      StaggeredEntrance(
                        index: 6,
                        replayKey: _kindEpoch,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppFieldLabel(
                              strings.detailsLabel,
                              onReset: () =>
                                  setState(_descriptionController.clear),
                              requirement: FieldRequirement.optional,
                              counterController: _descriptionController,
                              counterMax: kStarDescriptionMaxLength,
                            ),
                            const SizedBox(height: kFieldLabelGap),
                            AppTextField(
                              controller: _descriptionController,
                              maxLength: kStarDescriptionMaxLength,
                              showCounter: false,
                              minLines: 4,
                              maxLines: 6,
                              hintText: _detailsHint(strings),
                              onChanged: (_) => _onTextEdited(),
                            ),
                          ],
                        ),
                      ),
                      if (_kind == StarKind.lit) ...[
                        const SizedBox(height: 20),
                        VictoryDateTimeFields(
                          entranceIndex: 7,
                          replayKey: _kindEpoch,
                          date: _date,
                          time: _time,
                          onPickDate: _pickDate,
                          onPickTime: _pickTime,
                          onResetDate: () => setState(() => _date = null),
                          onResetTime: () => setState(() => _time = null),
                          timeErrorText: _victoryTimeInFuture
                              ? strings.victoryTimeInFuture
                              : null,
                        ),
                      ] else if (_kind == StarKind.unlit) ...[
                        const SizedBox(height: 20),
                        StaggeredEntrance(
                          index: 7,
                          replayKey: _kindEpoch,
                          child: AppPickerField(
                            label: strings.targetDateLabel,
                            onReset: () => setState(() => _targetDate = null),
                            requirement: FieldRequirement.optional,
                            hint: strings.selectATargetDateHint,
                            icon: Icons.flag_outlined,
                            text: _targetDate == null
                                ? null
                                : formatDisplayDate(_targetDate!, strings),
                            onTap: _pickTargetDate,
                          ),
                        ),
                      ],
                      // A pulsar works in cycles: this many distinct days complete
                      // one, and the reward below is what completing it is worth.
                      if (_kind == StarKind.pulsar) ...[
                        const SizedBox(height: 20),
                        StaggeredEntrance(
                          index: 8,
                          replayKey: _kindEpoch,
                          child: CycleLengthField(
                            length: _cycleLength,
                            custom: _cycleCustom,
                            canReset:
                                _cycleLength != kDefaultCycleLength ||
                                _cycleCustom,
                            onReset: () => setState(() {
                              _cycleLength = kDefaultCycleLength;
                              _cycleCustom = false;
                            }),
                            onPreset: (value) => setState(() {
                              _cycleLength = value;
                              _cycleCustom = false;
                            }),
                            onCustom: () => setState(() => _cycleCustom = true),
                            onLengthChanged: (value) => setState(
                              () => _cycleLength = value.clamp(
                                kMinCycleLength,
                                kMaxCycleLength,
                              ),
                            ),
                          ),
                        ),
                      ],
                      // A lit star's intensity is what the effort cost, rated
                      // once it's lit; a pulsar's is the reward for completing
                      // a cycle, picked up front. An unlit star has none yet:
                      // it gets one the moment it's lit.
                      if (_kind != StarKind.unlit) ...[
                        const SizedBox(height: 20),
                        HintTarget(
                          // Keyed — see the Supernova field's own HintTarget
                          // above for why.
                          key: const ValueKey('star-form-intensity'),
                          tour: 'star-form',
                          order: 2,
                          showArrow: true,
                          contentBuilder: appTourStepCard,
                          title: strings.starTourIntensityTitle,
                          description: strings.starTourIntensityBody,
                          // Label, bolts and slider all inside now — the whole
                          // section highlights together, not just the slider.
                          child: StaggeredEntrance(
                            index: 8,
                            replayKey: _kindEpoch,
                            child: IntensityField(
                              label: _kind == StarKind.pulsar
                                  ? strings.habitRewardLabel
                                  : strings.intensityLabel,
                              intensity: _intensity,
                              touched: _intensityTouched,
                              showUntouchedValue: _hasSavedIntensity,
                              onChanged: (value) => setState(() {
                                _intensityTouched = true;
                                _intensity = value;
                              }),
                              onReset: () => setState(() {
                                _intensityTouched = false;
                                _intensity = _initialIntensity;
                              }),
                            ),
                          ),
                        ),
                      ],
                      if (_kind == StarKind.pulsar) ...[
                        const SizedBox(height: 20),
                        StaggeredEntrance(
                          index: 10,
                          replayKey: _kindEpoch,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StaggeredEntrance(
                                index: 0,
                                replayKey: _kindEpoch,
                                child: AppFieldLabel(
                                  strings.habitFrequencyLabel,
                                  canReset:
                                      _habitFrequency != HabitFrequency.daily ||
                                      _habitTargetPerPeriod != 1,
                                  onReset: () => setState(() {
                                    _habitFrequency = HabitFrequency.daily;
                                    _habitTargetPerPeriod = 1;
                                  }),
                                  requirement: FieldRequirement.optional,
                                ),
                              ),
                              const SizedBox(height: kFieldLabelGap),
                              Row(
                                children: [
                                  Expanded(
                                    child: StaggeredEntrance(
                                      index: 1,
                                      replayKey: _kindEpoch,
                                      axis: Axis.horizontal,
                                      child: _HabitFrequencyChip(
                                        label: strings.habitFrequencyDaily,
                                        selected:
                                            _habitFrequency ==
                                            HabitFrequency.daily,
                                        onTap: () => setState(() {
                                          _habitFrequency =
                                              HabitFrequency.daily;
                                          if (_habitTargetPerPeriod > 50) {
                                            _habitTargetPerPeriod = 50;
                                          }
                                        }),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: StaggeredEntrance(
                                      index: 2,
                                      replayKey: _kindEpoch,
                                      axis: Axis.horizontal,
                                      child: _HabitFrequencyChip(
                                        label: strings.habitFrequencyWeekly,
                                        selected:
                                            _habitFrequency ==
                                            HabitFrequency.weekly,
                                        onTap: () => setState(() {
                                          _habitFrequency =
                                              HabitFrequency.weekly;
                                          if (_habitTargetPerPeriod > 7) {
                                            _habitTargetPerPeriod = 7;
                                          }
                                        }),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  StaggeredEntrance(
                                    index: 3,
                                    replayKey: _kindEpoch,
                                    axis: Axis.horizontal,
                                    child: IconButton(
                                      onPressed: _habitTargetPerPeriod > 1
                                          ? () => setState(
                                              () => _habitTargetPerPeriod--,
                                            )
                                          : null,
                                      icon: Icon(
                                        Icons.remove_circle_outline,
                                        color: colors.gold,
                                      ),
                                    ),
                                  ),
                                  StaggeredEntrance(
                                    index: 4,
                                    replayKey: _kindEpoch,
                                    axis: Axis.horizontal,
                                    child: SizedBox(
                                      width: 48,
                                      child: Text(
                                        '$_habitTargetPerPeriod',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: colors.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                  StaggeredEntrance(
                                    index: 5,
                                    replayKey: _kindEpoch,
                                    axis: Axis.horizontal,
                                    child: IconButton(
                                      onPressed:
                                          _habitTargetPerPeriod <
                                              (_habitFrequency ==
                                                      HabitFrequency.weekly
                                                  ? 7
                                                  : 50)
                                          ? () => setState(
                                              () => _habitTargetPerPeriod++,
                                            )
                                          : null,
                                      icon: Icon(
                                        Icons.add_circle_outline,
                                        color: colors.gold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Center(
                                child: StaggeredEntrance(
                                  index: 6,
                                  replayKey: _kindEpoch,
                                  child: Text(
                                    _habitFrequency == HabitFrequency.daily
                                        ? strings.habitFrequencySummaryDaily(
                                            _habitTargetPerPeriod,
                                          )
                                        : strings.habitFrequencySummaryWeekly(
                                            _habitTargetPerPeriod,
                                          ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        StaggeredEntrance(
                          index: 11,
                          replayKey: _kindEpoch,
                          // Like every other field: a name with its dot, a picker
                          // that is empty until a time is chosen (then the app's
                          // single reminder time applies), and a reset.
                          child: AppPickerField(
                            label: strings.reminderTimeLabel,
                            requirement: FieldRequirement.optional,
                            hint: strings.selectATimeHint,
                            icon: Icons.notifications_none,
                            text: _customReminder
                                ? TimeOfDay(
                                    hour: _reminderHour,
                                    minute: _reminderMinute,
                                  ).format(context)
                                : null,
                            onTap: _pickReminderTime,
                            onReset: () =>
                                setState(() => _customReminder = false),
                          ),
                        ),
                      ],
                      if (_kind == StarKind.lit) ...[
                        const SizedBox(height: 44),
                        VictoryDetailsSection(
                          entranceIndex: 12,
                          replayKey: _kindEpoch,
                          expanded: _victoryDetailsExpanded,
                          onToggle: () => setState(
                            () => _victoryDetailsExpanded =
                                !_victoryDetailsExpanded,
                          ),
                          photoPath: _photoPath,
                          onPickPhoto: _pickPhoto,
                          onRemovePhoto: _removePhoto,
                          media: _media,
                          onMediaChanged: _onMediaChanged,
                        ),
                      ],
                      // Wider than the standard 20 between fields — this is the
                      // form's own action row, not one more field, and reads as
                      // such better with a bit of extra air separating it from
                      // whatever field happens to be last above it.
                      const SizedBox(height: 44),
                      StaggeredEntrance(
                        index: 14,
                        replayKey: _kindEpoch,
                        child: Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              if (widget.isEditing && !widget.hideDelete)
                                StaggeredEntrance(
                                  index: 0,
                                  axis: Axis.horizontal,
                                  child: PillActionButton(
                                    icon: Icons.delete_outline,
                                    label: strings.archiveAction,
                                    onTap: _confirmAndDelete,
                                    danger: true,
                                  ),
                                ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _titleController,
                                builder: (context, value, child) {
                                  final canSave =
                                      value.text.trim().isNotEmpty &&
                                      _selectedProject != null &&
                                      _iconSlug.isNotEmpty &&
                                      !_victoryTimeInFuture &&
                                      !_intensityMissing &&
                                      // Reigniting (hideDelete) is the one edit
                                      // that is worth saving unchanged.
                                      (!widget.isEditing ||
                                          widget.hideDelete ||
                                          _hasUnsavedChanges);
                                  return StaggeredEntrance(
                                    index: 1,
                                    axis: Axis.horizontal,
                                    child: SaveActionButton(
                                      label: widget.isEditing
                                          ? strings.saveChanges
                                          : (_kind == StarKind.lit
                                                ? strings.lightThisStar
                                                : strings.placeThisStarAction),
                                      lit: canSave,
                                      onPressed: canSave ? _save : null,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _builtDirty = _hasUnsavedChanges;
    final shouldReturnToChooser =
        widget.startWithoutSelection && _hasKindSelection;
    return PopScope(
      canPop: !_builtDirty && !shouldReturnToChooser,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: scaffold,
    );
  }
}

/// One of the two habit-frequency toggle chips ("Every day"/"Every week")
/// in the pulsar-only frequency picker — same selectable look
/// ([selectableDecoration]) the star-kind switch below already uses, for
/// one consistent "pick one of a few" control style across this form.
class _HabitFrequencyChip extends StatelessWidget {
  const _HabitFrequencyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: selectableDecoration(colors, selected: selected),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.text : colors.muted,
          ),
        ),
      ),
    );
  }
}
