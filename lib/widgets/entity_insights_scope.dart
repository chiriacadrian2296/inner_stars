import 'dart:async';

import 'package:flutter/material.dart';

import '../data/custom_constellation_repository.dart';
import '../data/habit_completion_repository.dart';
import '../data/habit_repository.dart';
import '../data/project_repository.dart';
import '../data/star_repository.dart';
import '../utils/entity_insights.dart';
import '../utils/habit_stats.dart';

class EntityInsightsController extends ChangeNotifier
    with WidgetsBindingObserver {
  EntityInsightsController({
    required this.projects,
    required this.stars,
    required this.habits,
    required this.completions,
    required this.shapes,
  }) {
    for (final repository in _repositories) {
      repository.addListener(refresh);
    }
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }
  final ProjectRepository projects;
  final StarRepository stars;
  final HabitRepository habits;
  final HabitCompletionRepository completions;
  final StarsShapeRepository shapes;
  Iterable<ChangeNotifier> get _repositories => [
    projects,
    stars,
    habits,
    completions,
  ];
  final _cache = <(InsightEntity, HabitStatsRange), EntityInsights>{};
  Timer? _midnight;

  EntityInsights read(
    InsightEntity entity, {
    HabitStatsRange range = HabitStatsRange.days30,
  }) => _cache.putIfAbsent(
    (entity, range),
    () => EntityInsights.read(
      entity: entity,
      projects: projects,
      stars: stars,
      habits: habits,
      completions: completions,
      range: range,
    ),
  );

  void refresh() {
    _cache.clear();
    notifyListeners();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        refresh();
        _scheduleMidnight();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
      _scheduleMidnight();
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final repository in _repositories) {
      repository.removeListener(refresh);
    }
    super.dispose();
  }
}

/// Placed above the Navigator so pushed pages and floating tooltips share data.
class EntityInsightsScope extends InheritedNotifier<EntityInsightsController> {
  const EntityInsightsScope({
    super.key,
    required EntityInsightsController controller,
    required super.child,
  }) : super(notifier: controller);

  static EntityInsightsController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<EntityInsightsScope>()
      ?.notifier;
}

class EntityInsightsHost extends StatefulWidget {
  const EntityInsightsHost({
    super.key,
    required this.projects,
    required this.stars,
    required this.habits,
    required this.completions,
    required this.shapes,
    required this.child,
  });
  final ProjectRepository projects;
  final StarRepository stars;
  final HabitRepository habits;
  final HabitCompletionRepository completions;
  final StarsShapeRepository shapes;
  final Widget child;
  @override
  State<EntityInsightsHost> createState() => _EntityInsightsHostState();
}

class _EntityInsightsHostState extends State<EntityInsightsHost> {
  late EntityInsightsController _controller;
  void _create() => _controller = EntityInsightsController(
    projects: widget.projects,
    stars: widget.stars,
    habits: widget.habits,
    completions: widget.completions,
    shapes: widget.shapes,
  );
  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(EntityInsightsHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projects != widget.projects ||
        oldWidget.stars != widget.stars ||
        oldWidget.habits != widget.habits ||
        oldWidget.completions != widget.completions ||
        oldWidget.shapes != widget.shapes) {
      _controller.dispose();
      _create();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      EntityInsightsScope(controller: _controller, child: widget.child);
}
