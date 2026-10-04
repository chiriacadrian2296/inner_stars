import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../widgets/share_arrangement.dart';

Future<void> showSharePreview({
  required BuildContext context,
  required Widget content,
  required String shareText,
  required String fileName,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SharePreviewScreen(
        content: content,
        shareText: shareText,
        fileName: fileName,
      ),
    ),
  );
}

/// Lets the user inspect and style the image before opening the platform
/// share sheet. The same three arrangements wrap every shareable subject, so
/// stars, goals, pulsars and constellations all have the same interaction.
class SharePreviewScreen extends StatefulWidget {
  const SharePreviewScreen({
    super.key,
    required this.content,
    required this.shareText,
    required this.fileName,
  });

  final Widget content;
  final String shareText;
  final String fileName;

  @override
  State<SharePreviewScreen> createState() => _SharePreviewScreenState();
}

class _SharePreviewScreenState extends State<SharePreviewScreen> {
  final _captureKey = GlobalKey();
  ShareArrangement _arrangement = ShareArrangement.editorial;
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Share preview is not ready');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not encode share preview');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes.buffer.asUint8List(),
              mimeType: 'image/png',
              name: widget.fileName,
            ),
          ],
          text: widget.shareText,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.shareContentError)),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    final labels = [
      strings.shareLayoutImmersive,
      strings.shareLayoutFramed,
      strings.shareLayoutPostcard,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.sharePreviewTitle),
        leading: IconButton(
          tooltip: strings.cancel,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: ShareArrangementScope(
                        arrangement: _arrangement,
                        child: widget.content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.shareChooseLayout,
                  style: TextStyle(color: colors.muted, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<ShareArrangement>(
                showSelectedIcon: false,
                segments: [
                  for (var i = 0; i < ShareArrangement.values.length; i++)
                    ButtonSegment(
                      value: ShareArrangement.values[i],
                      label: Text(labels[i]),
                    ),
                ],
                selected: {_arrangement},
                onSelectionChanged: (selection) =>
                    setState(() => _arrangement = selection.single),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _sharing ? null : _share,
                  icon: _sharing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_outlined),
                  label: AppButtonLabel(strings.shareNowAction),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
