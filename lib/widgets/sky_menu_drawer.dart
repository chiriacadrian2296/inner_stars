import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';
import '../tutorials/tour_intro_target.dart';
import '../tutorials/tour_step_card.dart';
import '../utils/app_modals.dart';
import 'staggered_entrance.dart';

/// Parks the menu's "Metaphor" entry (the full-length explainer screen),
/// superseded by `hint_kit`-driven live tutorials — see the TRB entry for
/// this and `main.dart`'s own `_kShowOnboarding`. The entry, its callback,
/// and `MetaphorScreen` itself are all left wired up, just not drawn: flip
/// this back on to restore it exactly as it was.
const _kShowMetaphorMenuEntry = false;

/// The Sky's side menu — the app's only navigation. There's exactly one
/// screen now (the Sky itself); everything else opens from here as a page
/// on top of it, so the sky is never something you have to come *back* to.
///
/// A thin [Drawer] wrapper around [SkyMenuContent] in its default, compact
/// mode — split apart so the exact same content can also open as a modal
/// sheet (see `SkyScreen`'s own star-FAB, an alternative entry point being
/// tried alongside this one) in its bigger, more detailed mode, without
/// duplicating a single entry.
class SkyMenuDrawer extends StatelessWidget {
  const SkyMenuDrawer({
    super.key,
    required this.onLightAStar,
    required this.onNewConstellation,
    required this.onVisions,
    required this.onShootingStars,
    required this.onNightlight,
    required this.onSearch,
    required this.onStatistics,
    required this.onFriends,
    required this.onMetaphor,
    required this.onSettings,
  });

  final VoidCallback onLightAStar;
  final VoidCallback onNewConstellation;
  final VoidCallback onVisions;
  final VoidCallback onShootingStars;
  final VoidCallback onNightlight;
  final VoidCallback onSearch;
  final VoidCallback onStatistics;
  final VoidCallback onFriends;
  final VoidCallback onMetaphor;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: SkyMenuContent(
          onLightAStar: onLightAStar,
          onNewConstellation: onNewConstellation,
          onVisions: onVisions,
          onShootingStars: onShootingStars,
          onNightlight: onNightlight,
          onSearch: onSearch,
          onStatistics: onStatistics,
          onFriends: onFriends,
          onMetaphor: onMetaphor,
          onSettings: onSettings,
        ),
      ),
    );
  }
}

/// The menu's actual content: the logo/tagline header, then every entry,
/// grouped into sections. Used two ways — inside [SkyMenuDrawer]'s
/// [Drawer] (unbounded height, scrolls the whole thing if it ever needs
/// to) and inside a [showModalBottomSheet] (bounded height, passed in by
/// the caller) — so this widget itself makes no assumption about which;
/// it just fills whatever height it's given, scrollable list on top,
/// Settings pinned below.
///
/// [detailed] (off by default, so the drawer stays exactly as tuned) is
/// the modal's own look: a bigger header, section titles brought back
/// (centered, under the now-bigger header — [detailed] centers this
/// whole thing more deliberately than the compact mode ever tried to),
/// and a one-line caption under every entry. The compact mode (the
/// drawer) skips all of that — with 6 sections and up to 3 entries each,
/// section labels alone cost it its "everything visible without
/// scrolling" fit on a typical phone, which mattered there and doesn't
/// in a scrollable modal.
///
/// Every entry reads the same way — a gold icon beside white text. There's
/// no second, dimmer tier any more: a muted vs. bright split within
/// entries. (Emoji leads were tried for the two "make something" entries,
/// but an emoji glyph carries its own baked-in color that can't be
/// retinted to the app's exact gold — next to a true gold [Icon] it read
/// as a mismatched, slightly-off yellow rather than the same color, so
/// every entry uses a plain [Icon] now.)
///
/// What each group is:
/// - **Search** — [onSearch] alone, first: the fastest way off "wander and
///   hope" navigation deserves to be found before anything else, not
///   buried alongside the statistics page it used to share a section with.
/// - **Activity** — the things you *make*: [onLightAStar]/[onNewConstellation]/
///   [onVisions] all sit behind one entry ("Light Your Sky") that opens a
///   small chooser mirroring the sky's own three levels (Supernovas/
///   Constellations/Stars) rather than claiming three rows of their own,
///   and [onShootingStars] — sketched in ahead of the feature existing.
/// - **Nightlight** — [onNightlight] ("Find Your Light"), right under
///   Activity: what it's *for* (a place to go when things are hard, reached
///   in as few taps as making something) matters more here than it being
///   its own category.
/// - **Data** — [onStatistics], a way of *looking back*.
/// - **Social** — [onFriends], sketched in the same way as Shooting Stars.
/// - **Info** — just the metaphor guide. Onboarding replay moved back to
///   Settings' debug tools (a dev aid, not something worth its own
///   first-class entry); the app's own about card lives there too — it's
///   a fact about the app, not a place to go.
/// - **Settings** — its own section like every other, last: the page
///   behind it has its own sections in turn.
class SkyMenuContent extends StatelessWidget {
  const SkyMenuContent({
    super.key,
    required this.onLightAStar,
    required this.onNewConstellation,
    required this.onVisions,
    required this.onShootingStars,
    required this.onNightlight,
    required this.onSearch,
    required this.onStatistics,
    required this.onFriends,
    required this.onMetaphor,
    required this.onSettings,
    this.detailed = false,
    this.scrollController,
    this.physics,
  });

  final VoidCallback onLightAStar;
  final VoidCallback onNewConstellation;
  final VoidCallback onVisions;
  final VoidCallback onShootingStars;
  final VoidCallback onNightlight;
  final VoidCallback onSearch;
  final VoidCallback onStatistics;
  final VoidCallback onFriends;
  final VoidCallback onMetaphor;
  final VoidCallback onSettings;

  /// See the class doc comment — off for the drawer, on for the modal.
  final bool detailed;

  /// [SkyMenuModalFrame] needs to be able to read this list's own
  /// scroll position (to know whether it's at its own top) — null (the
  /// default) lets the list use its own implicit controller instead,
  /// same as before.
  final ScrollController? scrollController;

  /// [SkyMenuModalFrame] locks this list's own scrolling for the
  /// duration of a pull-to-dismiss over its content, so its own
  /// Scrollable never moves in parallel with the frame the pull is
  /// actually meant to move — null (the default) lets the list use its
  /// own default physics.
  final ScrollPhysics? physics;

  // The same disc icon already used as the phone's app icon (the ring +
  // star mark, pre-composited over the app's night background).
  static const _logoAsset = 'assets/icon/app_icon_ring_centered.png';

  /// "Light Your Sky" covers both of the app's two creation flows, so
  /// tapping it offers the choice rather than picking one — a small sheet
  /// in the same [colors.nightPanel]/gold language as every other sheet in
  /// the app, not a full screen of its own.
  void _openLightYourSkyChooser(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    // Fired here, not inside the dialog's own builder — by the time
    // `showDialog` schedules that builder's first frame, this call has
    // already reached `Tour.start`'s async storage check, so the "waits
    // for its target" behavior (see `HintTarget`'s own doc comment) is
    // what actually bridges the two rather than any ordering guarantee.
    Tour.read(context).start('light-your-sky');

    showAppDialog<void>(
      context: context,
      builder: (dialogContext) {
        Widget choice({
          required IconData icon,
          required String label,
          required VoidCallback onTap,
          required int index,
          int? tourOrder,
          String? tourTitle,
          String? tourBody,
        }) {
          final inkTile = InkWell(
            onTap: () {
              Navigator.of(dialogContext).pop();
              onTap();
            },
            // No ripple/highlight on these — Android's default press
            // feedback is a light flash, which reads as a stray white
            // flicker against this dark popup rather than a deliberate
            // part of its look.
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            child: Padding(
              // Horizontal is wider than these labels strictly need —
              // deliberately: with the popup's own width coming straight
              // from this padding (see the comment below), this is what
              // actually keeps it from reading as *too* tightly
              // shrink-wrapped now that [Dialog]'s own 280 default
              // minWidth is off.
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              // The Row default (fills whatever width it's given), not
              // `mainAxisSize.min` — every row is now stretched to the
              // width of the widest one by the `IntrinsicWidth` +
              // `CrossAxisAlignment.stretch` wrapping all three below, so
              // each row's own natural width no longer matters here; this
              // just lets it actually fill that shared width instead of
              // shrinking back to its own label's size inside it.
              child: Row(
                children: [
                  Icon(icon, color: colors.gold),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
          final tile = StaggeredEntrance(index: index, child: inkTile);
          if (tourOrder == null) return tile;
          return HintTarget(
            tour: 'light-your-sky',
            order: tourOrder,
            showArrow: true,
            contentBuilder: appTourStepCard,
            title: tourTitle,
            description: tourBody,
            child: tile,
          );
        }

        // A popup rather than a sheet, per request — [Dialog] alone (not
        // [AlertDialog]) since the content here is a plain list of
        // choices, not a title/actions layout; it still picks up the
        // app's own dialog theme (background, shape) automatically. No
        // title any more — the three choices, one per level of the sky
        // itself, don't need one to make sense — and Cancel sits right
        // below them, no divider: the muted color and plain-text
        // [TextButton] treatment (versus the icon+label choices above
        // it) already read as "the way out", not a fourth choice.
        return Dialog(
          // [Dialog]'s own default constraints impose a 280 minWidth
          // regardless of content — wider than these three short
          // options actually need, which is exactly why this kept
          // looking too wide no matter how tightly the content itself
          // was sized. An empty [BoxConstraints] (no minimum at all)
          // is what actually lets it shrink to fit.
          constraints: const BoxConstraints(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                TourIntroTarget(
                  tour: 'light-your-sky',
                  order: 1,
                  title: strings.lightYourSkyTourIntroTitle,
                  description: strings.lightYourSkyTourIntroBody,
                ),
                // `IntrinsicWidth` measures the widest of the three rows,
                // then `CrossAxisAlignment.stretch` makes every row that
                // same width — different from just centering them, which
                // would leave the shorter labels' *tap targets* narrower
                // than the widest one even if the text looked aligned.
                // Plain `CrossAxisAlignment.stretch` alone (no
                // `IntrinsicWidth`) would instead stretch every row to
                // whatever width the dialog's parent offers — up to
                // nearly full-screen — which is exactly what [Dialog]'s
                // own unbounded `constraints` below was chosen to avoid.
                // Scoped to just these three (a nested widget) rather
                // than the whole dialog, so Cancel below stays centered
                // on its own — it isn't one of the icon+label choices
                // this is about.
                IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      choice(
                        icon: Icons.flare,
                        label: strings.lightYourSkyChooserSupernovaOption,
                        onTap: onVisions,
                        index: 0,
                        tourOrder: 2,
                        tourTitle: strings.lightYourSkyTourSupernovaTitle,
                        tourBody: strings.lightYourSkyTourSupernovaBody,
                      ),
                      choice(
                        icon: Icons.auto_awesome,
                        label: strings.menuNewConstellation,
                        onTap: onNewConstellation,
                        index: 1,
                        tourOrder: 3,
                        tourTitle: strings.lightYourSkyTourConstellationTitle,
                        tourBody: strings.lightYourSkyTourConstellationBody,
                      ),
                      choice(
                        icon: Icons.star,
                        label: strings.menuLightAStar,
                        onTap: onLightAStar,
                        index: 2,
                        tourOrder: 4,
                        tourTitle: strings.lightYourSkyTourStarTitle,
                        tourBody: strings.lightYourSkyTourStarBody,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: StaggeredEntrance(
                    index: 3,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        strings.cancel,
                        style: TextStyle(color: colors.muted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    // A section title, centered under the header the same way the header
    // itself is — only rendered in [detailed] mode.
    Widget sectionHeader(String label, int index) {
      if (!detailed) return const SizedBox.shrink();
      return StaggeredEntrance(
        index: index,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.left,
            style: TextStyle(
              color: colors.text,
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Every entry is a gold icon beside plain white text. No muted/bright
    // split any more, and no glow beyond what [Icon]/[Text] draw on their
    // own — a divider is what separates one group from the next. In
    // [detailed] mode, [description] adds a one-line caption underneath.
    Widget entry({
      required IconData icon,
      required String label,
      String? description,
      required VoidCallback onTap,
      // Shared with the section title above it, so both arrive together.
      required int index,
      // Search is the one entry that skips this menu's own close-on-tap
      // entirely, in *both* modes — [SkyScreen._openSearch] now decides
      // for itself whether this menu should still be open once it's
      // done, the same "peek and go back" reasoning [detailed] mode's
      // usual "stays open underneath" rule already gives every other
      // entry, extended to compact mode too (see that method's own doc
      // comment).
      bool closeOnTap = true,
    }) {
      final tile = ListTile(
        leading: Icon(icon, color: colors.gold),
        title: Text(
          label,
          style: TextStyle(
            color: colors.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: detailed && description != null
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  description,
                  style: TextStyle(color: colors.muted, fontSize: 12.5),
                ),
              )
            : null,
        onTap: () {
          // Compact mode (the Drawer) closes first here, same as always —
          // standard drawer UX, straight to the destination. Detailed mode
          // (the modal) stays open instead: the page (or popup) this opens
          // goes on *top* of it rather than replacing it, so coming back
          // from that page — or closing that popup — lands right back on
          // the modal, open where it was left, instead of dropping back
          // onto the bare Sky underneath it. [closeOnTap] opts an entry
          // out of the compact-mode half of that too (see Search above).
          if (closeOnTap && !detailed) Navigator.of(context).pop();
          onTap();
        },
      );
      // [detailed] mode only: the same panel language every field/tile in
      // the app uses (see `panelDecoration`), so each row reads as its
      // own pressable button rather than a plain line in a list — the
      // compact drawer skips this on purpose, it was never ambiguous
      // there.
      if (!detailed) return StaggeredEntrance(index: index, child: tile);
      return StaggeredEntrance(
        index: index,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Container(
            decoration: panelDecoration(colors),
            clipBehavior: Clip.antiAlias,
            child: tile,
          ),
        ),
      );
    }

    final list = ListView(
      controller: scrollController,
      physics: physics,
      padding: EdgeInsets.zero,
      children: [
        StaggeredEntrance(
          index: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                ClipOval(
                  child: Image.asset(_logoAsset, width: 72, height: 72),
                ),
                const SizedBox(height: 14),
                Text(
                  'Inner Stars',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: kFontBranding,
                    fontSize: detailed ? 46 : 34,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.aboutTagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: detailed ? 18 : 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!detailed) Divider(color: colors.nightBorder, height: 1),
        sectionHeader(strings.menuSearchSection, 1),
        if (!detailed) const SizedBox(height: 8),
        entry(
          index: 1,
          icon: Icons.saved_search,
          label: strings.menuSearch,
          description: strings.menuSearchDescription,
          onTap: onSearch,
          closeOnTap: false,
        ),

        if (!detailed) Divider(color: colors.nightBorder, height: 1),
        sectionHeader(strings.menuActivitySection, 2),
        if (!detailed) const SizedBox(height: 8),
        entry(
          index: 2,
          icon: Icons.auto_awesome,
          label: strings.menuLightYourSky,
          description: strings.menuLightYourSkyDescription,
          onTap: () {
            // Reopening on the next frame: in compact mode (the
            // Drawer), the menu's own Navigator.pop (in entry()'s
            // onTap) has to finish closing it first, or the sheet
            // opens behind the closing menu instead of on top of
            // the Sky. Detailed mode (the modal) doesn't pop at
            // all any more, so there's nothing to race there — the
            // one-frame defer is just harmless overhead in that
            // case, not worth a separate code path to skip it.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _openLightYourSkyChooser(context);
            });
          },
        ),

        if (!detailed) Divider(color: colors.nightBorder, height: 1),
        sectionHeader(strings.menuNightlightSection, 3),
        if (!detailed) const SizedBox(height: 8),
        entry(
          index: 3,
          icon: Icons.tips_and_updates,
          label: strings.menuFindYourLight,
          description: strings.menuFindYourLightDescription,
          onTap: onNightlight,
        ),

        if (!detailed) Divider(color: colors.nightBorder, height: 1),
        sectionHeader(strings.menuChallengesSection, 4),
        if (!detailed) const SizedBox(height: 8),
        entry(
          index: 4,
          icon: Icons.auto_fix_high,
          label: strings.menuShootingStars,
          description: strings.menuShootingStarsDescription,
          onTap: onShootingStars,
        ),

        if (!detailed) Divider(color: colors.nightBorder, height: 1),
        sectionHeader(strings.menuDataSection, 5),
        if (!detailed) const SizedBox(height: 8),
        entry(
          index: 5,
          icon: Icons.bar_chart_outlined,
          label: strings.menuStatistics,
          description: strings.menuStatisticsDescription,
          onTap: onStatistics,
        ),

        if (!detailed) Divider(color: colors.nightBorder, height: 1),
        sectionHeader(strings.socialSection, 6),
        if (!detailed) const SizedBox(height: 8),
        entry(
          index: 6,
          icon: Icons.people,
          label: strings.menuFriends,
          description: strings.menuFriendsDescription,
          onTap: onFriends,
        ),

        if (_kShowMetaphorMenuEntry) ...[
          if (!detailed) Divider(color: colors.nightBorder, height: 1),
          sectionHeader(strings.menuInfoSection, 7),
          if (!detailed) const SizedBox(height: 8),
          entry(
            index: 7,
            icon: Icons.auto_stories_outlined,
            label: strings.menuMetaphor,
            description: strings.menuMetaphorDescription,
            onTap: onMetaphor,
          ),
        ],

        // In [detailed] mode (the modal), Settings is just one more
        // section in the same scrollable list as everything else —
        // it only gets pulled out and pinned below in compact mode
        // (the drawer); see the non-detailed branch further down.
        if (detailed) ...[
          sectionHeader(strings.menuSettings, 7),
          entry(
            index: 7,
            icon: Icons.settings_outlined,
            label: strings.menuSettings,
            description: strings.menuSettingsDescription,
            onTap: onSettings,
          ),
          // Settings is the last entry in this list, with nothing
          // below it — every *other* entry gets a "next section"
          // to breathe against (this same entry's own 4px bottom
          // padding plus the next sectionHeader's own 20px top
          // padding); this closes out with that same 24px instead
          // of just stopping dead at the list's own edge.
          const SizedBox(height: 24),
        ],
      ],
    );

    return Column(
      children: [
        // Pull-to-dismiss over this content (not just a drag handle) is
        // handled higher up, by [SkyMenuModalFrame] wrapping this whole
        // widget in detailed mode — see its own doc comment for why
        // that has to live there instead of here.
        Expanded(child: list),
        // Compact mode only: Settings sits outside the scrollable list
        // entirely, not just last within it — its own divider plus the
        // gap above and below reads as "a different kind of thing" (the
        // page that has its *own* sections) rather than one more row in
        // the same list. Skipped in [detailed] mode, where it's already
        // inside the list above like every other section.
        if (!detailed) ...[
          Divider(color: colors.nightBorder, height: 1),
          entry(
            icon: Icons.settings_outlined,
            label: strings.menuSettings,
            description: strings.menuSettingsDescription,
            onTap: onSettings,
            index: 7,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// The modal's own background, rounded top corners, and drag handle —
/// built by hand rather than via [showModalBottomSheet]'s own
/// `backgroundColor`/`shape`/`showDragHandle` (all turned off where this
/// is used — see `SkyScreen._openMenuModal`) — so that pulling down,
/// whether starting on the handle here or bubbling up from an
/// already-at-its-top [ListView] inside [child], moves this *whole*
/// frame together: a small pull springs it back up, a big enough pull
/// dismisses it, exactly like dragging [BottomSheet]'s own handle
/// already does.
///
/// Why build this by hand at all: [BottomSheet] (`enableDrag: true`)
/// already wraps its *entire* content — not just the handle — in a
/// drag recognizer of its own for exactly this follow-the-finger
/// behavior, but a descendant [Scrollable] (the menu's own [ListView])
/// claims the same vertical drag from the gesture arena first and never
/// releases it back up, even once genuinely at its own scroll boundary
/// — clamping physics keeps "owning" the gesture and just reports the
/// excess as [OverscrollNotification] instead of ceding it. And even if
/// it did cede the gesture, [BottomSheet]'s real animation controller
/// still isn't reachable from inside its own `builder` to drive
/// ourselves. Owning the whole frame sidesteps both problems at once.
class SkyMenuModalFrame extends StatefulWidget {
  const SkyMenuModalFrame({super.key, required this.builder});

  /// Builds the sheet's own content, given the [ScrollController] and
  /// [ScrollPhysics] this frame needs its scrollable descendant to use
  /// — see [_SkyMenuModalFrameState]'s own doc comment on why both are
  /// necessary for a pull that can be canceled by reversing direction.
  final Widget Function(ScrollController scrollController, ScrollPhysics? physics)
  builder;

  @override
  State<SkyMenuModalFrame> createState() => _SkyMenuModalFrameState();
}

/// Dragging down over the content (not just the handle) needs to move
/// *this whole frame*, stay following the finger for as long as it's
/// down — reversing direction partway through has to un-pull it, not
/// scroll the content underneath instead — and only decide close vs.
/// spring-back once the finger actually lifts.
///
/// [ScrollNotification]s (what an earlier pass here used) turned out
/// not to be enough for that: once a pull reverses direction, the
/// child list's own position is sitting at 0 with room to move, so
/// that reversal is a perfectly normal, in-bounds scroll to it — no
/// [OverscrollNotification] fires for it at all, just a plain
/// [ScrollUpdateNotification] once real content movement already
/// happened, too late to have stopped it from moving in the first
/// place. Patching that after the fact (snapping the list back to 0
/// again once its own position had already changed) sometimes
/// interrupted the *scroll activity itself* — an artifact of forcing a
/// programmatic jump mid-drag — which could fire a genuine
/// [ScrollEndNotification] while the finger never actually left the
/// screen, reading as an unwanted, premature "let go" and closing the
/// sheet out from under a still-held touch.
///
/// [Listener] sidesteps this by tracking the raw pointer directly,
/// entirely independent of whatever the child [Scrollable] does with
/// that same touch — so [_dragOffset] never depends on the list's own
/// activity lifecycle at all. The list is locked to
/// [NeverScrollableScrollPhysics] for the duration of a pull (see
/// [_contentLocked]) purely so it can't *also* react to the same
/// motion in parallel and scroll for real underneath this frame.
class _SkyMenuModalFrameState extends State<SkyMenuModalFrame>
    with SingleTickerProviderStateMixin {
  // How far a pull has to travel before letting go dismisses rather
  // than springs back — a plain pixel distance rather than a fraction
  // of the sheet's own height (what [BottomSheet]'s own
  // `_kCloseProgressThreshold` uses), since that reads the same
  // regardless of how tall the sheet happens to be.
  static const _dismissThreshold = 96.0;

  late final AnimationController _springBackController;
  final _scrollController = ScrollController();
  double _dragOffset = 0.0;
  bool _closing = false;
  bool _contentLocked = false;
  int? _activePointer;
  double? _lastPointerY;

  @override
  void initState() {
    super.initState();
    _springBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _springBackController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _springBack() {
    final animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _springBackController, curve: Curves.easeOut),
    );
    void listener() => setState(() => _dragOffset = animation.value);
    animation.addListener(listener);
    _springBackController
      ..value = 0.0
      ..forward().whenComplete(() => animation.removeListener(listener));
  }

  void _addDrag(double delta) {
    if (_closing) return;
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(0.0, _dismissThreshold * 2);
    });
  }

  void _endDrag() {
    if (_closing || _dragOffset <= 0) return;
    if (_dragOffset >= _dismissThreshold) {
      _closing = true;
      Navigator.of(context).pop();
    } else {
      _springBack();
    }
  }

  // The handle's own drag (its own plain [GestureDetector] in build(),
  // below) doesn't go through any of this — nothing else competes for
  // that gesture, so it never had the bug these three handlers exist
  // to work around.
  void _handleContentPointerDown(PointerDownEvent event) {
    _activePointer = event.pointer;
    _lastPointerY = event.position.dy;
  }

  void _handleContentPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    final previousY = _lastPointerY;
    _lastPointerY = event.position.dy;
    if (previousY == null) return;
    // Positive = finger moved down the screen.
    final delta = event.position.dy - previousY;

    if (_dragOffset > 0) {
      // Already mid-pull: every further move drives it directly from
      // here on, in either direction, regardless of what the (locked)
      // list underneath would otherwise have done with the same move.
      _addDrag(delta);
      return;
    }

    if (delta > 0 &&
        _scrollController.hasClients &&
        _scrollController.position.pixels <= 0) {
      if (!_contentLocked) setState(() => _contentLocked = true);
      _addDrag(delta);
    }
  }

  void _handleContentPointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _lastPointerY = null;
    if (_contentLocked) {
      setState(() => _contentLocked = false);
      _endDrag();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Transform.translate(
      offset: Offset(0, _dragOffset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.nightPanel,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(kRadiusCard),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(kRadiusCard),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A plain drag surface, not a [ListView] — any vertical
                // drag here maps straight to [_addDrag] with nothing
                // else competing for the gesture.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) =>
                      _addDrag(details.primaryDelta ?? 0),
                  onVerticalDragEnd: (_) => _endDrag(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.muted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: Listener(
                    onPointerDown: _handleContentPointerDown,
                    onPointerMove: _handleContentPointerMove,
                    onPointerUp: _handleContentPointerEnd,
                    onPointerCancel: _handleContentPointerEnd,
                    child: widget.builder(
                      _scrollController,
                      _contentLocked
                          ? const NeverScrollableScrollPhysics()
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
