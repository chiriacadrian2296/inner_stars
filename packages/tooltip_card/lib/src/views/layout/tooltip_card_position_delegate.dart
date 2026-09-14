part of '../views.dart';

/// Position delegate implementing a 3-phase sequential positioning system:
///
/// Phase 1: Select Best Side
///   - Calculate available space in each direction
///   - Select the optimal side based on content size and space availability
///
/// Phase 2: Calculate Beak Position
///   - Determine where the beak should be positioned on the flyout edge
///   - Avoid borderRadius zones to keep beak away from rounded corners
///
/// Phase 3: Calculate Flyout Position
///   - Position the flyout content such that the beak points to child center
///   - Apply viewport constraints to ensure content stays visible
class TooltipCardPositionDelegate extends SingleChildLayoutDelegate {
  TooltipCardPositionDelegate({
    required this.overlaySize,
    required this.targetRect,
    required this.awaySpace,
    required this.preferredSide,
    required this.textDirection,
    required this.viewportMargin,
    required this.fitToViewport,
    required this.autoFlipIfZeroSpace,
    required this.userConstraints,
    required this.borderRadius,
    required this.beakSize,
    required this.beakInset,
    required this.offset,
    required this.onResolvedPlacement,
  });

  /// Use shared constant for precision calculations
  static const double _epsilon = TooltipCardConstants.positionEpsilon;

  final Size overlaySize;
  final Rect targetRect;
  final double awaySpace;
  final TooltipCardPlacementSide preferredSide;
  final TextDirection textDirection;
  final EdgeInsetsDirectional viewportMargin;
  final bool fitToViewport;
  final bool autoFlipIfZeroSpace;
  final BoxConstraints? userConstraints;
  final BorderRadius borderRadius;
  final double beakSize;
  final double beakInset;

  bool get isLTR => textDirection == TextDirection.ltr;

  /// Custom offset to apply after positioning calculations (Fluent UI feature)
  final Offset offset;

  final void Function(TooltipCardPlacementSide side, double beakPosition)
  onResolvedPlacement;

  bool get _isRTL => textDirection == TextDirection.rtl;

  /// Extracts the maximum radius across every panel corner.
  double get _maxCornerRadius {
    final radii = <Radius>[
      borderRadius.topLeft,
      borderRadius.topRight,
      borderRadius.bottomLeft,
      borderRadius.bottomRight,
    ];
    return radii.fold<double>(
      0,
      (maximum, radius) => math.max(
        maximum,
        math.max(radius.x, radius.y),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 1: Select Best Side
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calculates available space in the top direction
  double _calculateTopSpace() {
    return math.max(
      0,
      targetRect.top - viewportMargin.top - beakSize - awaySpace,
    );
  }

  /// Calculates available space in the bottom direction
  double _calculateBottomSpace() {
    return math.max(
      0,
      overlaySize.height -
          targetRect.bottom -
          viewportMargin.bottom -
          beakSize -
          awaySpace,
    );
  }

  /// Calculates available space in the start direction (LTR: left, RTL: right)
  double _calculateStartSpace() {
    final bool tooltipOnLeft = !_isRTL;
    final viewportMarginLeft = isLTR
        ? viewportMargin.start
        : viewportMargin.end;
    final viewportMarginRight = isLTR
        ? viewportMargin.end
        : viewportMargin.start;

    final double available = tooltipOnLeft
        ? targetRect.left - viewportMarginLeft - beakSize - awaySpace
        : overlaySize.width -
              viewportMarginRight -
              targetRect.right -
              beakSize -
              awaySpace;
    return math.max(0, available);
  }

  /// Calculates available space in the end direction (LTR: right, RTL: left)
  double _calculateEndSpace() {
    final bool tooltipOnRight = !_isRTL;
    final viewportMarginLeft = isLTR
        ? viewportMargin.start
        : viewportMargin.end;
    final viewportMarginRight = isLTR
        ? viewportMargin.end
        : viewportMargin.start;

    final double available = tooltipOnRight
        ? overlaySize.width -
              viewportMarginRight -
              targetRect.right -
              beakSize -
              awaySpace
        : targetRect.left - viewportMarginLeft - beakSize - awaySpace;
    return math.max(0, available);
  }

  /// PHASE 1: Selects the best side for placing the tooltip
  TooltipCardPlacementSide _selectBestSide(Size contentSize) {
    final topSpace = _calculateTopSpace();
    final bottomSpace = _calculateBottomSpace();
    final startSpace = _calculateStartSpace();
    final endSpace = _calculateEndSpace();

    final preferredBase = preferredSide.baseSide;

    bool fitsInPreferred = false;
    switch (preferredBase) {
      case TooltipCardPlacementSide.top:
        fitsInPreferred = contentSize.height <= topSpace + _epsilon;
        break;
      case TooltipCardPlacementSide.bottom:
        fitsInPreferred = contentSize.height <= bottomSpace + _epsilon;
        break;
      case TooltipCardPlacementSide.start:
        fitsInPreferred = contentSize.width <= startSpace + _epsilon;
        break;
      case TooltipCardPlacementSide.end:
        fitsInPreferred = contentSize.width <= endSpace + _epsilon;
        break;
      default:
        break;
    }

    if (!autoFlipIfZeroSpace) {
      return preferredSide;
    }

    // Preferred side fits: keep it verbatim so any compound alignment
    // (e.g. topStart / endBottom) is preserved.
    if (fitsInPreferred) {
      return preferredSide;
    }

    final bestVerticalSide = topSpace > bottomSpace
        ? TooltipCardPlacementSide.top
        : TooltipCardPlacementSide.bottom;
    final bestVerticalSpace = math.max(topSpace, bottomSpace);

    final bestHorizontalSide = startSpace > endSpace
        ? TooltipCardPlacementSide.start
        : TooltipCardPlacementSide.end;
    final bestHorizontalSpace = math.max(startSpace, endSpace);

    TooltipCardPlacementSide chosenBase;
    if (preferredBase == TooltipCardPlacementSide.top ||
        preferredBase == TooltipCardPlacementSide.bottom) {
      if (contentSize.height <= bestVerticalSpace + _epsilon) {
        chosenBase = bestVerticalSide;
      } else if (contentSize.width <= bestHorizontalSpace + _epsilon) {
        chosenBase = bestHorizontalSide;
      } else {
        chosenBase = bestVerticalSpace > bestHorizontalSpace
            ? bestVerticalSide
            : bestHorizontalSide;
      }
    } else {
      if (contentSize.width <= bestHorizontalSpace + _epsilon) {
        chosenBase = bestHorizontalSide;
      } else if (contentSize.height <= bestVerticalSpace + _epsilon) {
        chosenBase = bestVerticalSide;
      } else {
        chosenBase = bestHorizontalSpace > bestVerticalSpace
            ? bestHorizontalSide
            : bestVerticalSide;
      }
    }

    // Re-attach the preferred cross-axis alignment when the resolved side
    // stays on the same axis (e.g. flipping topStart -> bottomStart).
    return _applyPreferredAlignment(chosenBase);
  }

  /// Re-applies the preferred compound alignment to a resolved base side.
  ///
  /// Alignment is only preserved when the resolved side lies on the same axis
  /// as the preferred side. When the tooltip is forced onto the perpendicular
  /// axis (because the preferred axis has no room) it falls back to the
  /// centered base side.
  TooltipCardPlacementSide _applyPreferredAlignment(
    TooltipCardPlacementSide chosenBase,
  ) {
    final chosenIsVertical =
        chosenBase == TooltipCardPlacementSide.top ||
        chosenBase == TooltipCardPlacementSide.bottom;

    if (chosenIsVertical != preferredSide.isVertical) {
      return chosenBase;
    }

    if (chosenIsVertical) {
      switch (preferredSide.horizontalAlign) {
        case HorizontalAlign.start:
          return chosenBase == TooltipCardPlacementSide.top
              ? TooltipCardPlacementSide.topStart
              : TooltipCardPlacementSide.bottomStart;
        case HorizontalAlign.end:
          return chosenBase == TooltipCardPlacementSide.top
              ? TooltipCardPlacementSide.topEnd
              : TooltipCardPlacementSide.bottomEnd;
        case HorizontalAlign.center:
          return chosenBase;
      }
    } else {
      switch (preferredSide.verticalAlign) {
        case VerticalAlign.top:
          return chosenBase == TooltipCardPlacementSide.start
              ? TooltipCardPlacementSide.startTop
              : TooltipCardPlacementSide.endTop;
        case VerticalAlign.bottom:
          return chosenBase == TooltipCardPlacementSide.start
              ? TooltipCardPlacementSide.startBottom
              : TooltipCardPlacementSide.endBottom;
        case VerticalAlign.center:
          return chosenBase;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 2: Calculate Beak Position
  // ═══════════════════════════════════════════════════════════════════════════

  /// PHASE 2: Calculates the beak position on the flyout content edge
  ///
  /// [contentOffset] must be the *final* on-screen offset of the content
  /// (including any custom [offset]) so the beak keeps pointing at the target
  /// center regardless of how the panel was aligned or nudged.
  double _calculateBeakPosition(
    TooltipCardPlacementSide side,
    Size contentSize,
    Offset contentOffset,
  ) {
    final safeZone = math.max(
      beakInset,
      _maxCornerRadius + beakSize,
    );

    if (side.isVertical) {
      final beakIdealX = targetRect.center.dx - contentOffset.dx;
      final beakMinX = safeZone;
      final beakMaxX = math.max(safeZone, contentSize.width - safeZone);
      final beakFinalX = beakIdealX.clamp(beakMinX, beakMaxX);
      return beakFinalX;
    } else {
      final beakIdealY = targetRect.center.dy - contentOffset.dy;
      final beakMinY = safeZone;
      final beakMaxY = math.max(safeZone, contentSize.height - safeZone);
      final beakFinalY = beakIdealY.clamp(beakMinY, beakMaxY);
      return beakFinalY;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 3: Calculate Flyout Position
  // ═══════════════════════════════════════════════════════════════════════════

  /// PHASE 3: Calculates the flyout content position
  ///
  /// The main axis (perpendicular to [side]) is fixed by the placement, while
  /// the cross axis honours the compound alignment (start/center/end or
  /// top/center/bottom) in a layout-direction aware way.
  Offset _calculateFlyoutOffset(
    TooltipCardPlacementSide side,
    Size layoutSize,
    Size contentSize,
  ) {
    final viewportMarginLeft = isLTR
        ? viewportMargin.start
        : viewportMargin.end;
    final viewportMarginRight = isLTR
        ? viewportMargin.end
        : viewportMargin.start;
    final double minX = viewportMarginLeft;
    final double maxX =
        layoutSize.width - viewportMarginRight - contentSize.width;
    final double minY = viewportMargin.top;
    final double maxY =
        layoutSize.height - viewportMargin.bottom - contentSize.height;

    double x = 0;
    double y = 0;

    switch (side.baseSide) {
      case TooltipCardPlacementSide.top:
        y = targetRect.top - beakSize - contentSize.height - awaySpace;
        x = _resolveHorizontalAlignment(side.horizontalAlign, contentSize);
        break;

      case TooltipCardPlacementSide.bottom:
        y = targetRect.bottom + beakSize + awaySpace;
        x = _resolveHorizontalAlignment(side.horizontalAlign, contentSize);
        break;

      case TooltipCardPlacementSide.start:
        x = _isRTL
            ? targetRect.right + beakSize + awaySpace
            : targetRect.left - beakSize - contentSize.width - awaySpace;
        y = _resolveVerticalAlignment(side.verticalAlign, contentSize);
        break;

      case TooltipCardPlacementSide.end:
        x = _isRTL
            ? targetRect.left - beakSize - contentSize.width - awaySpace
            : targetRect.right + beakSize + awaySpace;
        y = _resolveVerticalAlignment(side.verticalAlign, contentSize);
        break;

      default:
        break;
    }

    // Guard against content larger than the available space so clamp() never
    // receives an inverted range (lowerLimit > upperLimit).
    final double safeMaxX = math.max(minX, maxX);
    final double safeMaxY = math.max(minY, maxY);
    if (fitToViewport) {
      x = x.clamp(minX, safeMaxX);
      y = y.clamp(minY, safeMaxY);
    }

    return Offset(x, y);
  }

  /// Resolves the horizontal offset for vertical placements based on the
  /// requested cross-axis alignment, honouring layout direction.
  ///
  /// - center: content is centered on the target center.
  /// - start:  the content's start edge aligns with the target's start edge
  ///           (LTR: left/left, RTL: right/right).
  /// - end:    the content's end edge aligns with the target's end edge.
  double _resolveHorizontalAlignment(
    HorizontalAlign align,
    Size contentSize,
  ) {
    switch (align) {
      case HorizontalAlign.center:
        return targetRect.center.dx - contentSize.width / 2;
      case HorizontalAlign.start:
        return isLTR
            ? targetRect.left
            : targetRect.right - contentSize.width;
      case HorizontalAlign.end:
        return isLTR
            ? targetRect.right - contentSize.width
            : targetRect.left;
    }
  }

  /// Resolves the vertical offset for horizontal placements based on the
  /// requested cross-axis alignment.
  ///
  /// - center: content is centered on the target center.
  /// - top:    the content's top edge aligns with the target's top edge.
  /// - bottom: the content's bottom edge aligns with the target's bottom edge.
  double _resolveVerticalAlignment(VerticalAlign align, Size contentSize) {
    switch (align) {
      case VerticalAlign.center:
        return targetRect.center.dy - contentSize.height / 2;
      case VerticalAlign.top:
        return targetRect.top;
      case VerticalAlign.bottom:
        return targetRect.bottom - contentSize.height;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    double maxW = constraints.biggest.width - viewportMargin.horizontal;
    double maxH = constraints.biggest.height - viewportMargin.vertical;

    if (fitToViewport) {
      final topSpace = _calculateTopSpace();
      final bottomSpace = _calculateBottomSpace();
      final startSpace = _calculateStartSpace();
      final endSpace = _calculateEndSpace();

      final bestVerticalSpace = math.max(topSpace, bottomSpace);
      final bestHorizontalSpace = math.max(startSpace, endSpace);

      if (bestVerticalSpace > 0) {
        maxH = math.min(maxH, bestVerticalSpace);
      }
      if (bestHorizontalSpace > 0) {
        maxW = math.min(maxW, bestHorizontalSpace);
      }
    }

    if (userConstraints != null) {
      if (userConstraints!.maxWidth.isFinite) {
        maxW = math.min(maxW, userConstraints!.maxWidth);
      }
      if (userConstraints!.maxHeight.isFinite) {
        maxH = math.min(maxH, userConstraints!.maxHeight);
      }
    }

    return BoxConstraints(
      minWidth: 0,
      minHeight: 0,
      maxWidth: maxW,
      maxHeight: maxH,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final selectedSide = _selectBestSide(childSize);

    final flyoutOffset = _calculateFlyoutOffset(
      selectedSide,
      size,
      childSize,
    );

    // Apply the custom offset first, then derive the beak from the final
    // position so it keeps pointing at the target center even when nudged.
    final finalOffset = flyoutOffset + offset;

    final beakPosition = _calculateBeakPosition(
      selectedSide,
      childSize,
      finalOffset,
    );

    onResolvedPlacement(selectedSide, beakPosition);

    return finalOffset;
  }

  @override
  bool shouldRelayout(covariant TooltipCardPositionDelegate old) {
    return overlaySize != old.overlaySize ||
        targetRect != old.targetRect ||
        awaySpace != old.awaySpace ||
        preferredSide != old.preferredSide ||
        textDirection != old.textDirection ||
        viewportMargin != old.viewportMargin ||
        fitToViewport != old.fitToViewport ||
        autoFlipIfZeroSpace != old.autoFlipIfZeroSpace ||
        userConstraints != old.userConstraints ||
        borderRadius != old.borderRadius ||
        beakSize != old.beakSize ||
        beakInset != old.beakInset ||
        offset != old.offset;
  }
}
