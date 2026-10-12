import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../data/constellation_presets.dart';
import '../data/constellation_shape.dart';
import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/custom_constellation.dart';
import '../models/life_area.dart';
import '../models/project.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../tutorials/tour_step_card.dart';
import '../tutorials/tutorial_replay.dart';
import '../utils/app_modals.dart';
import '../utils/page_settled.dart';
import '../widgets/app_field.dart';
import '../widgets/area_picker.dart';
import '../utils/icon_for_slug.dart';
import '../widgets/constellation_editor_painter.dart';
import '../widgets/form_kind_tiles.dart';
import '../widgets/filters_trigger_button.dart';
import '../widgets/area_icon.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import 'constellation_editor_screen.dart';

/// Creates a project: a name, a [LifeArea], a constellation shape, and an
/// icon slug for the small badge glyph shown in project lists.
///
/// A shape is required — every project needs one for its wins to light up
/// stars in — and there are three ways to get one: pick a ready-made shape
/// from the library ([starsShapePresets], 100 of them across
/// [PresetCategory]s), draw a new one in [StarsShapeEditorScreen], or
/// reuse one already saved. The icon is always the user's own pick (see
/// [_buildIconField]) — a preset's own [StarsShapePreset.iconSlug] (a
/// bicycle shape, the bicycle badge) exists and is kept, but picking that
/// preset no longer fills the icon field in on its own; see
/// [_selectPreset]'s own note.
///
/// [presetArea] only pre-fills the area (e.g. when opened from an area's
/// project list). The same visible, editable area field is always present,
/// regardless of entry point or whether this is create or edit.
class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({
    super.key,
    required this.projectRepository,
    required this.starsShapeRepository,
    this.presetArea,
    this.existingProject,
    this.embedded = false,
  });

  final ProjectRepository projectRepository;
  final StarsShapeRepository starsShapeRepository;
  final LifeArea? presetArea;
  final Project? existingProject;

  /// Just the form's own column — no scaffold, scroll view or back handling —
  /// for placing it under the star form's kind switch, which supplies those.
  /// Saving still pops the enclosing route with the new [Project].
  final bool embedded;

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  // Remember each picker's filter for this app session, across form visits.
  static PresetCategory? _rememberedShapeCategory;
  static PresetCategory? _rememberedIconCategory;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late LifeArea? _selectedArea = widget.presetArea;
  String? _selectedIconSlug;

  /// The two shape selections are mutually exclusive — whichever was picked
  /// last wins, and setting one clears the other (see [_selectPreset] /
  /// [_selectCustom]). A preset is only turned into a real
  /// [StarsShape] at save time (see [_save]), so abandoning this
  /// form never leaves a stray shape behind in the user's own list.
  StarsShape? _selectedStarsShape;
  StarsShapePreset? _selectedPreset;

  /// Bumped whenever the person changes the shape selection, so the preview
  /// swaps its drawing (and name) in with the entrance rather than silently.
  int _shapeEpoch = 0;

  bool get _hasShape => _selectedStarsShape != null || _selectedPreset != null;

  ConstellationShape? get _selectedShape =>
      _selectedStarsShape?.shape ?? _selectedPreset?.shape;

  String? _selectedShapeName(AppStrings strings) =>
      _selectedStarsShape?.name ??
      _selectedPreset?.name.of(strings.languageCode);

  void _selectPreset(StarsShapePreset preset) {
    setState(() {
      _selectedPreset = preset;
      _selectedStarsShape = null;
      _shapeEpoch++;
      // Used to also fill in `_selectedIconSlug = preset.iconSlug` here —
      // switched off for now (still deciding how icon<->shape pairing
      // should actually work; see the memory note on this), but
      // [StarsShapePreset.iconSlug] itself is untouched, so turning this
      // back on later is a one-line change.
    });
  }

  void _selectCustom(StarsShape custom) {
    setState(() {
      _selectedStarsShape = custom;
      _selectedPreset = null;
      _shapeEpoch++;
    });
  }

  /// Clears the current shape selection back to the blank placeholder —
  /// only the shape, not the icon (which a preset may have filled in on
  /// its own but the user might still want to keep even after backing out
  /// of that preset).
  void _resetShape() {
    setState(() {
      _selectedStarsShape = null;
      _selectedPreset = null;
      _shapeEpoch++;
    });
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existingProject;
    if (existing != null) {
      _nameController.text = existing.name;
      _descriptionController.text = existing.description ?? '';
      _selectedArea = existing.area;
      _selectedIconSlug = existing.iconSlug;
      if (existing.starsShapeId case final shapeId?) {
        _selectedStarsShape = widget.starsShapeRepository.getById(shapeId);
      }
    }
    // The "constellation-form" tour — see its steps in [build] below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      whenPageSettled(context, () {
        startTourAuto(Tour.read(context), 'constellation-form');
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Everything on this form starts blank/unset, so unlike
  /// `AddStarScreen`'s own version of this getter (which has to compare
  /// against a possibly-pre-filled edit), "has anything changed" here just
  /// means "has anything been entered at all" — [_selectedArea] is the one
  /// exception, seeded from [NewProjectScreen.presetArea] rather than null.
  bool get _hasUnsavedChanges {
    final existing = widget.existingProject;
    if (existing != null) {
      return _nameController.text.trim() != existing.name ||
          _descriptionController.text.trim() != (existing.description ?? '') ||
          _selectedArea != existing.area ||
          _selectedIconSlug != existing.iconSlug ||
          _selectedStarsShape?.id != existing.starsShapeId ||
          _selectedPreset != null;
    }
    return _nameController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _selectedArea != widget.presetArea ||
        _selectedIconSlug != null ||
        _hasShape;
  }

  /// Shared by the back button and the system back gesture: leaving with
  /// unsaved changes needs confirmation first, everything else pops right
  /// away — mirrors `AddStarScreen._handleBack`.
  Future<void> _handleBack() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final strings = context.strings;
    final colors = context.colors;
    final discard = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: Text(strings.discardChangesConfirmTitle),
        content: Text(
          strings.discardChangesConfirmBody,
          style: TextStyle(color: colors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: AppButtonLabel(strings.cancel, color: colors.muted),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: AppButtonLabel(
              strings.discardChangesAction,
              color: colors.danger,
            ),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) Navigator.of(context).pop();
  }

  /// Same visual language as `AddStarScreen`'s date/time picker fields
  /// (label above, bordered row with a leading icon + the current
  /// value/hint) — see [_PickerField]. 1:3 width split (icon:area) instead
  /// of date/time's 1:1, in an [Expanded] pair.
  Widget _buildIconField(AppColors colors, AppStrings strings) {
    return AppPickerField(
      label: strings.iconLabel,
      onReset: () => setState(() => _selectedIconSlug = null),
      requirement: FieldRequirement.required,
      hint: strings.iconLabel,
      // A fixed representative glyph while unselected — like the calendar/
      // clock icons on the date/time fields — not a "+", which only made
      // sense back when this field's whole look changed on selection.
      icon: _selectedIconSlug == null
          ? Icons.apps_outlined
          : iconForSlug(_selectedIconSlug!),
      text: _selectedIconSlug,
      onTap: _openIconPicker,
      iconOnly: true,
    );
  }

  Widget _buildAreaField(AppColors colors, AppStrings strings) {
    return AppPickerField(
      label: strings.areaLabel,
      onReset: () => setState(() => _selectedArea = null),
      requirement: FieldRequirement.required,
      hint: strings.selectASupernova,
      icon: _selectedArea?.icon ?? Icons.flare,
      leading: _selectedArea == null
          ? null
          : AreaIcon(area: _selectedArea!, size: 20),
      text: _selectedArea?.displayName(strings),
      onTap: _openAreaPicker,
    );
  }

  /// Area icons (see [LifeAreaX.iconSlug]) are reserved for areas — a
  /// project can never pick one, so an area and a project never render with
  /// the same icon and get visually confused.
  static final _areaOnlySlugs = LifeArea.values.map((a) => a.iconSlug).toSet();

  /// Suggestions for [area] first, then the rest of the set. Deliberately
  /// *not* re-sorted alphabetically: [availableIconSlugs] already comes in
  /// the order `icon_for_slug.dart` declares it, which is the shape
  /// library's own category order (nature, animals, body & sport, ...), so
  /// scrolling the icon grid reads like scrolling the shape library rather
  /// than like a phone book.
  List<String> _orderedIconSlugs(LifeArea? area) {
    final all = availableIconSlugs
        .where((slug) => !_areaOnlySlugs.contains(slug))
        .toList();
    if (area == null) return all;
    final suggested =
        (suggestedIconsByArea[area.suggestedIconsKey] ?? const <String>[])
            .where((slug) => !_areaOnlySlugs.contains(slug));
    final rest = all.where((slug) => !suggested.contains(slug)).toList();
    return [...suggested, ...rest];
  }

  /// Opens the editor on a brand new, blank canvas ([existing] and
  /// [initialShape] both null — the "Draw your own" button), on a shape
  /// already owned by this user ([existing] — from [_editSelectedShape]),
  /// or pre-filled with a preset's own points/edges but *not* tied to
  /// updating anything ([initialShape] — also [_editSelectedShape], when
  /// the currently selected shape came from the library instead). Either
  /// way, whatever comes back becomes the current selection: there's
  /// nothing else a fresh save could sensibly select, and after revising
  /// an existing one the user almost certainly wants their just-revised
  /// version applied to this project rather than having to pick it again.
  Future<void> _openConstellationEditor({
    StarsShape? existing,
    ConstellationShape? initialShape,
    String? initialShapeName,
  }) async {
    final saved = await Navigator.of(context).push<StarsShape>(
      MaterialPageRoute(
        builder: (_) => StarsShapeEditorScreen(
          starsShapeRepository: widget.starsShapeRepository,
          existing: existing,
          initialShape: initialShape,
          initialShapeName: initialShapeName,
          onOpenLibrary: _openLibrary,
        ),
      ),
    );
    if (saved != null && mounted) _selectCustom(saved);
  }

  /// Reopens the editor on whatever shape is currently selected — a
  /// preset opens pre-filled but un-owned (see [_openConstellationEditor]'s
  /// own `initialShape`, so idly looking at it and backing out never
  /// leaves a stray copy behind), an already-owned shape opens for a real
  /// in-place revision, and nothing selected yet just opens a blank
  /// canvas — the single place editing happens now, from
  /// [_SelectedShapePreview] itself, rather than a pencil on every tile
  /// in a whole list of them.
  Future<void> _editSelectedShape() {
    final custom = _selectedStarsShape;
    if (custom != null) return _openConstellationEditor(existing: custom);
    final preset = _selectedPreset;
    if (preset != null) {
      return _openConstellationEditor(
        initialShape: preset.shape,
        initialShapeName: preset.name.of(context.strings.languageCode),
      );
    }
    return _openConstellationEditor();
  }

  /// The shape picker sheet — presets ([starsShapePresets], grouped by
  /// [PresetCategory]) and this user's own already-saved shapes, switched
  /// between by [_ShapePickerSwitch] rather than living in two separate
  /// places on the form (a saved shape used to have its own "Your
  /// constellations" section below, each tile with its own edit pencil —
  /// see [_editSelectedShape] for where that moved to instead). One
  /// combined, searchable sheet either way, reusing the same picker shell
  /// the area and icon fields already use.
  ///
  /// Resolves true when a shape was picked and applied.
  Future<bool> _openLibrary({_ShapePickerTab? initialTab}) async {
    final strings = context.strings;
    final language = strings.languageCode;
    final customs = widget.starsShapeRepository.getAll();
    final items = <_ShapePickerChoice>[
      for (final preset in starsShapePresets) _PresetChoice(preset),
      for (final custom in customs) _CustomChoice(custom),
    ];
    final currentSelection = _selectedPreset != null
        ? _PresetChoice(_selectedPreset!)
        : _selectedStarsShape != null
        ? _CustomChoice(_selectedStarsShape!)
        : null;

    // Opens on the tab asked for, else on whichever already holds the current
    // selection — no reason to land on the library if what is picked right
    // now is one of this user's own shapes.
    final tab = ValueNotifier(
      initialTab ??
          (currentSelection is _CustomChoice
              ? _ShapePickerTab.yourShapes
              : _ShapePickerTab.library),
    );
    final category = ValueNotifier<PresetCategory?>(_rememberedShapeCategory);
    final picked = await _showSearchablePicker<_ShapePickerChoice>(
      context: context,
      title: strings.shapeLibraryTitle,
      searchHint: strings.shapeSearchHint,
      header: _ShapePickerSwitch(tab: tab),
      filterListenable: category,
      additionalMatches: (choice) =>
          choice is! _PresetChoice ||
          category.value == null ||
          choice.preset.category == category.value,
      searchTrailing: ListenableBuilder(
        listenable: Listenable.merge([tab, category]),
        builder: (context, _) => tab.value == _ShapePickerTab.yourShapes
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(left: 10),
                child: FiltersTriggerButton(
                  active: category.value != null,
                  tooltip: strings.filtersAction,
                  onTap: () async {
                    final pickedCategory = await _pickShapeCategory(
                      context,
                      selected: category.value,
                      onCleared: () => category.value = null,
                    );
                    if (pickedCategory != null) category.value = pickedCategory;
                  },
                ),
              ),
      ),
      onSwipe: (direction) {
        final tabs = _ShapePickerTab.values;
        final next = tab.value.index + direction;
        if (next >= 0 && next < tabs.length) tab.value = tabs[next];
      },
      items: items,
      matches: (choice, query) => switch (choice) {
        _PresetChoice(:final preset) =>
          preset.name.of(language).toLowerCase().contains(query) ||
              preset.category.name.of(language).toLowerCase().contains(query),
        _CustomChoice(:final custom) => custom.name.toLowerCase().contains(
          query,
        ),
      },
      initialSelection: currentSelection,
      bodyBuilder: (context, filtered, selected, onSelect) {
        return _ShapePickerBody(
          tab: tab,
          libraryBuilder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categories keep their catalogue order, and one with
              // nothing left after a search simply doesn't appear — no
              // empty headings.
              for (final category in PresetCategory.values)
                if (filtered.any(
                  (c) => c is _PresetChoice && c.preset.category == category,
                )) ...[
                  _ShapeSectionHeading(category.name.of(language)),
                  Builder(
                    builder: (context) {
                      final categoryItems = filtered
                          .whereType<_PresetChoice>()
                          .where((c) => c.preset.category == category)
                          .toList();
                      return _StretchedTileWrap(
                        minTileWidth: _shapeTileMinSide,
                        itemCount: categoryItems.length,
                        itemBuilder: (context, index, tileWidth) {
                          final preset = categoryItems[index].preset;
                          return StaggeredEntrance(
                            index: index + 2,
                            child: _ShapeTile(
                              shape: preset.shape,
                              label: preset.name.of(language),
                              selected:
                                  selected is _PresetChoice &&
                                  selected.preset.id == preset.id,
                              onTap: () => onSelect(_PresetChoice(preset)),
                              side: tileWidth,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
            ],
          ),
          yourShapesBuilder: (context) {
            final customItems = filtered.whereType<_CustomChoice>().toList();
            if (customItems.isEmpty) {
              return StaggeredEntrance(
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      strings.noCustomShapesYetHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }
            // One "My Shapes" section, headed like a library category purely
            // for visual consistency between the two tabs.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShapeSectionHeading(strings.myShapesSectionTitle),
                _StretchedTileWrap(
                  minTileWidth: _shapeTileMinSide,
                  itemCount: customItems.length,
                  itemBuilder: (context, index, tileWidth) {
                    final custom = customItems[index].custom;
                    return StaggeredEntrance(
                      index: index + 2,
                      child: _ShapeTile(
                        shape: custom.shape,
                        label: custom.name,
                        selected:
                            selected is _CustomChoice &&
                            selected.custom.id == custom.id,
                        onTap: () => onSelect(_CustomChoice(custom)),
                        side: tileWidth,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
    _rememberedShapeCategory = category.value;
    category.dispose();
    tab.dispose();
    if (picked == null || !mounted) return false;
    switch (picked) {
      case _PresetChoice(:final preset):
        _selectPreset(preset);
      case _CustomChoice(:final custom):
        _selectCustom(custom);
    }
    return true;
  }

  Future<void> _openAreaPicker() async {
    final picked = await pickArea(context, selected: _selectedArea);
    if (picked != null && mounted) {
      setState(() => _selectedArea = picked);
    }
  }

  Future<void> _openIconPicker() async {
    final language = context.strings.languageCode;
    final category = ValueNotifier<PresetCategory?>(_rememberedIconCategory);
    final presetsBySlug = {
      for (final preset in starsShapePresets) preset.iconSlug: preset,
    };
    final picked = await _showSearchablePicker<String>(
      context: context,
      title: context.strings.chooseIconTitle,
      searchHint: context.strings.searchIconsHint,
      filterListenable: category,
      additionalMatches: (slug) =>
          category.value == null ||
          presetsBySlug[slug]!.category == category.value,
      searchTrailing: ValueListenableBuilder<PresetCategory?>(
        valueListenable: category,
        builder: (context, selectedCategory, _) => Padding(
          padding: const EdgeInsets.only(left: 10),
          child: FiltersTriggerButton(
            active: selectedCategory != null,
            tooltip: context.strings.filtersAction,
            onTap: () async {
              final pickedCategory = await _pickShapeCategory(
                context,
                selected: category.value,
                onCleared: () => category.value = null,
              );
              if (pickedCategory != null) category.value = pickedCategory;
            },
          ),
        ),
      ),
      items: _orderedIconSlugs(_selectedArea),
      matches: (slug, query) =>
          slug.toLowerCase().contains(query) ||
          presetsBySlug[slug]!.name
              .of(language)
              .toLowerCase()
              .contains(query) ||
          presetsBySlug[slug]!.category.name
              .of(language)
              .toLowerCase()
              .contains(query),
      initialSelection: _selectedIconSlug,
      bodyBuilder: (context, filtered, selected, onSelect) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final category in PresetCategory.values)
              if (filtered.any(
                (slug) => presetsBySlug[slug]!.category == category,
              )) ...[
                _ShapeSectionHeading(category.name.of(language)),
                Builder(
                  builder: (context) {
                    final slugs = filtered
                        .where(
                          (slug) => presetsBySlug[slug]!.category == category,
                        )
                        .toList();
                    return _StretchedTileWrap(
                      minTileWidth: _shapeTileMinSide,
                      columnCount: 5,
                      itemCount: slugs.length,
                      itemBuilder: (context, index, tileWidth) {
                        final slug = slugs[index];
                        return StaggeredEntrance(
                          index: index + 1,
                          child: _IconOption(
                            slug: slug,
                            label: presetsBySlug[slug]!.name.of(language),
                            side: tileWidth,
                            selected: selected == slug,
                            onTap: () => onSelect(slug),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
          ],
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedIconSlug = picked);
    }
    _rememberedIconCategory = category.value;
    category.dispose();
  }

  Future<void> _save() async {
    // Read off the context before the first await — [materializePreset]
    // names its copy in the app's language, and a State's context is only
    // safe to touch synchronously.
    final languageCode = context.strings.languageCode;
    final name = _nameController.text.trim();
    final area = _selectedArea;
    final iconSlug = _selectedIconSlug;
    final preset = _selectedPreset;
    if (name.isEmpty || area == null || iconSlug == null || !_hasShape) {
      return;
    }
    assert(
      !_areaOnlySlugs.contains(iconSlug),
      'Area icons are reserved and should never reach a project.',
    );

    // A library shape only becomes a real saved constellation here, once the
    // project is actually being created — and reuses the copy made the first
    // time this preset was picked, rather than adding another identical one.
    final constellation = preset != null
        ? await widget.starsShapeRepository.materializePreset(
            preset,
            languageCode: languageCode,
          )
        : _selectedStarsShape!;

    final existing = widget.existingProject;
    final Project project;
    if (existing != null) {
      project = await widget.projectRepository.update(
        projectId: existing.id,
        name: name,
        area: area,
        iconSlug: iconSlug,
        starsShapeId: constellation.id,
        description: _descriptionController.text,
      );
    } else {
      project = await widget.projectRepository.add(
        name: name,
        area: area,
        iconSlug: iconSlug,
        starsShapeId: constellation.id,
        description: _descriptionController.text,
      );
    }
    if (mounted) Navigator.of(context).pop(project);
  }

  void _showCannotSaveMessage() {
    final colors = context.colors;
    final strings = context.strings;
    showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppDialog(
        title: Text(strings.cannotSaveTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.cannotSaveMissingInfo,
              style: TextStyle(color: colors.text),
            ),
            const SizedBox(height: 16),
            const FieldRequirementLegend(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: AppButtonLabel(strings.gotIt, color: colors.gold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The same tile row every form starts with — here just the
        // constellation. Embedded in the star form, that form's own row is
        // above instead.
        if (!widget.embedded) ...[
          FormKindTiles(
            leading: [FormKindTile.constellation(context, selected: true)],
          ),
          const SizedBox(height: kFormTilesGap),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: StaggeredEntrance(
                index: 2,
                axis: Axis.horizontal,
                child: _buildAreaField(colors, strings),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: StaggeredEntrance(
                index: 3,
                axis: Axis.horizontal,
                child: _buildIconField(colors, strings),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StaggeredEntrance(
          index: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppFieldLabel(
                strings.titleFieldLabel,
                onReset: () => setState(_nameController.clear),
                requirement: FieldRequirement.required,
                counterController: _nameController,
                counterMax: kTitleMaxLength,
              ),
              const SizedBox(height: kFieldLabelGap),
              AppTextField(
                controller: _nameController,
                maxLength: kTitleMaxLength,
                showCounter: false,
                hintText: strings.newProjectNameHint,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        StaggeredEntrance(
          index: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppFieldLabel(
                strings.projectDescriptionLabel,
                onReset: () => setState(_descriptionController.clear),
                requirement: FieldRequirement.optional,
                counterController: _descriptionController,
                counterMax: kProjectDescriptionMaxLength,
              ),
              const SizedBox(height: kFieldLabelGap),
              AppTextField(
                controller: _descriptionController,
                maxLength: kProjectDescriptionMaxLength,
                showCounter: false,
                maxLines: 3,
                hintText: strings.projectDescriptionHint,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // The shape being committed to — always on screen, always editable
        // (tapping it, blank or not, opens the same editor
        // `_editSelectedShape` always did) — as wide as the page, with the
        // way into the shapes library as a button under it.
        LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HintTarget(
                  tour: 'constellation-form',
                  order: 1,
                  showArrow: true,
                  contentBuilder: appTourStepCard,
                  title: strings.constellationTourCanvasTitle,
                  description: strings.constellationTourCanvasBody,
                  child: StaggeredEntrance(
                    index: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppFieldLabel(
                          strings.chooseShapeLabel,
                          canReset: _hasShape,
                          onReset: _resetShape,
                          requirement: FieldRequirement.required,
                        ),
                        const SizedBox(height: kFieldLabelGap),
                        _SelectedShapePreview(
                          shape: _selectedShape,
                          label: _selectedShapeName(strings),
                          onEdit: _editSelectedShape,
                          side: constraints.maxWidth,
                          replayKey: _shapeEpoch,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        StaggeredEntrance(
          index: 8,
          child: Center(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _nameController,
              builder: (context, value, child) {
                final canSave =
                    value.text.trim().isNotEmpty &&
                    _selectedArea != null &&
                    _selectedIconSlug != null &&
                    _hasShape;
                return SaveActionButton(
                  label: strings.saveChanges,
                  lit: canSave,
                  onPressed: canSave ? _save : _showCannotSaveMessage,
                );
              },
            ),
          ),
        ),
      ],
    );
    if (widget.embedded) return column;

    final scaffold = Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: ResponsiveContent(child: column),
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

Future<PresetCategory?> _pickShapeCategory(
  BuildContext context, {
  required PresetCategory? selected,
  required VoidCallback onCleared,
}) {
  final strings = context.strings;
  return showAppSheet<PresetCategory>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSheetTitle(strings.shapeCategoryFilterTitle),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: PresetCategory.values.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final category = PresetCategory.values[index];
                  final preset = starsShapePresets.firstWhere(
                    (preset) => preset.category == category,
                  );
                  return StaggeredEntrance(
                    index: index + 1,
                    child: AppSheetAction(
                      uppercase: false,
                      selected: category == selected,
                      icon: iconForSlug(preset.iconSlug),
                      label: category.name.of(strings.languageCode),
                      onPressed: () => Navigator.of(sheetContext).pop(category),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton(
                onPressed: selected == null
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        onCleared();
                      },
                child: AppButtonLabel(strings.clearFilterAction),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.slug,
    required this.label,
    required this.side,
    required this.selected,
    required this.onTap,
  });

  final String slug;
  final String label;
  final double side;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: SizedBox(
        width: side,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: side,
              height: side,
              decoration: selectableDecoration(colors, selected: selected),
              child: Icon(
                iconForSlug(slug),
                color: selected ? colors.gold : colors.muted,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                color: selected ? colors.gold : colors.muted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A shape drawn small, inside an inset drawable area rather than the tile's
/// full footprint — [ConstellationEditorPainter] draws each star as a
/// fixed-radius circle, so a point sitting exactly at the shape's own 0..1
/// edge would otherwise have its circle clipped by the tile border. Shared
/// by every place a shape is shown at thumbnail size: the library's tiles,
/// the current-selection preview, and the user's own saved shapes.
class _ShapeThumbnail extends StatelessWidget {
  const _ShapeThumbnail({
    required this.shape,
    required this.side,
    this.pointRadius = 2.5,
    this.lineWidth = 1.5,
  });

  final ConstellationShape shape;
  final double side;

  /// Heavier for the big canvas than for the small picker tiles.
  final double pointRadius;
  final double lineWidth;

  static const _inset = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final drawable = side - _inset * 2;
    return CustomPaint(
      size: Size.square(side),
      painter: ConstellationEditorPainter(
        points: [
          for (final p in shape.points)
            Offset(_inset + p.dx * drawable, _inset + p.dy * drawable),
        ],
        edges: shape.edges,
        highlightedIndex: null,
        // Selection is shown by the tile's own gold border only — the drawn
        // shape itself stays the same white/muted look either way.
        pointColor: colors.text,
        highlightColor: colors.gold,
        lineColor: colors.muted.withValues(alpha: 0.6),
        pointRadius: pointRadius,
        lineWidth: lineWidth,
      ),
    );
  }
}

/// One entry in the shape picker sheet — either a ready-made
/// [StarsShapePreset] or one of this user's own saved
/// [StarsShape]s — wrapped in a common type so
/// `_NewProjectScreenState._openLibrary`'s single searchable sheet (see
/// [_ShapePickerSwitch]) can hold both kinds of item without the picker
/// shell itself needing to know shapes come from two different places.
sealed class _ShapePickerChoice {
  const _ShapePickerChoice();
}

class _PresetChoice extends _ShapePickerChoice {
  const _PresetChoice(this.preset);
  final StarsShapePreset preset;
}

class _CustomChoice extends _ShapePickerChoice {
  const _CustomChoice(this.custom);
  final StarsShape custom;
}

enum _ShapePickerTab { library, yourShapes }

/// The shape picker sheet's switch between [_ShapePickerTab.library] (every
/// ready-made [StarsShapePreset]) and [_ShapePickerTab.yourShapes] (this
/// user's own saved ones). It sits above the search field, like the Sky's
/// mode switch; the active tab lives in a [ValueNotifier] owned by
/// `_NewProjectScreenState._openLibrary` so [_ShapePickerBody] can follow it.
class _ShapePickerSwitch extends StatelessWidget {
  const _ShapePickerSwitch({required this.tab});

  final ValueNotifier<_ShapePickerTab> tab;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    final label = {
      _ShapePickerTab.library: strings.shapeLibraryTabLabel,
      _ShapePickerTab.yourShapes: strings.yourShapesTabLabel,
    };

    // The same rolling switch as the Sky's mode and view switches; the
    // names are tooltips since the switch itself is icons only.
    return Center(
      child: SizedBox(
        width: 104,
        child: ValueListenableBuilder<_ShapePickerTab>(
          valueListenable: tab,
          builder: (context, current, _) =>
              AnimatedToggleSwitch<_ShapePickerTab>.rolling(
                height: 40,
                current: current,
                values: _ShapePickerTab.values,
                onChanged: (value) => tab.value = value,
                borderWidth: kBorderWidth,
                iconOpacity: 1.0,
                iconBuilder: (value, size) => Tooltip(
                  message: label[value]!,
                  child: Icon(
                    value == _ShapePickerTab.library
                        ? Icons.grid_view_rounded
                        : Icons.draw_outlined,
                    size: 20,
                    color: value == current ? colors.night : colors.muted,
                  ),
                ),
                style: ToggleStyle(
                  backgroundColor: colors.nightPanel,
                  indicatorColor: colors.gold,
                  borderColor: colors.nightBorder,
                  borderRadius: BorderRadius.circular(kRadiusField),
                  indicatorBorderRadius: BorderRadius.circular(kRadiusField),
                ),
              ),
        ),
      ),
    );
  }
}

/// The shape picker sheet's scrolling body: whichever tab [tab] currently
/// names.
class _ShapePickerBody extends StatelessWidget {
  const _ShapePickerBody({
    required this.tab,
    required this.libraryBuilder,
    required this.yourShapesBuilder,
  });

  final ValueNotifier<_ShapePickerTab> tab;
  final WidgetBuilder libraryBuilder;
  final WidgetBuilder yourShapesBuilder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_ShapePickerTab>(
      valueListenable: tab,
      builder: (context, current, _) => switch (current) {
        _ShapePickerTab.library => libraryBuilder(context),
        _ShapePickerTab.yourShapes => yourShapesBuilder(context),
      },
    );
  }
}

/// A category-style heading in the shape picker ("Nature", "My Shapes", ...).
class _ShapeSectionHeading extends StatelessWidget {
  const _ShapeSectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return StaggeredEntrance(
      index: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: context.colors.gold,
          ),
        ),
      ),
    );
  }
}

/// [selectableDecoration]'s own gold radial fill + glow read fine for a
/// small chip/icon tile, but on a whole shape preview it was fighting the
/// shape's own thumbnail for attention — every shape preview in this
/// screen (both [_ShapeTile] and [_SelectedShapePreview]) uses this
/// instead: same gold border for "selected", the ordinary panel
/// background left alone. Local to this screen rather than a change to
/// [selectableDecoration] itself, which plenty of other pickers
/// (icons, areas, kinds) still want its fill/glow treatment for.
BoxDecoration _shapePreviewDecoration(
  AppColors colors, {
  required bool selected,
}) {
  return BoxDecoration(
    color: colors.nightPanel,
    border: Border.all(
      color: selected ? colors.gold : colors.nightBorder,
      width: kBorderWidth,
    ),
    borderRadius: BorderRadius.circular(kRadiusField),
  );
}

/// One shape in the picker sheet: its thumbnail over its name, selectable —
/// used for both a ready-made [StarsShapePreset] and one of this user's
/// own saved shapes alike (see [_ShapePickerChoice]), since a tile looks
/// and behaves identically either way now — no per-tile edit pencil any
/// more; see `_NewProjectScreenState._editSelectedShape` for where editing
/// moved to instead.
class _ShapeTile extends StatelessWidget {
  const _ShapeTile({
    required this.shape,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.side,
  });

  final ConstellationShape shape;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Computed per row by [_ShapeTileRow] so a row of these always spans
  /// the sheet's full width (rather than the smaller of a fixed size —
  /// [_minSide] is just the floor it won't shrink past), sized to fit
  /// three or four across a phone rather than to be studied one at a
  /// time.
  final double side;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: side,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(kRadiusField),
            child: Container(
              width: side,
              height: side,
              clipBehavior: Clip.antiAlias,
              decoration: _shapePreviewDecoration(colors, selected: selected),
              child: _ShapeThumbnail(shape: shape, side: side),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              color: selected ? colors.gold : colors.muted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// The shape currently chosen for the project being created — whichever
/// source it came from — or a placeholder while there isn't one. Tapping
/// anywhere on it always opens the editor: on an existing shape that's a
/// revise, on the empty placeholder it's a from-scratch draw — the one
/// place editing (or starting) a shape happens now, folding in what used
/// to be a separate "draw your own" button, whether the shape started as
/// a from-scratch drawing, a preset, or an already-saved one of this
/// user's own (see `_NewProjectScreenState._editSelectedShape`). No
/// separate edit-pencil badge any more — the whole tile is already the
/// tap target, so a dedicated one was redundant; its corner now shows the
/// shape's own name instead.
class _SelectedShapePreview extends StatelessWidget {
  const _SelectedShapePreview({
    required this.shape,
    required this.label,
    required this.onEdit,
    this.side = _constellationPreviewSide,
    this.replayKey,
  });

  final ConstellationShape? shape;
  final String? label;
  final VoidCallback onEdit;
  final double side;

  /// Changes whenever the shape does, so the drawing and its name play their
  /// entrance again instead of swapping in place.
  final Object? replayKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chosen = shape;
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: Container(
        width: side,
        height: side,
        clipBehavior: Clip.antiAlias,
        decoration: _shapePreviewDecoration(colors, selected: chosen != null),
        child: Stack(
          children: [
            if (chosen == null)
              // The insights glyph alone carries the empty state, sized like the
              // camera icon of the empty main photo field (no caption: the whole
              // tile visibly matches the empty canvas it opens).
              StaggeredEntrance(
                index: 0,
                replayKey: replayKey,
                child: Center(
                  child: Icon(Icons.insights, color: colors.muted, size: 56),
                ),
              )
            else
              StaggeredEntrance(
                index: 0,
                replayKey: replayKey,
                child: _ShapeThumbnail(
                  shape: chosen,
                  side: side,
                  pointRadius: 4,
                  lineWidth: 2.5,
                ),
              ),
            // The name, not a pencil badge — the whole tile already opens
            // the editor on tap (see `onEdit` above), so a dedicated edit
            // affordance was redundant; this corner was better spent
            // saying *what* the shape is instead. A soft shadow, not a
            // solid scrim behind it, keeps it legible over the shape's
            // own stars/lines without boxing it in. Only shown once
            // there's an actual name — nothing to caption while empty.
            if (label != null)
              Positioned(
                left: 10,
                top: 8,
                right: 10,
                child: StaggeredEntrance(
                  index: 1,
                  replayKey: replayKey,
                  child: Text(
                    label!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Footprint of every saved-shape preview tile. Big enough that a shape's
/// own stars/lines (drawn at their normal, fixed-pixel radius — see
/// [ConstellationEditorPainter]) read clearly instead of nearly
/// overlapping, which is what happened at the previous, much smaller size.
const double _constellationPreviewSide = 108.0;

/// The floor [_StretchedTileWrap] won't shrink a [_ShapeTile] below — a
/// hundred shapes scroll past in one sheet, so they're sized to fit three
/// or four across a phone rather than to be studied one at a time (unlike
/// [_constellationPreviewSide], tuned for a single, larger preview).
const double _shapeTileMinSide = 88.0;

/// Lays out [itemCount] equal-width tiles (built by [itemBuilder], given
/// each one's computed width) in rows that always span the *full*
/// available width — unlike a plain [Wrap] of fixed-size tiles, which
/// leaves whatever doesn't divide evenly as dead space on the right of
/// each row instead of growing the tiles to use it. Column count is
/// picked once (the most that fit at [minTileWidth] or wider), then every
/// tile in every row is stretched to that exact per-column width — the
/// same "these should fill the row, not just sit near [minTileWidth]"
/// idea a [GridView] gets for free from its own cross-axis extent, without
/// needing a fixed aspect ratio (unlike a [GridView] cell, one of these
/// tiles is free to size its own height — a thumbnail plus a one- or
/// two-line label underneath — to whatever it actually needs).
class _StretchedTileWrap extends StatelessWidget {
  const _StretchedTileWrap({
    required this.itemCount,
    required this.minTileWidth,
    required this.itemBuilder,
    this.columnCount,
  });

  final int itemCount;
  final double minTileWidth;
  final int? columnCount;
  final Widget Function(BuildContext context, int index, double tileWidth)
  itemBuilder;

  static const _spacing = 8.0;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        // Keep tile widths stable when filtering leaves a partly filled row.
        final columns =
            columnCount ??
            ((maxWidth + _spacing) / (minTileWidth + _spacing)).floor().clamp(
              1,
              1000,
            );
        final tileWidth = (maxWidth - _spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (var i = 0; i < itemCount; i++)
              itemBuilder(context, i, tileWidth),
          ],
        );
      },
    );
  }
}

/// Opens a fixed-height bottom sheet — a search field ([showSearch], on by
/// default; skip it for a short fixed list like the areas) above a
/// scrollable body of [items] (rendered by [bodyBuilder], so callers can
/// lay them out as a grid or a list) — plus an OK button that confirms
/// whatever's currently tapped and a close icon that dismisses without
/// changing anything. Shared by the area and icon pickers.
Future<T?> _showSearchablePicker<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required bool Function(T item, String query) matches,
  required Widget Function(
    BuildContext context,
    List<T> filtered,
    T? selected,
    ValueChanged<T> onSelect,
  )
  bodyBuilder,
  T? initialSelection,
  bool showSearch = true,
  String? searchHint,
  Widget? header,
  ValueChanged<int>? onSwipe,
  Widget? searchTrailing,
  Listenable? filterListenable,
  bool Function(T item)? additionalMatches,
}) {
  final sheetHeight = MediaQuery.sizeOf(context).height * 0.85;
  return showFixedAppSheet<T>(
    context: context,
    builder: (sheetContext) => _SearchablePickerSheet<T>(
      title: title,
      items: items,
      matches: matches,
      bodyBuilder: bodyBuilder,
      initialSelection: initialSelection,
      showSearch: showSearch,
      searchHint: searchHint,
      sheetHeight: sheetHeight,
      header: header,
      onSwipe: onSwipe,
      searchTrailing: searchTrailing,
      filterListenable: filterListenable,
      additionalMatches: additionalMatches,
    ),
  );
}

class _SearchablePickerSheet<T> extends StatefulWidget {
  const _SearchablePickerSheet({
    required this.title,
    required this.items,
    required this.matches,
    required this.bodyBuilder,
    required this.initialSelection,
    required this.showSearch,
    required this.searchHint,
    required this.sheetHeight,
    this.header,
    this.onSwipe,
    this.searchTrailing,
    this.filterListenable,
    this.additionalMatches,
  });

  final String title;
  final List<T> items;
  final bool Function(T item, String query) matches;
  final Widget Function(
    BuildContext context,
    List<T> filtered,
    T? selected,
    ValueChanged<T> onSelect,
  )
  bodyBuilder;
  final T? initialSelection;
  final bool showSearch;
  final Widget? searchTrailing;
  final Listenable? filterListenable;
  final bool Function(T item)? additionalMatches;

  /// Optional fixed row between the title and the search field (the shape
  /// picker's library / your-shapes switch).
  final Widget? header;

  /// Called with +1 (next) or -1 (previous) on a horizontal swipe over the
  /// results.
  final ValueChanged<int>? onSwipe;

  /// What the search box says when empty — the sheet is shared by pickers
  /// searching quite different things (icons, shapes), so the generic
  /// "search by title or description" doesn't fit all of them. Falls back to
  /// that generic hint when omitted.
  final String? searchHint;
  final double sheetHeight;

  @override
  State<_SearchablePickerSheet<T>> createState() =>
      _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T> extends State<_SearchablePickerSheet<T>> {
  final _queryController = TextEditingController();

  // Read from the controller, not mirrored into state: typing then rebuilds
  // only the results (see [build]) instead of the whole sheet on every key.
  String get _query => _queryController.text;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  late T? _selected = widget.initialSelection;

  List<T> get _filtered {
    final query = _query.trim().toLowerCase();
    return widget.items
        .where(
          (item) =>
              (widget.additionalMatches?.call(item) ?? true) &&
              (query.isEmpty || widget.matches(item, query)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    // Fixed, not just capped: filtering changes only the scrollable body.
    // The route itself deliberately ignores keyboard insets, so neither
    // this height nor the footer's position changes while typing.
    return SafeArea(
      child: SizedBox(
        height: widget.sheetHeight,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StaggeredEntrance(index: 0, child: AppSheetTitle(widget.title)),
              if (widget.header != null) ...[
                const SizedBox(height: 16),
                StaggeredEntrance(index: 1, child: widget.header!),
              ],
              if (widget.showSearch) ...[
                const SizedBox(height: 20),
                StaggeredEntrance(
                  index: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: AppSearchField(
                          controller: _queryController,
                          hintText: widget.searchHint ?? strings.searchHint,
                          onChanged: (_) {},
                        ),
                      ),
                      if (widget.searchTrailing != null) widget.searchTrailing!,
                    ],
                  ),
                ),
              ],
              SizedBox(height: widget.showSearch ? 12 : 20),
              Expanded(
                // The results are the only scrolling region. Clip them at
                // this boundary so cards never paint behind the fixed title,
                // search field, or footer actions during scroll/animation.
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: widget.onSwipe == null
                      ? null
                      : (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity.abs() < 180) return;
                          widget.onSwipe!(velocity < 0 ? 1 : -1);
                        },
                  child: ClipRect(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        _queryController,
                        if (widget.filterListenable != null)
                          widget.filterListenable!,
                      ]),
                      builder: (context, _) {
                        final filtered = _filtered;
                        return filtered.isEmpty
                            ? StaggeredEntrance(
                                index: 0,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  child: Center(
                                    child: Text(
                                      strings.noSearchResults,
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: widget.bodyBuilder(
                                  context,
                                  filtered,
                                  _selected,
                                  (item) => setState(() => _selected = item),
                                ),
                              );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                child: StaggeredEntrance(
                  index: 4,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: AppButtonLabel(strings.cancel),
                      ),
                      ElevatedButton(
                        onPressed: _selected == null
                            ? null
                            : () => Navigator.of(context).pop(_selected),
                        child: AppButtonLabel(strings.pickerConfirmAction),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
