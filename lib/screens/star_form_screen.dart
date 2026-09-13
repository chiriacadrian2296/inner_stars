import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:image_picker/image_picker.dart';

import '../data/custom_constellation_repository.dart';
import '../data/photo_storage.dart';
import '../data/project_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/habit.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../tutorials/tour_step_card.dart';
import '../utils/date_format.dart';
import '../utils/icon_for_slug.dart';
import '../widgets/app_field.dart';
import '../widgets/area_tag.dart';
import '../widgets/intensity_bolts.dart';
import '../widgets/photo_picker.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/project_picker.dart';
import '../widgets/responsive_content.dart';
import '../widgets/star_glyph.dart';
import 'photo_crop_screen.dart';

/// What the user entered, handed back to whoever pushed this screen.
/// Trimming and blank-to-null normalization for [description] happen in the
/// repositories, not here, so that logic lives in one place regardless of
/// whether this was an add or an edit.
class StarFormResult {
  const StarFormResult({
    required this.kind,
    required this.title,
    this.description,
    required this.projectId,
    this.slotSequence,
    this.targetDate,
    this.achievedDate,
    this.intensity,
    this.photoPath,
    this.reminderHour,
    this.reminderMinute,
    this.habitFrequency,
    this.habitTargetPerPeriod,
  });

  /// Which kind of star was chosen — always one of [kCreatableStarKinds].
  /// A [StarKind.pulsar] result belongs to [HabitRepository]; the other two
  /// belong to [StarRepository]. Callers switch on this rather than
  /// inspecting which optional fields happen to be filled in.
  final StarKind kind;

  final String title;
  final String? description;
  final int projectId;

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

  /// [StarKind.pulsar] only. Both null = inherits the app's single global
  /// reminder time.
  final int? reminderHour;
  final int? reminderMinute;

  /// [StarKind.pulsar] only — see [Habit.frequency]/[Habit.targetPerPeriod]
  /// for what each means. Null for every other kind.
  final HabitFrequency? habitFrequency;
  final int? habitTargetPerPeriod;
}

/// Popped instead of [StarFormResult] when editing and the user deleted the
/// star instead of saving changes to it — see [StarRepository.delete] /
/// [HabitRepository.delete]: both tombstone rather than erase.
class StarFormDeleteRequested {
  const StarFormDeleteRequested();
}

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
  }) : assert(
         existingStar == null || existingHabit == null,
         'A form edits either a star or a pulsar, never both.',
       ),
       assert(
         lockedProject != null ||
             (projectRepository != null &&
                 starsShapeRepository != null),
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

  bool get isEditing => existingStar != null || existingHabit != null;

  @override
  State<StarFormScreen> createState() => _StarFormScreenState();
}

class _StarFormScreenState extends State<StarFormScreen> {
  late final _titleController = TextEditingController(text: _initialTitle);
  late final _descriptionController = TextEditingController(
    text: _initialDescription,
  );

  late StarKind _kind = _resolveInitialKind();
  late Project? _selectedProject =
      widget.lockedProject ?? widget.contextProject;

  /// The supernova field's own selection — purely a picker convenience,
  /// never saved on its own (a star only ever stores a project id, never
  /// an area), so it's not part of the `_initial*`/`_hasUnsavedChanges`
  /// tracking below the way [_selectedProject] is. Seeded from whichever
  /// project already applies, same as that field; [_openAreaPicker]/
  /// [_openProjectPicker] are what keep the two in sync afterward.
  late LifeArea? _selectedArea = _selectedProject?.area;
  late int _intensity =
      widget.existingStar?.intensity ?? widget.existingHabit?.intensity ?? 3;

  /// Null until the user actually picks a date (or, when editing a lit
  /// star, seeded from the date it was lit on).
  late DateTime? _date =
      widget.existingStar?.achievedDate ??
      (_kind == StarKind.lit ? widget.initialDate : null);
  late DateTime? _targetDate = widget.existingStar?.targetDate;
  late String? _photoPath = widget.existingStar?.photoPath;
  late bool _customReminder = widget.existingHabit?.reminderHour != null;
  late int _reminderHour = widget.existingHabit?.reminderHour ?? 9;
  late int _reminderMinute = widget.existingHabit?.reminderMinute ?? 0;
  late HabitFrequency _habitFrequency =
      widget.existingHabit?.frequency ?? HabitFrequency.daily;
  late int _habitTargetPerPeriod =
      widget.existingHabit?.targetPerPeriod ?? 1;

  // What the form above started out as — captured once, alongside it, so
  // _hasUnsavedChanges has something to compare against regardless of
  // whether this is a blank new-star form or one seeded from something that
  // already exists. Deliberately mirrors each field's own initializer.
  late final int? _initialProjectId =
      (widget.lockedProject ?? widget.contextProject)?.id;
  late final StarKind _initialKind = _kind;
  late final int _initialIntensity = _intensity;
  late final DateTime? _initialDateValue = _date;
  late final DateTime? _initialTargetDate = widget.existingStar?.targetDate;
  late final String? _initialPhotoPath = widget.existingStar?.photoPath;
  late final bool _initialCustomReminder = _customReminder;
  late final int _initialReminderHour = _reminderHour;
  late final int _initialReminderMinute = _reminderMinute;
  late final HabitFrequency _initialHabitFrequency = _habitFrequency;
  late final int _initialHabitTargetPerPeriod = _habitTargetPerPeriod;

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

  @override
  void initState() {
    super.initState();
    // The "star-form" tour — see its steps on `_StarKindSwitch`'s Unlit
    // tile and below in this file's own `build`. Only for a brand new star:
    // editing an existing one isn't the "how do I add a goal" moment this
    // tour is for, and `Tour.start` itself already no-ops once the user has
    // seen it (see `PrefsTourStorage`).
    if (!widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Tour.read(context).start('star-form');
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Whether the form has drifted from how it started — true for a new star
  /// as soon as the user's typed or picked anything, not just when editing
  /// one that already existed. Drives whether leaving the page needs a
  /// confirmation first.
  bool get _hasUnsavedChanges {
    final trimmedDescription = _descriptionController.text.trim();
    final normalizedDescription = trimmedDescription.isEmpty
        ? null
        : trimmedDescription;
    final normalizedInitialDescription = _initialDescription.isEmpty
        ? null
        : _initialDescription;
    return _titleController.text.trim() != _initialTitle ||
        normalizedDescription != normalizedInitialDescription ||
        _selectedProject?.id != _initialProjectId ||
        _kind != _initialKind ||
        (_kind != StarKind.unlit && _intensity != _initialIntensity) ||
        (_kind == StarKind.lit &&
            (_date != _initialDateValue ||
                _photoPath != _initialPhotoPath)) ||
        (_kind == StarKind.unlit && _targetDate != _initialTargetDate) ||
        (_kind == StarKind.pulsar &&
            (_habitFrequency != _initialHabitFrequency ||
                _habitTargetPerPeriod != _initialHabitTargetPerPeriod ||
                _customReminder != _initialCustomReminder ||
                (_customReminder &&
                    (_reminderHour != _initialReminderHour ||
                        _reminderMinute != _initialReminderMinute))));
  }

  /// Shared by the back button and the system back gesture: leaving with
  /// unsaved changes needs confirmation first, everything else pops right
  /// away.
  Future<void> _handleBack() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await _confirm(
      title: context.strings.discardChangesConfirmTitle,
      body: context.strings.discardChangesConfirmBody,
      confirmLabel: context.strings.discardChangesAction,
    );
    if (discard && mounted) Navigator.of(context).pop();
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
      confirmLabel: strings.deleteStarAction,
    );
    if (confirmed && mounted) {
      Navigator.of(context).pop(const StarFormDeleteRequested());
    }
  }

  /// A yes/no dialog styled like the rest of the app's destructive
  /// confirmations — a muted cancel next to a [AppColors.danger]-colored
  /// confirm action.
  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final colors = context.colors;
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: colors.muted),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _save() {
    final title = _titleController.text.trim();
    final project = _selectedProject;
    if (title.isEmpty || project == null) return;

    Navigator.of(context).pop(
      StarFormResult(
        kind: _kind,
        title: title,
        description: _descriptionController.text,
        projectId: project.id,
        slotSequence: widget.slotSequence,
        targetDate: _kind == StarKind.unlit ? _targetDate : null,
        achievedDate: _kind == StarKind.lit ? (_date ?? DateTime.now()) : null,
        intensity: _kind == StarKind.unlit ? null : _intensity,
        photoPath: _kind == StarKind.lit ? _photoPath : null,
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
      ),
    );
  }

  void _showCannotSaveMessage() {
    final strings = context.strings;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Text(strings.cannotSaveMissingInfo),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.gotIt),
          ),
        ],
      ),
    );
  }

  /// Offers camera vs. gallery, sends whatever's picked through
  /// [PhotoCropScreen] to force it into 9:16, and copies the cropped result
  /// into app-private storage (see [PhotoStorage]).
  ///
  /// A popup (see `SkyMenuDrawer._openLightYourSkyChooser`'s own doc
  /// comment), not a bottom sheet, per request — same [Dialog] with empty
  /// [BoxConstraints] shrink-wrapped to its own two choices, same
  /// icon+label row treatment, same plain-text Cancel underneath. Kept
  /// local rather than factored into a shared helper — there's no third
  /// caller yet to justify one, and the two are already small enough to
  /// duplicate without it costing much.
  Future<void> _pickPhoto() async {
    final colors = context.colors;
    final strings = context.strings;

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) {
        Widget choice({
          required IconData icon,
          required String label,
          required ImageSource source,
        }) {
          return InkWell(
            onTap: () => Navigator.of(dialogContext).pop(source),
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: colors.gold),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Dialog(
          constraints: const BoxConstraints(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    choice(
                      icon: Icons.photo_camera_outlined,
                      label: strings.takePhotoOption,
                      source: ImageSource.camera,
                    ),
                    choice(
                      icon: Icons.photo_library_outlined,
                      label: strings.choosePhotoOption,
                      source: ImageSource.gallery,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      strings.cancel,
                      style: TextStyle(color: colors.muted),
                    ),
                  ),
                ),
              ],
            ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.photoPickError)));
    }
  }

  void _removePhoto() {
    setState(() => _photoPath = null);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: current == null || current.isAfter(today) ? today : current,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current?.hour ?? now.hour,
        current?.minute ?? now.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final current = _date;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current?.hour ?? now.hour,
        minute: current?.minute ?? now.minute,
      ),
    );
    if (picked == null) return;
    final base = current ?? DateTime(now.year, now.month, now.day);
    setState(() {
      _date = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null) return;
    setState(() => _targetDate = picked);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked == null) return;
    setState(() {
      _reminderHour = picked.hour;
      _reminderMinute = picked.minute;
    });
  }

  /// The supernova field's own picker — a plain [pickArea], no constellation
  /// step (that's [_openProjectPicker]'s job, filtered by whatever this
  /// picks). Changing to an area the current constellation doesn't belong
  /// to clears it rather than leaving the two fields disagreeing about
  /// which supernova the star is actually under.
  Future<void> _openAreaPicker() async {
    final picked = await pickArea(context);
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
    );
    if (picked != null && mounted) {
      // A constellation picked without a supernova chosen first (the flat,
      // every-area list — see [pickProject]) fills this field in from its
      // own area automatically, rather than leaving it looking unanswered
      // when it's really just implied by what was just picked.
      setState(() {
        _selectedProject = picked;
        _selectedArea ??= picked.area;
      });
    }
  }

  String _question(AppStrings strings) => switch (_kind) {
    StarKind.lit => strings.litStarQuestion,
    StarKind.unlit => strings.unlitStarQuestion,
    StarKind.pulsar => strings.pulsarQuestion,
    // Neither is ever the form's own kind — see [_availableKinds].
    StarKind.nascent || StarKind.dead => strings.litStarQuestion,
  };

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

  String _eyebrow(AppStrings strings) {
    if (widget.slotSequence != null && !widget.isEditing) {
      return strings.configureStarEyebrow;
    }
    return widget.isEditing ? strings.editStarEyebrow : strings.newStarEyebrow;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final kinds = _availableKinds;

    final scaffold = Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _handleBack,
                      icon: Icon(Icons.arrow_back, color: colors.muted),
                    ),
                    Text(
                      _eyebrow(strings),
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                        color: colors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // The one control that decides which half of the form
                // below shows. Omitted entirely when there's nothing to
                // choose (editing a pulsar) — a one-option switch is just
                // a label pretending to be a control.
                if (kinds.length > 1)
                  _StarKindSwitch(
                    kinds: kinds,
                    selected: _kind,
                    onChanged: (kind) => setState(() => _kind = kind),
                  )
                else
                  Center(
                    child: _StarKindMeaning(kind: _kind, showGlyph: true),
                  ),
                const SizedBox(height: 18),
                // A fixed minimum height, not just a Text — the three
                // questions are different lengths and wrap differently, so
                // without this everything below them jumps as the kind
                // changes. minHeight (not a fixed height) so an
                // unexpectedly long translation still isn't clipped.
                Container(
                  constraints: const BoxConstraints(minHeight: 76),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _question(strings),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      color: colors.text,
                    ),
                  ),
                ),
                if (_selectedProject != null) ...[
                  const SizedBox(height: 14),
                  AreaTag(
                    area: _selectedProject!.area,
                    iconSize: 22,
                    fontSize: 20,
                  ),
                ],
                const SizedBox(height: 24),
                // Sits here rather than at the very top of the form so it
                // reads as introducing the fields, not the question above
                // them — right before whichever field ends up first,
                // whether that's Supernova (below) or, when
                // [widget.lockedProject] hides both picker fields, Title
                // further down.
                const FieldRequirementLegend(),
                const SizedBox(height: 16),
                if (widget.lockedProject == null) ...[
                  HintTarget(
                    // Explicit keys on every HintTarget in this form: with
                    // several of these steps only conditionally present
                    // (branching on `_kind`), switching kind changes how
                    // many widgets sit ahead of a given step in this
                    // Column's children — without a stable key, Flutter's
                    // positional reconciliation can match a step's old
                    // Element to a *different* step's new widget for one
                    // frame, which briefly registers two HintTargets under
                    // the same order and crashes
                    // (`hint_kit`'s own "Orders must be unique" assertion).
                    // Confirmed live: switching Lit -> Pulsar crashed here
                    // before every step in this file got its own key.
                    key: const ValueKey('star-form-supernova'),
                    tour: 'star-form',
                    order: 2,
                    showArrow: true,
                    contentBuilder: appTourStepCard,
                    title: strings.starTourSupernovaFieldTitle,
                    description: strings.starTourSupernovaFieldBody,
                    child: AppPickerField(
                      label: strings.areaLabel,
                      // Not itself checked by [_save]/`canSave` — picking a
                      // Constellation fills it in on its own (see
                      // [_openProjectPicker]) — but there's no real path to
                      // saving a star without one ending up set, so it reads
                      // as required same as the field that actually is.
                      requirement: FieldRequirement.required,
                      hint: strings.selectASupernova,
                      icon: _selectedArea?.icon ?? Icons.auto_awesome_outlined,
                      text: _selectedArea?.displayName(strings),
                      onTap: _openAreaPicker,
                      trailing: Icon(Icons.expand_more, color: colors.muted),
                    ),
                  ),
                  const SizedBox(height: 20),
                  HintTarget(
                    // Keyed — see the Supernova field's own HintTarget
                    // above for why.
                    key: const ValueKey('star-form-constellation'),
                    tour: 'star-form',
                    order: 3,
                    showArrow: true,
                    contentBuilder: appTourStepCard,
                    title: strings.starTourConstellationFieldTitle,
                    description: strings.starTourConstellationFieldBody,
                    child: AppPickerField(
                      label: strings.projectLabel,
                      requirement: FieldRequirement.required,
                      hint: strings.selectAProject,
                      icon: _selectedProject == null
                          ? Icons.auto_awesome_outlined
                          : iconForSlug(_selectedProject!.iconSlug),
                      text: _selectedProject?.name,
                      onTap: _openProjectPicker,
                      trailing: Icon(Icons.expand_more, color: colors.muted),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                AppFieldLabel(
                  strings.titleFieldLabel,
                  requirement: FieldRequirement.required,
                ),
                const SizedBox(height: 6),
                HintTarget(
                  // Keyed — see the Supernova field's own HintTarget above
                  // for why.
                  key: const ValueKey('star-form-title'),
                  tour: 'star-form',
                  order: 4,
                  showArrow: true,
                  contentBuilder: appTourStepCard,
                  title: strings.starTourTitleFieldTitle,
                  description: strings.starTourTitleFieldBody,
                  child: AppTextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    hintText: _titleHint(strings),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 20),
                AppFieldLabel(
                  strings.detailsLabel,
                  requirement: FieldRequirement.optional,
                ),
                const SizedBox(height: 6),
                HintTarget(
                  // Keyed — see the Supernova field's own HintTarget above
                  // for why.
                  key: const ValueKey('star-form-details'),
                  tour: 'star-form',
                  order: 5,
                  showArrow: true,
                  contentBuilder: appTourStepCard,
                  title: strings.starTourDetailsFieldTitle,
                  description: strings.starTourDetailsFieldBody,
                  child: AppTextField(
                    controller: _descriptionController,
                    minLines: 4,
                    maxLines: 6,
                    hintText: _detailsHint(strings),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_kind == StarKind.lit) ...[
                  const SizedBox(height: 20),
                  // Same order as the Unlit branch's own target-date step
                  // below — only one of the two is ever mounted for a given
                  // `_kind`, so the tour always lands on whichever applies.
                  HintTarget(
                    // Keyed — see the Supernova field's own HintTarget
                    // above for why.
                    key: const ValueKey('star-form-date'),
                    tour: 'star-form',
                    order: 6,
                    showArrow: true,
                    contentBuilder: appTourStepCard,
                    title: strings.starTourDateFieldTitle,
                    description: strings.starTourDateFieldBody,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppPickerField(
                            label: strings.dateLabel,
                            // Not checked by [_save] either — an unset
                            // date silently becomes `DateTime.now()`
                            // rather than blocking save — but a lit
                            // star's whole point is recording *when* the
                            // victory happened, so this reads as
                            // required same as Supernova above.
                            requirement: FieldRequirement.required,
                            hint: strings.selectADateHint,
                            icon: Icons.calendar_today,
                            text: _date == null
                                ? null
                                : formatDisplayDate(_date!, strings),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppPickerField(
                            label: strings.timeLabel,
                            requirement: FieldRequirement.required,
                            hint: strings.selectATimeHint,
                            icon: Icons.access_time,
                            text: _date == null
                                ? null
                                : formatDisplayTime(_date!),
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_kind == StarKind.unlit) ...[
                  const SizedBox(height: 20),
                  HintTarget(
                    // Keyed — see the Supernova field's own HintTarget
                    // above for why.
                    key: const ValueKey('star-form-target-date'),
                    tour: 'star-form',
                    order: 6,
                    showArrow: true,
                    contentBuilder: appTourStepCard,
                    title: strings.starTourTargetDateFieldTitle,
                    description: strings.starTourTargetDateFieldBody,
                    child: AppPickerField(
                      label: strings.targetDateLabel,
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
                // Every kind that's already burning carries an intensity —
                // a lit star's is what the effort cost once, a pulsar's
                // what it costs each day. An unlit star has none yet: it
                // gets one the moment it's lit.
                if (_kind != StarKind.unlit) ...[
                  const SizedBox(height: 20),
                  AppFieldLabel(
                    strings.intensityLabel,
                    requirement: FieldRequirement.required,
                  ),
                  // Same label-to-content gap every other field uses (6),
                  // not this section's own one-off 10 — kept it from
                  // reading as more loosely spaced than its neighbors.
                  const SizedBox(height: 6),
                  Center(
                    child: IntensityBolts(
                      intensity: _intensity,
                      size: 26,
                      spacing: 6,
                      emphasizeLast: true,
                      emphasizedScale: 1.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  HintTarget(
                    // Keyed — see the Supernova field's own HintTarget
                    // above for why.
                    key: const ValueKey('star-form-intensity'),
                    tour: 'star-form',
                    order: 7,
                    showArrow: true,
                    contentBuilder: appTourStepCard,
                    title: strings.starTourIntensityTitle,
                    description: strings.starTourIntensityBody,
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.7,
                        // A plain [Slider]'s own vertical padding defaults to
                        // the height of its overlay shape (the halo around
                        // the thumb) — invisible space that made the gap down
                        // to whatever field comes next read as much bigger
                        // than the standard 20 between every other pair of
                        // fields, even with the same explicit `SizedBox` in
                        // between. Zeroing it here makes this widget's own
                        // bounding box actually match what's visible.
                        child: SliderTheme(
                          data: SliderTheme.of(
                            context,
                          ).copyWith(padding: EdgeInsets.zero),
                          child: Slider(
                            value: _intensity.toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            onChanged: (value) =>
                                setState(() => _intensity = value.round()),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_kind == StarKind.pulsar) ...[
                  const SizedBox(height: 20),
                  AppFieldLabel(
                    strings.habitFrequencyLabel,
                    requirement: FieldRequirement.required,
                  ),
                  const SizedBox(height: 6),
                  HintTarget(
                    // Keyed — see the Supernova field's own HintTarget
                    // above for why.
                    key: const ValueKey('star-form-habit-frequency'),
                    tour: 'star-form',
                    order: 8,
                    showArrow: true,
                    contentBuilder: appTourStepCard,
                    title: strings.starTourHabitFrequencyTitle,
                    description: strings.starTourHabitFrequencyBody,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _HabitFrequencyChip(
                                label: strings.habitFrequencyDaily,
                                selected:
                                    _habitFrequency == HabitFrequency.daily,
                                onTap: () => setState(() {
                                  _habitFrequency = HabitFrequency.daily;
                                  if (_habitTargetPerPeriod > 50) {
                                    _habitTargetPerPeriod = 50;
                                  }
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _HabitFrequencyChip(
                                label: strings.habitFrequencyWeekly,
                                selected:
                                    _habitFrequency == HabitFrequency.weekly,
                                onTap: () => setState(() {
                                  _habitFrequency = HabitFrequency.weekly;
                                  if (_habitTargetPerPeriod > 7) {
                                    _habitTargetPerPeriod = 7;
                                  }
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _habitTargetPerPeriod > 1
                                  ? () =>
                                        setState(() => _habitTargetPerPeriod--)
                                  : null,
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: colors.gold,
                              ),
                            ),
                            SizedBox(
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
                            IconButton(
                              onPressed:
                                  _habitTargetPerPeriod <
                                      (_habitFrequency ==
                                              HabitFrequency.weekly
                                          ? 7
                                          : 50)
                                  ? () =>
                                        setState(() => _habitTargetPerPeriod++)
                                  : null,
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: colors.gold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Center(
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  HintTarget(
                    // Keyed — see the Supernova field's own HintTarget
                    // above for why.
                    key: const ValueKey('star-form-reminder'),
                    tour: 'star-form',
                    order: 9,
                    showArrow: true,
                    contentBuilder: appTourStepCard,
                    title: strings.starTourReminderTitle,
                    description: strings.starTourReminderBody,
                    child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(kRadiusCard),
                    child: Container(
                      decoration: panelDecoration(colors),
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _customReminder,
                            onChanged: (value) =>
                                setState(() => _customReminder = value),
                            title: Text(
                              strings.customReminderToggleLabel,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (_customReminder)
                            ListTile(
                              onTap: _pickReminderTime,
                              title: Text(
                                strings.reminderTimeLabel,
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: Text(
                                TimeOfDay(
                                  hour: _reminderHour,
                                  minute: _reminderMinute,
                                ).format(context),
                                style: TextStyle(
                                  color: colors.gold,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ),
                  ),
                ],
                if (_kind == StarKind.lit) ...[
                  const SizedBox(height: 20),
                  AppFieldLabel(
                    strings.photoLabel,
                    requirement: FieldRequirement.optional,
                  ),
                  const SizedBox(height: 6),
                  HintTarget(
                    // Keyed — see the Supernova field's own HintTarget
                    // above for why.
                    key: const ValueKey('star-form-photo'),
                    tour: 'star-form',
                    order: 10,
                    showArrow: true,
                    contentBuilder: appTourStepCard,
                    title: strings.starTourPhotoTitle,
                    description: strings.starTourPhotoBody,
                    child: PhotoPicker(
                      photoPath: _photoPath,
                      onPick: _pickPhoto,
                      onRemove: _removePhoto,
                    ),
                  ),
                ],
                // Wider than the standard 20 between fields — this is the
                // form's own action row, not one more field, and reads as
                // such better with a bit of extra air separating it from
                // whatever field happens to be last above it.
                const SizedBox(height: 44),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      if (widget.isEditing && !widget.hideDelete)
                        PillActionButton(
                          icon: Icons.delete_outline,
                          label: strings.deleteStarAction,
                          onTap: _confirmAndDelete,
                          danger: true,
                        ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _titleController,
                        builder: (context, value, child) {
                          final canSave =
                              value.text.trim().isNotEmpty &&
                              _selectedProject != null &&
                              (!widget.isEditing || _hasUnsavedChanges);
                          return HintTarget(
                            // Keyed — see the Supernova field's own
                            // HintTarget above for why.
                            key: const ValueKey('star-form-save'),
                            tour: 'star-form',
                            order: 11,
                            showArrow: true,
                            contentBuilder: appTourStepCard,
                            title: strings.starTourSaveTitle,
                            description: strings.starTourSaveBody,
                            child: SaveActionButton(
                              label: widget.isEditing
                                  ? strings.saveChanges
                                  : (_kind == StarKind.lit
                                        ? strings.lightThisStar
                                        : strings.placeThisStarAction),
                              lit: canSave,
                              onPressed: canSave
                                  ? _save
                                  : _showCannotSaveMessage,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: scaffold,
    );
  }
}

/// One of the two habit-frequency toggle chips ("Every day"/"Every week")
/// in the pulsar-only frequency picker — same flat selectable look
/// ([flatSelectableDecoration]) the star-kind switch below already uses,
/// for one consistent "pick one of a few" control style across this form.
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
        decoration: flatSelectableDecoration(colors, selected: selected),
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

/// The kind switch at the top of the form — one card per available kind,
/// each showing that kind the way the sky shows it ([StarGlyph]) above its
/// name and what it means. Deliberately not a `SegmentedButton`: the whole
/// point is that the three kinds are three *different things in time*
/// (past, present, future), which needs more than three words in a row to
/// land.
class _StarKindSwitch extends StatelessWidget {
  const _StarKindSwitch({
    required this.kinds,
    required this.selected,
    required this.onChanged,
  });

  final List<StarKind> kinds;
  final StarKind selected;
  final ValueChanged<StarKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    // This Row sits in an unconstrained Column (the form's own scroll
    // view), which hands it unbounded height — `CrossAxisAlignment.stretch`
    // alone in that context tries to stretch every tile to *infinite*
    // height (a real crash, confirmed live: it blanked the whole screen).
    // `IntrinsicHeight` measures the row's children first and hands the
    // Row back a finite height equal to the tallest of them, which is what
    // stretch actually needs to work — without this, each `Expanded` sized
    // to its own content, so three meaning texts of different lengths
    // (wrapping to one line here, two there) left the tiles visibly uneven.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < kinds.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Builder(
                builder: (context) {
                  final tile = InkWell(
                    onTap: () => onChanged(kinds[i]),
                    borderRadius: BorderRadius.circular(kRadiusField),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: flatSelectableDecoration(
                        colors,
                        selected: kinds[i] == selected,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          StarGlyph(kind: kinds[i], size: 22),
                          const SizedBox(height: 4),
                          Text(
                            kinds[i].label(strings),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: kinds[i] == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: kinds[i] == selected
                                  ? colors.text
                                  : colors.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            kinds[i].meaning(strings),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  // The "star-form" tour's first step — see
                  // `StarFormScreen`'s own doc comment on where it starts.
                  // Only the Unlit tile carries it: that's the one this
                  // tour is actually about, not the switch as a whole.
                  if (kinds[i] != StarKind.unlit) return tile;
                  return HintTarget(
                    key: const ValueKey('star-form-kind'),
                    tour: 'star-form',
                    order: 1,
                    showArrow: true,
                    contentBuilder: appTourStepCard,
                    title: strings.starTourKindTitle,
                    description: strings.starTourKindBody,
                    child: tile,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The static stand-in for [_StarKindSwitch] when there's only one possible
/// kind — the same glyph, name and meaning, minus the pretense of a choice.
class _StarKindMeaning extends StatelessWidget {
  const _StarKindMeaning({required this.kind, this.showGlyph = false});

  final StarKind kind;
  final bool showGlyph;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showGlyph) ...[
          StarGlyph(kind: kind, size: 22),
          const SizedBox(width: 6),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kind.label(strings),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            Text(
              kind.meaning(strings),
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          ],
        ),
      ],
    );
  }
}
