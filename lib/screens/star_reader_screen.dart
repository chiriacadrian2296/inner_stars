import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../data/custom_constellation_repository.dart';
import '../data/photo_storage.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/project.dart';
import '../models/star.dart';
import '../models/star_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../utils/date_format.dart';
import '../widgets/area_tag.dart';
import '../widgets/intensity_bolts.dart';
import '../widgets/navigate_here_button.dart';
import '../widgets/photo_image.dart';
import '../widgets/photo_picker.dart';
import '../widgets/project_tag.dart';
import '../widgets/responsive_content.dart';
import '../widgets/shareable_lit_star_card.dart';
import 'photo_crop_screen.dart';
import 'star_form_screen.dart';

/// Shows one star at a time, with looping prev/next navigation, its content
/// switching by whether the star is lit, still unlit, or dead.
///
/// Used two ways:
/// - From the crisis intro, browsing everything starting at the most
///   recent star ([allowEdit] false — pure reflection, no editing).
/// - From a tap on a specific card/star ([allowEdit] true — adds an edit
///   button that reuses [StarFormScreen], which requires
///   [projectRepository] and [refreshStars] too, since editing can move a
///   star to a different constellation).
class StarReaderScreen extends StatefulWidget {
  const StarReaderScreen({
    super.key,
    required this.repository,
    required this.initialStars,
    required this.startIndex,
    required this.projectsById,
    this.allowEdit = false,
    this.projectRepository,
    this.starsShapeRepository,
    this.refreshStars,
    this.onNavigateTo,
  }) : assert(
         !allowEdit ||
             (projectRepository != null &&
                 starsShapeRepository != null &&
                 refreshStars != null),
         'projectRepository, starsShapeRepository, and refreshStars are required when allowEdit is true.',
       );

  final StarRepository repository;
  final List<Star> initialStars;
  final int startIndex;

  /// Resolves each star's project (and, through it, its area) for display.
  /// A star whose id isn't in here (stale data) still renders — just
  /// without that context row.
  final Map<int, Project> projectsById;
  final bool allowEdit;

  final ProjectRepository? projectRepository;
  final StarsShapeRepository? starsShapeRepository;

  /// Re-derives this reader's star list the same way [initialStars] was
  /// originally scoped — called after an edit/achieve/delete/resurrect so
  /// prev/next keeps browsing the right set.
  final List<Star> Function()? refreshStars;

  /// Set only when opened from the Sky's search popup — shows a
  /// "take me there" button that closes both this reader and the popup,
  /// handing the current star's project back to the sky camera to jump to.
  final ValueChanged<Project>? onNavigateTo;

  @override
  State<StarReaderScreen> createState() => _StarReaderScreenState();
}

class _StarReaderScreenState extends State<StarReaderScreen> {
  late List<Star> _stars = widget.initialStars;
  late int _index = widget.startIndex;

  final _shareKey = GlobalKey();
  bool _sharing = false;

  /// Tap-to-hide-everything-but-the-photo, on a lit star's own image. Reset
  /// on prev/next so browsing to another star always lands back on its data.
  bool _photoOnly = false;

  void _showPrevious() {
    setState(() {
      _index = (_index - 1 + _stars.length) % _stars.length;
      _photoOnly = false;
    });
  }

  void _showNext() {
    setState(() {
      _index = (_index + 1) % _stars.length;
      _photoOnly = false;
    });
  }

  void _togglePhotoOnly() => setState(() => _photoOnly = !_photoOnly);

  Future<void> _shareCurrent() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('toByteData returned null');
      if (!mounted) return;
      final shareFile = XFile.fromData(
        byteData.buffer.asUint8List(),
        name: 'star_${DateTime.now().microsecondsSinceEpoch}.png',
        mimeType: 'image/png',
      );
      await SharePlus.instance.share(
        ShareParams(files: [shareFile], text: _stars[_index].title),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.strings.shareStarError)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _refreshFrom(Star anchor) {
    final refreshed = widget.refreshStars!();
    if (refreshed.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final refreshedIndex = refreshed.indexWhere((s) => s.id == anchor.id);
    setState(() {
      _stars = refreshed;
      _index = refreshedIndex == -1
          ? _index.clamp(0, refreshed.length - 1)
          : refreshedIndex;
    });
  }

  Future<void> _editOrResurrectCurrent() async {
    final current = _stars[_index];

    if (current.dead) {
      final result = await Navigator.of(context).push<Object>(
        MaterialPageRoute(
          builder: (_) => StarFormScreen(
            existingStar: current,
            contextProject: widget.projectsById[current.projectId],
            projectRepository: widget.projectRepository,
            starsShapeRepository: widget.starsShapeRepository,
            hideDelete: true,
          ),
        ),
      );
      if (result is! StarFormResult) return;
      await widget.repository.resurrect(
        current.id,
        title: result.title,
        description: result.description,
        projectId: result.projectId,
        targetDate: result.targetDate,
        achievedDate: result.achievedDate,
        intensity: result.intensity,
        photoPath: result.photoPath,
      );
      _refreshFrom(current);
      return;
    }

    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => StarFormScreen(
          existingStar: current,
          contextProject: widget.projectsById[current.projectId],
          projectRepository: widget.projectRepository,
          starsShapeRepository: widget.starsShapeRepository,
        ),
      ),
    );
    if (result == null) return;

    if (result is StarFormDeleteRequested) {
      await widget.repository.delete(current.id);
      _refreshFrom(current);
      return;
    }

    final addResult = result as StarFormResult;
    await widget.repository.update(
      id: current.id,
      title: addResult.title,
      description: addResult.description,
      projectId: addResult.projectId,
      targetDate: addResult.targetDate,
      achievedDate: addResult.achievedDate,
      intensity: addResult.intensity,
      photoPath: addResult.photoPath,
    );
    _refreshFrom(current);
  }

  Future<void> _markAchieved() async {
    final current = _stars[_index];
    final result = await showModalBottomSheet<_MarkAchievedResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MarkAchievedSheet(),
    );
    if (result == null) return;
    await widget.repository.markAchieved(
      current.id,
      intensity: result.intensity,
      photoPath: result.photoPath,
    );
    _refreshFrom(current);
  }

  @override
  Widget build(BuildContext context) {
    final star = _stars[_index];
    final project = widget.projectsById[star.projectId];
    final colors = context.colors;
    final strings = context.strings;

    final photoPath = star.isLit ? star.photoPath : null;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (star.isLit)
            RepaintBoundary(
              key: _shareKey,
              child: ShareableLitStarCard(star: star, project: project),
            ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final scale = Tween<double>(
                  begin: 0.94,
                  end: 1.0,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: scale, child: child),
                );
              },
              child: Stack(
                key: ValueKey(_index),
                fit: StackFit.expand,
                children: [
                  if (photoPath != null)
                    PhotoImage(
                      photoPath: photoPath,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  AnimatedOpacity(
                    // Only the photo's own darkening veil fades away in
                    // photo-only mode — a star with no photo has nothing to
                    // reveal underneath, so its plain [crisisGradient]
                    // background never toggles.
                    opacity: photoPath != null && _photoOnly ? 0 : 1,
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: photoPath == null
                            ? colors.crisisGradient
                            : RadialGradient(
                                center: const Alignment(0, -0.6),
                                radius: 1.2,
                                colors: [
                                  colors.crisisGradientCenter.withValues(
                                    alpha: 0.55,
                                  ),
                                  colors.crisisGradientMid.withValues(
                                    alpha: 0.75,
                                  ),
                                  colors.crisisGradientOuter.withValues(
                                    alpha: 0.9,
                                  ),
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (photoPath != null)
            // Catches the tap that brings everything back once the chrome
            // below is [IgnorePointer]d in photo-only mode — translucent so
            // it never steals a tap from an actual button when the chrome
            // is showing (see the [IgnorePointer] below for why those still
            // win first).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _togglePhotoOnly,
              ),
            ),
          IgnorePointer(
            ignoring: photoPath != null && _photoOnly,
            child: AnimatedOpacity(
              opacity: photoPath != null && _photoOnly ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                  child: Column(
                    children: [
                      ResponsiveContent(
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.close,
                                color: colors.crisisMuted,
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  strings.indexOfCount(
                                    _index + 1,
                                    _stars.length,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.crisisMuted,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.allowEdit)
                              IconButton(
                                onPressed: _editOrResurrectCurrent,
                                icon: Icon(
                                  star.dead
                                      ? Icons.auto_fix_high
                                      : Icons.edit_outlined,
                                  color: colors.crisisMuted,
                                ),
                              )
                            else
                              const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: photoPath != null ? _togglePhotoOnly : null,
                          onHorizontalDragEnd: (details) {
                            final velocity = details.primaryVelocity ?? 0;
                            if (velocity < -200) {
                              _showNext();
                            } else if (velocity > 200) {
                              _showPrevious();
                            }
                          },
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: ResponsiveContent(
                                child: AnimatedSwitcher(
                                  duration: const Duration(
                                    milliseconds: 260,
                                  ),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, animation) {
                                    final scale = Tween<double>(
                                      begin: 0.94,
                                      end: 1.0,
                                    ).animate(animation);
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: scale,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _StarContent(
                                    key: ValueKey(_index),
                                    star: star,
                                    project: project,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ResponsiveContent(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _NavCircleButton(
                              icon: Icons.chevron_left,
                              onTap: _showPrevious,
                            ),
                            _MiddleAction(
                              star: star,
                              sharing: _sharing,
                              onShare: _shareCurrent,
                              onMarkAchieved: _markAchieved,
                              onResurrect: _editOrResurrectCurrent,
                            ),
                            _NavCircleButton(
                              icon: Icons.chevron_right,
                              onTap: _showNext,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.onNavigateTo != null && project != null)
            _TakeMeThereButton(
              tooltip: strings.takeMeThereAction,
              hidden: photoPath != null && _photoOnly,
              onTap: () {
                Navigator.of(context).pop();
                widget.onNavigateTo!(project);
              },
            ),
          if (photoPath != null) _PhotoOnlyHint(photoOnly: _photoOnly),
        ],
      ),
    );
  }
}

/// The "take me there" trigger, centered horizontally and pinned roughly
/// midway between the bottom nav row's share button and [_StarContent]'s
/// own intensity bolts just above it — an eyeballed offset (both endpoints
/// move with content length, so there's no fixed midpoint to measure),
/// same spirit as [_PhotoOnlyHint]'s own placement.
class _TakeMeThereButton extends StatelessWidget {
  const _TakeMeThereButton({
    required this.onTap,
    required this.tooltip,
    required this.hidden,
  });

  final VoidCallback onTap;
  final String tooltip;

  /// Mirrors the chrome's own hidden state in photo-only mode — see
  /// [_StarReaderScreenState._photoOnly].
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    // [Positioned] must stay the outermost widget here: it's only
    // meaningful as a direct child of the enclosing [Stack], so
    // [IgnorePointer]/[AnimatedOpacity] nest *inside* it rather than
    // wrapping it — the reverse order silently drops the positioning
    // (Stack falls back to `fit: StackFit.expand`, blowing this up to
    // fill the whole screen instead of sitting where [right]/[bottom] say).
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 130),
              child: Center(
                child: NavigateHereButton(
                  onTap: onTap,
                  tooltip: tooltip,
                  size: 40,
                  iconSize: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "tap to see the photo"/"tap to see the details" hint pinned over a
/// lit star's own photo — the one thing that stays on screen through both
/// of [_StarReaderScreenState]'s states (only its text/icon cross-fade),
/// so there's always a visible cue for what tapping the photo does next.
/// Purely informational — [IgnorePointer]d so the tap it describes still
/// lands on whichever of [_StarReaderScreenState]'s own detectors is
/// underneath it.
class _PhotoOnlyHint extends StatelessWidget {
  const _PhotoOnlyHint({required this.photoOnly});

  final bool photoOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        child: SafeArea(
          bottom: false,
          child: Padding(
            // Roughly midway between the header row above and the star
            // icon that normally opens [_StarContent] below — an eyeballed
            // offset (the icon's own position isn't fixed, since the
            // content column is vertically centered), not a measured one.
            padding: const EdgeInsets.only(top: 132),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Container(
                  key: ValueKey(photoOnly),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 16,
                        color: colors.crisisMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        photoOnly
                            ? strings.starReaderTapForDataHint
                            : strings.starReaderTapForPhotoHint,
                        style: TextStyle(fontSize: 13, color: colors.crisisMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The star's icon/date/tags/title/description/bolts block, shaped by
/// whether it's a victory, a still-unlit goal, or a dead star.
class _StarContent extends StatelessWidget {
  const _StarContent({super.key, required this.star, required this.project});

  final Star star;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    if (star.dead) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(StarKind.dead.icon, size: 44, color: colors.starDead),
          const SizedBox(height: 24),
          Text(
            StarKind.dead.label(strings),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            strings.deadStarBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: colors.crisisMuted,
            ),
          ),
        ],
      );
    }

    final lit = star.isLit;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          star.kind.icon,
          size: 44,
          color: lit ? colors.gold : colors.starUnlit,
        ),
        const SizedBox(height: 28),
        Text(
          lit
              ? formatDisplayDateTime(star.achievedDate!, strings)
              : (star.targetDate == null
                    ? StarKind.unlit.label(strings)
                    : strings.goalTargetLabel(
                        formatDisplayDate(star.targetDate!, strings),
                      )),
          style: TextStyle(fontSize: 15, color: colors.crisisMuted),
        ),
        if (project != null) ...[
          const SizedBox(height: 16),
          AreaTag(area: project!.area, iconSize: 24, fontSize: 21),
          const SizedBox(height: 8),
          ProjectTag(
            project: project!,
            textColor: colors.crisisMuted,
            iconSize: 17,
            fontSize: 17,
          ),
        ],
        const SizedBox(height: 24),
        Text(
          star.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kFontStarTitle,
            fontStyle: FontStyle.italic,
            fontSize: 34,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: colors.text,
          ),
        ),
        if (star.description != null) ...[
          const SizedBox(height: 22),
          Text(
            star.description!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              height: 1.6,
              color: colors.crisisMuted,
            ),
          ),
        ],
        if (lit) ...[
          const SizedBox(height: 28),
          IntensityBolts(
            intensity: star.intensity!,
            size: 30,
            spacing: 6,
            emphasizeLast: true,
          ),
        ],
      ],
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  const _NavCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.crisisMuted.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: context.colors.text),
        ),
      ),
    );
  }
}

/// The bottom row's middle slot — share for a victory, "mark achieved" for
/// a goal, "resurrect" for a dead star. Undoing an achieved star back into a
/// goal is done through editing (the achieved toggle), not a dedicated
/// button here.
class _MiddleAction extends StatelessWidget {
  const _MiddleAction({
    required this.star,
    required this.sharing,
    required this.onShare,
    required this.onMarkAchieved,
    required this.onResurrect,
  });

  final Star star;
  final bool sharing;
  final VoidCallback onShare;
  final VoidCallback onMarkAchieved;
  final VoidCallback onResurrect;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    if (star.dead) {
      return _ActionButton(
        icon: Icons.auto_fix_high,
        label: strings.reigniteAction,
        onTap: onResurrect,
      );
    }
    if (!star.isLit) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: Icons.star,
            label: strings.markAchievedAction,
            onTap: onMarkAchieved,
          ),
        ],
      );
    }
    return _ActionButton(
      icon: Icons.share_outlined,
      label: strings.shareStarLabel,
      onTap: sharing ? null : onShare,
      loading: sharing,
    );
  }
}

/// The bottom row's shared pill-shaped gold button — same look for "mark
/// achieved", "resurrect", and "share": an icon and label together inside
/// one gold [StadiumBorder], rather than share's previous bespoke circle +
/// caption-underneath treatment.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.gold,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onGold,
                  ),
                )
              else
                Icon(icon, color: colors.onGold, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: colors.onGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the "mark achieved" sheet collects before handing control back to
/// [_StarReaderScreenState._markAchieved].
class _MarkAchievedResult {
  const _MarkAchievedResult({required this.intensity, this.photoPath});
  final int intensity;
  final String? photoPath;
}

/// Quick "log it now" sheet for a goal — lighter than the full edit form,
/// but still covers the one thing a goal is missing next to a plain
/// victory: intensity and an optional photo, exactly like [AddStarScreen]'s
/// achieved fields.
class _MarkAchievedSheet extends StatefulWidget {
  const _MarkAchievedSheet();

  @override
  State<_MarkAchievedSheet> createState() => _MarkAchievedSheetState();
}

class _MarkAchievedSheetState extends State<_MarkAchievedSheet> {
  int _intensity = 3;
  String? _photoPath;

  Future<void> _pickPhoto() async {
    final colors = context.colors;
    final strings = context.strings;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_outlined, color: colors.gold),
                title: Text(
                  strings.takePhotoOption,
                  style: TextStyle(color: colors.text),
                ),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: colors.gold),
                title: Text(
                  strings.choosePhotoOption,
                  style: TextStyle(color: colors.text),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final croppedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => PhotoCropScreen(imageFile: picked)),
      );
      if (croppedBytes == null || !mounted) return;

      final savedPath = await PhotoStorage.saveBytes(croppedBytes);
      if (!mounted) return;
      setState(() => _photoPath = savedPath);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.photoPickError)));
    }
  }

  void _removePhoto() => setState(() => _photoPath = null);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.markAchievedSheetTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 18),
            IntensityBolts(
              intensity: _intensity,
              size: 26,
              spacing: 6,
              emphasizeLast: true,
              emphasizedScale: 1.6,
            ),
            Slider(
              value: _intensity.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (v) => setState(() => _intensity = v.round()),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                strings.photoLabel,
                style: TextStyle(fontSize: 13, color: colors.muted),
              ),
            ),
            const SizedBox(height: 6),
            PhotoPicker(
              photoPath: _photoPath,
              onPick: _pickPhoto,
              onRemove: _removePhoto,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(
                  _MarkAchievedResult(
                    intensity: _intensity,
                    photoPath: _photoPath,
                  ),
                ),
                child: Text(strings.markAchievedConfirm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
