import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';

/// Whether a field must be filled in to submit its form — shown as a small
/// dot beside that field's own [AppFieldLabel]/[AppPickerField] rather than
/// spelled out in words at every field. [FieldRequirementLegend] is the one
/// place the words themselves appear, once per form.
enum FieldRequirement {
  required,
  optional;

  IconData get _icon =>
      this == FieldRequirement.required ? Icons.circle : Icons.circle_outlined;

  Color _color(AppColors colors) =>
      this == FieldRequirement.required ? colors.gold : colors.muted;
}

/// The small muted caption that sits above every field. Its own widget
/// because it appeared, hand-written and very slightly different, above
/// roughly fifteen fields across the app.
///
/// [requirement] is null for the handful of fields it doesn't meaningfully
/// apply to (a slider that's never empty, a static non-editable box) —
/// those render with no dot at all rather than an arbitrary guess.
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.label, {super.key, this.requirement});

  final String label;
  final FieldRequirement? requirement;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final requirement = this.requirement;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Before the text, not after — so the dot sits in the same column
        // for every field regardless of how long each one's own label is,
        // rather than trailing off at a different point per field.
        if (requirement != null) ...[
          Icon(requirement._icon, size: 8, color: requirement._color(colors)),
          const SizedBox(width: 5),
        ],
        Text(label, style: context.typography.compactSectionLabel),
      ],
    );
  }
}

/// The one-line key explaining [FieldRequirement]'s two dots — shown once,
/// centered, above a form that uses them on its own fields, right before
/// the first one. Keeps every per-field marker icon-only instead of
/// repeating "required"/"optional" at each one.
class FieldRequirementLegend extends StatelessWidget {
  const FieldRequirementLegend({super.key});

  Widget _item(AppColors colors, FieldRequirement requirement, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(requirement._icon, size: 8, color: requirement._color(colors)),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, color: colors.muted)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Center(
      // Shrink-wrapped, not [width]: double.infinity like the fields below
      // it — this card is a caption for the form, not one more field
      // matching their own full-width shape, so its own background only
      // needs to be as wide as "Info" plus the two dots actually require.
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        // Same surface as the fields it's explaining — a plain panel, not
        // one more field of its own (no [fieldDecoration]/focus behavior;
        // it never holds a value or gets tapped).
        decoration: panelDecoration(colors),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 18, color: colors.gold),
                const SizedBox(width: 8),
                Text(
                  strings.fieldLegendTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _item(
                  colors,
                  FieldRequirement.required,
                  strings.requiredFieldLegend,
                ),
                const SizedBox(width: 16),
                _item(
                  colors,
                  FieldRequirement.optional,
                  strings.optionalFieldLegend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's one text input.
///
/// A plain [TextField] can follow two thirds of the field rule from the
/// theme alone (dark when empty, lit while focused) but not the third:
/// staying lit once it *holds* something. Only the widget with the
/// controller knows that, which is why every typed field goes through here
/// rather than through `TextField` directly — otherwise a filled name box
/// and a filled date picker, side by side in the same form, disagree about
/// whether being filled means anything.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.minLines,
    this.maxLines = 1,
    this.autofocus = false,
    this.textInputAction,
    this.onChanged,
    this.prefixIcon,
    this.enabled = true,
    this.readOnly = false,
    this.errorText,
  });

  final TextEditingController controller;
  final String? hintText;
  final int? minLines;
  final int? maxLines;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final bool enabled;
  final bool readOnly;
  final String? errorText;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChanged);

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Rebuilt against the controller rather than on every keystroke's own
    // setState: the border only has to change on the empty↔non-empty edge,
    // and this way a caller that doesn't pass onChanged still gets it.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final state = fieldStateOf(
          hasValue: value.text.trim().isNotEmpty,
          focused: _focusNode.hasFocus,
          enabled: widget.enabled,
          hasError: widget.errorText != null,
        );
        // The glow can't go through InputDecoration, so it's painted behind
        // the field; the border itself still comes from the decoration so
        // the text/hint keep their normal insets.
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusField),
            boxShadow: state == FieldState.focused
                ? goldGlow(colors, strength: 0.7, size: 40)
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            style: TextStyle(color: colors.text, fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.hintText,
              errorText: widget.errorText,
              prefixIcon: widget.prefixIcon,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kRadiusField),
                borderSide: BorderSide(
                  color: fieldBorderColor(colors, state),
                  width: fieldBorderWidth(state),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The app's one "tap to choose" field — a date, a constellation, a life
/// area, an icon. Looks and lights exactly like [AppTextField], because to
/// a user it's the same object: a box that's either empty or holds your
/// answer.
///
/// Its content is either [text] (with [icon] beside it) or, when
/// [iconOnly] is set, just the icon centered — the icon picker has nothing
/// readable to show once chosen, and an icon alone reads better there than
/// an icon next to an empty label slot.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    super.key,
    this.label,
    this.requirement,
    required this.hint,
    required this.icon,
    required this.text,
    required this.onTap,
    this.trailing,
    this.iconOnly = false,
    this.enabled = true,
    this.errorText,
  });

  /// Omitted when the surrounding form already labels this field some other
  /// way (a section heading, a row of two).
  final String? label;

  /// Forwarded straight to [AppFieldLabel] — meaningless without [label].
  final FieldRequirement? requirement;

  final String hint;
  final IconData icon;

  /// Null means empty — which is exactly what decides whether this field
  /// is lit.
  final String? text;

  final VoidCallback onTap;

  /// An affordance at the right edge, e.g. a chevron on a picker that opens
  /// a full list.
  final Widget? trailing;

  final bool iconOnly;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = text != null;
    final state = fieldStateOf(
      hasValue: filled,
      focused: false,
      enabled: enabled,
      hasError: errorText != null,
    );

    final field = InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(kRadiusField),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: fieldDecoration(colors, state),
        child: iconOnly && filled
            ? Center(child: Icon(icon, size: 22, color: colors.gold))
            : Row(
                children: [
                  Icon(
                    icon,
                    size: filled ? 20 : 16,
                    color: filled ? colors.gold : colors.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text ?? hint,
                      style: TextStyle(
                        color: filled ? colors.text : colors.muted,
                        fontSize: 15,
                        fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ?trailing,
                ],
              ),
      ),
    );

    final fieldWithError = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(opacity: enabled ? 1 : 0.45, child: field),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(color: colors.danger, fontSize: 12),
          ),
        ],
      ],
    );

    if (label == null) return fieldWithError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label!, requirement: requirement),
        const SizedBox(height: 6),
        fieldWithError,
      ],
    );
  }
}
