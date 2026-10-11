import 'package:flutter/material.dart';

import '../data/star_repository.dart';
import '../data/habit_repository.dart';
import '../data/habit_completion_repository.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/celebration_stats.dart';
import '../utils/date_format.dart';
import '../widgets/stats/accumulation_chart.dart';
import '../widgets/responsive_content.dart';

/// Experimental celebration page, kept separate from the original statistics.
class CelebrationStatsScreen extends StatefulWidget {
  const CelebrationStatsScreen({
    super.key,
    required this.starRepository,
    required this.habitRepository,
    required this.completionRepository,
  });
  final StarRepository starRepository;
  final HabitRepository habitRepository;
  final HabitCompletionRepository completionRepository;
  @override
  State<CelebrationStatsScreen> createState() => _CelebrationStatsScreenState();
}

class _CelebrationStatsScreenState extends State<CelebrationStatsScreen> {
  int? _days;
  String _text(String it, String en, String ro) =>
      switch (context.strings.languageCode) {
        'it' => it,
        'ro' => ro,
        _ => en,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final stats = CelebrationStats(
      stars: widget.starRepository.getAll(),
      habits: widget.habitRepository.getAll(),
      completions: widget.completionRepository.getAll(),
      now: DateTime.now(),
      days: _days,
    );
    return Scaffold(
      backgroundColor: colors.night,
      appBar: AppBar(
        title: Text(_text('La tua luce', 'Your light', 'Lumina ta')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          children: [
            ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final days in <int?>[null, 30, 7])
                        ChoiceChip(
                          label: Text(
                            days == null
                                ? _text(
                                    'Dall’inizio',
                                    'Since the beginning',
                                    'De la început',
                                  )
                                : '$days ${_text('giorni', 'days', 'zile')}',
                          ),
                          selected: _days == days,
                          onSelected: (_) => setState(() => _days = days),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    stats.total == 0
                        ? _text(
                            'Qui prenderà forma la tua luce',
                            'Your light will take shape here',
                            'Aici va prinde formă lumina ta',
                          )
                        : _text(
                            'Guarda quanto hai fatto.',
                            'Look at all you have done.',
                            'Privește câte ai făcut.',
                          ),
                    style: type.immersivePageTitle,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _text(
                      'Ogni risultato. Ogni piccolo gesto. Tutto questo è tuo.',
                      'Every achievement. Every small action. All of this is yours.',
                      'Fiecare reușită. Fiecare gest mic. Toate acestea sunt ale tale.',
                    ),
                    style: type.supporting,
                  ),
                  const SizedBox(height: 12),
                  if (stats.total > 0) ...[
                    const SizedBox(height: 20),
                    Text(
                      _text(
                        'Il tuo percorso, un passo alla volta',
                        'Your journey, one step at a time',
                        'Parcursul tău, pas cu pas',
                      ),
                      style: type.sectionHeading,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _days == null
                          ? _text(
                              'Stelle e gesti dei Pulsar accumulati dall’inizio.',
                              'Stars and Pulsar actions accumulated since the beginning.',
                              'Stele și gesturi ale Pulsarilor acumulate de la început.',
                            )
                          : _text(
                              'Stelle e gesti dei Pulsar accumulati in questi $_days giorni.',
                              'Stars and Pulsar actions accumulated over these $_days days.',
                              'Stele și gesturi ale Pulsarilor acumulate în aceste $_days zile.',
                            ),
                      style: type.supporting,
                    ),
                    const SizedBox(height: 20),
                    AccumulationChart(
                      points: stats.cumulative,
                      dateLabel: (date) =>
                          formatDisplayDate(date, context.strings),
                      axisLabel: _text(
                        'Azioni completate · totale cumulativo',
                        'Completed actions · cumulative total',
                        'Acțiuni finalizate · total cumulativ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _text(
                        'Tocca o trascina sul grafico per vedere la data e il totale preciso.',
                        'Tap or drag across the chart to see the exact date and total.',
                        'Atinge sau glisează pe grafic pentru a vedea data și totalul exact.',
                      ),
                      style: type.supporting,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _text(
                        'Dentro questo percorso',
                        'Within this journey',
                        'În acest parcurs',
                      ),
                      style: type.sectionHeading,
                    ),
                    if (stats.starsCount > 0)
                      _metric(
                        stats.starsCount,
                        _text(
                          'stelle che hai acceso',
                          'stars you have lit',
                          'stele pe care le-ai aprins',
                        ),
                        colors.gold,
                        Icons.auto_awesome,
                      ),
                    if (stats.gesturesCount > 0)
                      _metric(
                        stats.gesturesCount,
                        _text(
                          'gesti dei tuoi Pulsar',
                          'Pulsar actions completed',
                          'gesturi ale Pulsarilor tăi',
                        ),
                        colors.text,
                        Icons.circle_outlined,
                      ),
                    if (stats.projectsCount > 0)
                      _metric(
                        stats.projectsCount,
                        _text(
                          'costellazioni in cui hai lasciato un segno',
                          'constellations you have contributed to',
                          'constelații în care ai lăsat o urmă',
                        ),
                        colors.gold,
                        Icons.hub_outlined,
                      ),
                  ] else ...[
                    Text(
                      _text(
                        'Il tuo percorso cresce con ogni azione che registri.',
                        'Your journey grows with every action you record.',
                        'Parcursul tău crește cu fiecare acțiune înregistrată.',
                      ),
                      textAlign: TextAlign.center,
                      style: type.body,
                    ),
                    if (_days != null)
                      TextButton(
                        onPressed: () => setState(() => _days = null),
                        child: Text(
                          _text(
                            'Guarda tutto il percorso',
                            'See your whole journey',
                            'Vezi întregul parcurs',
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(int count, String label, Color color, IconData icon) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text('$count', style: context.typography.sectionHeading),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: context.typography.body)),
          ],
        ),
      );
}
