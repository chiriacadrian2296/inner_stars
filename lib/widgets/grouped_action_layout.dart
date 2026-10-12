import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_style.dart';
import 'action_group_dot.dart';

/// Centers action rows and paints separators only between groups on the same row.
/// The separator is layout decoration, so it can never wrap onto a row by itself.
class GroupedActionLayout extends StatelessWidget {
  const GroupedActionLayout({
    super.key,
    required this.groups,
    required this.children,
    this.separatorBuilder,
  });
  final List<int> groups;
  final List<Widget> children;
  final Widget Function(Widget dot)? separatorBuilder;
  @override
  Widget build(BuildContext context) => _GroupedActionsWidget(
    groups: groups,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0 && groups[i] != groups[i - 1])
          IgnorePointer(
            child:
                separatorBuilder?.call(const ActionGroupDot(width: 4)) ??
                const ActionGroupDot(width: 4),
          ),
        children[i],
      ],
    ],
  );
}

class _GroupedActionsWidget extends MultiChildRenderObjectWidget {
  const _GroupedActionsWidget({required this.groups, required super.children});
  final List<int> groups;
  @override
  RenderGroupedActions createRenderObject(BuildContext context) =>
      RenderGroupedActions(groups);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderGroupedActions renderObject,
  ) => renderObject.groups = groups;
}

class _ActionParentData extends ContainerBoxParentData<RenderBox> {}

class RenderGroupedActions extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  RenderGroupedActions(this._groups);
  List<int> _groups;
  final List<Rect> _separators = [];
  final Set<RenderBox> _dots = {};
  final Set<RenderBox> _visibleDots = {};
  List<Rect> get separators => List.unmodifiable(_separators);
  set groups(List<int> value) {
    _groups = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _ActionParentData();
    }
  }

  @override
  void performLayout() {
    final maxWidth = constraints.maxWidth;
    final rows =
        <List<({RenderBox child, RenderBox? dot, double x, int index})>>[];
    var row = <({RenderBox child, RenderBox? dot, double x, int index})>[];
    var x = 0.0;
    var index = 0;
    _dots.clear();
    _visibleDots.clear();
    RenderBox? child = firstChild;
    while (child != null) {
      RenderBox? dot;
      if (index > 0 && _groups[index] != _groups[index - 1]) {
        dot = child;
        dot.layout(const BoxConstraints.tightFor(width: 4, height: 4));
        _dots.add(dot);
        child =
            (dot.parentData! as ContainerBoxParentData<RenderBox>).nextSibling!;
      }
      child.layout(BoxConstraints(maxWidth: maxWidth), parentUsesSize: true);
      var gap = row.isEmpty
          ? 0.0
          : (_groups[index] == _groups[index - 1] ? 8.0 : kActionGroupGap);
      if (row.isNotEmpty && x + gap + child.size.width > maxWidth) {
        rows.add(row);
        row = [];
        x = 0;
        gap = 0;
      }
      row.add((child: child, dot: dot, x: x + gap, index: index));
      x += gap + child.size.width;
      child =
          (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
      index++;
    }
    if (row.isNotEmpty) rows.add(row);
    final widths = [for (final r in rows) r.last.x + r.last.child.size.width];
    final width = maxWidth.isFinite
        ? maxWidth
        : widths.fold<double>(0, math.max);
    var y = 0.0;
    _separators.clear();
    for (final r in rows) {
      final rowHeight = r.fold<double>(
        0,
        (height, item) => math.max(height, item.child.size.height),
      );
      final inset = (width - r.last.x - r.last.child.size.width) / 2;
      for (var i = 0; i < r.length; i++) {
        final item = r[i];
        (item.child.parentData! as ContainerBoxParentData<RenderBox>).offset =
            Offset(
              inset + item.x,
              y + (rowHeight - item.child.size.height) / 2,
            );
        if (i > 0 && _groups[item.index] != _groups[r[i - 1].index]) {
          final previous = r[i - 1];
          const height = 4.0;
          final dot = item.dot!;
          _visibleDots.add(dot);
          _separators.add(
            Rect.fromLTWH(
              inset + (previous.x + previous.child.size.width + item.x) / 2 - 2,
              y + (rowHeight - height) / 2,
              4,
              height,
            ),
          );
          (dot.parentData! as ContainerBoxParentData<RenderBox>).offset =
              _separators.last.topLeft;
        }
      }
      y += rowHeight + 8;
    }
    size = constraints.constrain(Size(width, rows.isEmpty ? 0 : y - 8));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as ContainerBoxParentData<RenderBox>;
      if (!_dots.contains(child) || _visibleDots.contains(child)) {
        context.paintChild(child, offset + parentData.offset);
      }
      child = parentData.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
