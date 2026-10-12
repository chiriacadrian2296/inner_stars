import 'package:flutter/material.dart';

import '../data/constellation_presets.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';
import '../utils/icon_for_slug.dart';
import 'responsive_content.dart';
import 'app_field.dart';

/// Reuses the app's icon catalogue without coupling an activity to a shape.
Future<String?> pickActivityIcon(
  BuildContext context, {
  required String selected,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(builder: (_) => _ActivityIconPicker(selected: selected)),
);

class _ActivityIconPicker extends StatefulWidget {
  const _ActivityIconPicker({required this.selected});
  final String selected;
  @override
  State<_ActivityIconPicker> createState() => _ActivityIconPickerState();
}

class _ActivityIconPickerState extends State<_ActivityIconPicker> {
  final _search = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final icons = starsShapePresets
        .where(
          (preset) =>
              preset.name
                  .of(s.languageCode)
                  .toLowerCase()
                  .contains(_query.toLowerCase()) ||
              preset.iconSlug.contains(_query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      backgroundColor: context.colors.night,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.iconLabel, style: context.typography.utilityPageTitle),
                const SizedBox(height: 16),
                AppSearchField(
                  controller: _search,
                  hintText: s.iconLabel,
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 16),
                if (icons.isEmpty) Text(s.noSearchResults),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in icons)
                      Tooltip(
                        message: preset.name.of(s.languageCode),
                        child: Material(
                          color: widget.selected == preset.iconSlug
                              ? context.colors.gold
                              : context.colors.nightPanel,
                          borderRadius: BorderRadius.circular(kRadiusCard),
                          child: InkWell(
                            onTap: () =>
                                Navigator.of(context).pop(preset.iconSlug),
                            borderRadius: BorderRadius.circular(kRadiusCard),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: Icon(
                                iconForSlug(preset.iconSlug),
                                color: widget.selected == preset.iconSlug
                                    ? context.colors.night
                                    : context.colors.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: AppButtonLabel(s.cancel, color: context.colors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
