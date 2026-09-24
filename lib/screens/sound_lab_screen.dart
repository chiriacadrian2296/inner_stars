import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../l10n/strings_scope.dart';
import '../models/background_track.dart';
import '../models/sky_sound_effect.dart';
import '../models/sky_whoosh_effect.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';

/// Every sound experiment in one place: the Sky's background loop
/// (pick a track, play/pause), its tap/hold sounds, and its two zoom
/// whooshes — each picked from a dropdown or stepped through with arrows —
/// plus a volume slider per category. Reached via a dedicated button on the
/// Sky itself (top-right) rather than buried in Settings, since this screen
/// exists mainly for quickly auditioning the growing pool of candidate
/// sounds; nothing here is destructive, so there's nothing wrong with it
/// being one tap away.
class SoundLabScreen extends StatefulWidget {
  const SoundLabScreen({super.key, required this.audioService});

  final AudioService audioService;

  @override
  State<SoundLabScreen> createState() => _SoundLabScreenState();
}

/// Steps [current] forward/backward through [values] by [delta], wrapping
/// around at either end — shared by every arrow-stepped picker on this
/// screen (the background track and each sound-effect panel).
T _cycled<T>(List<T> values, T current, int delta) {
  final index = values.indexOf(current);
  final next = (index + delta) % values.length;
  return values[next < 0 ? next + values.length : next];
}

class _SoundLabScreenState extends State<SoundLabScreen> {
  Future<void> _toggleBackgroundPlayback() async {
    if (widget.audioService.backgroundPaused) {
      await widget.audioService.resumeBackground();
    } else {
      await widget.audioService.pauseBackground();
    }
    setState(() {});
  }

  Future<void> _selectTrack(BackgroundTrack? track) async {
    if (track == null) return;
    await widget.audioService.setBackgroundTrack(track);
    setState(() {});
  }

  void _stepTrack(int delta) => _selectTrack(
    _cycled(BackgroundTrack.values, widget.audioService.backgroundTrack, delta),
  );

  // Every sound choice previews immediately — this is the only place a
  // user ever hears these before actually tapping/holding/moving around
  // in the Sky, so picking one silently would leave them guessing.
  Future<void> _selectTapSound(SkySoundEffect? sound) async {
    if (sound == null) return;
    await widget.audioService.setTapSound(sound);
    await widget.audioService.previewTapSound(sound);
    setState(() {});
  }

  Future<void> _selectHoldSound(SkySoundEffect? sound) async {
    if (sound == null) return;
    await widget.audioService.setHoldSound(sound);
    await widget.audioService.previewHoldSound(sound);
    setState(() {});
  }

  Future<void> _selectWhooshInSound(SkyWhooshEffect? sound) async {
    if (sound == null) return;
    await widget.audioService.setWhooshInSound(sound);
    await widget.audioService.previewWhooshSound(sound);
    setState(() {});
  }

  Future<void> _selectWhooshOutSound(SkyWhooshEffect? sound) async {
    if (sound == null) return;
    await widget.audioService.setWhooshOutSound(sound);
    await widget.audioService.previewWhooshSound(sound);
    setState(() {});
  }

  // The background slider previews itself — it's already playing, so
  // [AudioService.setBackgroundVolume] applies the new level to the live
  // player immediately. The other three aren't currently playing anything,
  // so each gets its own explicit preview instead, fired once on release
  // (see the `onChangeEnd` handlers below) rather than on every
  // intermediate value while dragging — a one-shot sound retriggering
  // dozens of times a second mid-drag would be noise, not feedback.
  Future<void> _setBackgroundVolume(double volume) async {
    await widget.audioService.setBackgroundVolume(volume);
    setState(() {});
  }

  Future<void> _setTapVolume(double volume) async {
    await widget.audioService.setTapVolume(volume);
    setState(() {});
  }

  Future<void> _setHoldVolume(double volume) async {
    await widget.audioService.setHoldVolume(volume);
    setState(() {});
  }

  Future<void> _setWhooshVolume(double volume) async {
    await widget.audioService.setWhooshVolume(volume);
    setState(() {});
  }

  void _previewTapVolume(double _) =>
      widget.audioService.previewTapSound(widget.audioService.tapSound);

  void _previewHoldVolume(double _) =>
      widget.audioService.previewHoldSound(widget.audioService.holdSound);

  void _previewWhooshVolume(double _) => widget.audioService
      .previewWhooshSound(widget.audioService.whooshInSound);

  Future<void> _resetToDefaults() async {
    await widget.audioService.resetToDefaults();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final paused = widget.audioService.backgroundPaused;

    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: ResponsiveContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              StaggeredEntrance(
                index: 0,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back, color: colors.muted),
                    ),
                    Text(
                      strings.soundLabEyebrow,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                        color: colors.gold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _resetToDefaults,
                      tooltip: strings.soundLabResetAction,
                      icon: Icon(Icons.restore, color: colors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              StaggeredEntrance(
                index: 0,
                child: Text(
                  strings.soundLabTitle,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              StaggeredEntrance(
                index: 0,
                child: Text(
                  strings.soundLabSubtitle,
                  style: TextStyle(fontSize: 14, height: 1.45, color: colors.muted),
                ),
              ),
              const SizedBox(height: 22),

              StaggeredEntrance(
                index: 1,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: panelDecoration(colors),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StaggeredEntrance(
                        index: 0,
                        child: Text(
                          strings.backgroundTrackLabel,
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: StaggeredEntrance(
                              index: 1,
                              axis: Axis.horizontal,
                              child: _SoundDropdown<BackgroundTrack>(
                                value: widget.audioService.backgroundTrack,
                                items: [
                                  for (final track in BackgroundTrack.values)
                                    DropdownMenuItem(
                                      value: track,
                                      child: Text(track.displayName(strings)),
                                    ),
                                ],
                                onChanged: _selectTrack,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: StaggeredEntrance(
                              index: 2,
                              axis: Axis.horizontal,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _StepArrowButton(
                                      icon: Icons.chevron_left,
                                      onTap: () => _stepTrack(-1),
                                    ),
                                    _StepArrowButton(
                                      icon: Icons.chevron_right,
                                      onTap: () => _stepTrack(1),
                                    ),
                                    const SizedBox(width: 6),
                                    _PlayPauseButton(
                                      paused: paused,
                                      onTap: _toggleBackgroundPlayback,
                                      playTooltip: strings.playBackgroundTrackAction,
                                      pauseTooltip: strings.pauseBackgroundTrackAction,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              StaggeredEntrance(
                index: 2,
                child: _SoundEffectPanel<SkySoundEffect>(
                  label: strings.tapSoundLabel,
                  value: widget.audioService.tapSound,
                  allValues: SkySoundEffect.values,
                  displayName: (sound) => sound.displayName(strings),
                  onChanged: _selectTapSound,
                ),
              ),
              const SizedBox(height: 12),

              StaggeredEntrance(
                index: 3,
                child: _SoundEffectPanel<SkySoundEffect>(
                  label: strings.holdSoundLabel,
                  value: widget.audioService.holdSound,
                  allValues: SkySoundEffect.values,
                  displayName: (sound) => sound.displayName(strings),
                  onChanged: _selectHoldSound,
                ),
              ),
              const SizedBox(height: 12),

              StaggeredEntrance(
                index: 4,
                child: _SoundEffectPanel<SkyWhooshEffect>(
                  label: strings.whooshInLabel,
                  value: widget.audioService.whooshInSound,
                  allValues: SkyWhooshEffect.values,
                  displayName: (sound) => sound.displayName(strings),
                  onChanged: _selectWhooshInSound,
                ),
              ),
              const SizedBox(height: 12),

              StaggeredEntrance(
                index: 5,
                child: _SoundEffectPanel<SkyWhooshEffect>(
                  label: strings.whooshOutLabel,
                  value: widget.audioService.whooshOutSound,
                  allValues: SkyWhooshEffect.values,
                  displayName: (sound) => sound.displayName(strings),
                  onChanged: _selectWhooshOutSound,
                ),
              ),
              const SizedBox(height: 12),

              StaggeredEntrance(
                index: 6,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 18, 8),
                  decoration: panelDecoration(colors),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StaggeredEntrance(
                        index: 0,
                        child: Text(
                          strings.volumeSectionLabel,
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        ),
                      ),
                      const SizedBox(height: 14),
                      StaggeredEntrance(
                        index: 1,
                        child: _VolumeSliderRow(
                          label: strings.backgroundVolumeLabel,
                          value: widget.audioService.backgroundVolume,
                          onChanged: _setBackgroundVolume,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StaggeredEntrance(
                        index: 2,
                        child: _VolumeSliderRow(
                          label: strings.tapVolumeLabel,
                          value: widget.audioService.tapVolume,
                          onChanged: _setTapVolume,
                          onChangeEnd: _previewTapVolume,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StaggeredEntrance(
                        index: 3,
                        child: _VolumeSliderRow(
                          label: strings.holdVolumeLabel,
                          value: widget.audioService.holdVolume,
                          onChanged: _setHoldVolume,
                          onChangeEnd: _previewHoldVolume,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StaggeredEntrance(
                        index: 4,
                        child: _VolumeSliderRow(
                          label: strings.whooshVolumeLabel,
                          value: widget.audioService.whooshVolume,
                          onChanged: _setWhooshVolume,
                          onChangeEnd: _previewWhooshVolume,
                        ),
                      ),
                      const SizedBox(height: 6),
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

/// One tap/hold/whoosh panel: a label above a row pairing a
/// [_SoundDropdown] (2/3 width) with a pair of step arrows (1/3 width) that
/// cycle through [allValues] without opening the dropdown. Generic over the
/// sound enum type so the same panel shape serves [SkySoundEffect]
/// (tap/hold) and [SkyWhooshEffect] (zoom in/out) without duplicating the
/// layout four times.
class _SoundEffectPanel<T> extends StatelessWidget {
  const _SoundEffectPanel({
    required this.label,
    required this.value,
    required this.allValues,
    required this.displayName,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> allValues;
  final String Function(T) displayName;
  final ValueChanged<T?> onChanged;

  void _step(int delta) => onChanged(_cycled(allValues, value, delta));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: panelDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaggeredEntrance(
            index: 0,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.muted),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: StaggeredEntrance(
                  index: 1,
                  axis: Axis.horizontal,
                  child: _SoundDropdown<T>(
                    value: value,
                    items: [
                      for (final item in allValues)
                        DropdownMenuItem(
                          value: item,
                          child: Text(displayName(item)),
                        ),
                    ],
                    onChanged: onChanged,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: StaggeredEntrance(
                  index: 2,
                  axis: Axis.horizontal,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StepArrowButton(
                          icon: Icons.chevron_left,
                          onTap: () => _step(-1),
                        ),
                        _StepArrowButton(
                          icon: Icons.chevron_right,
                          onTap: () => _step(1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The one dropdown shape every sound picker in this screen uses — styled
/// like the app's other fields (`fieldDecoration`) rather than Material's
/// own default dropdown chrome, so it reads as one more field belonging to
/// this app instead of a stock widget dropped in.
class _SoundDropdown<T> extends StatelessWidget {
  const _SoundDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: fieldDecoration(colors, FieldState.filled),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: colors.nightPanel,
          icon: Icon(Icons.keyboard_arrow_down, color: colors.gold),
          style: TextStyle(
            color: colors.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// A small round-ish icon button that steps a picker to the previous/next
/// value without opening its dropdown. Kept compact (fixed 34x34) so a
/// pair of these plus, on the background row, the play/pause button all
/// still fit inside the 1/3-width right-hand zone.
class _StepArrowButton extends StatelessWidget {
  const _StepArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        splashRadius: 18,
        icon: Icon(icon, color: colors.gold, size: 22),
      ),
    );
  }
}

/// The background track's play/pause control — kept as its own widget
/// (rather than inline) since, unlike every other row on this screen, it
/// sits apart from the step arrows within the same right-hand zone.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.paused,
    required this.onTap,
    required this.playTooltip,
    required this.pauseTooltip,
  });

  final bool paused;
  final VoidCallback onTap;
  final String playTooltip;
  final String pauseTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        splashRadius: 18,
        tooltip: paused ? playTooltip : pauseTooltip,
        icon: Icon(
          paused ? Icons.play_arrow : Icons.pause,
          color: colors.gold,
        ),
      ),
    );
  }
}

/// One row of the volume panel: a label beside a full-width [Slider] and
/// its percentage readout, with enough breathing room around each row
/// (see the [SizedBox]s between rows in [SoundLabScreen.build]) to read as
/// separate controls rather than a cramped stack. [onChangeEnd] is null
/// for the background row — that one previews itself live (see
/// [AudioService.setBackgroundVolume]), since it's already playing; the
/// other three pass one, fired once on release to preview the level
/// without retriggering on every intermediate value while dragging.
class _VolumeSliderRow extends StatelessWidget {
  const _VolumeSliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: StaggeredEntrance(
            index: 0,
            axis: Axis.horizontal,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StaggeredEntrance(
            index: 1,
            axis: Axis.horizontal,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                padding: EdgeInsets.zero,
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: StaggeredEntrance(
            index: 2,
            axis: Axis.horizontal,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          ),
        ),
      ],
    );
  }
}
