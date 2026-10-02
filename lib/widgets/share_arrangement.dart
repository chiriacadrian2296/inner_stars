import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

enum ShareArrangement { editorial, photographic, statement }

class ShareArrangementScope extends InheritedWidget {
  const ShareArrangementScope({
    super.key,
    required this.arrangement,
    required super.child,
  });

  final ShareArrangement arrangement;

  static ShareArrangement of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ShareArrangementScope>()
          ?.arrangement ??
      ShareArrangement.editorial;

  @override
  bool updateShouldNotify(ShareArrangementScope oldWidget) =>
      arrangement != oldWidget.arrangement;
}

/// Three genuinely different information hierarchies for shareable stories.
/// Domain cards provide the data; this widget decides where that data lives.
class ShareableStoryLayout extends StatelessWidget {
  const ShareableStoryLayout({
    super.key,
    required this.title,
    required this.hero,
    this.background,
    this.meta,
    this.context,
    this.description,
    this.footer,
  });

  final String title;
  final Widget hero;
  final Widget? background;
  final String? meta;
  final Widget? context;
  final String? description;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return switch (ShareArrangementScope.of(context)) {
      ShareArrangement.editorial => _editorial(context),
      ShareArrangement.photographic => _photographic(context),
      ShareArrangement.statement => _statement(context),
    };
  }

  Widget _backdrop(BuildContext context, {required Widget child}) {
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.night),
        ?background,
        if (background != null)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.night.withValues(alpha: 0.25),
                  colors.night.withValues(alpha: 0.45),
                  colors.night.withValues(alpha: 0.96),
                ],
                stops: const [0, 0.48, 1],
              ),
            ),
          ),
        child,
      ],
    );
  }

  Widget _brand(
    BuildContext context, {
    Alignment alignment = Alignment.center,
  }) {
    return Align(
      alignment: alignment,
      child: Text(
        'VICTORY STARS',
        style: TextStyle(
          color: context.colors.gold,
          fontFamily: kFontMono,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.2,
        ),
      ),
    );
  }

  Widget _editorial(BuildContext context) {
    final colors = context.colors;
    return _backdrop(
      context,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
          child: Column(
            children: [
              _brand(context),
              const Spacer(),
              hero,
              if (meta != null) ...[
                const SizedBox(height: 22),
                Text(
                  meta!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.muted,
                    fontFamily: kFontMono,
                    fontSize: 13,
                  ),
                ),
              ],
              if (this.context != null) ...[
                const SizedBox(height: 14),
                this.context!,
              ],
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.text,
                  fontFamily: kFontStarTitle,
                  fontSize: 32,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 16),
                Text(
                  description!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
              ],
              if (footer != null) ...[const SizedBox(height: 22), footer!],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photographic(BuildContext context) {
    final colors = context.colors;
    return _backdrop(
      context,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _brand(context, alignment: Alignment.centerLeft),
                  ),
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: FittedBox(child: hero),
                  ),
                ],
              ),
              const Spacer(),
              if (this.context != null) this.context!,
              if (this.context != null) const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontFamily: kFontStarTitle,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  height: 1.08,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 12),
                Text(
                  description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text.withValues(alpha: 0.82),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  if (meta != null)
                    Expanded(
                      child: Text(
                        meta!,
                        style: TextStyle(
                          color: colors.muted,
                          fontFamily: kFontMono,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ?footer,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statement(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.night,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: FittedBox(child: hero),
                  ),
                  const Spacer(),
                  _brand(context, alignment: Alignment.centerRight),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontFamily: kFontStarTitle,
                  fontSize: 36,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  height: 1.08,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 14),
                Text(
                  description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              const Spacer(),
              Container(height: 1, color: colors.gold.withValues(alpha: 0.55)),
              const SizedBox(height: 14),
              if (this.context != null) this.context!,
              if (meta != null) ...[
                const SizedBox(height: 8),
                Text(
                  meta!,
                  style: TextStyle(
                    color: colors.muted,
                    fontFamily: kFontMono,
                    fontSize: 12,
                  ),
                ),
              ],
              if (footer != null) ...[const SizedBox(height: 10), footer!],
            ],
          ),
        ),
      ),
    );
  }
}
