import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../theme/app_typography.dart';
import '../widgets/app_choice_chip.dart';
import '../widgets/intensity_bolts.dart';

/// A lab page to compare layouts for the back of the flip cards (Sky grid)
/// and of the Galaxy tooltips: today's badge grid next to three proposals —
/// A (three equal columns), B (one leading figure, two beside it) and C (a
/// compact list like the Moments) — for every kind of card, drawn at the
/// real sizes with sample data.
class CardBackLabScreen extends StatefulWidget {
  const CardBackLabScreen({super.key});

  @override
  State<CardBackLabScreen> createState() => _CardBackLabScreenState();
}

enum _Kind { constellation, pulsar, victory, goal }

enum _Layout { current, columns, hero, list }

/// One figure of a card's back.
class _Figure {
  const _Figure(
    this.icon,
    this.label,
    this.value, {
    this.progress,
    this.bolts,
    this.date = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// The current cycle's share, drawn as a bar.
  final double? progress;

  /// An intensity, drawn as bolts instead of a number.
  final int? bolts;
  final bool date;
}

class _CardBackLabScreenState extends State<CardBackLabScreen> {
  _Kind _kind = _Kind.constellation;
  bool _drawerOpen = true;
  bool _longTitle = false;

  String _title() => switch (_kind) {
    _Kind.constellation =>
      _longTitle ? 'Allenamento per la mezza maratona di primavera' : 'Corsa',
    _Kind.pulsar =>
      _longTitle ? 'Stretching mattutino prima di colazione' : 'Stretching',
    _Kind.victory =>
      _longTitle ? 'Primi dieci chilometri senza fermarmi' : 'Primi 10 km',
    _Kind.goal =>
      _longTitle
          ? 'Correre la mezza maratona sotto le due ore'
          : 'Mezza maratona',
  };

  List<_Figure> _figures(AppStrings s) => switch (_kind) {
    _Kind.constellation => [
      _Figure(Icons.bolt_rounded, s.intensityLabel, '128'),
      _Figure(Icons.auto_awesome_rounded, s.cardBadgeLitStars, '12'),
      _Figure(Icons.sync_rounded, s.habitStatsCyclesLabel, '3'),
    ],
    _Kind.pulsar => [
      _Figure(Icons.event_available_rounded, s.habitStatsDaysDoneLabel, '46'),
      _Figure(
        Icons.sync_rounded,
        s.habitCycleLabel,
        s.cycleProgressLabel(5, 7),
        progress: 5 / 7,
      ),
      _Figure(Icons.sync_rounded, s.habitStatsCyclesLabel, '3'),
    ],
    _Kind.victory => [
      _Figure(
        Icons.calendar_today_outlined,
        s.insightAchieved,
        '12 ott 2026',
        date: true,
      ),
      _Figure(Icons.bolt_rounded, s.intensityLabel, '4/5', bolts: 4),
      _Figure(
        Icons.calendar_today_outlined,
        s.insightCreated,
        '3 set 2026',
        date: true,
      ),
    ],
    _Kind.goal => [
      _Figure(
        Icons.calendar_today_outlined,
        s.insightCreated,
        '3 set 2026',
        date: true,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final figures = _figures(strings);
    final tooltipWidth =
        math.min(480.0, MediaQuery.sizeOf(context).width - 12) - 16;
    String kindLabel(_Kind kind) => switch (kind) {
      _Kind.constellation => 'Costellazione',
      _Kind.pulsar => 'Pulsar',
      _Kind.victory => 'Vittoria',
      _Kind.goal => 'Obiettivo',
    };
    String layoutLabel(_Layout layout) => switch (layout) {
      _Layout.current => 'Ora · griglia di badge',
      _Layout.columns => 'A · tre colonne uguali',
      _Layout.hero => 'B · un numero protagonista',
      _Layout.list => 'C · lista compatta',
    };

    return Scaffold(
      backgroundColor: colors.night,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Text('Card Back Lab', style: context.typography.utilityPageTitle),
            const SizedBox(height: 6),
            Text(
              'Il retro delle card della Sky (a sinistra, misura reale della '
              'griglia) e dei tooltip di Galaxy (a destra o sotto), con dati '
              'di esempio.',
              style: context.typography.supporting,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in _Kind.values)
                  AppChoiceChip(
                    label: kindLabel(kind),
                    selected: kind == _kind,
                    onPressed: () => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppChoiceChip(
                  label: 'Cassetto Aperto',
                  icon: Icons.unfold_more_rounded,
                  selected: _drawerOpen,
                  onPressed: () => setState(() => _drawerOpen = !_drawerOpen),
                ),
                AppChoiceChip(
                  label: 'Titolo Lungo',
                  icon: Icons.short_text_rounded,
                  selected: _longTitle,
                  onPressed: () => setState(() => _longTitle = !_longTitle),
                ),
              ],
            ),
            for (final layout in _Layout.values) ...[
              const SizedBox(height: 28),
              Text(
                layoutLabel(layout),
                style: context.typography.sectionHeading,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  _Back(
                    width: 154,
                    height: 231,
                    grid: true,
                    title: _title(),
                    showManage: _kind == _Kind.constellation,
                    body: _body(layout, figures, grid: true),
                  ),
                  _Back(
                    width: tooltipWidth,
                    // The back keeps the front's height: the card body,
                    // plus the drawer while it is open.
                    height: _drawerOpen ? 138 : 88,
                    grid: false,
                    title: _title(),
                    showManage: _kind == _Kind.constellation,
                    body: _body(layout, figures, grid: false),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(_Layout layout, List<_Figure> figures, {required bool grid}) =>
      switch (layout) {
        _Layout.current => _CurrentBody(figures: figures, grid: grid),
        _Layout.columns => _ColumnsBody(figures: figures, grid: grid),
        _Layout.hero => _HeroBody(figures: figures, grid: grid),
        _Layout.list => _ListBody(figures: figures, grid: grid),
      };
}

/// The back's frame: title row (with room for the flip button), the body
/// (scrolling when it doesn't fit, as the real back does) and the actions.
class _Back extends StatelessWidget {
  const _Back({
    required this.width,
    required this.height,
    required this.grid,
    required this.title,
    required this.showManage,
    required this.body,
  });

  final double width;
  final double height;
  final bool grid;
  final String title;
  final bool showManage;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final actions = [
      (Icons.bar_chart, strings.statsTitle),
      if (showManage) (Icons.checklist_rounded, strings.manageHabits),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        height: height,
        color: colors.nightPanel,
        padding: EdgeInsets.fromLTRB(12, 0, 12, grid ? 8 : 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: grid ? 12 : 13,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.night,
                      border: Border.all(color: colors.nightBorder),
                    ),
                    child: Icon(Icons.flip, size: 14, color: colors.muted),
                  ),
                ],
              ),
            ),
            Expanded(child: SingleChildScrollView(child: body)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  if (grid)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.night,
                        border: Border.all(color: colors.nightBorder),
                      ),
                      child: Icon(actions[i].$1, size: 14, color: colors.muted),
                    )
                  else
                    Expanded(
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: colors.night,
                          borderRadius: BorderRadius.circular(kRadiusPill),
                          border: Border.all(color: colors.nightBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(actions[i].$1, size: 14, color: colors.muted),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                actions[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A figure's value: bolts for an intensity, the text otherwise.
Widget _value(
  BuildContext context,
  _Figure figure, {
  required double size,
  bool center = false,
}) {
  final colors = context.colors;
  if (figure.bolts != null) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: IntensityBolts(intensity: figure.bolts!, size: size * 0.8),
    );
  }
  return Text(
    figure.value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: center ? TextAlign.center : TextAlign.start,
    style: TextStyle(
      fontSize: figure.date ? size * 0.75 : size,
      fontWeight: FontWeight.w700,
      color: colors.text,
      height: 1.1,
    ),
  );
}

Color _iconColor(BuildContext context, _Figure figure) =>
    figure.date ? context.colors.text : context.colors.gold;

Widget _bar(BuildContext context, double progress) => ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: LinearProgressIndicator(
    value: progress,
    minHeight: 3,
    color: context.colors.gold,
    backgroundColor: context.colors.nightBorder,
  ),
);

/// Today's look: badges in a grid, two (or three, in tooltips) a row.
class _CurrentBody extends StatelessWidget {
  const _CurrentBody({required this.figures, required this.grid});
  final List<_Figure> figures;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final columns = grid ? 2 : 3;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final f in figures)
              SizedBox(
                width: grid && (f.progress != null || f.date)
                    ? constraints.maxWidth
                    : width,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: colors.night,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.nightBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(f.icon, size: 12, color: _iconColor(context, f)),
                          const SizedBox(width: 4),
                          Expanded(child: _value(context, f, size: 12)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        f.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: colors.muted),
                      ),
                      if (f.progress != null) ...[
                        const SizedBox(height: 5),
                        _bar(context, f.progress!),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A: every figure in its own equal column, side by side.
class _ColumnsBody extends StatelessWidget {
  const _ColumnsBody({required this.figures, required this.grid});
  final List<_Figure> figures;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bar = figures.where((f) => f.progress != null).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in figures)
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        f.icon,
                        size: grid ? 14 : 16,
                        color: _iconColor(context, f),
                      ),
                      const SizedBox(height: 4),
                      _value(context, f, size: grid ? 14 : 18, center: true),
                      const SizedBox(height: 2),
                      Text(
                        f.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: grid ? 8.5 : 10,
                          color: colors.muted,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (bar != null) ...[
            const SizedBox(height: 8),
            _bar(context, bar.progress!),
          ],
        ],
      ),
    );
  }
}

/// B: the first figure large and centered (with its bar), the others in one
/// line beneath it.
class _HeroBody extends StatelessWidget {
  const _HeroBody({required this.figures, required this.grid});
  final List<_Figure> figures;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hero = figures.first;
    final rest = figures.skip(1).toList();
    final secondaryBar = rest.where((f) => f.progress != null).firstOrNull;
    Widget secondary(_Figure f) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(f.icon, size: grid ? 11 : 13, color: _iconColor(context, f)),
        const SizedBox(width: 3),
        Flexible(child: _value(context, f, size: grid ? 11 : 13)),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            f.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: grid ? 8.5 : 10.5, color: colors.muted),
          ),
        ),
      ],
    );
    final heroBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hero.icon,
              size: grid ? 18 : 20,
              color: _iconColor(context, hero),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: _value(context, hero, size: grid ? 24 : 26, center: true),
            ),
          ],
        ),
        Text(
          hero.label,
          style: TextStyle(fontSize: grid ? 9 : 10.5, color: colors.muted),
        ),
      ],
    );
    if (!grid) {
      // A tooltip is wide and short: the leading figure on the left, the
      // others stacked beside it.
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Expanded(child: heroBlock),
            if (rest.isNotEmpty) ...[
              Container(width: 1, height: 36, color: colors.nightBorder),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final f in rest) ...[
                      secondary(f),
                      if (f.progress != null) ...[
                        const SizedBox(height: 3),
                        _bar(context, f.progress!),
                      ],
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          heroBlock,
          if (secondaryBar != null) ...[
            const SizedBox(height: 6),
            _bar(context, secondaryBar.progress!),
          ],
          const SizedBox(height: 10),
          for (final f in rest) ...[secondary(f), const SizedBox(height: 4)],
        ],
      ),
    );
  }
}

/// C: one row per figure, like the Moments — label left, value right.
class _ListBody extends StatelessWidget {
  const _ListBody({required this.figures, required this.grid});
  final List<_Figure> figures;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        for (final f in figures)
          Padding(
            padding: EdgeInsets.symmetric(vertical: grid ? 4 : 3),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      f.icon,
                      size: grid ? 12 : 14,
                      color: _iconColor(context, f),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: grid ? 9.5 : 11,
                          color: colors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _value(context, f, size: grid ? 12 : 14),
                  ],
                ),
                if (f.progress != null) ...[
                  const SizedBox(height: 3),
                  _bar(context, f.progress!),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
