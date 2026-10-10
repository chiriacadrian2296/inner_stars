import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../data/star_media_storage.dart';
import '../l10n/strings_scope.dart';
import '../models/star_media.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'play_badge.dart';
import 'voice_note_player.dart';

/// The one gap between the reader's stacked blocks: data slot, texts, voice
/// notes, photos, links.
const double kReaderBlockGap = 20;

/// How wide a voice note is, as a fraction of the media column.
const double _kVoiceCardWidthFactor = 0.5;

/// How wide the photo mosaic is, as a fraction of the media column; its tile
/// heights shrink by the same factor so every photo scales linearly.
const double _kMosaicWidthFactor = 0.8;

/// Normalizes what the user typed into a link, or null if it isn't a usable
/// http(s) address. A bare "example.com" gets "https://" in front.
Uri? parseExtraLink(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text.contains(' ')) return null;
  final withScheme = text.contains('://') ? text : 'https://$text';
  final uri = Uri.tryParse(withScheme);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      !uri.host.contains('.')) {
    return null;
  }
  return uri;
}

/// A stored extra photo, read straight from app storage.
class StarMediaImage extends StatelessWidget {
  const StarMediaImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (StarMediaStorage.isRemote(path)) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => SizedBox(width: width, height: height),
      );
    }

    return FutureBuilder<Object?>(
      future: kIsWeb
          ? StarMediaStorage.readBytes(path)
          : StarMediaStorage.file(path),
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (value == null) {
          return SizedBox(width: width, height: height);
        }
        Widget error(
          BuildContext context,
          Object exception,
          StackTrace? stack,
        ) => SizedBox(width: width, height: height);
        return kIsWeb
            ? Image.memory(
                value as Uint8List,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: error,
              )
            : Image.file(
                value as File,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: error,
              );
      },
    );
  }
}

/// A still from a stored video with a play glyph over it, or just the glyph
/// on a dark panel while the still is missing or still being made.
class StarVideoThumb extends StatelessWidget {
  const StarVideoThumb({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.badgeColor = Colors.white,
    this.badgeSize = kPlayBadgeSize,
  });

  final String path;
  final double? width;
  final double? height;

  /// Color of the play mark (gold in the create form, white elsewhere).
  final Color badgeColor;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (kIsWeb) {
      return _WebVideoThumb(
        path: path,
        badgeColor: badgeColor,
        badgeSize: badgeSize,
      );
    }
    return FutureBuilder<File?>(
      future: StarMediaStorage.videoThumbnail(path),
      builder: (context, snapshot) {
        final thumb = snapshot.data;
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            ColoredBox(color: colors.night),
            if (thumb != null)
              Image.file(
                thumb,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            // A translucent navy veil: over the picture, under the play mark.
            ColoredBox(color: colors.night.withValues(alpha: 0.6)),
            Center(
              child: PlayBadge(size: badgeSize, color: badgeColor),
            ),
          ],
        );
      },
    );
  }
}

class _WebVideoThumb extends StatefulWidget {
  const _WebVideoThumb({
    required this.path,
    required this.badgeColor,
    required this.badgeSize,
  });

  final String path;
  final Color badgeColor;
  final double badgeSize;

  @override
  State<_WebVideoThumb> createState() => _WebVideoThumbState();
}

class _WebVideoThumbState extends State<_WebVideoThumb> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final controller = await StarMediaStorage.video(widget.path);
    if (controller == null) return;
    try {
      await controller.initialize();
      await controller.seekTo(Duration.zero);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.night),
        if (controller != null)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ColoredBox(color: colors.night.withValues(alpha: 0.6)),
        Center(
          child: PlayBadge(size: widget.badgeSize, color: widget.badgeColor),
        ),
      ],
    );
  }
}

/// Small square tile for a photo or video extra — a photo shows its image,
/// a video shows its first frame under a play glyph.
class StarMediaTile extends StatelessWidget {
  const StarMediaTile({
    super.key,
    required this.media,
    this.size = 72,
    this.height,
    this.badgeColor = Colors.white,
    this.badgeSize = kPlayBadgeSize,
  });

  final StarMedia media;
  final double size;

  /// Defaults to [size] (a square); set for a non-square tile.
  final double? height;
  final Color badgeColor;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusField),
      child: SizedBox(
        width: size,
        height: height ?? size,
        child: media.kind == StarMediaKind.photo
            ? StarMediaImage(
                path: media.path!,
                width: size,
                height: height ?? size,
              )
            : StarVideoThumb(
                path: media.path!,
                badgeColor: badgeColor,
                badgeSize: badgeSize,
              ),
      ),
    );
  }
}

/// Full-screen swipeable viewer over a victory's photo and video extras.
Future<void> showStarMediaViewer(
  BuildContext context,
  List<StarMedia> visuals,
  int initialIndex,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _StarMediaViewer(visuals: visuals, initial: initialIndex),
    ),
  );
}

class _StarMediaViewer extends StatefulWidget {
  const _StarMediaViewer({required this.visuals, required this.initial});

  final List<StarMedia> visuals;
  final int initial;

  @override
  State<_StarMediaViewer> createState() => _StarMediaViewerState();
}

class _StarMediaViewerState extends State<_StarMediaViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.visuals.length,
        itemBuilder: (context, index) {
          final item = widget.visuals[index];
          return item.kind == StarMediaKind.video
              ? _VideoPage(media: item)
              : InteractiveViewer(
                  child: Center(
                    child: StarMediaImage(
                      path: item.path!,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
        },
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.media});

  final StarMedia media;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final controller = await StarMediaStorage.video(widget.media.path!);
      if (controller == null) throw StateError('missing video');
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) {
      return Center(
        child: Text(
          context.strings.mediaError,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        controller.value.isPlaying ? controller.pause() : controller.play();
      }),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          if (!controller.value.isPlaying)
            const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white70,
              size: 72,
            ),
        ],
      ),
    );
  }
}

/// The reader's "Memories" block, everything centered and stacked one thing
/// under the next: all photos and videos together as one mosaic (the
/// moodboard's layout), then voice notes, then links. Shows nothing
/// when the victory has no extras.
class StarMediaSection extends StatelessWidget {
  const StarMediaSection({super.key, required this.media});

  final List<StarMedia> media;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty || !StarMediaStorage.isSupported) {
      return const SizedBox.shrink();
    }
    List<StarMedia> of(StarMediaKind kind) =>
        media.where((m) => m.kind == kind).toList();
    final voices = of(StarMediaKind.voice);
    final visuals = media
        .where(
          (m) => m.kind == StarMediaKind.photo || m.kind == StarMediaKind.video,
        )
        .toList();
    final links = of(StarMediaKind.link);

    final blocks = <Widget>[
      if (visuals.isNotEmpty)
        FractionallySizedBox(
          widthFactor: _kMosaicWidthFactor,
          child: StarMediaMosaic(visuals: visuals),
        ),
      for (final voice in voices)
        FractionallySizedBox(
          widthFactor: _kVoiceCardWidthFactor,
          child: VoiceNotePlayer(key: ValueKey(voice.id), media: voice),
        ),
      if (links.isNotEmpty)
        FractionallySizedBox(
          widthFactor: _kMosaicWidthFactor,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final link in links)
                StarLinkRow(key: ValueKey(link.id), media: link),
            ],
          ),
        ),
    ];
    // Opaque and tap-absorbing: the reader treats a tap on the page as
    // "show only the photo", and a tap that lands on the padding around a
    // player or tile must not trigger that.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: kReaderBlockGap),
            blocks[i],
          ],
        ],
      ),
    );
  }
}

/// The secondary photos and videos of a victory as one group, laid out like
/// the moodboard: a big tile beside two stacked ones, flipping sides every
/// three. Tapping a tile opens the full-screen viewer at it.
class StarMediaMosaic extends StatelessWidget {
  const StarMediaMosaic({super.key, required this.visuals});

  final List<StarMedia> visuals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget tile(int index) => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: colors.nightPanel,
        child: InkWell(
          onTap: () => showStarMediaViewer(context, visuals, index),
          child: SizedBox.expand(child: _MosaicContent(media: visuals[index])),
        ),
      ),
    );
    // Heights are tuned for the full 420 px column; the mosaic is narrower,
    // so they shrink by the same factor.
    const scale = _kMosaicWidthFactor;
    if (visuals.length == 1) {
      return SizedBox(height: 220 * scale, child: tile(0));
    }
    return Column(
      children: [
        for (var i = 0; i < visuals.length; i += 3)
          Padding(
            padding: EdgeInsets.only(bottom: i + 3 < visuals.length ? 10 : 0),
            child: SizedBox(
              height: (visuals.length - i == 2 ? 160 : 220) * scale,
              child: Row(
                textDirection: (i ~/ 3).isEven
                    ? TextDirection.ltr
                    : TextDirection.rtl,
                children: [
                  if (visuals.length - i == 2) ...[
                    Expanded(child: tile(i)),
                    const SizedBox(width: 10),
                    Expanded(child: tile(i + 1)),
                  ] else ...[
                    Expanded(flex: 3, child: tile(i)),
                    if (i + 1 < visuals.length) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Expanded(child: tile(i + 1)),
                            if (i + 2 < visuals.length) ...[
                              const SizedBox(height: 10),
                              Expanded(child: tile(i + 2)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MosaicContent extends StatelessWidget {
  const _MosaicContent({required this.media});

  final StarMedia media;

  @override
  Widget build(BuildContext context) {
    if (media.kind == StarMediaKind.photo) {
      return StarMediaImage(path: media.path!);
    }
    return StarVideoThumb(path: media.path!);
  }
}

/// A link as a small pill, as wide as what it says and no wider: a thin white
/// outline, the site (or the label the user gave it) and an arrow out. Its
/// shape is what tells it apart from the wide voice-note card.
class StarLinkRow extends StatelessWidget {
  const StarLinkRow({super.key, required this.media});

  final StarMedia media;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openExtraLink(context, media),
        customBorder: const StadiumBorder(),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: ShapeDecoration(
            color: colors.night.withValues(alpha: 0.4),
            shape: StadiumBorder(
              side: const BorderSide(color: Colors.white, width: 1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  linkPillText(media),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.arrow_outward_rounded,
                color: Colors.white,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a link extra in the browser, or says it could not be opened.
Future<void> openExtraLink(BuildContext context, StarMedia link) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = context.strings.linkOpenError;
  final uri = parseExtraLink(link.url ?? '');
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(message)));
}

/// What a link pill says: its label if it has one, else just the site
/// (`example.com`, no scheme or `www.`).
String linkPillText(StarMedia link) {
  final label = link.label?.trim();
  if (label != null && label.isNotEmpty) return label;
  final host = Uri.tryParse(link.url ?? '')?.host ?? '';
  final bare = host.startsWith('www.') ? host.substring(4) : host;
  return bare.isEmpty ? (link.url ?? '') : bare;
}

/// What to show for a link row: its label if it has one, else the address.
String linkDisplayText(StarMedia link) {
  final label = link.label?.trim();
  return (label == null || label.isEmpty) ? (link.url ?? '') : label;
}
