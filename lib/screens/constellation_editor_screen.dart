import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../data/constellation_editor_prefs.dart';
import '../data/constellation_shape.dart';
import '../data/custom_constellation_repository.dart';
import '../l10n/strings_scope.dart';
import '../models/custom_constellation.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../widgets/constellation_editor_painter.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/responsive_content.dart';

/// Lets the user hand-draw their own constellation shape: tap empty space to
/// place a star, tap two stars in turn to connect/disconnect them, drag a
/// star to reposition it, and save the result as a reusable
/// [StarsShape]. Interaction mirrors the offline Astralarium
/// workflow already used to co-design the app's own built-in shapes (see
/// `tools/constellation-astralarium/`) — tap to place, tap-tap to connect —
/// brought in-app for end users.
///
/// Pass [existing] to open an already-saved shape for editing instead of
/// starting from a blank canvas — saving then updates that same
/// [StarsShape] (same id, same position in the user's list) rather
/// than creating a new one, via [StarsShapeRepository.update].
///
/// The canvas is fixed-size and never pans/zooms: unlike
/// [ConstellationScreen] (which frames an already-known shape), the user is
/// actively placing points, and where they land within the canvas doesn't
/// matter — [normalizeEditorPoints] rescales everything into the shared 0..1
/// box once, at save time.
class StarsShapeEditorScreen extends StatefulWidget {
  const StarsShapeEditorScreen({
    super.key,
    required this.starsShapeRepository,
    this.existing,
    this.initialShape,
    this.initialShapeName,
  }) : assert(
         existing == null || initialShape == null,
         'Pass at most one of existing/initialShape — existing already '
         'carries its own shape to start from.',
       ),
       assert(
         initialShapeName == null || initialShape != null,
         'initialShapeName only makes sense alongside initialShape — '
         'existing already carries its own name.',
       );

  final StarsShapeRepository starsShapeRepository;
  final StarsShape? existing;

  /// Starts the canvas pre-filled with these points/edges, same as
  /// [existing] would, but *without* tying [_save] to updating some
  /// already-saved constellation — saving still creates a brand new one,
  /// same as a blank canvas would. What a preset picked from the shape
  /// library opens with: the user can go on to reshape it freely, and it
  /// only ever becomes a real, owned [StarsShape] at that save,
  /// never the moment they merely opened the editor to look at it.
  final ConstellationShape? initialShape;

  /// [initialShape]'s own name, shown the same way [existing]'s name is —
  /// a preset already has one (see `StarsShapePreset.name`), it's just
  /// not tied to anything owned yet. Null for a blank canvas, where
  /// there's nothing to show.
  final String? initialShapeName;

  @override
  State<StarsShapeEditorScreen> createState() =>
      _StarsShapeEditorScreenState();
}

/// A soft cap, distinct from `maxChainedStars` in constellation_layout.dart
/// (which bounds the *rendered, algorithmically grown* graph for
/// performance). This one bounds how many points a person can usefully
/// place and keep track of by hand in one sitting — the ready-made library
/// shapes (see `constellation_presets.dart`, which respects this same cap so
/// every preset is one a person could have drawn here) mostly land at 6-14
/// points, so this leaves headroom without inviting a shape so dense it
/// stops reading as a constellation on a phone screen.
const int _maxEditorPoints = 30;

/// Splits [text] around its own *first* run of digits — the changing
/// figure a formatted status string like
/// [AppStrings.constellationEditorStarCount] embeds (its own fixed
/// second number, e.g. [_maxEditorPoints], never comes first in any of
/// this app's translations, so "first digit run" reliably means "the one
/// that changes" without needing per-language special-casing) — styling
/// that run bold gold and leaving the rest of the sentence in [colors]'s
/// own muted tone around it.
List<InlineSpan> _highlightFirstNumber(String text, AppColors colors) {
  final match = RegExp(r'\d+').firstMatch(text);
  final baseStyle = TextStyle(color: colors.muted);
  if (match == null) return [TextSpan(text: text, style: baseStyle)];
  return [
    TextSpan(text: text.substring(0, match.start), style: baseStyle),
    TextSpan(
      text: match.group(0),
      style: TextStyle(color: colors.gold, fontWeight: FontWeight.w700),
    ),
    TextSpan(text: text.substring(match.end), style: baseStyle),
  ];
}

class _EditorSnapshot {
  const _EditorSnapshot(this.points, this.edges, this.mirrorOf);
  final List<Offset> points;
  final List<(int, int)> edges;
  final List<int?> mirrorOf;
}

class _StarsShapeEditorScreenState extends State<StarsShapeEditorScreen> {
  /// Working coordinates, relative to the canvas's own size (roughly 0..1,
  /// same convention a saved [ConstellationShape] uses — but not clamped:
  /// dragging a point past the visible canvas edge just pushes it slightly
  /// outside that range, which [normalizeEditorPoints] resolves at save
  /// time by re-fitting everything to the actual bounding box). Storing
  /// points this way — rather than in raw canvas-pixel space — means
  /// opening an existing [StarsShape] for editing is a direct
  /// assignment (its `shape.points` are already in this same convention),
  /// with no dependency on knowing the on-screen canvas's pixel size up
  /// front.
  final List<Offset> _points = [];
  final List<(int, int)> _edges = [];
  /// Parallel to [_points]: [_mirrorOf]\[i\] is the index of point i's
  /// mirror partner (see [_mirrorEnabled]), itself if it sits exactly on
  /// the mirror axis, or null if it has none — either mirror mode was off
  /// when it was placed, or it came from [widget.existing]. Kept in
  /// lockstep with [_points] through every add/move/delete, and part of
  /// [_EditorSnapshot] so undo/redo restores the pairing too, not just the
  /// points/edges.
  final List<int?> _mirrorOf = [];
  int? _armedIndex;
  int? _draggingIndex;
  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];

  /// Draw once, mirrored automatically on the other side of an axis
  /// through the canvas's own center — every placed/moved/deleted point,
  /// and every connection between two mirrored points, happens on both
  /// sides at once. Off by default: a plain, un-mirrored canvas, same as
  /// before this existed.
  bool _mirrorEnabled = false;

  /// true = the mirror axis is the vertical center line (left/right
  /// symmetry, flips the x coordinate); false = the horizontal center
  /// line (top/bottom symmetry, flips y). Defaults off (false, same as
  /// [_mirrorEnabled]) so only the grid switch reads as "on" the moment
  /// this screen opens — this one doesn't do anything until mirroring
  /// itself is switched on anyway.
  bool _mirrorVertical = false;

  /// How close a point's own reflection has to be to itself (in the same
  /// 0..1 relative space [_points] uses) before it's treated as sitting
  /// exactly on the mirror axis — see [_addPointMaybeMirrored]. Small
  /// enough it only catches a deliberately-near-center tap/drag, not
  /// anything that merely happens to be somewhere in the middle third of
  /// the canvas.
  static const _mirrorAxisEpsilon = 0.02;

  /// The on-screen canvas's actual pixel size, refreshed every build (see
  /// the `LayoutBuilder` in [build]) — needed to convert between the
  /// relative [_points] and the raw pixel positions pointer events report
  /// and [ConstellationEditorPainter] draws in.
  Size _canvasSize = Size.zero;

  Offset? _pointerDownPosition;
  int? _pointerDownIndex;
  bool _isDragging = false;

  /// Graph-paper background: a fixed [_gridDivisions] x [_gridDivisions]
  /// grid across the whole canvas — the canvas itself is the one "big
  /// square", divided into 10x10 small ones, with no separate coarser tier.
  /// When [_gridEnabled], every added/dragged point snaps to the nearest
  /// grid vertex (see [_snapIfGridEnabled]).
  bool _gridEnabled = true;
  static const _gridDivisions = 10;

  /// [_canvasSize]-dependent, so always recomputed rather than cached — the
  /// canvas can resize (e.g. on rotation) between builds.
  double get _gridSpacing => _canvasSize.width / _gridDivisions;

  /// How far the pointer has to move from where it went down before a touch
  /// on an existing point counts as a drag rather than a tap. Deliberately
  /// small (real touchscreens always have a few pixels of finger wobble
  /// during a "still" tap) — the actual tap/connect/add logic lives in
  /// [_handleTap], driven by raw pointer events rather than
  /// [GestureDetector]'s onTap+onPan combo: on a real device, that combo let
  /// the pan recognizer occasionally win the gesture arena even for a
  /// stationary tap, silently swallowing the tap-to-connect gesture (see
  /// [_handlePointerDown]/[_handlePointerMove]/[_handlePointerUp] below).
  static const _dragActivationDistance = 8.0;

  ConstellationEditorPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    final startingShape = widget.existing?.shape ?? widget.initialShape;
    if (startingShape != null) {
      _points.addAll(startingShape.points);
      _edges.addAll(startingShape.edges);
      // No known pairing for a shape drawn before mirror mode existed —
      // mirroring only ever applies to points placed *while* it's on.
      _mirrorOf.addAll(List<int?>.filled(_points.length, null));
    }
    _maybeAutoShowHelp();
  }

  /// [_points] and [ConstellationEditorPainter]/pointer events don't speak
  /// the same units — these two converters are the only place that
  /// boundary is crossed, using [_canvasSize] as captured by the most
  /// recent build's `LayoutBuilder`.
  Offset _toRelative(Offset pixelPosition) {
    if (_canvasSize.isEmpty) return pixelPosition;
    return Offset(
      pixelPosition.dx / _canvasSize.width,
      pixelPosition.dy / _canvasSize.height,
    );
  }

  List<Offset> get _pixelPoints => _points
      .map((p) => Offset(p.dx * _canvasSize.width, p.dy * _canvasSize.height))
      .toList();

  /// Snaps a raw pixel position to the nearest grid vertex when the grid is
  /// on — a no-op otherwise. Applied at the moment a point is added or
  /// dragged (see [_handleTap]/[_handlePointerMove]), before converting to
  /// [_points]' relative space, so the stored position is exactly on the
  /// grid rather than merely close to it.
  Offset _snapIfGridEnabled(Offset pixelPosition) {
    return _gridEnabled
        ? snapToGrid(pixelPosition, _gridSpacing)
        : pixelPosition;
  }

  Future<void> _maybeAutoShowHelp() async {
    final prefs = await ConstellationEditorPrefs.create();
    if (!mounted) return;
    _prefs = prefs;
    if (prefs.hideHelp) return;
    // Editing an already-saved shape means the user has already been
    // through the "how this works" tutorial once (they had to draw it in
    // the first place) — showing it again here would just be in the way.
    if (widget.existing != null) return;
    // Scheduled for after the first frame (not called directly here) since
    // showDialog needs a BuildContext with an Overlay already mounted above
    // it — this screen's own build() hasn't run yet during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showHelp();
    });
  }

  /// Always available via the app bar's "?" icon regardless of the "don't
  /// show this again" preference — that flag only skips the *automatic*
  /// pop-up on [_maybeAutoShowHelp], never the manual one.
  Future<void> _showHelp() async {
    final prefs = _prefs ??= await ConstellationEditorPrefs.create();
    if (!mounted) return;
    final strings = context.strings;
    final colors = context.colors;
    var hideNextTime = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
              title: Text(
            strings.constellationEditorHelpTitle,
            style: TextStyle(color: colors.text),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HelpBullet(
                  text: strings.constellationEditorHelpAddPoint,
                  illustration: _addPointDiagram,
                ),
                _HelpBullet(
                  text: strings.constellationEditorHelpConnectPoint,
                  illustration: _connectDiagram,
                ),
                _HelpBullet(
                  text: strings.constellationEditorHelpDisarmPoint,
                  illustration: _disarmDiagram,
                ),
                _HelpBullet(
                  text: strings.constellationEditorHelpMovePoint,
                  illustration: _moveDiagram,
                ),
                _HelpBullet(
                  text: strings.constellationEditorHelpDeletePoint,
                  illustration: _deleteDiagram,
                ),
                _HelpBullet(
                  text: strings.constellationEditorHelpMirrorToggle,
                  illustration: _mirrorDiagram,
                ),
                _HelpBullet(
                  text: strings.constellationEditorHelpMirrorAxis,
                  illustration: const _MirrorAxisSwitchIllustration(),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () =>
                      setDialogState(() => hideNextTime = !hideNextTime),
                  borderRadius: BorderRadius.circular(kRadiusField),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: hideNextTime,
                          activeColor: colors.gold,
                          onChanged: (value) => setDialogState(
                            () => hideNextTime = value ?? false,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            strings.constellationEditorHelpDontShowAgain,
                            style: TextStyle(color: colors.muted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setHideHelp(hideNextTime);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: Text(
                strings.constellationEditorHelpClose,
                style: TextStyle(color: colors.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _EditorSnapshot _currentSnapshot() =>
      _EditorSnapshot(List.of(_points), List.of(_edges), List.of(_mirrorOf));

  void _pushUndoSnapshot() {
    _undoStack.add(_currentSnapshot());
    // A fresh edit invalidates whatever redo history existed — standard
    // undo/redo semantics (there's no single "future" once you've branched
    // off into a new change).
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final last = _undoStack.removeLast();
    _redoStack.add(_currentSnapshot());
    setState(() {
      _points
        ..clear()
        ..addAll(last.points);
      _edges
        ..clear()
        ..addAll(last.edges);
      _mirrorOf
        ..clear()
        ..addAll(last.mirrorOf);
      _armedIndex = null;
      _draggingIndex = null;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(_currentSnapshot());
    setState(() {
      _points
        ..clear()
        ..addAll(next.points);
      _edges
        ..clear()
        ..addAll(next.edges);
      _mirrorOf
        ..clear()
        ..addAll(next.mirrorOf);
      _armedIndex = null;
      _draggingIndex = null;
    });
  }

  void _toggleEdge(int a, int b) {
    final forward = _edges.indexWhere((e) => e.$1 == a && e.$2 == b);
    final backward = _edges.indexWhere((e) => e.$1 == b && e.$2 == a);
    if (forward != -1) {
      _edges.removeAt(forward);
    } else if (backward != -1) {
      _edges.removeAt(backward);
    } else {
      _edges.add((a, b));
    }
  }

  /// [relative]'s reflection across whichever mirror axis is active (see
  /// [_mirrorVertical]) — a vertical axis (the canvas's own vertical
  /// center line) mirrors left/right, flipping x; a horizontal one mirrors
  /// top/bottom, flipping y.
  Offset _mirrorAcrossAxis(Offset relative) {
    return _mirrorVertical
        ? Offset(1.0 - relative.dx, relative.dy)
        : Offset(relative.dx, 1.0 - relative.dy);
  }

  /// Adds [relative] to [_points] — as a single, self-mirrored point if it
  /// sits within [_mirrorAxisEpsilon] of its own reflection (snapped
  /// exactly onto the axis, so it doesn't drift off it), or as a mirrored
  /// pair otherwise. Only called while [_mirrorEnabled]; the plain
  /// single-point add ([_handleTap]'s own `_points.add` when mirroring is
  /// off) still handles the unmirrored case directly.
  void _addPointMaybeMirrored(Offset relative) {
    final reflected = _mirrorAcrossAxis(relative);
    if ((relative - reflected).distance < _mirrorAxisEpsilon) {
      final onAxis = _mirrorVertical
          ? Offset(0.5, relative.dy)
          : Offset(relative.dx, 0.5);
      _points.add(onAxis);
      _mirrorOf.add(_points.length - 1);
      return;
    }
    _points.add(relative);
    final index = _points.length - 1;
    _points.add(reflected);
    final mirrorIndex = _points.length - 1;
    _mirrorOf.add(mirrorIndex);
    _mirrorOf.add(index);
  }

  /// If both [a] and [b] have a known mirror partner (see [_mirrorOf]) and
  /// that mirrored edge isn't just [a]-[b] itself (which happens when they
  /// *are* each other's mirror pair, or both sit self-mirrored on the
  /// axis), toggles the equivalent edge between those two partners too —
  /// called right after [_toggleEdge] itself, from [_handleTap], only
  /// while [_mirrorEnabled].
  void _mirrorToggleEdgeIfNeeded(int a, int b) {
    final mirrorA = a < _mirrorOf.length ? _mirrorOf[a] : null;
    final mirrorB = b < _mirrorOf.length ? _mirrorOf[b] : null;
    if (mirrorA == null || mirrorB == null) return;
    final sameEdge =
        (mirrorA == a && mirrorB == b) || (mirrorA == b && mirrorB == a);
    if (sameEdge) return;
    _toggleEdge(mirrorA, mirrorB);
  }

  /// [removeEditorPoint]'s own index-shifting logic, applied to
  /// [_mirrorOf] instead of edges: drops the entry for the removed point
  /// and shifts every remaining reference above it down by one, so
  /// mirror pairing stays valid the same way edge endpoints do.
  List<int?> _removeMirrorEntry(List<int?> mirrorOf, int index) {
    final result = <int?>[];
    for (var i = 0; i < mirrorOf.length; i++) {
      if (i == index) continue;
      final value = mirrorOf[i];
      result.add(value == null ? null : (value > index ? value - 1 : value));
    }
    return result;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.localPosition;
    _pointerDownIndex = hitTestEditorPoint(event.localPosition, _pixelPoints);
    _isDragging = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final downIndex = _pointerDownIndex;
    final downPosition = _pointerDownPosition;
    if (downIndex == null || downPosition == null) return;

    if (!_isDragging) {
      if ((event.localPosition - downPosition).distance <
          _dragActivationDistance) {
        return;
      }
      _isDragging = true;
      _draggingIndex = downIndex;
      _pushUndoSnapshot();
    }
    setState(() {
      final relative = _toRelative(_snapIfGridEnabled(event.localPosition));
      _points[downIndex] = relative;
      if (!_mirrorEnabled) return;
      final mirrorIndex = downIndex < _mirrorOf.length
          ? _mirrorOf[downIndex]
          : null;
      if (mirrorIndex == null) return;
      // A self-mirrored point (sitting on the axis) stays pinned to it
      // while dragging, rather than drifting off; anything else moves its
      // separate partner to the reflected position instead.
      _points[downIndex == mirrorIndex ? downIndex : mirrorIndex] =
          downIndex == mirrorIndex
          ? (_mirrorVertical
                ? Offset(0.5, relative.dy)
                : Offset(relative.dx, 0.5))
          : _mirrorAcrossAxis(relative);
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    final wasDragging = _isDragging;
    final downIndex = _pointerDownIndex;
    _pointerDownPosition = null;
    _pointerDownIndex = null;
    _isDragging = false;

    if (wasDragging) {
      setState(() => _draggingIndex = null);
      return;
    }
    _handleTap(downIndex, event.localPosition);
  }

  /// The actual tap logic (add/arm/connect), driven by raw pointer events —
  /// see [_dragActivationDistance]'s doc comment for why this isn't a plain
  /// [GestureDetector.onTapUp]. [tapped] is the point that was under the
  /// finger when it went *down* (not up), matching normal touch semantics
  /// and avoiding a second, possibly-different hit test at release.
  void _handleTap(int? tapped, Offset position) {
    if (tapped == null) {
      final relative = _toRelative(_snapIfGridEnabled(position));
      // Mirroring can add two points at once — checked against the cap
      // up front (using the same "would it land on the axis" test
      // [_addPointMaybeMirrored] itself does) rather than after the fact,
      // so a single add never sneaks one point past [_maxEditorPoints].
      final wouldAddTwo =
          _mirrorEnabled &&
          (relative - _mirrorAcrossAxis(relative)).distance >=
              _mirrorAxisEpsilon;
      if (_points.length + (wouldAddTwo ? 2 : 1) > _maxEditorPoints) return;
      _pushUndoSnapshot();
      setState(() {
        if (_mirrorEnabled) {
          _addPointMaybeMirrored(relative);
        } else {
          _points.add(relative);
          _mirrorOf.add(null);
        }
        _armedIndex = null;
      });
      return;
    }

    final armed = _armedIndex;
    if (armed == null) {
      setState(() => _armedIndex = tapped);
      return;
    }
    if (armed == tapped) {
      setState(() => _armedIndex = null);
      return;
    }

    _pushUndoSnapshot();
    setState(() {
      _toggleEdge(armed, tapped);
      if (_mirrorEnabled) _mirrorToggleEdgeIfNeeded(armed, tapped);
      _armedIndex = tapped;
    });
  }

  void _deleteArmedPoint() {
    final index = _armedIndex;
    if (index == null) return;

    _pushUndoSnapshot();
    final mirrorIndex = _mirrorEnabled && index < _mirrorOf.length
        ? _mirrorOf[index]
        : null;
    if (mirrorIndex != null && mirrorIndex != index) {
      // Remove the larger index first so removing it can't shift the
      // smaller one out from under itself.
      final first = math.max(index, mirrorIndex);
      final second = math.min(index, mirrorIndex);
      var (points, edges) = removeEditorPoint(_points, _edges, first);
      var mirrorOf = _removeMirrorEntry(_mirrorOf, first);
      (points, edges) = removeEditorPoint(points, edges, second);
      mirrorOf = _removeMirrorEntry(mirrorOf, second);
      setState(() {
        _points
          ..clear()
          ..addAll(points);
        _edges
          ..clear()
          ..addAll(edges);
        _mirrorOf
          ..clear()
          ..addAll(mirrorOf);
        _armedIndex = null;
      });
      return;
    }

    final (newPoints, newEdges) = removeEditorPoint(_points, _edges, index);
    final newMirrorOf = _removeMirrorEntry(_mirrorOf, index);
    setState(() {
      _mirrorOf
        ..clear()
        ..addAll(newMirrorOf);
      _points
        ..clear()
        ..addAll(newPoints);
      _edges
        ..clear()
        ..addAll(newEdges);
      _armedIndex = null;
    });
  }

  int get _disconnectedCount {
    final connected = <int>{};
    for (final (a, b) in _edges) {
      connected.add(a);
      connected.add(b);
    }
    return _points.length - connected.length;
  }

  /// True once the canvas differs from whatever it started as — an empty
  /// canvas when creating a brand new shape, or [widget.existing]'s /
  /// [widget.initialShape]'s own points/edges otherwise (a preset's own
  /// shape counts here exactly like an already-saved one would: opening
  /// the editor on it and leaving without changing anything isn't a
  /// "change" worth confirming discarding). Compared against those
  /// originals directly rather than a separate "dirty" flag, so undo/redo
  /// back to the exact starting state also correctly clears this.
  bool get _hasUnsavedChanges {
    final startingShape = widget.existing?.shape ?? widget.initialShape;
    final initialPoints = startingShape?.points ?? const <Offset>[];
    final initialEdges = startingShape?.edges ?? const <(int, int)>[];
    return !listEquals(_points, initialPoints) || !listEquals(_edges, initialEdges);
  }

  /// Shared by the back button and the system back gesture (see the
  /// [PopScope] in [build]): leaving with unsaved changes needs
  /// confirmation first, everything else pops right away. [_save] itself
  /// pops directly rather than through here — an explicit [Navigator.pop]
  /// call always succeeds regardless of [PopScope.canPop], so a completed
  /// save is never blocked or re-prompted just because the canvas still
  /// differs from where it started.
  Future<void> _handleBack() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await _confirmDiscard();
    if (discard && mounted) Navigator.of(context).pop();
  }

  /// Styled like the rest of the app's confirmations (see
  /// [SettingsScreen]'s reset-all-data prompt) — a muted cancel next to a
  /// [danger]-colored confirm action.
  Future<bool> _confirmDiscard() async {
    final colors = context.colors;
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
          title: Text(
          strings.discardChangesConfirmTitle,
          style: TextStyle(color: colors.text),
        ),
        content: Text(
          strings.discardChangesConfirmBody,
          style: TextStyle(color: colors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel, style: TextStyle(color: colors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              strings.discardChangesAction,
              style: TextStyle(color: colors.danger),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _save() async {
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _NameConstellationDialog(initialName: widget.existing?.name),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final normalized = normalizeEditorPoints(_points);
    final shape = ConstellationShape(
      points: normalized,
      edges: List.of(_edges),
    );
    final existing = widget.existing;
    final saved = existing == null
        ? await widget.starsShapeRepository.add(
            name: name,
            shape: shape,
          )
        : await widget.starsShapeRepository.update(
            id: existing.id,
            name: name,
            shape: shape,
          );
    if (mounted) Navigator.of(context).pop(saved);
  }

  /// The name to show above the canvas — [widget.existing]'s own, or
  /// [widget.initialShapeName] for a preset opened to look at/fork. Null
  /// only for a genuinely blank canvas, which has no name to show yet.
  String? get _shapeName => widget.existing?.name ?? widget.initialShapeName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    // Enough points to be a real shape *and* something's actually
    // different from wherever this canvas started — see
    // [_hasUnsavedChanges]'s own doc comment for why "started" means an
    // already-saved/preset shape's own points/edges, not just "empty".
    // Reusing it here (rather than a separate points-changed check) means
    // undo/redo back to the exact starting state also correctly turns
    // Save back off.
    final canSave = _points.length >= 2 && _hasUnsavedChanges;
    final disconnected = _disconnectedCount;

    final scaffold = Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: ResponsiveContent(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _handleBack,
                    icon: Icon(Icons.arrow_back, color: colors.muted),
                  ),
                  Expanded(
                    child: Text(
                      widget.existing == null
                          ? strings.constellationEditorTitle
                          : strings.constellationEditorEditTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: colors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _showHelp,
                    icon: Icon(Icons.help_outline, color: colors.muted),
                    tooltip: strings.constellationEditorHelpAction,
                  ),
                ],
              ),
              // The name of the shape being edited — an already-saved
              // one's own name, or a preset's (not yet owned, but already
              // named in the library it came from) — shown either way;
              // only a genuinely blank canvas has nothing to show here,
              // since only then is there truly no name yet (only entered
              // at save time). Used to live inside the canvas's own
              // layout, given a fixed slot above it; moved up here, right
              // under the app bar, now that this region is otherwise just
              // a stack of header rows anyway. Its space stays reserved
              // (`maintainSize`) even with nothing to show — otherwise a
              // blank canvas's header content is shorter than a named
              // one's, which shifts how much room is left below for the
              // switches/canvas/buttons block to center itself in, moving
              // the canvas up or down depending on whether a name happens
              // to be showing above it.
              Visibility(
                visible: _shapeName != null,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: _ShapeNameHeader(name: _shapeName ?? ''),
              ),
              // The two pieces of at-a-glance status this screen has — how
              // many stars are placed (out of [_maxEditorPoints]) and how
              // many of those aren't wired into the shape yet — as one
              // line, bigger and with real breathing room between the two
              // (rather than the small, tight caption this started as),
              // with just the *changing* numbers in bold gold (never
              // [_maxEditorPoints] itself, which never moves) so the two
              // figures that actually matter moment to moment stand out
              // from the words around them. The disconnected count stays
              // on screen even at zero now — always there at the same
              // spot rather than popping in only once it has something to
              // warn about.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text.rich(
                  TextSpan(
                    children: [
                      ..._highlightFirstNumber(
                        strings.constellationEditorStarCount(
                          _points.length,
                          _maxEditorPoints,
                        ),
                        colors,
                      ),
                      TextSpan(text: '     ', style: TextStyle(color: colors.muted)),
                      ..._highlightFirstNumber(
                        strings.constellationEditorDisconnectedWarning(
                          disconnected,
                        ),
                        colors,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: colors.muted),
                ),
              ),
              // Grid/Mirror/Axis, the canvas, and undo/redo/delete as one
              // tight group — the switches row directly above the canvas,
              // the action row directly below it, both close enough to
              // read as one block (see the canvas's own inner padding,
              // which is what actually keeps that gap even on both
              // sides — these two rows carry only side padding of their
              // own). The [Padding] wrapping the whole group is what
              // separates *it* from the info line above and the Save
              // button below; the grid toggle used to live in the app bar
              // on its own, moved here to sit with the two mirror
              // controls instead of splitting canvas-related settings
              // across two different places on screen.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  // The canvas below is squared to *width* (it's almost
                  // always the tighter dimension on a phone), so it ends
                  // up shorter than this whole region is tall — center,
                  // not the plain top-aligned default, is what keeps that
                  // leftover height from piling up as one lopsided gap
                  // below the group; it splits it evenly above and below
                  // instead, which is also why the canvas itself is a
                  // loose [Flexible] rather than an [Expanded] two lines
                  // down — a tight fit would force it to consume all of
                  // this Column's height and re-center *within itself*,
                  // undoing the outer centering.
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _EditorToggle(
                              icon: Icons.grid_on,
                              label: strings.constellationEditorGridToggleLabel,
                              value: _gridEnabled,
                              onChanged: (value) =>
                                  setState(() => _gridEnabled = value),
                            ),
                            const SizedBox(width: 20),
                            _EditorToggle(
                              icon: Icons.flip,
                              label:
                                  strings.constellationEditorMirrorToggleLabel,
                              value: _mirrorEnabled,
                              onChanged: (value) =>
                                  setState(() => _mirrorEnabled = value),
                            ),
                            const SizedBox(width: 20),
                            _EditorToggle(
                              // The icon itself shows which axis is active —
                              // horizontal arrows for a vertical (left/right)
                              // axis, vertical arrows for a horizontal
                              // (top/bottom) one — rather than a fixed icon
                              // next to a switch whose two positions would
                              // otherwise look identical at a glance.
                              icon: _mirrorVertical
                                  ? Icons.swap_horiz
                                  : Icons.swap_vert,
                              label: _mirrorVertical
                                  ? strings
                                        .constellationEditorMirrorAxisVerticalLabel
                                  : strings
                                        .constellationEditorMirrorAxisHorizontalLabel,
                              value: _mirrorVertical,
                              onChanged: (value) =>
                                  setState(() => _mirrorVertical = value),
                            ),
                          ],
                        ),
                      ),
                      // An explicit, equal gap on each side of the canvas —
                      // not padding on the canvas itself, which came out
                      // uneven in practice: the switches row and the
                      // action row don't have the same intrinsic height
                      // (the Switch's own tap target vs. the pill
                      // buttons' padding), so identical [Padding] values
                      // above and below the canvas still landed as
                      // visibly different gaps. A fixed [SizedBox] on
                      // both sides is immune to that — it's the same 8
                      // either way regardless of what's sitting next to
                      // it.
                      const SizedBox(height: 8),
                      Flexible(
                        // The canvas is a square capped to whichever of the
                        // available width/height is smaller — sizing it off
                        // width alone (an AspectRatio taking the Column's
                        // full width) could ask for more height than this
                        // region actually has on a wide-but-short viewport
                        // (typical of a browser window), overflowing past
                        // the controls below it. Loose, not tight
                        // ([Expanded]'s default): tight would force this
                        // slot to consume the Column's *entire* remaining
                        // height even though the square itself is usually
                        // shorter than that, which just re-centers the
                        // square *within* the extra height it didn't need
                        // — invisible padding no [Padding] value here
                        // could ever cancel out. Loose lets the square be
                        // exactly its own computed size, so the Column's
                        // own [mainAxisAlignment.center] (see the Column
                        // above) is what actually absorbs any leftover
                        // height, split evenly above and below the whole
                        // switches/canvas/buttons group instead.
                        fit: FlexFit.loose,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                              final canvasSize = math.min(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              // No [Center] wrapper here — Center always
                              // fills whatever bounded space it's given
                              // (that's what lets it center a child
                              // *within* extra room), so it would report
                              // its own size as the full available height
                              // regardless of [canvasSize] being smaller,
                              // silently defeating the parent [Flexible]'s
                              // `loose` fit above. A bare [SizedBox]
                              // reports its true, exact size instead, which
                              // is what the outer Column's own
                              // [mainAxisAlignment.center] needs to
                              // actually have leftover height to work
                              // with.
                              return SizedBox(
                                width: canvasSize,
                                height: canvasSize,
                                child: LayoutBuilder(
                                  builder: (context, canvasConstraints) {
                                      _canvasSize = canvasConstraints.biggest;
                                      return Listener(
                                        behavior: HitTestBehavior.opaque,
                                        onPointerDown: _handlePointerDown,
                                        onPointerMove: _handlePointerMove,
                                        onPointerUp: _handlePointerUp,
                                        child: Container(
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            color: colors.nightPanel,
                                            border: Border.all(
                                              color: colors.nightBorder,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Stack(
                                            children: [
                                              if (_gridEnabled)
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter: _GridPainter(
                                                      divisions:
                                                          _gridDivisions,
                                                      color:
                                                          colors.nightBorder,
                                                      // Just a touch
                                                      // brighter than the
                                                      // regular grid lines —
                                                      // a small blend
                                                      // toward `muted`
                                                      // rather than jumping
                                                      // straight to it, so
                                                      // the center reads as
                                                      // "the same grid,
                                                      // slightly lifted"
                                                      // rather than a
                                                      // visually distinct
                                                      // line.
                                                      centerColor: Color.lerp(
                                                        colors.nightBorder,
                                                        colors.muted,
                                                        0.3,
                                                      )!,
                                                    ),
                                                  ),
                                                ),
                                              if (_mirrorEnabled)
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter: _MirrorAxisPainter(
                                                      vertical: _mirrorVertical,
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              // No empty-canvas hint any
                                              // more — the grid plus the
                                              // help action already say
                                              // enough, and an always-on
                                              // canvas (no swap between a
                                              // hint and the painter) is
                                              // one less thing to jump the
                                              // moment the first star
                                              // lands.
                                              CustomPaint(
                                                size:
                                                    canvasConstraints.biggest,
                                                painter:
                                                    ConstellationEditorPainter(
                                                      points: _pixelPoints,
                                                      edges: _edges,
                                                      highlightedIndex:
                                                          _armedIndex ??
                                                          _draggingIndex,
                                                      pointColor: colors.text,
                                                      highlightColor:
                                                          colors.gold,
                                                      lineColor: Colors.white
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                            },
                          ),
                        ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        // A Row of Flexible buttons, not a Wrap — a Wrap
                        // drops to a second line once the three pills stop
                        // fitting (which a longer translation, e.g.
                        // Romanian, hits easily), while Flexible instead
                        // lets each pill's own label ellipsize so all three
                        // always stay on one row.
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: PillActionButton(
                                icon: Icons.undo,
                                label: strings.undoAction,
                                onTap: _undoStack.isEmpty ? null : _undo,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: PillActionButton(
                                icon: Icons.redo,
                                label: strings.redoAction,
                                onTap: _redoStack.isEmpty ? null : _redo,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: PillActionButton(
                                icon: Icons.delete_outline,
                                label: strings.deletePointAction,
                                onTap: _armedIndex == null
                                    ? null
                                    : _deleteArmedPoint,
                                danger: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                // Top is small on purpose — the group above already ends
                // in its own [vertical: 12] padding (see the Expanded
                // wrapping the switches/canvas/action-row block), so this
                // is only the little bit more needed to read as a clear
                // gap before Save rather than double-padding the same gap.
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Center(
                  child: SaveActionButton(
                    label: strings.saveConstellationAction,
                    lit: canSave,
                    onPressed: canSave ? _save : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: scaffold,
    );
  }
}

/// One icon+switch pair in the Grid/Mirror/Axis row above the canvas, with
/// its own [label] — same compact "small icon beside a scaled-down
/// [Switch]" shape the grid toggle already used in the app bar, factored
/// out now that there are three of these side by side instead of one.
/// The label itself stays off-screen (a [Tooltip] rather than visible
/// text — three captions was what pushed this row into overflow), with
/// the icon sized up in its place so what each switch does still reads at
/// a glance without the width a caption needs.
class _EditorToggle extends StatelessWidget {
  const _EditorToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: label,
          child: Icon(icon, size: 27, color: colors.muted),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            // [Transform.scale] only shrinks what's painted, not the
            // widget's own layout box — left at the default `padded`
            // tap target, the Switch still reserves its full 48dp-tall
            // footprint, which is what was actually keeping this row
            // (and so the canvas below it) far from where the tiny
            // [Padding] values above would suggest.
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

/// The line marking where [_StarsShapeEditorScreenState._mirrorEnabled]
/// splits the canvas in two — the exact vertical or horizontal center
/// line, matching [_StarsShapeEditorScreenState._mirrorAcrossAxis]'s own
/// reflection (a point exactly on this line reflects to itself). Purely a
/// visual reference, the same role [_GridPainter] plays for
/// [_snapIfGridEnabled]'s own grid.
class _MirrorAxisPainter extends CustomPainter {
  const _MirrorAxisPainter({required this.vertical, required this.color});

  final bool vertical;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    if (vertical) {
      final x = size.width / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    } else {
      final y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MirrorAxisPainter oldDelegate) =>
      vertical != oldDelegate.vertical || color != oldDelegate.color;
}

/// The name of the shape being edited, shown above the canvas — see
/// [_StarsShapeEditorScreenState._shapeName] for where it comes from
/// (an already-saved shape's own name, or a preset's). A shape only ever
/// has a name — no description (see [StarsShape]'s own doc
/// comment: the same shape can be reused across several projects, so
/// "what it means" belongs to the project, not the shape).
class _ShapeNameHeader extends StatelessWidget {
  const _ShapeNameHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        // Symmetric top/bottom — was 4/14 before, which pushed the title
        // toward the top of its own block instead of centering it there.
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: colors.text,
          ),
        ),
      ),
    );
  }
}

/// One row of the help dialog: a small hand-drawn-looking diagram (see
/// [_GestureDiagram]) illustrating the gesture, next to its text
/// description — a picture of the before/after state reads faster than the
/// sentence alone, especially for the two-tap connect/disconnect gestures
/// that are hardest to describe in words.
class _HelpBullet extends StatelessWidget {
  const _HelpBullet({required this.text, required this.illustration});

  final String text;
  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          illustration,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.muted, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where one dot sits in a [_GestureDiagram]'s normalized (0..1) box, and
/// how it should be drawn: [ghost] for "not there yet / no longer there"
/// (a dashed outline instead of a filled dot), [ringed] for "currently
/// selected/armed" (an extra gold ring, matching
/// [ConstellationEditorPainter]'s own selection ring in the real canvas).
class _DiagramDot {
  const _DiagramDot(this.position, {this.ghost = false, this.ringed = false});

  final Offset position;
  final bool ghost;
  final bool ringed;
}

/// A tiny, static before/after illustration for one editor gesture — dots,
/// optional connecting/trailing lines, an optional center arrow, and an
/// optional small icon overlay (tap, drag, delete) — built entirely from
/// [CustomPainter] primitives plus a couple of [Icon]s, so no image assets
/// are needed. Colors are resolved from the active theme at build time
/// (via `context.colors`) rather than passed in, so every diagram instance
/// below can be a compile-time `const`.
class _GestureDiagram extends StatelessWidget {
  const _GestureDiagram({
    required this.dots,
    this.line,
    this.trail,
    this.showArrow = false,
    this.icon,
    this.iconAt,
    this.iconIsDanger = false,
    this.axisLine,
  });

  final List<_DiagramDot> dots;

  /// A solid connecting line between two dots (by index) — "these two stars
  /// are now linked".
  final (int, int)? line;

  /// A dashed line between two dots (by index) — a drag trail from where a
  /// star used to be to where it is now.
  final (int, int)? trail;

  /// A short horizontal arrow through the diagram's center, for a
  /// before/after state change that isn't a physical connection or move
  /// (e.g. "armed" → "not armed", "here" → "deleted").
  final bool showArrow;

  final IconData? icon;
  final Offset? iconAt;
  final bool iconIsDanger;

  /// A static line through the diagram's center, standing in for the
  /// mirror axis itself — `true` for the vertical (left/right) axis,
  /// `false` for the horizontal (top/bottom) one. Independent of [dots];
  /// unlike [line]/[trail] it isn't anchored to any star.
  final bool? axisLine;

  static const _width = 74.0;
  static const _height = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final iconAtValue = iconAt;
    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(_width, _height),
            painter: _GestureDiagramPainter(
              dots: dots,
              line: line,
              trail: trail,
              showArrow: showArrow,
              axisLine: axisLine,
              dotColor: colors.text,
              ghostColor: colors.muted,
              ringColor: colors.gold,
              lineColor: colors.gold,
              arrowColor: colors.muted,
              axisColor: colors.muted,
            ),
          ),
          if (icon != null && iconAtValue != null)
            Positioned(
              left: iconAtValue.dx * _width - 8,
              top: iconAtValue.dy * _height - 8,
              child: Icon(
                icon,
                size: 15,
                color: iconIsDanger ? colors.danger : colors.gold,
              ),
            ),
        ],
      ),
    );
  }
}

class _GestureDiagramPainter extends CustomPainter {
  const _GestureDiagramPainter({
    required this.dots,
    required this.line,
    required this.trail,
    required this.showArrow,
    required this.axisLine,
    required this.dotColor,
    required this.ghostColor,
    required this.ringColor,
    required this.lineColor,
    required this.arrowColor,
    required this.axisColor,
  });

  final List<_DiagramDot> dots;
  final (int, int)? line;
  final (int, int)? trail;
  final bool showArrow;
  final bool? axisLine;
  final Color dotColor;
  final Color ghostColor;
  final Color ringColor;
  final Color lineColor;
  final Color arrowColor;
  final Color axisColor;

  static const _dotRadius = 4.0;
  static const _ringRadius = 7.5;
  static const _ghostRadius = 5.0;

  Offset _px(Offset normalized, Size size) =>
      Offset(normalized.dx * size.width, normalized.dy * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final axis = axisLine;
    if (axis != null) {
      final axisPaint = Paint()
        ..color = axisColor
        ..strokeWidth = 1.2;
      if (axis) {
        final x = size.width / 2;
        _drawDashedLine(
          canvas,
          Offset(x, 0),
          Offset(x, size.height),
          axisPaint,
        );
      } else {
        final y = size.height / 2;
        _drawDashedLine(
          canvas,
          Offset(0, y),
          Offset(size.width, y),
          axisPaint,
        );
      }
    }

    final solidLine = line;
    if (solidLine != null) {
      canvas.drawLine(
        _px(dots[solidLine.$1].position, size),
        _px(dots[solidLine.$2].position, size),
        Paint()
          ..color = lineColor
          ..strokeWidth = 1.5,
      );
    }

    final dashedTrail = trail;
    if (dashedTrail != null) {
      _drawDashedLine(
        canvas,
        _px(dots[dashedTrail.$1].position, size),
        _px(dots[dashedTrail.$2].position, size),
        Paint()
          ..color = ghostColor
          ..strokeWidth = 1.2,
      );
    }

    for (final dot in dots) {
      final center = _px(dot.position, size);
      if (dot.ghost) {
        _drawDashedCircle(
          canvas,
          center,
          _ghostRadius,
          Paint()
            ..color = ghostColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      } else {
        canvas.drawCircle(center, _dotRadius, Paint()..color = dotColor);
      }
      if (dot.ringed) {
        canvas.drawCircle(
          center,
          _ringRadius,
          Paint()
            ..color = ringColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    if (showArrow) {
      final y = size.height / 2;
      final start = Offset(size.width * 0.4, y);
      final end = Offset(size.width * 0.6, y);
      final arrowPaint = Paint()
        ..color = arrowColor
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(start, end, arrowPaint);
      final headPath = Path()
        ..moveTo(end.dx - 4, end.dy - 3)
        ..lineTo(end.dx, end.dy)
        ..lineTo(end.dx - 4, end.dy + 3);
      canvas.drawPath(headPath, arrowPaint);
    }
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    const dashCount = 10;
    for (var i = 0; i < dashCount; i += 2) {
      final startAngle = (i / dashCount) * 2 * math.pi;
      const sweep = (1 / dashCount) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLength = 3.0, gapLength = 2.5;
    final total = (b - a).distance;
    if (total == 0) return;
    final direction = (b - a) / total;
    var covered = 0.0;
    while (covered < total) {
      final segmentEnd = math.min(covered + dashLength, total);
      canvas.drawLine(
        a + direction * covered,
        a + direction * segmentEnd,
        paint,
      );
      covered = segmentEnd + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _GestureDiagramPainter oldDelegate) => false;
}

const _addPointDiagram = _GestureDiagram(
  dots: [
    _DiagramDot(Offset(0.28, 0.5), ghost: true),
    _DiagramDot(Offset(0.75, 0.5)),
  ],
  showArrow: true,
  icon: Icons.touch_app,
  iconAt: Offset(0.28, 0.15),
);

const _connectDiagram = _GestureDiagram(
  dots: [
    _DiagramDot(Offset(0.25, 0.5), ringed: true),
    _DiagramDot(Offset(0.75, 0.5)),
  ],
  line: (0, 1),
  icon: Icons.touch_app,
  iconAt: Offset(0.75, 0.15),
);

const _disarmDiagram = _GestureDiagram(
  dots: [
    _DiagramDot(Offset(0.3, 0.5), ringed: true),
    _DiagramDot(Offset(0.7, 0.5)),
  ],
  showArrow: true,
  icon: Icons.touch_app,
  iconAt: Offset(0.3, 0.15),
);

const _moveDiagram = _GestureDiagram(
  dots: [
    _DiagramDot(Offset(0.25, 0.72), ghost: true),
    _DiagramDot(Offset(0.75, 0.28)),
  ],
  trail: (0, 1),
  icon: Icons.pan_tool_alt,
  iconAt: Offset(0.25, 0.72),
);

const _deleteDiagram = _GestureDiagram(
  dots: [
    _DiagramDot(Offset(0.3, 0.5), ringed: true),
    _DiagramDot(Offset(0.7, 0.5), ghost: true),
  ],
  showArrow: true,
  icon: Icons.delete_outline,
  iconAt: Offset(0.7, 0.15),
  iconIsDanger: true,
);

const _mirrorDiagram = _GestureDiagram(
  dots: [_DiagramDot(Offset(0.3, 0.5)), _DiagramDot(Offset(0.7, 0.5))],
  axisLine: true,
  icon: Icons.touch_app,
  iconAt: Offset(0.3, 0.15),
);

/// Small enough that it doesn't need a full [_GestureDiagram] — the axis
/// switch is self-explanatory (its own icon already shows which way it's
/// set, see the editor's mirror-axis toggle), this just gives the bullet
/// row below it the same icon-sized illustration slot the other rows have.
class _MirrorAxisSwitchIllustration extends StatelessWidget {
  const _MirrorAxisSwitchIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: _GestureDiagram._width,
      height: _GestureDiagram._height,
      child: Center(
        child: Icon(Icons.swap_horiz, color: colors.muted, size: 22),
      ),
    );
  }
}

/// A graph-paper backdrop for the editor canvas: a uniform grid dividing
/// the whole canvas — the one "big square" — into [divisions] equal small
/// ones on each axis, with the center vertical/horizontal line emphasized
/// (see [centerColor]) so the middle of the shape stays easy to spot.
/// Purely decorative (and a visual reference for [_snapIfGridEnabled]'s
/// vertices).
class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.divisions,
    required this.color,
    required this.centerColor,
  });

  final int divisions;
  final Color color;

  /// The one vertical and one horizontal line through the exact center
  /// (only when [divisions] is even — [_StarsShapeEditorScreenState._gridDivisions]
  /// is fixed at 10, so this always lands cleanly) are drawn in this
  /// brighter shade of the same neutral grid color, same stroke width as
  /// every other line — just enough to keep the canvas's center visible at
  /// a glance without turning it into a visually distinct accent line.
  final Color centerColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (divisions <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final centerPaint = Paint()
      ..color = centerColor
      ..strokeWidth = 1;
    final centerIndex = divisions / 2;

    for (var i = 0; i <= divisions; i++) {
      final x = size.width * i / divisions;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i == centerIndex ? centerPaint : paint,
      );
    }
    for (var i = 0; i <= divisions; i++) {
      final y = size.height * i / divisions;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        i == centerIndex ? centerPaint : paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return divisions != oldDelegate.divisions ||
        color != oldDelegate.color ||
        centerColor != oldDelegate.centerColor;
  }
}

/// The "name your constellation" prompt shown by [_StarsShapeEditorScreenState._save]
/// — its own [TextEditingController] lives and dies with *this widget's*
/// element, not with the `showDialog` call's Future. `showDialog`'s Future
/// resolves the instant `Navigator.pop` is called, before the dialog route's
/// exit transition has actually finished removing this widget's `TextField`
/// from the tree — disposing the controller right after that `await` (as
/// this used to) could hit a still-animating, still-mounted `TextField`
/// still holding the disposed controller, throwing "used after being
/// disposed" for the transition's remaining frames (the app's own users
/// reported this as a brief red error screen right after saving a shape,
/// self-recovering once the dialog actually finished closing). Owning the
/// controller here instead means Flutter disposes it at the correct moment
/// on its own — when this widget's own `State` actually unmounts.
class _NameConstellationDialog extends StatefulWidget {
  const _NameConstellationDialog({this.initialName});

  final String? initialName;

  @override
  State<_NameConstellationDialog> createState() =>
      _NameConstellationDialogState();
}

class _NameConstellationDialogState extends State<_NameConstellationDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    return AlertDialog(
      title: Text(
        strings.nameYourConstellationTitle,
        style: TextStyle(color: colors.text),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(color: colors.text),
        decoration: InputDecoration(hintText: strings.constellationNameHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel, style: TextStyle(color: colors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(
            strings.saveConstellationAction,
            style: TextStyle(color: colors.gold),
          ),
        ),
      ],
    );
  }
}
