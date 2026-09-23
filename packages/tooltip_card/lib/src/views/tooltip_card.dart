part of 'views.dart';

/// A customizable tooltip/callout widget.
///
/// The implementation follows MVC responsibilities:
/// - [TooltipCardViewModel] resolves immutable presentation values.
/// - [TooltipCardController] and [TooltipCardOverlayController] own state and
///   imperative lifecycle decisions.
/// - the trigger, barrier, overlay, and panel classes render the views.
class TooltipCard extends StatefulWidget {
  const TooltipCard.builder({
    super.key,
    required this.child,
    required this.builder,
    this.whenContentHide = WhenContentHide.goAway,
    @Deprecated('Use triggerMode instead') this.whenContentVisible,
    this.triggerMode,
    Duration? hoverOpenDelay,
    Duration? hoverCloseDelay,
    double? awaySpace,
    this.placementSide = TooltipCardPlacementSide.top,
    this.flyoutBackgroundColor,
    double? elevation,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    this.controller,
    BoxConstraints? constraints,
    this.onOpenChanged,
    this.onOpen,
    this.onClose,
    this.useRootOverlay = true,
    this.publicState,
    this.fitToViewport = true,
    this.viewportMargin = const EdgeInsetsDirectional.all(8),
    this.autoFlipIfZeroSpace = true,
    this.wrapContentInScrollView = true,
    this.modalBarrierEnabled = false,
    this.barrierColor,
    double? barrierBlur,
    this.barrierDismissible,
    this.dismissOnPointerMoveAway = false,
    Duration? showDuration,
    this.offset = Offset.zero,
    bool? beakEnabled,
    double? beakSize,
    double? beakInset,
    this.beakColor,
    this.borderColor,
    double? borderWidth,
    this.animation = TooltipCardAnimation.fadeScale,
  }) : flyoutContent = null,
       _hoverOpenDelay = hoverOpenDelay,
       _hoverCloseDelay = hoverCloseDelay,
       _awaySpace = awaySpace,
       _elevation = elevation,
       _borderRadius = borderRadius,
       _padding = padding,
       _constraints = constraints,
       _barrierBlur = barrierBlur,
       _showDuration = showDuration,
       _beakEnabled = beakEnabled,
       _beakSize = beakSize,
       _beakInset = beakInset,
       _borderWidth = borderWidth,
       _defaults = const TooltipCardDefaults.builder();

  const TooltipCard({
    super.key,
    required this.child,
    required this.flyoutContent,
    this.controller,
    this.whenContentHide = WhenContentHide.goAway,
    @Deprecated('Use triggerMode instead') this.whenContentVisible,
    this.triggerMode,
    Duration? hoverOpenDelay,
    Duration? hoverCloseDelay,
    double? awaySpace,
    this.placementSide = TooltipCardPlacementSide.bottom,
    this.flyoutBackgroundColor,
    double? elevation,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    BoxConstraints? constraints,
    this.onOpenChanged,
    this.onOpen,
    this.onClose,
    this.useRootOverlay = true,
    this.publicState,
    this.fitToViewport = true,
    this.viewportMargin = const EdgeInsetsDirectional.all(8),
    this.autoFlipIfZeroSpace = true,
    this.wrapContentInScrollView = true,
    this.modalBarrierEnabled = false,
    this.barrierColor,
    double? barrierBlur,
    this.barrierDismissible,
    this.dismissOnPointerMoveAway = false,
    Duration? showDuration,
    this.offset = Offset.zero,
    bool? beakEnabled,
    double? beakSize,
    double? beakInset,
    this.beakColor,
    this.borderColor,
    double? borderWidth,
    this.animation = TooltipCardAnimation.fadeScale,
  }) : builder = null,
       _hoverOpenDelay = hoverOpenDelay,
       _hoverCloseDelay = hoverCloseDelay,
       _awaySpace = awaySpace,
       _elevation = elevation,
       _borderRadius = borderRadius,
       _padding = padding,
       _constraints = constraints,
       _barrierBlur = barrierBlur,
       _showDuration = showDuration,
       _beakEnabled = beakEnabled,
       _beakSize = beakSize,
       _beakInset = beakInset,
       _borderWidth = borderWidth,
       _defaults = const TooltipCardDefaults.content();

  final Widget? flyoutContent;
  final Widget Function(BuildContext context, VoidCallback close)? builder;
  final Widget child;
  final WhenContentHide whenContentHide;

  @Deprecated('Use triggerMode instead')
  final WhenContentVisible? whenContentVisible;

  final Set<WhenContentVisible>? triggerMode;
  final Duration? _hoverOpenDelay;
  final Duration? _hoverCloseDelay;
  final double? _awaySpace;
  final TooltipCardPlacementSide placementSide;
  final Color? flyoutBackgroundColor;
  final double? _elevation;
  final BorderRadius? _borderRadius;
  final EdgeInsetsGeometry? _padding;
  final BoxConstraints? _constraints;
  final TooltipCardController? controller;
  final ValueChanged<bool>? onOpenChanged;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final bool useRootOverlay;
  final TooltipCardPublicState? publicState;
  final bool fitToViewport;
  final EdgeInsetsDirectional viewportMargin;
  final bool autoFlipIfZeroSpace;
  final bool wrapContentInScrollView;
  final bool modalBarrierEnabled;
  final Color? barrierColor;
  final double? _barrierBlur;
  final bool? barrierDismissible;
  final bool dismissOnPointerMoveAway;
  final Duration? _showDuration;
  final Offset offset;
  final bool? _beakEnabled;
  final double? _beakSize;
  final double? _beakInset;
  final TooltipCardDefaults _defaults;
  final Color? beakColor;
  final Color? borderColor;
  final double? _borderWidth;
  final TooltipCardAnimation animation;

  /// Effective non-themed fallback values retained for API compatibility.
  Duration get hoverOpenDelay =>
      _hoverOpenDelay ?? _defaults.hoverOpenDelay;
  Duration get hoverCloseDelay =>
      _hoverCloseDelay ?? _defaults.hoverCloseDelay;
  double get awaySpace => _awaySpace ?? _defaults.awaySpace;
  double get elevation =>
      _elevation ?? _defaults.elevation;
  BorderRadius get borderRadius =>
      _borderRadius ?? _defaults.borderRadius;
  EdgeInsetsGeometry get padding => _padding ?? _defaults.padding;
  BoxConstraints? get constraints => _constraints;
  double get barrierBlur => _barrierBlur ?? _defaults.barrierBlur;
  Duration? get showDuration => _showDuration;
  bool get beakEnabled => _beakEnabled ?? _defaults.beakEnabled;
  double get beakSize =>
      _beakSize ?? _defaults.beakSize;
  double get beakInset =>
      _beakInset ?? _defaults.beakInset;
  double get borderWidth => _borderWidth ?? _defaults.borderWidth;

  @override
  State<TooltipCard> createState() => _TooltipCardState();
}

class _TooltipCardState extends State<TooltipCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey _targetKey = GlobalKey();

  late TooltipCardController _controller;
  late TooltipCardPublicState _publicState;
  late bool _ownsController;
  late AnimationController _animationController;
  late TooltipOverlayController _overlayController;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<Offset> _slide;

  TooltipCardPlacementSide _resolvedSide = TooltipCardPlacementSide.top;
  double _resolvedBeakPosition = 0;
  bool _hoverTarget = false;
  bool _hoverPanel = false;
  Timer? _hoverTimer;
  Timer? _showDurationTimer;
  ScrollPosition? _scrollPosition;

  Set<WhenContentVisible> get _triggers {
    final triggerMode = widget.triggerMode;
    if (triggerMode != null && triggerMode.isNotEmpty) return triggerMode;
    if (widget.whenContentVisible != null) {
      // ignore: deprecated_member_use_from_same_package
      return {widget.whenContentVisible!};
    }
    return {WhenContentVisible.pressButton};
  }

  bool get _isPressLike =>
      _triggers.contains(WhenContentVisible.pressButton) ||
      _triggers.contains(WhenContentVisible.doubleTapButton) ||
      _triggers.contains(WhenContentVisible.secondaryTapButton) ||
      _triggers.contains(WhenContentVisible.longPressButton) ||
      _triggers.contains(WhenContentVisible.longPressUpButton) ||
      _triggers.contains(WhenContentVisible.forcePressButton);

  bool get _shouldAutoCloseOnHoverOut {
    if (widget.modalBarrierEnabled) return false;
    if (_triggers.contains(WhenContentVisible.hoverButton)) return true;
    return (_isPressLike && widget.whenContentHide == WhenContentHide.goAway) ||
        widget.dismissOnPointerMoveAway;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolvedSide = widget.placementSide;
    _attachController(widget.controller);
    _publicState = widget.publicState ?? TooltipCardPublicState.global;
    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration(widget.animation),
      reverseDuration: TooltipCardTiming.exitDuration,
    );
    _overlayController = TooltipCardOverlayController(
      animation: _animationController,
    );
    _configureAnimations();
    if (_controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleControllerChange();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (identical(nextPosition, _scrollPosition)) return;
    _scrollPosition?.removeListener(_refreshOverlay);
    _scrollPosition = nextPosition;
    _scrollPosition?.addListener(_refreshOverlay);
  }

  @override
  void didChangeMetrics() => _refreshOverlay();

  @override
  void didUpdateWidget(covariant TooltipCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.controller, widget.controller)) {
      final previousController = _controller;
      _publicState.registerClose(previousController);
      _detachController();
      _attachController(widget.controller);
      if (_controller.isOpen) {
        _handleControllerChange();
      } else if (_overlayController.hasEntries) {
        _hideTooltipCard();
      }
    }

    if (!identical(oldWidget.publicState, widget.publicState)) {
      _publicState.registerClose(_controller);
      _publicState = widget.publicState ?? TooltipCardPublicState.global;
      if (_controller.isOpen) _publicState.registerOpen(_controller);
    }

    if (oldWidget.animation != widget.animation ||
        oldWidget.placementSide != widget.placementSide) {
      _resolvedSide = widget.placementSide;
      _animationController.duration = _animationDuration(widget.animation);
      _configureAnimations();
    }

    if (_overlayController.hasEntries) _refreshOverlay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_refreshOverlay);
    _hoverTimer?.cancel();
    _showDurationTimer?.cancel();
    _publicState.registerClose(_controller);
    _detachController();
    _overlayController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _attachController(TooltipCardController? externalController) {
    _ownsController = externalController == null;
    _controller = externalController ?? TooltipCardController<Object?>();
    _controller.addListener(_handleControllerChange);
  }

  void _detachController() {
    _controller.removeListener(_handleControllerChange);
    if (_ownsController) _controller.dispose();
  }

  Duration _animationDuration(TooltipCardAnimation animation) {
    switch (animation) {
      case TooltipCardAnimation.none:
        return Duration.zero;
      case TooltipCardAnimation.bounce:
      case TooltipCardAnimation.elastic:
        return const Duration(milliseconds: 400);
      case TooltipCardAnimation.zoom:
        return const Duration(milliseconds: 300);
      default:
        return TooltipCardTiming.enterDuration;
    }
  }

  void _configureAnimations() {
    _fade = CurvedAnimation(
      parent: _animationController,
      curve: TooltipCardCurves.fade,
      reverseCurve: TooltipCardCurves.fadeOut,
    );

    final scaleConfig = _scaleConfig(widget.animation);
    _scale = Tween<double>(begin: scaleConfig.$1, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: scaleConfig.$2,
        reverseCurve: scaleConfig.$3,
      ),
    );

    _slide = Tween<Offset>(
      begin: _slideOffset(_resolvedSide),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: TooltipCardCurves.slideIn,
        reverseCurve: TooltipCardCurves.slideOut,
      ),
    );
  }

  (double, Curve, Curve) _scaleConfig(TooltipCardAnimation animation) {
    switch (animation) {
      case TooltipCardAnimation.scale:
      case TooltipCardAnimation.fadeScale:
        return (0.88, TooltipCardCurves.scaleIn, TooltipCardCurves.scaleOut);
      case TooltipCardAnimation.bounce:
        return (0.5, TooltipCardCurves.bounce, TooltipCardCurves.scaleOut);
      case TooltipCardAnimation.elastic:
        return (0.6, TooltipCardCurves.elastic, TooltipCardCurves.scaleOut);
      case TooltipCardAnimation.zoom:
        return (0.3, TooltipCardCurves.zoom, TooltipCardCurves.zoomOut);
      case TooltipCardAnimation.fade:
      case TooltipCardAnimation.slideIn:
      case TooltipCardAnimation.slideFade:
      case TooltipCardAnimation.none:
        return (1, Curves.linear, Curves.linear);
    }
  }

  Offset _slideOffset(TooltipCardPlacementSide side) {
    const amount = 0.1;
    switch (side.baseSide) {
      case TooltipCardPlacementSide.top:
        return const Offset(0, amount);
      case TooltipCardPlacementSide.bottom:
        return const Offset(0, -amount);
      case TooltipCardPlacementSide.start:
        return const Offset(amount, 0);
      case TooltipCardPlacementSide.end:
        return const Offset(-amount, 0);
      default:
        return Offset.zero;
    }
  }

  TooltipCardViewModel _resolveViewModel(BuildContext context) {
    return TooltipCardViewModel.resolve(
      materialTheme: Theme.of(context),
      defaults: widget._defaults,
      backgroundColor: widget.flyoutBackgroundColor,
      beakColor: widget.beakColor,
      borderColor: widget.borderColor,
      borderWidth: widget._borderWidth,
      elevation: widget._elevation,
      borderRadius: widget._borderRadius,
      padding: widget._padding,
      constraints: widget._constraints,
      awaySpace: widget._awaySpace,
      beakEnabled: widget._beakEnabled,
      beakSize: widget._beakSize,
      beakInset: widget._beakInset,
      hoverOpenDelay: widget._hoverOpenDelay,
      hoverCloseDelay: widget._hoverCloseDelay,
      showDuration: widget._showDuration,
      barrierColor: widget.barrierColor,
      barrierBlur: widget._barrierBlur,
    );
  }

  void _handleControllerChange() {
    if (!mounted) return;

    setState(() {});
    if (_controller.isOpen) {
      _publicState.registerOpen(_controller);
      _showTooltipCard();
    } else {
      _publicState.registerClose(_controller);
      _hideTooltipCard();
    }
  }

  void _toggleFromPressLike() {
    if (widget.whenContentHide == WhenContentHide.goAway) {
      _controller.toggle();
    } else {
      _controller.open();
    }
  }

  void _onTargetHoverChanged(bool hovered) {
    _hoverTarget = hovered;
    _hoverTimer?.cancel();

    if (hovered) {
      final model = _resolveViewModel(context);
      _hoverTimer = Timer(model.hoverOpenDelay, () {
        if (mounted && _hoverTarget) _controller.open();
      });
    } else {
      _scheduleMaybeClose();
    }
  }

  void _onPanelHoverChanged(bool hovered) {
    _hoverPanel = hovered;
    _hoverTimer?.cancel();
    if (!hovered) _scheduleMaybeClose();
  }

  void _scheduleMaybeClose() {
    if (!_shouldAutoCloseOnHoverOut) return;
    final model = _resolveViewModel(context);
    _hoverTimer?.cancel();
    _hoverTimer = Timer(model.hoverCloseDelay, () {
      if (mounted && !_hoverTarget && !_hoverPanel) _controller.close();
    });
  }

  void _showTooltipCard() {
    final overlay = Overlay.of(context, rootOverlay: widget.useRootOverlay);
    final reopened = _overlayController.reopen();
    if (reopened) {
      _scheduleShowDuration(_resolveViewModel(context).showDuration);
      return;
    }

    final effectiveDismissible =
        widget.barrierDismissible ??
        (widget.modalBarrierEnabled ||
            widget.whenContentHide == WhenContentHide.pressOutSide);
    final needsBarrier = widget.modalBarrierEnabled || effectiveDismissible;

    final panelEntry = OverlayEntry(
      builder: (overlayContext) {
        final model = _resolveViewModel(
          _targetKey.currentContext ?? overlayContext,
        );
        return TooltipCardOverlayView(
          overlay: overlay,
          targetKey: _targetKey,
          contentBuilder: (contentContext) => widget.builder != null
              ? widget.builder!(contentContext, _controller.close)
              : widget.flyoutContent!,
          viewModel: model,
          preferredSide: widget.placementSide,
          viewportMargin: widget.viewportMargin,
          fitToViewport: widget.fitToViewport,
          autoFlipIfZeroSpace: widget.autoFlipIfZeroSpace,
          wrapContentInScrollView: widget.wrapContentInScrollView,
          offset: widget.offset,
          animationType: widget.animation,
          fade: _fade,
          scale: _scale,
          slide: _slide,
          resolvedSide: _resolvedSide,
          resolvedBeakPosition: _resolvedBeakPosition,
          onResolvedPlacement: _updateResolvedPlacement,
          onPanelHoverChanged: _onPanelHoverChanged,
          onClose: _controller.close,
        );
      },
    );

    OverlayEntry? barrierEntry;
    if (needsBarrier) {
      barrierEntry = OverlayEntry(
        builder: (barrierContext) {
          final model = _resolveViewModel(
            _targetKey.currentContext ?? barrierContext,
          );
          return TooltipCardBarrierView(
            fade: _fade,
            modal: widget.modalBarrierEnabled,
            dismissible: effectiveDismissible,
            color: model.barrierColor,
            blur: model.barrierBlur,
            onDismiss: _controller.close,
          );
        },
      );
    }

    final inserted = _overlayController.show(
      overlay: overlay,
      panelEntry: panelEntry,
      barrierEntry: barrierEntry,
    );
    if (!inserted) return;

    widget.onOpenChanged?.call(true);
    widget.onOpen?.call();
    _scheduleShowDuration(_resolveViewModel(context).showDuration);
  }

  void _scheduleShowDuration(Duration? duration) {
    _showDurationTimer?.cancel();
    if (duration == null) return;
    _showDurationTimer = Timer(duration, () {
      if (mounted) _controller.close();
    });
  }

  Future<void> _hideTooltipCard() async {
    _showDurationTimer?.cancel();
    final removed = await _overlayController.hide();
    if (!mounted || !removed) return;
    widget.onOpenChanged?.call(false);
    widget.onClose?.call();
  }

  void _updateResolvedPlacement(
    TooltipCardPlacementSide side,
    double beakPosition,
  ) {
    if (_resolvedSide == side && _resolvedBeakPosition == beakPosition) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_resolvedSide == side && _resolvedBeakPosition == beakPosition) {
        return;
      }
      _resolvedSide = side;
      _resolvedBeakPosition = beakPosition;
      _configureAnimations();
      _refreshOverlay();
    });
  }

  void _refreshOverlay() => _overlayController.refresh();

  @override
  Widget build(BuildContext context) {
    assert(
      widget.flyoutContent != null || widget.builder != null,
      'Either flyoutContent or builder must be provided',
    );

    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (notification) {
        _refreshOverlay();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: TooltipCardTriggerView(
          targetKey: _targetKey,
          triggers: _triggers,
          isOpen: _controller.isOpen,
          onToggle: _toggleFromPressLike,
          onOpen: () => _controller.open(),
          onClose: _controller.close,
          onHoverChanged: _onTargetHoverChanged,
          child: widget.child,
        ),
      ),
    );
  }
}
