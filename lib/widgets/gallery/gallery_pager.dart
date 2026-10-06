import 'package:flutter/material.dart';

import '../../l10n/strings_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_style.dart';
import '../responsive_content.dart';
import 'gallery_cards.dart';

/// The Gallery's one-at-a-time view for areas and constellations: swipe
/// through the same tiles the grid shows, each as a big page, with an
/// "Open" button for the real detail screen. (Stars use `StarReaderScreen`
/// instead.) Popping returns to the grid.
///
/// [onOpen] opens page [index]'s detail screen and returns whatever that
/// screen asked to fly to (or null) — a non-null result closes this pager
/// and is handed on to whoever pushed it.
class GalleryPager<T> extends StatefulWidget {
  const GalleryPager({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.tileBuilder,
    required this.onOpen,
  });

  final List<T> items;
  final int initialIndex;
  final Widget Function(T item) tileBuilder;
  final Future<Object?> Function(int index) onOpen;

  @override
  State<GalleryPager<T>> createState() => _GalleryPagerState<T>();
}

class _GalleryPagerState<T> extends State<GalleryPager<T>> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
    viewportFraction: 0.86,
  );
  late int _index = widget.initialIndex;
  bool _opening = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    final result = await widget.onOpen(_index);
    _opening = false;
    if (result != null && mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: ResponsiveContent(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.text),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        '${_index + 1} / ${widget.items.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.muted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.items.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: kGalleryTileAspectRatio,
                        child: widget.tileBuilder(widget.items[i]),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: ElevatedButton(
                  onPressed: _open,
                  child: AppButtonLabel(strings.searchCardOpenAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
