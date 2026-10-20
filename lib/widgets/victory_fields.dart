import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../models/star_media.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_style.dart';
import '../utils/date_format.dart';
import 'app_field.dart';
import 'intensity_bolts.dart';
import 'photo_picker.dart';
import 'staggered_entrance.dart';
import 'star_media_editor.dart';

/// A victory's fields, shared by the star form (creating or editing a lit
/// star) and the "mark achieved" sheet, so lighting a goal asks for exactly
/// what creating a victory does, in the same look.

/// When the victory happened: a date and a time side by side, each
/// resettable on its own (an unset one falls back to today / now).
class VictoryDateTimeFields extends StatelessWidget {
  const VictoryDateTimeFields({
    super.key,
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
    required this.onResetDate,
    required this.onResetTime,
    this.timeErrorText,
    this.entranceIndex = 0,
    this.replayKey,
  });

  /// Shown under the time — e.g. a time today that hasn't come yet.
  final String? timeErrorText;

  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onResetDate;
  final VoidCallback onResetTime;

  /// The date's [StaggeredEntrance] index; the time follows at +1.
  final int entranceIndex;
  final Object? replayKey;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final date = this.date;
    final time = this.time;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: StaggeredEntrance(
            index: entranceIndex,
            replayKey: replayKey,
            axis: Axis.horizontal,
            child: AppPickerField(
              label: strings.dateLabel,
              onReset: onResetDate,
              // Left empty it becomes today on save, so nothing has to be
              // entered here: only fields with no default read as required.
              requirement: FieldRequirement.optional,
              hint: strings.selectADateHint,
              icon: Icons.calendar_today,
              text: date == null ? null : formatDisplayDate(date, strings),
              onTap: onPickDate,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StaggeredEntrance(
            index: entranceIndex + 1,
            replayKey: replayKey,
            axis: Axis.horizontal,
            child: AppPickerField(
              label: strings.timeLabel,
              onReset: onResetTime,
              // Left empty it becomes now on save.
              requirement: FieldRequirement.optional,
              hint: strings.selectATimeHint,
              icon: Icons.access_time,
              text: time == null
                  ? null
                  : formatDisplayTime(
                      DateTime(2000, 1, 1, time.hour, time.minute),
                    ),
              errorText: timeErrorText,
              onTap: onPickTime,
            ),
          ),
        ),
      ],
    );
  }
}

/// The intensity label, bolts and slider. Until [touched] the bolts are all
/// small, flat and unlit, and the slider is muted.
class IntensityField extends StatelessWidget {
  const IntensityField({
    super.key,
    required this.label,
    required this.intensity,
    required this.touched,
    required this.onChanged,
    required this.onReset,
    this.showUntouchedValue = false,
  });

  /// While untouched, show [intensity]'s bolts (still muted) instead of none
  /// — an edit's saved value: where it was, to be chosen again.
  final bool showUntouchedValue;

  final String label;
  final int intensity;

  /// Until the slider is moved on purpose there's no intensity yet: the
  /// value shown is only where the slider starts, and saving is held back.
  final bool touched;

  /// Called on every slider move (and once when a drag starts, with the
  /// current value), which also marks the field touched.
  final ValueChanged<int> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(
          label,
          canReset: touched,
          onReset: onReset,
          requirement: FieldRequirement.required,
        ),
        // The shared label-to-content gap, not this section's own one-off 10
        // — kept it from reading as more loosely spaced than its neighbors.
        const SizedBox(height: kFieldLabelGap),
        Center(
          child: touched
              ? IntensityBolts(
                  intensity: intensity,
                  size: 26,
                  spacing: 6,
                  emphasizeLast: true,
                  emphasizedScale: 1.6,
                )
              // Untouched: all small, flat, in the field-label color, none
              // lit — or, with [showUntouchedValue], the saved ones picked
              // out in that same muted color. Same height as the emphasized bolt, whose glow copy is
              // drawn 1.15x its size (26 * 1.6 * 1.15) and sets the row's
              // height, so nothing below jumps on first use.
              : SizedBox(
                  height: 26 * 1.6 * 1.15,
                  child: IntensityBolts(
                    intensity: showUntouchedValue ? intensity : 0,
                    size: 26,
                    spacing: 6,
                    color: colors.muted,
                  ),
                ),
        ),
        const SizedBox(height: 14),
        Center(
          child: FractionallySizedBox(
            widthFactor: 0.7,
            // A plain [Slider]'s own vertical padding defaults to the height
            // of its overlay shape (the halo around the thumb) — invisible
            // space that made the gap down to whatever comes next read as
            // much bigger than the standard 20 between fields. Zeroing it
            // makes this widget's bounding box match what's visible.
            child: SliderTheme(
              data: touched
                  ? SliderTheme.of(context).copyWith(padding: EdgeInsets.zero)
                  : SliderTheme.of(context).copyWith(
                      padding: EdgeInsets.zero,
                      activeTrackColor: colors.muted,
                      thumbColor: colors.muted,
                      activeTickMarkColor: colors.muted,
                      overlayColor: colors.muted.withValues(alpha: 0.12),
                    ),
              child: Slider(
                value: intensity.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                onChangeStart: (_) {
                  if (!touched) onChanged(intensity);
                },
                onChanged: (value) => onChanged(value.round()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The "Details" toggle and, once open, a victory's main photo (on the left)
/// beside its one voice note and its song, place and site links.
class VictoryDetailsSection extends StatelessWidget {
  const VictoryDetailsSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.photoPath,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    required this.media,
    required this.onMediaChanged,
    this.entranceIndex = 0,
    this.replayKey,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String? photoPath;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemovePhoto;

  final List<StarMedia> media;
  final ValueChanged<List<StarMedia>> onMediaChanged;

  /// The toggle's [StaggeredEntrance] index.
  final int entranceIndex;
  final Object? replayKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaggeredEntrance(
          index: entranceIndex,
          replayKey: replayKey,
          child: Center(
            child: Semantics(
              button: true,
              expanded: expanded,
              child: GestureDetector(
                key: const ValueKey('victory-details-toggle'),
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.detailsLabel,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedContainer(
                        duration: motionDuration(context, kMotionBase),
                        curve: kMotionEnter,
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: expanded ? colors.gold : colors.night,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.nightBorder,
                            width: kBorderWidth,
                          ),
                        ),
                        child: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          size: 24,
                          color: expanded ? colors.night : colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: motionDuration(context, kMotionBase),
            curve: kMotionEnter,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    key: const ValueKey('victory-details-content'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // As much air below the toggle as callers leave
                      // above it.
                      const SizedBox(height: 44),
                      StaggeredEntrance(
                        index: 0,
                        // Split in two halves: the main photo on the left; on
                        // the right one voice note, then a song, a place and
                        // a site link, down to the photo's own bottom edge.
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const gap = 12.0;
                            final half = (constraints.maxWidth - gap) / 2;
                            final gridHeight = half * 16 / 9;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: kFieldNameRowHeight,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: AppFieldLabel(
                                            strings.photoLabel,
                                            requirement:
                                                FieldRequirement.optional,
                                            onReset: onRemovePhoto,
                                            canReset: photoPath != null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: kFieldLabelGap),
                                      PhotoPicker(
                                        photoPath: photoPath,
                                        onPick: onPickPhoto,
                                        onRemove: onRemovePhoto,
                                        compact: true,
                                        compactWidth: half,
                                        compactHeight: gridHeight,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: gap),
                                Expanded(
                                  child: StarMediaEditor(
                                    media: media,
                                    onChanged: onMediaChanged,
                                    sideColumn: true,
                                    // As tall as the left column: its name row,
                                    // the gap, and the photo.
                                    gridHeight:
                                        kFieldNameRowHeight +
                                        kFieldLabelGap +
                                        gridHeight,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
