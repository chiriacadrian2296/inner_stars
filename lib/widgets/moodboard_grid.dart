import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

import '../data/moodboard_repository.dart';
import '../data/moodboard_storage.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'logo_watermark.dart';
import 'staggered_entrance.dart';

class MoodboardGrid extends StatelessWidget {
  const MoodboardGrid({
    super.key,
    required this.items,
    this.onTap,
    this.placeholders = false,
    this.showEmptyMessage = true,
    this.placeholderReplayKey,
  });
  final List<MoodboardItem> items;
  final ValueChanged<MoodboardItem>? onTap;

  /// When [items] is empty, shows a block of white-tinted squares holding the
  /// place of future content instead of the explanatory text — for the small
  /// preview on an area's page.
  final bool placeholders;

  /// Replays the placeholder blocks' entrance when it changes, e.g. when the
  /// area page swipes to another area (the blocks are otherwise the same
  /// widgets and would stay put).
  final Object? placeholderReplayKey;

  /// The full moodboard supplies its own centered empty state over the
  /// watermark; small previews can still use this grid's inline message.
  final bool showEmptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && placeholders) {
      return _MoodboardPlaceholders(replayKey: placeholderReplayKey);
    }
    if (items.isEmpty && !showEmptyMessage) return const SizedBox.shrink();
    if (items.isEmpty) {
      return StaggeredEntrance(
        index: 0,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.strings.moodboardEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.muted),
            ),
          ),
        ),
      );
    }
    // A tile's wrapper is reused by position, so after an item is removed or
    // edited the tiles that shift into a slot replay their entrance (keyed to
    // what the slot now shows) instead of swapping their media silently.
    Widget tile(int index) => StaggeredEntrance(
      index: index,
      replayKey: '${items[index].id}:${items[index].content}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: context.colors.nightPanel,
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(items[index]),
            child: SizedBox.expand(
              child: MoodboardMedia(
                key: ValueKey('${items[index].id}:${items[index].content}'),
                item: items[index],
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 240,
              child: Row(
                textDirection: (i ~/ 3).isEven
                    ? TextDirection.ltr
                    : TextDirection.rtl,
                children: [
                  Expanded(flex: 3, child: tile(i)),
                  if (i + 1 < items.length) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(child: tile(i + 1)),
                          if (i + 2 < items.length) ...[
                            const SizedBox(height: 10),
                            Expanded(child: tile(i + 2)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Three rows of white-tinted blocks, standing in for a moodboard with nothing
/// in it yet. Some are wider than the squares, since real photos and videos
/// make the mosaic uneven too.
class _MoodboardPlaceholders extends StatelessWidget {
  const _MoodboardPlaceholders({this.replayKey});

  final Object? replayKey;

  static const _gap = 10.0;

  /// Each row's blocks, as relative widths.
  static const _rows = [
    [2, 1],
    [1, 1, 1],
    [1, 2],
  ];

  /// How far each block leans from night toward white, in reading order, so
  /// they read as different photos rather than one repeated tile.
  static const _whiteMix = [0.26, 0.16, 0.22, 0.12, 0.30, 0.19];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The height of a square when three sit side by side; every row
        // shares it so the rows stay even.
        final rowHeight = (constraints.maxWidth - 2 * _gap) / 3;
        // Blocks are numbered in reading order, for both the tint and the
        // entrance delay.
        var next = 0;
        Widget block(int flex) {
          final index = next++;
          return Expanded(
            flex: flex,
            child: StaggeredEntrance(
              index: index,
              replayKey: replayKey,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(
                    context.colors.night,
                    Colors.white,
                    _whiteMix[index % _whiteMix.length],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (var r = 0; r < _rows.length; r++) ...[
              if (r > 0) const SizedBox(height: _gap),
              SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    for (var c = 0; c < _rows[r].length; c++) ...[
                      if (c > 0) const SizedBox(width: _gap),
                      block(_rows[r][c]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class MoodboardMedia extends StatefulWidget {
  const MoodboardMedia({super.key, required this.item, this.expanded = false});
  final MoodboardItem item;
  final bool expanded;
  @override
  State<MoodboardMedia> createState() => _MoodboardMediaState();
}

class _MoodboardMediaState extends State<MoodboardMedia> {
  Future<Uint8List>? _image;
  VideoPlayerController? _video;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    if (widget.item.kind == MoodboardKind.photo) {
      _image = MoodboardStorage.read(widget.item.content);
    }
    if (widget.item.kind == MoodboardKind.video) _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final video = await MoodboardStorage.video(widget.item.content);
      if (!mounted) {
        await video.dispose();
        return;
      }
      _video = video;
      await video.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = Center(
      child: Text(
        context.strings.moodboardMediaError,
        textAlign: TextAlign.center,
      ),
    );
    if (widget.item.kind == MoodboardKind.quote) {
      return MoodboardQuoteCard(item: widget.item, expanded: widget.expanded);
    }
    if (_image != null) {
      return FutureBuilder<Uint8List>(
        future: _image,
        builder: (context, snapshot) => snapshot.hasError
            ? error
            : snapshot.hasData
            ? Image.memory(
                snapshot.data!,
                fit: widget.expanded ? BoxFit.contain : BoxFit.cover,
                errorBuilder: (_, _, _) => error,
              )
            : Center(
                child: CircularProgressIndicator(color: context.colors.gold),
              ),
      );
    }
    if (_failed) return error;
    final video = _video;
    if (video == null || !video.value.isInitialized) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.gold),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: video.value.aspectRatio,
            child: VideoPlayer(video),
          ),
        ),
        if (!widget.expanded)
          const IgnorePointer(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
          ),
        if (widget.expanded)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                ValueListenableBuilder(
                  valueListenable: video,
                  builder: (context, value, _) => IconButton.filled(
                    tooltip: value.isPlaying
                        ? context.strings.moodboardPause
                        : context.strings.moodboardPlay,
                    onPressed: () =>
                        value.isPlaying ? video.pause() : video.play(),
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VideoProgressIndicator(
                    video,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class MoodboardQuoteCard extends StatelessWidget {
  const MoodboardQuoteCard({
    super.key,
    required this.item,
    this.expanded = false,
  });

  final MoodboardItem item;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = item.quoteStyle;
    final isMinimal = style == MoodboardQuoteStyle.minimal;
    final isEditorial = style == MoodboardQuoteStyle.editorial;
    final textColor = isMinimal ? colors.night : Colors.white;
    final alignment = isEditorial ? Alignment.bottomLeft : Alignment.center;
    final textAlign = isEditorial ? TextAlign.left : TextAlign.center;
    final fontFamily = switch (style) {
      MoodboardQuoteStyle.editorial => kFontBranding,
      MoodboardQuoteStyle.minimal => kFontBody,
      MoodboardQuoteStyle.constellation => kFontMono,
      _ => kFontStarTitle,
    };
    final decoration = BoxDecoration(
      color: isMinimal ? const Color(0xFFF1EBDD) : colors.nightPanel,
      gradient: switch (style) {
        MoodboardQuoteStyle.celestial => const RadialGradient(
          center: Alignment(-0.7, -0.8),
          radius: 1.4,
          colors: [Color(0xFF344A86), Color(0xFF11182D), Color(0xFF080B14)],
        ),
        MoodboardQuoteStyle.aurora => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF173B46), Color(0xFF4B296A), Color(0xFF10152A)],
        ),
        MoodboardQuoteStyle.editorial => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9B4D36), Color(0xFF29151C)],
        ),
        MoodboardQuoteStyle.constellation => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07101F), Color(0xFF15294C)],
        ),
        MoodboardQuoteStyle.minimal => null,
      },
    );
    final watermarkColor = switch (style) {
      MoodboardQuoteStyle.celestial => Colors.white.withValues(alpha: 0.07),
      MoodboardQuoteStyle.aurora => const Color(
        0xFF72E5C2,
      ).withValues(alpha: 0.09),
      MoodboardQuoteStyle.editorial => colors.gold.withValues(alpha: 0.09),
      MoodboardQuoteStyle.constellation => colors.starUnlit.withValues(
        alpha: 0.12,
      ),
      MoodboardQuoteStyle.minimal => colors.night.withValues(alpha: 0.055),
    };
    final brandColor = isMinimal ? colors.night : colors.gold;

    return DecoratedBox(
      decoration: decoration,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LogoWatermark(
            color: watermarkColor,
            scale: switch (style) {
              MoodboardQuoteStyle.editorial => 1.05,
              MoodboardQuoteStyle.minimal => 0.72,
              MoodboardQuoteStyle.constellation => 0.82,
              _ => 0.9,
            },
            duration: Duration.zero,
          ),
          if (style == MoodboardQuoteStyle.celestial ||
              style == MoodboardQuoteStyle.constellation)
            Positioned(
              right: 14,
              top: 12,
              child: Icon(
                style == MoodboardQuoteStyle.celestial
                    ? Icons.auto_awesome
                    : Icons.hub_outlined,
                color: colors.gold.withValues(alpha: 0.7),
                size: expanded ? 42 : 26,
              ),
            ),
          if (style == MoodboardQuoteStyle.aurora)
            Positioned(
              left: -30,
              bottom: -30,
              child: Icon(
                Icons.blur_on,
                size: expanded ? 170 : 100,
                color: const Color(0xFF72E5C2).withValues(alpha: 0.18),
              ),
            ),
          if (isEditorial)
            Positioned(
              left: 18,
              top: 16,
              child: Text(
                '“',
                style: TextStyle(
                  color: colors.gold,
                  fontFamily: kFontStarTitle,
                  fontSize: expanded ? 76 : 54,
                  height: 0.8,
                ),
              ),
            ),
          Align(
            alignment: alignment,
            child: Padding(
              padding: EdgeInsets.all(expanded ? 32 : 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isEditorial
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Text(
                    item.content,
                    textAlign: textAlign,
                    maxLines: expanded ? null : 4,
                    overflow: expanded ? null : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: expanded ? 34 : 16,
                      fontStyle: style == MoodboardQuoteStyle.celestial
                          ? FontStyle.italic
                          : FontStyle.normal,
                      fontWeight: isMinimal ? FontWeight.w600 : FontWeight.w500,
                      height: 1.2,
                      color: textColor,
                    ),
                  ),
                  if (item.author.isNotEmpty) ...[
                    SizedBox(height: expanded ? 20 : 8),
                    Text(
                      '— ${item.author}',
                      textAlign: textAlign,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.72),
                        fontFamily: kFontMono,
                        fontSize: expanded ? 16 : 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: _QuoteBrand(
              color: brandColor.withValues(alpha: 0.62),
              expanded: expanded,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteBrand extends StatelessWidget {
  const _QuoteBrand({required this.color, required this.expanded});

  final Color color;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final markSize = expanded ? 15.0 : 10.0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: markSize,
            child: OverflowBox(
              maxWidth: markSize * 1.9,
              maxHeight: markSize * 1.9,
              child: SvgPicture.asset(
                'assets/icon/Logo.svg',
                width: markSize * 1.9,
                height: markSize * 1.9,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
          ),
          SizedBox(width: expanded ? 7 : 4),
          Text(
            'VICTORY STARS',
            style: TextStyle(
              color: color,
              fontFamily: kFontBranding,
              fontSize: expanded ? 11 : 7,
              fontWeight: FontWeight.w600,
              letterSpacing: expanded ? 1.6 : 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
