import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../debug/ui_audit_catalog.dart';
import '../debug/ui_audit_specimens.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../utils/app_modals.dart';
import '../widgets/app_field.dart';
import '../widgets/app_toggle_chip.dart';
import '../widgets/moon_mascot.dart';
import '../widgets/pill_action_button.dart';

/// Debug-only, data-isolated catalogue for reviewing the app's current UI
/// variants before any production component is migrated or removed.
class UiSandboxScreen extends StatefulWidget {
  const UiSandboxScreen({super.key});

  @override
  State<UiSandboxScreen> createState() => _UiSandboxScreenState();
}

class _UiSandboxScreenState extends State<UiSandboxScreen> {
  bool _showParkedStudies = false;
  UiAuditCategory? _category;
  UiAuditKind? _kind;
  UiAuditDecision? _decision;
  double _viewportWidth = 390;
  bool _toggle = false;
  bool _selected = false;
  bool _loading = false;
  bool _moonAnimated = true;
  MoonAppearance _moonAppearance = const MoonAppearance();
  MoonExpression _moonExpression = MoonExpression.neutral;
  final _moonController = MoonMascotController();
  final _emptyController = TextEditingController();
  final _filledController = TextEditingController(text: 'A completed value');

  @override
  void dispose() {
    _emptyController.dispose();
    _filledController.dispose();
    super.dispose();
  }

  List<UiAuditItem> get _visibleItems => uiAuditCatalog
      .where((item) {
        return (_category == null || item.category == _category) &&
            (_kind == null || item.kind == _kind) &&
            (_decision == null || item.decision == _decision);
      })
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    assert(kDebugMode, 'UiSandboxScreen must only be opened in debug builds.');
    final colors = context.colors;
    final strings = context.strings;
    final items = _visibleItems;

    if (_showParkedStudies) {
      return _buildParkedStudies(context, colors, strings, items);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moon visual lab'),
        backgroundColor: colors.night,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            key: const Key('moon-sandbox-open-parked'),
            tooltip: 'Parked UI studies',
            onPressed: () => setState(() => _showParkedStudies = true),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SelectionArea(
          child: ListView(
            key: const Key('ui-sandbox-list'),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                'Live controls for exploring Moon layers and color without changing her motion system.',
                style: TextStyle(color: colors.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              _MoonMascotPreview(
                expression: _moonExpression,
                animate: _moonAnimated,
                appearance: _moonAppearance,
                controller: _moonController,
                onExpressionChanged: (value) =>
                    setState(() => _moonExpression = value),
                onAnimateChanged: (value) =>
                    setState(() => _moonAnimated = value),
                onAppearanceChanged: (value) =>
                    setState(() => _moonAppearance = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParkedStudies(
    BuildContext context,
    AppColors colors,
    AppStrings strings,
    List<UiAuditItem> items,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${strings.uiSandboxTitle} · parked'),
        leading: IconButton(
          key: const Key('moon-sandbox-close-parked'),
          tooltip: 'Back to Moon',
          onPressed: () => setState(() => _showParkedStudies = false),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        backgroundColor: colors.night,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SelectionArea(
          child: ListView(
            key: const Key('ui-sandbox-parked-list'),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                strings.uiSandboxIntro,
                style: TextStyle(color: colors.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              _AuditSummary(items: uiAuditCatalog),
              const SizedBox(height: 20),
              _FilterSection(
                category: _category,
                kind: _kind,
                decision: _decision,
                onCategoryChanged: (value) => setState(() => _category = value),
                onKindChanged: (value) => setState(() => _kind = value),
                onDecisionChanged: (value) => setState(() => _decision = value),
              ),
              const SizedBox(height: 20),
              _SectionHeading(
                title: strings.uiSandboxViewportTitle,
                subtitle: strings.uiSandboxViewportBody,
              ),
              const SizedBox(height: 10),
              SegmentedButton<double>(
                key: const Key('ui-sandbox-viewport-picker'),
                segments: const [
                  ButtonSegment(value: 320, label: Text('320')),
                  ButtonSegment(value: 390, label: Text('390')),
                  ButtonSegment(value: 960, label: Text('960')),
                ],
                selected: {_viewportWidth},
                onSelectionChanged: (selection) =>
                    setState(() => _viewportWidth = selection.single),
              ),
              const SizedBox(height: 12),
              _ViewportFrame(
                width: _viewportWidth,
                child: _InteractiveSpecimens(
                  toggle: _toggle,
                  selected: _selected,
                  loading: _loading,
                  emptyController: _emptyController,
                  filledController: _filledController,
                  onToggleChanged: (value) => setState(() => _toggle = value),
                  onSelectedChanged: (value) =>
                      setState(() => _selected = value),
                  onLoadingChanged: (value) => setState(() => _loading = value),
                ),
              ),
              const SizedBox(height: 28),
              _SectionHeading(
                title: strings.uiSandboxMatrixTitle,
                subtitle: strings.uiSandboxMatrixBody(items.length),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                _EmptyAuditState(onReset: _resetFilters)
              else
                for (final item in items) ...[
                  _AuditItemCard(item: item),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _category = null;
      _kind = null;
      _decision = null;
    });
  }
}

class _AuditSummary extends StatelessWidget {
  const _AuditSummary({required this.items});
  final List<UiAuditItem> items;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final existing = items
        .where((item) => item.kind == UiAuditKind.existing)
        .length;
    final candidates = items.length - existing;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CountChip(
          label: strings.uiSandboxVariantsCount(existing),
          icon: Icons.inventory_2_outlined,
        ),
        _CountChip(
          label: strings.uiSandboxCandidatesCount(candidates),
          icon: Icons.auto_fix_high_outlined,
        ),
        _CountChip(
          label: strings.uiSandboxCategoriesCount(
            UiAuditCategory.values.length,
          ),
          icon: Icons.category_outlined,
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: panelDecoration(colors, radius: kRadiusField),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.gold),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.category,
    required this.kind,
    required this.decision,
    required this.onCategoryChanged,
    required this.onKindChanged,
    required this.onDecisionChanged,
  });

  final UiAuditCategory? category;
  final UiAuditKind? kind;
  final UiAuditDecision? decision;
  final ValueChanged<UiAuditCategory?> onCategoryChanged;
  final ValueChanged<UiAuditKind?> onKindChanged;
  final ValueChanged<UiAuditDecision?> onDecisionChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: strings.uiSandboxFiltersTitle),
        const SizedBox(height: 10),
        DropdownButtonFormField<UiAuditCategory?>(
          key: const Key('ui-sandbox-category-filter'),
          isExpanded: true,
          initialValue: category,
          decoration: InputDecoration(
            labelText: strings.uiSandboxCategoryLabel,
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(strings.uiSandboxAllLabel),
            ),
            for (final value in UiAuditCategory.values)
              DropdownMenuItem(
                value: value,
                child: Text(_categoryLabel(strings, value)),
              ),
          ],
          onChanged: onCategoryChanged,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: strings.uiSandboxAllLabel,
              selected: kind == null,
              onTap: () => onKindChanged(null),
            ),
            _FilterChip(
              label: strings.uiSandboxExistingLabel,
              selected: kind == UiAuditKind.existing,
              onTap: () => onKindChanged(UiAuditKind.existing),
            ),
            _FilterChip(
              label: strings.uiSandboxCandidateLabel,
              selected: kind == UiAuditKind.candidate,
              onTap: () => onKindChanged(UiAuditKind.candidate),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: strings.uiSandboxAllStatesLabel,
              selected: decision == null,
              onTap: () => onDecisionChanged(null),
            ),
            for (final value in UiAuditDecision.values)
              _FilterChip(
                label: _decisionLabel(strings, value),
                selected: decision == value,
                onTap: () => onDecisionChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusPill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          alignment: Alignment.center,
          decoration: selectableDecoration(
            colors,
            selected: selected,
            radius: kRadiusPill,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.gold : colors.muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewportFrame extends StatelessWidget {
  const _ViewportFrame({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: '${width.round()} logical pixels preview',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          key: const Key('ui-sandbox-viewport-frame'),
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.night,
            border: Border.all(color: colors.gold, width: kBorderWidthActive),
            borderRadius: BorderRadius.circular(kRadiusCard),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MoonMascotPreview extends StatelessWidget {
  const _MoonMascotPreview({
    required this.expression,
    required this.animate,
    required this.appearance,
    required this.controller,
    required this.onExpressionChanged,
    required this.onAnimateChanged,
    required this.onAppearanceChanged,
  });

  final MoonExpression expression;
  final bool animate;
  final MoonAppearance appearance;
  final MoonMascotController controller;
  final ValueChanged<MoonExpression> onExpressionChanged;
  final ValueChanged<bool> onAnimateChanged;
  final ValueChanged<MoonAppearance> onAppearanceChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const Key('moon-mascot-preview'),
      padding: const EdgeInsets.all(16),
      decoration: panelDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            key: const Key('moon-expression-picker'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in MoonExpression.values)
                ChoiceChip(
                  key: ValueKey('moon-expression-${value.name}'),
                  label: Text(_expressionLabel(value)),
                  selected: expression == value,
                  selectedColor: colors.gold,
                  checkmarkColor: colors.onGold,
                  labelStyle: TextStyle(
                    color: expression == value ? colors.onGold : colors.text,
                    fontWeight: expression == value
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: expression == value
                        ? colors.gold
                        : colors.nightBorder,
                  ),
                  onSelected: (_) => onExpressionChanged(value),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              spacing: 24,
              runSpacing: 20,
              crossAxisAlignment: WrapCrossAlignment.end,
              alignment: WrapAlignment.center,
              children: [
                _MoonSizeSample(
                  label: 'Icon · 56',
                  size: 56,
                  expression: expression,
                  animate: animate,
                  appearance: appearance,
                ),
                _MoonSizeSample(
                  label: 'Card · 112',
                  size: 112,
                  expression: expression,
                  animate: animate,
                  appearance: appearance,
                ),
                _MoonSizeSample(
                  label: 'Hero · 220',
                  size: 220,
                  expression: expression,
                  animate: animate,
                  appearance: appearance,
                  controller: controller,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              key: const Key('moon-animation-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Ambient motion'),
              subtitle: const Text('Blink, breath, glow, and gentle floating'),
              value: animate,
              onChanged: onAnimateChanged,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                key: const Key('moon-reaction-acknowledge'),
                onPressed: animate
                    ? () async {
                        await controller.play(MoonReaction.acknowledge);
                      }
                    : null,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                label: const Text('ACKNOWLEDGE'),
              ),
              OutlinedButton.icon(
                key: const Key('moon-reaction-celebrate'),
                onPressed: animate
                    ? () async {
                        await controller.play(MoonReaction.celebrate);
                      }
                    : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('CELEBRATE'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MoonAppearanceEditor(
            appearance: appearance,
            onChanged: onAppearanceChanged,
          ),
        ],
      ),
    );
  }

  String _expressionLabel(MoonExpression value) => switch (value) {
    MoonExpression.neutral => 'Neutral',
    MoonExpression.happy => 'Happy',
    MoonExpression.sleepy => 'Sleepy',
    MoonExpression.curious => 'Curious',
    MoonExpression.concerned => 'Concerned',
    MoonExpression.surprised => 'Surprised',
  };
}

class _MoonAppearanceEditor extends StatelessWidget {
  const _MoonAppearanceEditor({
    required this.appearance,
    required this.onChanged,
  });

  final MoonAppearance appearance;
  final ValueChanged<MoonAppearance> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const Key('moon-appearance-editor'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.night.withValues(alpha: 0.42),
        border: Border.all(color: colors.nightBorder),
        borderRadius: BorderRadius.circular(kRadiusField),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Visual layers',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('moon-appearance-reset'),
                onPressed: () => onChanged(const MoonAppearance()),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('RESET'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            key: const Key('moon-layer-toggles'),
            spacing: 8,
            runSpacing: 8,
            children: [
              _MoonLayerToggle(
                id: 'stars',
                label: 'Stars',
                value: appearance.showEyeStars,
                onChanged: (value) =>
                    onChanged(appearance.copyWith(showEyeStars: value)),
              ),
              _MoonLayerToggle(
                id: 'eye-accent',
                label: 'Eye accent',
                value: appearance.showEyeAccent,
                onChanged: (value) =>
                    onChanged(appearance.copyWith(showEyeAccent: value)),
              ),
              _MoonLayerToggle(
                id: 'outer-glow',
                label: 'Outer glow',
                value: appearance.showOuterGlow,
                onChanged: (value) =>
                    onChanged(appearance.copyWith(showOuterGlow: value)),
              ),
              _MoonLayerToggle(
                id: 'blush',
                label: 'Blush',
                value: appearance.showBlush,
                onChanged: (value) =>
                    onChanged(appearance.copyWith(showBlush: value)),
              ),
              _MoonLayerToggle(
                id: 'mouth',
                label: 'Mouth',
                value: appearance.showMouth,
                onChanged: (value) =>
                    onChanged(appearance.copyWith(showMouth: value)),
              ),
              _MoonLayerToggle(
                id: 'brows',
                label: 'Brows',
                value: appearance.showBrows,
                onChanged: (value) =>
                    onChanged(appearance.copyWith(showBrows: value)),
              ),
              _MoonLayerToggle(
                id: 'forehead-shine',
                label: 'Forehead light',
                value: appearance.showForeheadShine,
                onChanged: (value) =>
                    onChanged(appearance.copyWith(showForeheadShine: value)),
              ),
              _MoonLayerToggle(
                id: 'rim',
                label: 'Rim',
                value: appearance.showRim,
                onChanged: (value) =>
                    onChanged(appearance.copyWith(showRim: value)),
              ),
              _MoonLayerToggle(
                id: 'body-gradient',
                label: 'Sphere gradient',
                value: appearance.useBodyGradient,
                onChanged: (value) =>
                    onChanged(appearance.copyWith(useBodyGradient: value)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Hue',
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final sliderWidth = constraints.maxWidth >= 680
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                children: [
                  _MoonHueSlider(
                    width: sliderWidth,
                    id: 'body',
                    label: 'Sphere',
                    value: appearance.bodyHue,
                    onChanged: (value) =>
                        onChanged(appearance.copyWith(bodyHue: value)),
                  ),
                  _MoonHueSlider(
                    width: sliderWidth,
                    id: 'rim',
                    label: 'Rim',
                    value: appearance.rimHue,
                    onChanged: (value) =>
                        onChanged(appearance.copyWith(rimHue: value)),
                  ),
                  _MoonHueSlider(
                    width: sliderWidth,
                    id: 'glow',
                    label: 'Outer glow',
                    value: appearance.glowHue,
                    onChanged: (value) =>
                        onChanged(appearance.copyWith(glowHue: value)),
                  ),
                  _MoonHueSlider(
                    width: sliderWidth,
                    id: 'face',
                    label: 'Face and eyes',
                    value: appearance.faceHue,
                    onChanged: (value) =>
                        onChanged(appearance.copyWith(faceHue: value)),
                  ),
                  _MoonHueSlider(
                    width: sliderWidth,
                    id: 'stars',
                    label: 'Stars',
                    value: appearance.starHue,
                    onChanged: (value) =>
                        onChanged(appearance.copyWith(starHue: value)),
                  ),
                  _MoonHueSlider(
                    width: sliderWidth,
                    id: 'eye-accent',
                    label: 'Eye accent',
                    value: appearance.eyeAccentHue,
                    onChanged: (value) =>
                        onChanged(appearance.copyWith(eyeAccentHue: value)),
                  ),
                  _MoonHueSlider(
                    width: sliderWidth,
                    id: 'blush',
                    label: 'Blush',
                    value: appearance.blushHue,
                    onChanged: (value) =>
                        onChanged(appearance.copyWith(blushHue: value)),
                  ),
                  _MoonHueSlider(
                    width: sliderWidth,
                    id: 'shine',
                    label: 'Forehead light',
                    value: appearance.shineHue,
                    onChanged: (value) =>
                        onChanged(appearance.copyWith(shineHue: value)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MoonLayerToggle extends StatelessWidget {
  const _MoonLayerToggle({
    required this.id,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String id;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FilterChip(
      key: ValueKey('moon-layer-$id'),
      label: Text(label),
      selected: value,
      selectedColor: colors.gold,
      checkmarkColor: colors.onGold,
      labelStyle: TextStyle(color: value ? colors.onGold : colors.text),
      side: BorderSide(color: value ? colors.gold : colors.nightBorder),
      onSelected: onChanged,
    );
  }
}

class _MoonHueSlider extends StatelessWidget {
  const _MoonHueSlider({
    required this.width,
    required this.id,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final double width;
  final String id;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(color: colors.muted)),
          ),
          Expanded(
            child: Slider(
              key: ValueKey('moon-hue-$id'),
              value: value,
              min: 0,
              max: 360,
              divisions: 360,
              label: '${value.round()}°',
              activeColor: HSLColor.fromAHSL(1, value, 0.78, 0.56).toColor(),
              inactiveColor: colors.nightBorder,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${value.round()}°',
              textAlign: TextAlign.end,
              style: TextStyle(color: colors.text, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoonSizeSample extends StatelessWidget {
  const _MoonSizeSample({
    required this.label,
    required this.size,
    required this.expression,
    required this.animate,
    required this.appearance,
    this.controller,
  });

  final String label;
  final double size;
  final MoonExpression expression;
  final bool animate;
  final MoonAppearance appearance;
  final MoonMascotController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MoonMascot(
          key: ValueKey('moon-${size.round()}'),
          size: size,
          expression: expression,
          animate: animate,
          appearance: appearance,
          controller: controller,
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: colors.muted, fontSize: 12)),
      ],
    );
  }
}

class _InteractiveSpecimens extends StatelessWidget {
  const _InteractiveSpecimens({
    required this.toggle,
    required this.selected,
    required this.loading,
    required this.emptyController,
    required this.filledController,
    required this.onToggleChanged,
    required this.onSelectedChanged,
    required this.onLoadingChanged,
  });

  final bool toggle;
  final bool selected;
  final bool loading;
  final TextEditingController emptyController;
  final TextEditingController filledController;
  final ValueChanged<bool> onToggleChanged;
  final ValueChanged<bool> onSelectedChanged;
  final ValueChanged<bool> onLoadingChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SpecimenLabel(strings.uiSandboxTypographySpecimen),
        Text(
          'Immersive page title',
          style: TextStyle(
            color: colors.text,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'UTILITY PAGE TITLE',
          style: TextStyle(
            color: colors.gold,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Section label and supporting body text shown together.',
          style: TextStyle(color: colors.muted, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 20),
        _SpecimenLabel(strings.uiSandboxActionsSpecimen),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SaveActionButton(
              label: 'Save',
              lit: !loading,
              onPressed: () => onLoadingChanged(!loading),
            ),
            PillActionButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              danger: true,
              onTap: () {},
            ),
            OutlinedButton(
              onPressed: () {},
              child: const AppButtonLabel('Secondary'),
            ),
            TextButton(onPressed: () {}, child: const AppButtonLabel('Cancel')),
            ElevatedButton(
              onPressed: null,
              child: AppButtonLabel(loading ? 'Loading…' : 'Disabled'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SpecimenLabel(strings.uiSandboxFieldsSpecimen),
        AppFieldLabel('Empty field', requirement: FieldRequirement.required),
        const SizedBox(height: 6),
        AppTextField(
          controller: emptyController,
          hintText: 'Focus or type here',
        ),
        const SizedBox(height: 12),
        AppFieldLabel('Filled field', requirement: FieldRequirement.optional),
        const SizedBox(height: 6),
        AppTextField(controller: filledController),
        const SizedBox(height: 12),
        AppPickerField(
          label: 'Picker field',
          hint: 'Choose a value',
          icon: Icons.auto_awesome_outlined,
          text: selected ? 'Selected value' : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onSelectedChanged(!selected),
        ),
        const SizedBox(height: 20),
        _SpecimenLabel(strings.uiSandboxSelectionSpecimen),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppToggleChip(
              label: 'Gold theme state',
              value: toggle,
              onChanged: onToggleChanged,
            ),
            _FilterChip(
              label: selected ? 'Selected' : 'Available',
              selected: selected,
              onTap: () => onSelectedChanged(!selected),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SpecimenLabel(strings.uiSandboxSurfacesSpecimen),
        Row(
          children: [
            Expanded(child: _SurfaceSample(label: 'Inactive', selected: false)),
            const SizedBox(width: 10),
            Expanded(child: _SurfaceSample(label: 'Active', selected: true)),
          ],
        ),
        const SizedBox(height: 20),
        _SpecimenLabel(strings.uiSandboxOverlaysSpecimen),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showIsolatedDialog(context, destructive: false),
              icon: const Icon(Icons.info_outline),
              label: const Text('INFORMATION'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showIsolatedDialog(context, destructive: true),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('DESTRUCTIVE'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showIsolatedDialog(
    BuildContext context, {
    required bool destructive,
  }) {
    final colors = context.colors;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: Text(
          destructive ? 'Destructive confirmation' : 'Information dialog',
        ),
        content: Text(
          destructive
              ? 'This sandbox action never changes real data.'
              : 'A shared shell can keep modal spacing and actions consistent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: AppButtonLabel('Cancel', color: colors.muted),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: AppButtonLabel(
              destructive ? 'Delete' : 'OK',
              color: destructive ? colors.danger : colors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceSample extends StatelessWidget {
  const _SurfaceSample({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      alignment: Alignment.center,
      decoration: selectableDecoration(colors, selected: selected),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? colors.gold : colors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SpecimenLabel extends StatelessWidget {
  const _SpecimenLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: colors.gold,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _AuditItemCard extends StatelessWidget {
  const _AuditItemCard({required this.item});
  final UiAuditItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Container(
      key: ValueKey(item.id),
      decoration: panelDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.category.icon, color: colors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Badge(label: item.id, color: colors.muted),
                          _Badge(
                            label: item.kind == UiAuditKind.existing
                                ? strings.uiSandboxExistingLabel
                                : strings.uiSandboxCandidateLabel,
                            color: item.kind == UiAuditKind.existing
                                ? colors.text
                                : colors.gold,
                          ),
                          _Badge(
                            label: _decisionLabel(strings, item.decision),
                            color: _decisionColor(colors, item.decision),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UiAuditSpecimens(item: item),
          ),
          const SizedBox(height: 8),
          Divider(color: colors.nightBorder, height: 1),
          ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              strings.uiSandboxDifferencesLabel,
              style: TextStyle(color: colors.muted, fontSize: 13),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                label: strings.uiSandboxOriginsLabel,
                value: item.origins.join('\n'),
              ),
              _DetailRow(
                label: strings.uiSandboxStatesLabel,
                value: item.states.join(' · '),
              ),
              _DetailRow(
                label: strings.uiSandboxDifferencesLabel,
                value: item.differences,
              ),
              _DetailRow(
                label: strings.uiSandboxRationaleLabel,
                value: item.rationale,
              ),
              _DetailRow(label: strings.uiSandboxRisksLabel, value: item.risks),
              _DetailRow(
                label: strings.uiSandboxOptionsLabel,
                value: item.options.map((option) => '• $option').join('\n'),
              ),
              _DetailRow(
                label: strings.uiSandboxRecommendationLabel,
                value: item.recommendation,
                emphasized: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.65)),
      borderRadius: BorderRadius.circular(kRadiusPill),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: emphasized ? colors.gold : colors.text,
              height: 1.4,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TextStyle(color: colors.muted, height: 1.4)),
        ],
      ],
    );
  }
}

class _EmptyAuditState extends StatelessWidget {
  const _EmptyAuditState({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: onReset,
      child: AppButtonLabel(context.strings.uiSandboxResetFiltersAction),
    ),
  );
}

String _categoryLabel(AppStrings strings, UiAuditCategory value) =>
    switch (value) {
      UiAuditCategory.typography => strings.uiSandboxTypographyCategory,
      UiAuditCategory.actions => strings.uiSandboxActionsCategory,
      UiAuditCategory.fields => strings.uiSandboxFieldsCategory,
      UiAuditCategory.selection => strings.uiSandboxSelectionCategory,
      UiAuditCategory.surfaces => strings.uiSandboxSurfacesCategory,
      UiAuditCategory.overlays => strings.uiSandboxOverlaysCategory,
      UiAuditCategory.navigation => strings.uiSandboxNavigationCategory,
      UiAuditCategory.feedback => strings.uiSandboxFeedbackCategory,
      UiAuditCategory.spacing => strings.uiSandboxSpacingCategory,
      UiAuditCategory.color => strings.uiSandboxColorCategory,
      UiAuditCategory.icons => strings.uiSandboxIconsCategory,
      UiAuditCategory.motion => strings.uiSandboxMotionCategory,
    };

String _decisionLabel(AppStrings strings, UiAuditDecision value) =>
    switch (value) {
      UiAuditDecision.review => strings.uiSandboxReviewStatus,
      UiAuditDecision.keep => strings.uiSandboxKeepStatus,
      UiAuditDecision.replace => strings.uiSandboxReplaceStatus,
      UiAuditDecision.exception => strings.uiSandboxExceptionStatus,
    };

Color _decisionColor(AppColors colors, UiAuditDecision value) =>
    switch (value) {
      UiAuditDecision.review => colors.muted,
      UiAuditDecision.keep => colors.gold,
      UiAuditDecision.replace => colors.danger,
      UiAuditDecision.exception => colors.text,
    };
