part of 'controllers.dart';

abstract interface class TooltipOverlayController {
  bool get isMounted;
  bool get hasEntries;

  bool show({
    required OverlayState overlay,
    required OverlayEntry panelEntry,
    OverlayEntry? barrierEntry,
  });

  bool reopen();
  void refresh();
  Future<bool> hide();
  void removeImmediately();
  void dispose();
}

/// Controls the lifecycle of the overlay entries used by a TooltipCard.
///
/// This controller owns the imperative framework interaction while the widget
/// remains responsible for creating views. A monotonically increasing
/// transition token prevents a stale close animation from removing an overlay
/// that has already been opened again.
class TooltipCardOverlayController implements TooltipOverlayController {
  TooltipCardOverlayController({required AnimationController animation})
    : _animation = animation;

  final AnimationController _animation;

  OverlayEntry? _barrierEntry;
  OverlayEntry? _panelEntry;
  int _transitionToken = 0;
  bool _disposed = false;

  @override
  bool get isMounted => _panelEntry?.mounted ?? false;
  @override
  bool get hasEntries => _panelEntry != null;

  /// Inserts new entries or refreshes and reopens the existing entries.
  @override
  bool show({
    required OverlayState overlay,
    required OverlayEntry panelEntry,
    OverlayEntry? barrierEntry,
  }) {
    if (_disposed) return false;

    _transitionToken++;

    if (_panelEntry != null) {
      _markEntriesNeedingBuild();
      unawaited(_animation.forward());
      return false;
    }

    _panelEntry = panelEntry;
    _barrierEntry = barrierEntry;

    if (barrierEntry != null) {
      overlay.insertAll([barrierEntry, panelEntry]);
    } else {
      overlay.insert(panelEntry);
    }

    unawaited(_animation.forward(from: 0));
    return true;
  }

  /// Cancels a pending close and animates the existing entries open again.
  @override
  bool reopen() {
    if (_disposed || _panelEntry == null) return false;
    _transitionToken++;
    refresh();
    unawaited(_animation.forward());
    return true;
  }

  /// Rebuilds mounted entries after data, theme, or geometry changes.
  @override
  void refresh() {
    if (_disposed) return;
    _markEntriesNeedingBuild();
  }

  /// Marks both entries dirty — deferred one frame when a frame is already
  /// mid-build.
  ///
  /// `TooltipCard.didUpdateWidget` calls [refresh] unconditionally whenever
  /// the overlay is open (see its own call site), which makes this run
  /// during a build far more often than `show`/`reopen`'s own direct calls
  /// do — any prop change on `TooltipCard` while its tooltip is showing
  /// reaches here mid-build. `OverlayEntry.markNeedsBuild()` on an entry
  /// the build pass has already visited this frame is illegal outside that
  /// window (Flutter's own rule: only a still-to-be-visited *descendant*
  /// may be dirtied mid-build), which is exactly what live inner_stars
  /// hit — updating a still-open sky tooltip's data from a post-frame
  /// callback schedules the very rebuild that then calls this from inside
  /// `didUpdateWidget`, and the entries hosting the tooltip sit earlier in
  /// the tree than the widget that triggers it. Checking the scheduler
  /// phase and deferring to `addPostFrameCallback` when unsafe sidesteps
  /// that without changing behaviour for the ordinary (outside-build)
  /// case, which stays synchronous.
  void _markEntriesNeedingBuild() {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        _barrierEntry?.markNeedsBuild();
        _panelEntry?.markNeedsBuild();
      });
      return;
    }
    _barrierEntry?.markNeedsBuild();
    _panelEntry?.markNeedsBuild();
  }

  /// Reverses the animation and removes entries if this close operation is
  /// still current when the animation completes.
  @override
  Future<bool> hide() async {
    if (_disposed || _panelEntry == null) return false;

    final token = ++_transitionToken;
    try {
      await _animation.reverse().orCancel;
    } on TickerCanceled {
      return false;
    }

    if (_disposed || token != _transitionToken || _panelEntry == null) {
      return false;
    }

    _removeEntries();
    return true;
  }

  @override
  void removeImmediately() {
    if (_disposed) return;
    _transitionToken++;
    _removeEntries();
  }

  void _removeEntries() {
    final panelEntry = _panelEntry;
    final barrierEntry = _barrierEntry;
    if (panelEntry?.mounted ?? false) panelEntry!.remove();
    if (barrierEntry?.mounted ?? false) barrierEntry!.remove();
    _panelEntry = null;
    _barrierEntry = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _transitionToken++;
    _removeEntries();
  }
}
