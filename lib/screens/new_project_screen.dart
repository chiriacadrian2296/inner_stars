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
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../tutorials/tour_glow.dart';
import '../widgets/app_field.dart';
import '../utils/icon_for_slug.dart';
import '../widgets/constellation_editor_painter.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/responsive_content.dart';
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
/// [presetArea] locks the area (e.g. opened from that area's project list);
/// when omitted (e.g. opened inline while adding a win), the user picks an
/// area here first.
class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({
    super.key,
    required this.projectRepository,
    required this.starsShapeRepository,
    this.presetArea,
  });

  final ProjectRepository projectRepository;
  final StarsShapeRepository starsShapeRepository;
  final LifeArea? presetArea;

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
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

  bool get _hasShape =>
      _selectedStarsShape != null || _selectedPreset != null;

  ConstellationShape? get _selectedShape =>
      _selectedStarsShape?.shape ?? _selectedPreset?.shape;

  String? _selectedShapeName(AppStrings strings) =>
      _selectedStarsShape?.name ??
      _selectedPreset?.name.of(strings.languageCode);

  void _selectPreset(StarsShapePreset preset) {
    setState(() {
      _selectedPreset = preset;
      _selectedStarsShape = null;
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
    });
  }

  @override
  void initState() {
    super.initState();
    // The "constellation-form" tour — see its steps in [build] below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Tour.read(context).start('constellation-form');
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
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          strings.discardChangesConfirmTitle,
          style: TextStyle(color: colors.text),
        ),
        content: Text(
          strings.discardChangesConfirmBody,
          style: TextStyle(color: colors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel, style: TextStyle(color: colors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              strings.discardChangesAction,
              style: TextStyle(color: colors.danger),
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
      requirement: FieldRequirement.required,
      hint: strings.areaLabel,
      icon: _selectedArea?.icon ?? Icons.explore_outlined,
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
  /// between by [_ShapePickerTabs] rather than living in two separate
  /// places on the form (a saved shape used to have its own "Your
  /// constellations" section below, each tile with its own edit pencil —
  /// see [_editSelectedShape] for where that moved to instead). One
  /// combined, searchable sheet either way, reusing the same picker shell
  /// the area and icon fields already use.
  Future<void> _openLibrary() async {
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

    final picked = await _showSearchablePicker<_ShapePickerChoice>(
      context: context,
      title: strings.shapeLibraryTitle,
      searchHint: strings.shapeSearchHint,
      items: items,
      matches: (choice, query) => switch (choice) {
        _PresetChoice(:final preset) =>
          preset.name.of(language).toLowerCase().contains(query) ||
              preset.category.name.of(language).toLowerCase().contains(query),
        _CustomChoice(:final custom) =>
          custom.name.toLowerCase().contains(query),
      },
      initialSelection: currentSelection,
      bodyBuilder: (context, filtered, selected, onSelect) {
        return _ShapePickerTabs(
          // Opens on whichever tab already holds the current selection —
          // no reason to land on the library if what's picked right now
          // is one of this user's own shapes.
          initialTab: currentSelection is _CustomChoice
              ? _ShapePickerTab.yourShapes
              : _ShapePickerTab.library,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
                    child: Text(
                      category.name.of(language),
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: context.colors.gold,
                      ),
                    ),
                  ),
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
                          return _ShapeTile(
                            shape: preset.shape,
                            label: preset.name.of(language),
                            selected:
                                selected is _PresetChoice &&
                                selected.preset.id == preset.id,
                            onTap: () => onSelect(_PresetChoice(preset)),
                            side: tileWidth,
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
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    strings.noCustomShapesYetHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.muted, fontSize: 14),
                  ),
                ),
              );
            }
            return _StretchedTileWrap(
              minTileWidth: _constellationPreviewSide,
              itemCount: customItems.length,
              itemBuilder: (context, index, tileWidth) {
                final custom = customItems[index].custom;
                return _ShapeTile(
                  shape: custom.shape,
                  label: custom.name,
                  selected:
                      selected is _CustomChoice &&
                      selected.custom.id == custom.id,
                  onTap: () => onSelect(_CustomChoice(custom)),
                  side: tileWidth,
                );
              },
            );
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case _PresetChoice(:final preset):
        _selectPreset(preset);
      case _CustomChoice(:final custom):
        _selectCustom(custom);
    }
  }

  Future<void> _openAreaPicker() async {
    final strings = context.strings;
    final picked = await _showSearchablePicker<LifeArea>(
      context: context,
      title: strings.areaLabel,
      items: LifeArea.values,
      matches: (area, query) =>
          area.displayName(strings).toLowerCase().contains(query),
      // Only 8, fixed areas — a search field would just be clutter.
      showSearch: false,
      initialSelection: _selectedArea,
      bodyBuilder: (context, filtered, selected, onSelect) {
        // 2 columns x 4 rows — all 8 areas visible at once, no scrolling
        // needed or possible. Same square-tile idea as the icon grid,
        // just with room for the area's name inside too.
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.3,
          children: [
            for (final area in filtered)
              _AreaOption(
                area: area,
                selected: selected == area,
                onTap: () => onSelect(area),
              ),
          ],
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedArea = picked);
    }
  }

  Future<void> _openIconPicker() async {
    final picked = await _showSearchablePicker<String>(
      context: context,
      title: context.strings.chooseIconTitle,
      searchHint: context.strings.searchHint,
      items: _orderedIconSlugs(_selectedArea),
      matches: (slug, query) => slug.toLowerCase().contains(query),
      initialSelection: _selectedIconSlug,
      bodyBuilder: (context, filtered, selected, onSelect) {
        return GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final slug in filtered)
              _IconOption(
                slug: slug,
                selected: selected == slug,
                onTap: () => onSelect(slug),
              ),
          ],
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedIconSlug = picked);
    }
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

    final project = await widget.projectRepository.add(
      name: name,
      area: area,
      iconSlug: iconSlug,
      starsShapeId: constellation.id,
      description: _descriptionController.text,
    );
    if (mounted) Navigator.of(context).pop(project);
  }

  void _showCannotSaveMessage() {
    final colors = context.colors;
    final strings = context.strings;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Text(
          strings.cannotSaveMissingInfo,
          style: TextStyle(color: colors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.gotIt, style: TextStyle(color: colors.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

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
                      strings.newProjectEyebrow,
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
                Text(
                  strings.newProjectQuestion,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 24),
                const FieldRequirementLegend(),
                const SizedBox(height: 16),
                if (widget.presetArea == null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: HintTarget(
                          tour: 'constellation-form',
                          order: 1,
                          pulse: true,
                          showArrow: true,
                          spotlightPadding: kTourGlowSpotlightPadding,
                          title: strings.constellationTourAreaTitle,
                          description: strings.constellationTourAreaBody,
                          child: TourGlow(
                            tour: 'constellation-form',
                            order: 1,
                            color: colors.gold,
                            child: _buildAreaField(colors, strings),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildIconField(colors, strings),
                      ),
                    ],
                  )
                else
                  _buildIconField(colors, strings),
                const SizedBox(height: 20),
                AppFieldLabel(
                  strings.nameLabel,
                  requirement: FieldRequirement.required,
                ),
                const SizedBox(height: 6),
                HintTarget(
                  tour: 'constellation-form',
                  order: 2,
                  pulse: true,
                  showArrow: true,
                  spotlightPadding: kTourGlowSpotlightPadding,
                  title: strings.constellationTourNameTitle,
                  description: strings.constellationTourNameBody,
                  child: TourGlow(
                    tour: 'constellation-form',
                    order: 2,
                    color: colors.gold,
                    child: AppTextField(
                      controller: _nameController,
                      autofocus: widget.presetArea != null,
                      hintText: strings.newProjectNameHint,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppFieldLabel(
                  strings.projectDescriptionLabel,
                  requirement: FieldRequirement.optional,
                ),
                const SizedBox(height: 6),
                HintTarget(
                  tour: 'constellation-form',
                  order: 3,
                  pulse: true,
                  showArrow: true,
                  spotlightPadding: kTourGlowSpotlightPadding,
                  title: strings.constellationTourDescriptionTitle,
                  description: strings.constellationTourDescriptionBody,
                  child: TourGlow(
                    tour: 'constellation-form',
                    order: 3,
                    color: colors.gold,
                    child: AppTextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      hintText: strings.projectDescriptionHint,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppFieldLabel(
                  strings.chooseShapeLabel,
                  requirement: FieldRequirement.required,
                ),
                const SizedBox(height: 8),
                // The shape being committed to, on the left — always on
                // screen, always editable (tapping it, blank or not,
                // opens the same editor `_editSelectedShape` always did)
                // — sized to the same width as the Area field above it
                // (same 3:1 split, same gap, over the same total row
                // width) so the two line up rather than matching by
                // coincidence. The three ways to change it fill the
                // space that leaves on the right, stacked to match
                // whatever height that makes the preview (square, so
                // wider now also means taller) via [IntrinsicHeight] +
                // `stretch` rather than a guessed fixed height.
                HintTarget(
                  tour: 'constellation-form',
                  order: 4,
                  pulse: true,
                  showArrow: true,
                  spotlightPadding: kTourGlowSpotlightPadding,
                  title: strings.constellationTourShapeTitle,
                  description: strings.constellationTourShapeBody,
                  child: TourGlow(
                    tour: 'constellation-form',
                    order: 4,
                    color: colors.gold,
                    child: LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 12.0;
                    final side = (constraints.maxWidth - gap) * 3 / 4;
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SelectedShapePreview(
                            shape: _selectedShape,
                            label: _selectedShapeName(strings),
                            onEdit: _editSelectedShape,
                            side: side,
                          ),
                          const SizedBox(width: gap),
                          Expanded(
                            // `stretch`, not the Column default `center`
                            // — [Expanded] alone only shares out the
                            // *height* between the three buttons; without
                            // this each one would still shrink-wrap to
                            // its own icon+label width and sit centered
                            // in the middle of this slot instead of
                            // actually filling it edge to edge, the same
                            // width as the icon field above.
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _ShapeSideButton(
                                    icon: Icons.edit_outlined,
                                    label: strings.drawShapeShort,
                                    onTap: _editSelectedShape,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _ShapeSideButton(
                                    icon: Icons.insights,
                                    label: strings.pickFromLibraryShort,
                                    onTap: _openLibrary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _ShapeSideButton(
                                    icon: Icons.refresh,
                                    label: strings.resetShapeShort,
                                    onTap: _hasShape ? _resetShape : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  ),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _nameController,
                    builder: (context, value, child) {
                      final canSave =
                          value.text.trim().isNotEmpty &&
                          _selectedArea != null &&
                          _selectedIconSlug != null &&
                          _hasShape;
                      return HintTarget(
                        tour: 'constellation-form',
                        order: 5,
                        pulse: true,
                        showArrow: true,
                        spotlightPadding: kTourGlowSpotlightPadding,
                        title: strings.constellationTourSaveTitle,
                        description: strings.constellationTourSaveBody,
                        child: TourGlow(
                          tour: 'constellation-form',
                          order: 5,
                          color: colors.gold,
                          borderRadius: BorderRadius.circular(100),
                          child: SaveActionButton(
                            label: strings.createProject,
                            lit: canSave,
                            onPressed: canSave
                                ? _save
                                : _showCannotSaveMessage,
                          ),
                        ),
                      );
                    },
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

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.slug,
    required this.selected,
    required this.onTap,
  });

  final String slug;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: Container(
        decoration: selectableDecoration(colors, selected: selected),
        child: Icon(
          iconForSlug(slug),
          color: selected ? colors.gold : colors.muted,
          size: 20,
        ),
      ),
    );
  }
}

/// One square tile in the area picker's 2x4 grid — icon on top, name
/// below, same selected/unselected treatment as [_IconOption].
class _AreaOption extends StatelessWidget {
  const _AreaOption({
    required this.area,
    required this.selected,
    required this.onTap,
  });

  final LifeArea area;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: Container(
        decoration: selectableDecoration(
          colors,
          selected: selected,
          glowSize: 64,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A chosen area is literally a supernova, so it's drawn as
            // one: a white glyph inside the gold ring and glow the
            // decoration already provides, rather than a gold-on-gold icon.
            Icon(
              area.icon,
              size: 34,
              color: selected ? Colors.white : colors.muted,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                area.displayName(strings),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? colors.gold : colors.text,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
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
  const _ShapeThumbnail({required this.shape, required this.side});

  final ConstellationShape shape;
  final double side;

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
        pointRadius: 2.5,
      ),
    );
  }
}

/// One entry in the shape picker sheet — either a ready-made
/// [StarsShapePreset] or one of this user's own saved
/// [StarsShape]s — wrapped in a common type so
/// `_NewProjectScreenState._openLibrary`'s single searchable sheet (see
/// [_ShapePickerTabs]) can hold both kinds of item without the picker
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

/// The shape picker sheet's own body: a small segmented switch between
/// [_ShapePickerTab.library] (every ready-made [StarsShapePreset]) and
/// [_ShapePickerTab.yourShapes] (this user's own saved ones) — a local
/// [StatefulWidget] rather than plumbing the active tab up through
/// `_NewProjectScreenState` itself, since which tab is showing is purely
/// this sheet's own transient UI state, gone the moment it closes either
/// way.
class _ShapePickerTabs extends StatefulWidget {
  const _ShapePickerTabs({
    required this.initialTab,
    required this.libraryBuilder,
    required this.yourShapesBuilder,
  });

  final _ShapePickerTab initialTab;
  final WidgetBuilder libraryBuilder;
  final WidgetBuilder yourShapesBuilder;

  @override
  State<_ShapePickerTabs> createState() => _ShapePickerTabsState();
}

class _ShapePickerTabsState extends State<_ShapePickerTabs> {
  late _ShapePickerTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    Widget tabButton(_ShapePickerTab tab, String label) {
      final active = _tab == tab;
      return Expanded(
        child: Material(
          color: active ? colors.gold : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusField),
            side: BorderSide(color: colors.nightBorder),
          ),
          child: InkWell(
            onTap: () => setState(() => _tab = tab),
            borderRadius: BorderRadius.circular(kRadiusField),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? colors.onGold : colors.muted,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            tabButton(_ShapePickerTab.library, strings.shapeLibraryTabLabel),
            const SizedBox(width: 8),
            tabButton(
              _ShapePickerTab.yourShapes,
              strings.yourShapesTabLabel,
            ),
          ],
        ),
        const SizedBox(height: 12),
        switch (_tab) {
          _ShapePickerTab.library => widget.libraryBuilder(context),
          _ShapePickerTab.yourShapes => widget.yourShapesBuilder(context),
        },
      ],
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
BoxDecoration _shapePreviewDecoration(AppColors colors, {required bool selected}) {
  return BoxDecoration(
    color: colors.nightPanel,
    border: Border.all(
      color: selected ? colors.gold : colors.nightBorder,
      width: selected ? kBorderWidthActive : kBorderWidth,
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
  });

  final ConstellationShape? shape;
  final String? label;
  final VoidCallback onEdit;
  final double side;

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
              // Same [Icons.insights] as the "Shapes" button beside it —
              // no separate caption under it any more ("No shape chosen
              // yet" was redundant once this whole tile visibly matched
              // the empty canvas it opens), bigger now that it's carrying
              // the empty state on its own.
              Center(
                child: Icon(Icons.insights, color: colors.muted, size: 44),
              )
            else
              _ShapeThumbnail(shape: chosen, side: side),
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
          ],
        ),
      ),
    );
  }
}

/// One of the three ways to change the shape, beside the preview — icon
/// above a short label, filling whatever cell height
/// [Expanded]/[IntrinsicHeight] give it in the column of three these stack
/// in (see the shape picker's own build code). A disabled (null [onTap])
/// one — Reset with nothing to reset — dims to [AppColors.muted] the same
/// way every other disabled control in this app does.
class _ShapeSideButton extends StatelessWidget {
  const _ShapeSideButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;
    final foreground = enabled ? colors.gold : colors.muted;

    // The same flat panel + border every other tappable tile in this app
    // uses (see `panelDecoration`) — a plain [InkWell] with no surface of
    // its own read as three loose icons floating beside the preview
    // rather than three buttons.
    return Container(
      decoration: panelDecoration(colors),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled ? colors.text : colors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
  });

  final int itemCount;
  final double minTileWidth;
  final Widget Function(BuildContext context, int index, double tileWidth)
  itemBuilder;

  static const _spacing = 8.0;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = ((maxWidth + _spacing) / (minTileWidth + _spacing))
            .floor()
            .clamp(1, itemCount);
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
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.nightPanel,
    builder: (sheetContext) => _SearchablePickerSheet<T>(
      title: title,
      items: items,
      matches: matches,
      bodyBuilder: bodyBuilder,
      initialSelection: initialSelection,
      showSearch: showSearch,
      searchHint: searchHint,
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

  /// What the search box says when empty — the sheet is shared by pickers
  /// searching quite different things (icons, shapes), so the generic
  /// "search by title or description" doesn't fit all of them. Falls back to
  /// that generic hint when omitted.
  final String? searchHint;

  @override
  State<_SearchablePickerSheet<T>> createState() =>
      _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T> extends State<_SearchablePickerSheet<T>> {
  String _query = '';
  late T? _selected = widget.initialSelection;

  List<T> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items.where((item) => widget.matches(item, query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final filtered = _filtered;
    // Fixed, not just capped — a min==max height means the sheet doesn't
    // visibly shrink as typing a search query narrows the results down to
    // just a couple of items; the body area below just has more empty
    // space instead of the whole sheet resizing under the user's thumb.
    //
    // The keyboard is subtracted from that target height (not just capped
    // by it): showModalBottomSheet already wraps this content in its own
    // AnimatedPadding that grows by the keyboard's height as it opens, so
    // without this the sheet's *total* footprint (our fixed height + that
    // padding) would grow past the original 85%, pushing the whole sheet's
    // top edge upward — which is exactly the "shifts slightly" the search
    // field inside the icon picker causes. Shrinking our own height by the
    // same amount the padding is about to add cancels that out, so the top
    // edge stays put and only the scrollable body gets shorter.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height * 0.85 - keyboardInset).clamp(
          0.0,
          MediaQuery.sizeOf(context).height * 0.85,
        );

    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: colors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.muted),
                    tooltip: strings.closeAction,
                  ),
                ],
              ),
              if (widget.showSearch) ...[
                const SizedBox(height: 4),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  style: TextStyle(color: colors.text, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: widget.searchHint ?? strings.searchHint,
                    prefixIcon: Icon(
                      Icons.search,
                      color: colors.muted,
                      size: 20,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            strings.noSearchResults,
                            style: TextStyle(color: colors.muted, fontSize: 14),
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
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  child: Text(strings.pickerConfirmAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
