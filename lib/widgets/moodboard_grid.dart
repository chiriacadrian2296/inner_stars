import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/moodboard_repository.dart';
import '../data/moodboard_storage.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_fonts.dart';
import 'staggered_entrance.dart';

class MoodboardGrid extends StatelessWidget {
  const MoodboardGrid({
    super.key,
    required this.items,
    this.onTap,
    this.placeholders = false,
  });
  final List<MoodboardItem> items;
  final ValueChanged<MoodboardItem>? onTap;

  /// When [items] is empty, shows a block of plain grey squares holding the
  /// place of future content instead of the explanatory text — for the small
  /// preview on an area's page.
  final bool placeholders;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && placeholders) return const _MoodboardPlaceholders();
    if (items.isEmpty) {
      return StaggeredEntrance(
        index: 0,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.strings.moodboardEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
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
          color: const Color(0xFF141D30),
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

/// Three rows of plain grey blocks, standing in for a moodboard with nothing
/// in it yet. Some are wider than the squares, since real photos and videos
/// make the mosaic uneven too.
class _MoodboardPlaceholders extends StatelessWidget {
  const _MoodboardPlaceholders();

  static const _gap = 10.0;

  /// Each row's blocks, as relative widths.
  static const _rows = [
    [2, 1],
    [1, 1, 1],
    [1, 2],
  ];

  /// A slightly different grey per block, in reading order, so they read as
  /// different photos rather than one repeated tile.
  static const _greys = [
    Color(0xFF2B2B2B),
    Color(0xFF3A3A3A),
    Color(0xFF333333),
    Color(0xFF262626),
    Color(0xFF3F3F3F),
    Color(0xFF303030),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The height of a square when three sit side by side; every row
        // shares it so the rows stay even.
        final rowHeight = (constraints.maxWidth - 2 * _gap) / 3;
        // Blocks are numbered in reading order, for both the grey and the
        // entrance delay.
        var next = 0;
        Widget block(int flex) {
          final index = next++;
          return Expanded(
            flex: flex,
            child: StaggeredEntrance(
              index: index,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _greys[index % _greys.length],
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            widget.item.content,
            textAlign: TextAlign.center,
            maxLines: widget.expanded ? null : 6,
            overflow: widget.expanded ? null : TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kFontStarTitle,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
        ),
      );
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
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
      );
    }
    if (_failed) return error;
    final video = _video;
    if (video == null || !video.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
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
