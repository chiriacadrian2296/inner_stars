import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../widgets/share_arrangement.dart';
import '../utils/share_content_from_card.dart';
import 'share_composer_screen.dart';

Future<void> showSharePreview({
  required BuildContext context,
  required Widget content,
  required String shareText,
  required String fileName,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ShareComposerScreen(
        data: shareContentFromCard(context, content),
        shareText: shareText,
        fileName: fileName,
      ),
    ),
  );
}

/// Production version of the share lab: the user sees the real card, can move
/// through three genuinely different compositions, and only then opens the
/// platform share sheet.
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: strings.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      strings.sharePreviewTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _CompositionPicker(
                labels: labels,
                selected: _arrangement.index,
                onChanged: (index) => setState(
                  () => _arrangement = ShareArrangement.values[index],
                ),
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

/// The compact stepper comes from the share lab. It keeps the control narrow
/// on phones while the centre opens the complete list of compositions.
class _CompositionPicker extends StatelessWidget {
  const _CompositionPicker({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  void _step(int delta) =>
      onChanged((selected + delta + labels.length) % labels.length);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Container(
        width: 248,
        height: 46,
        decoration: BoxDecoration(
          color: colors.nightPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.nightBorder),
        ),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('share-composition-prev'),
              tooltip: context.strings.sharePreviousLayout,
              onPressed: () => _step(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: PopupMenuButton<int>(
                key: const ValueKey('share-composition-menu'),
                initialValue: selected,
                tooltip: context.strings.shareChooseLayout,
                onSelected: onChanged,
                color: colors.nightPanel,
                position: PopupMenuPosition.under,
                itemBuilder: (_) => [
                  for (var i = 0; i < labels.length; i++)
                    PopupMenuItem(value: i, child: Text(labels[i])),
                ],
                child: Center(
                  child: Text(
                    labels[selected],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('share-composition-next'),
              tooltip: context.strings.shareNextLayout,
              onPressed: () => _step(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
