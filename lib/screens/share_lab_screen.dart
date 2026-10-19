import 'package:flutter/material.dart';

import '../models/share_content.dart';
import '../l10n/strings_it.dart';
import '../l10n/strings_scope.dart';
import 'share_composer_screen.dart';

/// Development-only samples. Public sharing constructs snapshots from real data.
class ShareLabScreen extends StatelessWidget {
  const ShareLabScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final samples = [
      for (final subject in ShareSubject.values)
        ShareContent(
          subject: subject,
          title: [
            'Ho corso i miei primi 10 km',
            'Correre la mezza maratona',
            'Stretching ogni mattina',
            'Una casa tutta nostra',
            'La mia visione di benessere',
            'La vita che sto costruendo',
            'Fai il primo passo.',
          ][subject.index],
          typeLabel: [
            'Vittoria',
            'Obiettivo',
            'Abitudine',
            'Progetto',
            'Visione',
            'Moodboard',
            'Citazione',
          ][subject.index],
          description: 'Piccoli passi costanti per costruire ciò che desidero.',
          areaLabel: 'Salute',
          projectLabel: 'Mezza maratona',
          dateLabel: '12 Ott 2026',
          statLabel: '7 stelle',
          heroValue: '7',
          heroCaption: 'stelle accese su 12',
          intensity: 4,
          total: 12,
          completed: 7,
          artwork: const Icon(Icons.auto_awesome, size: 80),
        ),
    ];
    return StringsScope(
      strings: const StringsIt(),
      child: ShareComposerScreen(data: samples.first, variants: samples),
    );
  }
}
