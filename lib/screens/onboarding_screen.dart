import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_content.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/star_glyph.dart';

/// One page's fixed content — its picture, title, and body. Built fresh in
/// [build] (not cached) since it reads localized strings off [AppStrings].
///
/// A page shows either a plain [icon] or, for the pages that introduce a
/// kind of star, the very [kind] itself as the sky draws it (see
/// [StarGlyph]) — so the tutorial teaches the actual thing the user will
/// be looking at, not a stand-in for it.
class _OnboardingPage {
  const _OnboardingPage({this.icon, this.kind, required this.title, required this.body})
    : assert(
        icon != null || kind != null,
        'A page needs something to show: an icon or a star kind.',
      );

  final IconData? icon;
  final StarKind? kind;
  final String title;
  final String body;
}

/// The first-launch "stories" tutorial walking through how the app's
/// astronomy metaphor fits together — nascent/lit/pulsar/unlit stars,
/// constellations (life projects), and supernovas (life areas). The short
/// version of `MetaphorScreen`, which is the same thing in full and stays
/// available any time. Shown once automatically (see `OnboardingPrefs`,
/// checked in `main.dart`), and replayable from Settings' debug tools.
///
/// Tap the left/right half of a page (or swipe, since it's a plain
/// [PageView] under the hood) to move between pages; the bottom button does
/// the same, ending in "Get started" on the last page. The close button in
/// the corner skips straight out. Either way, popping this screen is the
/// only signal `main.dart` needs to mark onboarding as seen — there's no
/// separate "did they finish" state to track.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_OnboardingPage> _pages(AppStrings strings) => [
    _OnboardingPage(
      icon: Icons.nights_stay,
      title: strings.onboardingIntroTitle,
      body: strings.onboardingIntroBody,
    ),
    // Smallest to largest, and within the star pages past → present →
    // future, matching the order the star form's own kind switch uses.
    _OnboardingPage(
      kind: StarKind.nascent,
      title: strings.onboardingNascentTitle,
      body: strings.onboardingNascentBody,
    ),
    _OnboardingPage(
      kind: StarKind.lit,
      title: strings.onboardingLitTitle,
      body: strings.onboardingLitBody,
    ),
    _OnboardingPage(
      kind: StarKind.pulsar,
      title: strings.onboardingPulsarTitle,
      body: strings.onboardingPulsarBody,
    ),
    _OnboardingPage(
      kind: StarKind.unlit,
      title: strings.onboardingUnlitTitle,
      body: strings.onboardingUnlitBody,
    ),
    _OnboardingPage(
      icon: Icons.insights,
      title: strings.onboardingConstellationsTitle,
      body: strings.onboardingConstellationsBody,
    ),
    _OnboardingPage(
      icon: Icons.flare,
      title: strings.onboardingAreasTitle,
      body: strings.onboardingAreasBody,
    ),
    _OnboardingPage(
      icon: Icons.rocket_launch,
      title: strings.onboardingOutroTitle,
      body: strings.onboardingOutroBody,
    ),
  ];

  void _next(int pageCount) {
    if (_index >= pageCount - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _previous() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final pages = _pages(strings);

    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: ResponsiveContent(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    for (var i = 0; i < pages.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      // The page indicator segments slide in left to right.
                      Expanded(
                        child: StaggeredEntrance(
                          index: i,
                          axis: Axis.horizontal,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: i <= _index
                                  ? colors.gold
                                  : colors.nightBorder,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  StaggeredEntrance(
                    index: 1,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: strings.onboardingSkipTooltip,
                      icon: Icon(Icons.close, color: colors.muted),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) {
                    final width = MediaQuery.sizeOf(context).width;
                    if (details.globalPosition.dx < width / 2) {
                      _previous();
                    } else {
                      _next(pages.length);
                    }
                  },
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) =>
                        _OnboardingPageBody(page: pages[i]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: StaggeredEntrance(
                    index: 3,
                    child: ElevatedButton(
                      onPressed: () => _next(pages.length),
                      child: Text(
                        _index == pages.length - 1
                            ? strings.onboardingGetStartedAction
                            : strings.onboardingNextAction,
                      ),
                    ),
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

class _OnboardingPageBody extends StatelessWidget {
  const _OnboardingPageBody({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: page.kind != null
                    ? StarGlyph(kind: page.kind!, size: 44)
                    : Icon(page.icon, color: colors.gold, size: 44),
              ),
            ),
            const SizedBox(height: 28),
            StaggeredEntrance(
              index: 1,
              child: Text(
                page.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ),
            const SizedBox(height: 14),
            StaggeredEntrance(
              index: 2,
              child: Text(
                page.body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: colors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
