import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../theme/nightlight_style.dart';
import '../widgets/nightlight_starfield.dart';
import '../widgets/responsive_content.dart';
import 'nightlight_breathing_screen.dart';

/// [_SchemeStep]'s icon circle diameter — icon (26) + its padding (14 each
/// side) + its border (2 × [kBorderWidthActive]) — shared with
/// [_SchemeArrow] so the arrow can be centered against exactly that height
/// rather than a hand-tuned padding guess.
const double _kSchemeCircleSize = 58;

/// Every [_SchemeStep]'s own fixed width — wide enough for the longest of
/// the three labels ("See Clearly") at one line. Fixed rather than
/// [Flexible] (an earlier pass): a [Flexible] step sizes to its own
/// label's width, and since a plain [Column] centers its children, a wider
/// label centers the (narrower) circle within that extra width too —
/// pushing the circle itself away from the arrows on either side of the
/// step unevenly. A shared fixed width keeps every circle, and so every
/// arrow, the same distance apart regardless of label length.
const double _kSchemeStepWidth = 84;

/// Parses `*word*`-marked [text] into spans — bold inside the asterisks,
/// [baseStyle] outside them — so a paragraph can mark as many of its own
/// words bold as it needs to, in whatever spots make sense for its own
/// sentence, rather than being limited to one fixed bold phrase.
List<InlineSpan> parseBoldMarkup(String text, TextStyle baseStyle) {
  final pattern = RegExp(r'\*(.+?)\*');
  final spans = <InlineSpan>[];
  var lastEnd = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }
  return spans;
}

/// The second screen of the Nightlight "in crisis" path — reached from
/// [NightlightGateScreen], leads into [NightlightBreathingScreen]. Explains
/// *why* the breathing exercise comes before the victories: an agitated
/// mind finds plausible-sounding reasons to dismiss good news, so it needs
/// to settle first or looking at those victories risks doing nothing (or
/// worse, backfiring).
///
/// Led by a title and a quick 3-step icon scheme (agitated -> breathe ->
/// see clearly) that makes the same point at a glance, for anyone too
/// keyed-up right now to want to read three paragraphs before they can
/// move on — the text underneath is still there for whoever does.
class NightlightExplainedScreen extends StatelessWidget {
  const NightlightExplainedScreen({
    super.key,
    required this.starRepository,
    required this.projectRepository,
    required this.starsShapeRepository,
  });

  final StarRepository starRepository;
  final ProjectRepository projectRepository;
  final StarsShapeRepository starsShapeRepository;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final bodyStyle = TextStyle(fontSize: 17, height: 1.6, color: colors.text);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: colors.nightlightGradient),
        child: Stack(
          children: [
            // Kept clear of the title, the icon scheme, and each paragraph
            // individually — see [NightlightStarfield.exclusionZones] —
            // rather than one solid block over the whole text section:
            // the gaps between paragraphs (and around the title/icons) are
            // deliberately left open, so a star can still show up between
            // lines of content, just never directly behind the content
            // itself. Estimated against this screen's own compact,
            // top-packed layout below (fixed gaps, not stretched to fill
            // the screen) — recalibrate here if that layout changes.
            Positioned.fill(
              child: NightlightStarfield(
                exclusionZones: [
                  const Rect.fromLTWH(0.25, 0.10, 0.5, 0.06), // title
                  const Rect.fromLTWH(0.15, 0.19, 0.7, 0.12), // icon scheme
                  const Rect.fromLTWH(0.1, 0.35, 0.8, 0.07), // paragraph 1
                  const Rect.fromLTWH(0.1, 0.44, 0.8, 0.08), // paragraph 2
                  const Rect.fromLTWH(0.1, 0.54, 0.8, 0.07), // paragraph 3
                ],
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  ResponsiveContent(
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () =>
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ResponsiveContent(
                        // The screen's 3 sections — title, the quick
                        // icon-scheme explanation, the fuller text
                        // explanation — kept the same fixed distance apart
                        // (32 each) and sized to their own natural content
                        // height, rather than stretched to fill whatever
                        // vertical space happens to be available: that
                        // left visibly odd empty space around the short
                        // title in particular, and forced scrolling that a
                        // compact, top-packed layout doesn't need. The
                        // [Expanded] above is still what pins the "Continue"
                        // button below to the actual bottom of the screen
                        // even when this content is short enough to leave
                        // room to spare.
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 32,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                strings.nightlightExplainedTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 32),
                              const _ExplainedScheme(),
                              const SizedBox(height: 32),
                              _ExplainedParagraph(
                                text: strings.nightlightExplainedBodyPart1,
                                style: bodyStyle,
                              ),
                              const SizedBox(height: 18),
                              _ExplainedParagraph(
                                text: strings.nightlightExplainedBodyPart2,
                                style: bodyStyle,
                              ),
                              const SizedBox(height: 18),
                              _ExplainedParagraph(
                                text: strings.nightlightExplainedBodyPart3,
                                style: bodyStyle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  ResponsiveContent(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                      child: ElevatedButton(
                        style: nightlightButtonStyle(colors),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NightlightBreathingScreen(
                              starRepository: starRepository,
                              projectRepository: projectRepository,
                              starsShapeRepository: starsShapeRepository,
                            ),
                          ),
                        ),
                        child: Text(strings.nightlightExplainedContinue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One paragraph, its own `*word*`-marked spans bold — see
/// [parseBoldMarkup] — so each paragraph can put its emphasis wherever its
/// own sentence needs it, rather than being limited to one fixed phrase.
class _ExplainedParagraph extends StatelessWidget {
  const _ExplainedParagraph({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(style: style, children: parseBoldMarkup(text, style)),
      textAlign: TextAlign.center,
    );
  }
}

/// The quick "agitated -> breathe -> see clearly" scheme above the
/// explanation text — three white-on-navy icon circles (the section's own
/// look, see `nightlight_style.dart`) joined by plain arrows.
class _ExplainedScheme extends StatelessWidget {
  const _ExplainedScheme();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SchemeStep(
          icon: Icons.mood_bad,
          label: strings.nightlightExplainedSchemeAgitated,
        ),
        const _SchemeArrow(),
        _SchemeStep(
          icon: Icons.air,
          label: strings.nightlightExplainedSchemeBreathe,
        ),
        const _SchemeArrow(),
        _SchemeStep(
          icon: Icons.auto_awesome,
          label: strings.nightlightExplainedSchemeClarity,
        ),
      ],
    );
  }
}

class _SchemeStep extends StatelessWidget {
  const _SchemeStep({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kSchemeStepWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: Colors.white,
                width: kBorderWidthActive,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchemeArrow extends StatelessWidget {
  const _SchemeArrow();

  @override
  Widget build(BuildContext context) {
    // Boxed to exactly [_kSchemeCircleSize] and centered inside it, rather
    // than a hand-picked top padding — the [Row] above starts every child
    // (including this one) at the same y, so matching the circle's own
    // height here is what actually centers the arrow against it,
    // regardless of the label text sitting below either one.
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        height: _kSchemeCircleSize,
        child: Center(
          child: Icon(Icons.arrow_forward, color: Colors.white70, size: 18),
        ),
      ),
    );
  }
}
