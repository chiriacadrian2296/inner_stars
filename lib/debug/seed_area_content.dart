import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/area_vision_repository.dart';
import '../data/moodboard_repository.dart';
import '../data/moodboard_storage.dart';
import '../data/reflection_answer_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_it.dart';
import '../l10n/strings_ro.dart';
import '../models/life_area.dart';

/// Debug helper, run by the "seed sample data" action: gives the areas
/// (supernovas) something to show — a written vision, answers to a couple of
/// reflection questions and a small moodboard (quotes and generated
/// pictures) — so those pages and the badges that count them can be tried
/// without typing everything in.
///
/// Never overwrites anything: an area that already has a vision, an answer or
/// moodboard items keeps them. Spiritual is left untouched on purpose, like
/// in the star seed, to exercise the empty state.
Future<void> seedAreaContent({
  required String languageCode,
  required AreaVisionRepository areaVisionRepository,
  required ReflectionAnswerRepository reflectionAnswerRepository,
  required MoodboardRepository moodboardRepository,
}) async {
  final strings = _stringsFor(languageCode);
  final content = _contentFor(languageCode);
  var index = 0;
  for (final area in LifeArea.values) {
    if (area == LifeArea.spiritual) continue;
    final name = area.displayName(strings);

    if (areaVisionRepository.getVision(area).isEmpty) {
      await areaVisionRepository.setVision(area, content.vision(name));
    }

    // Two of the area's four questions, with texts taken in turn from a
    // small pool and an easy-to-hard intensity that varies.
    for (final questionIndex in const [0, 2]) {
      final id = '$questionIndex';
      if (reflectionAnswerRepository.getAnswer(area, id) != null) continue;
      await reflectionAnswerRepository.setAnswer(
        area,
        id,
        answerText:
            content.answers[(index + questionIndex) % content.answers.length],
        intensity: 1 + (index * 2 + questionIndex) % 5,
      );
    }

    if (moodboardRepository.getItems(area).isEmpty) {
      final items = <MoodboardItem>[];
      var stamp = DateTime.now().microsecondsSinceEpoch;
      String nextId() => '${stamp++}';
      for (var i = 0; i < 2; i++) {
        final quote = content.quotes[(index * 2 + i) % content.quotes.length];
        items.add(
          MoodboardItem(
            id: nextId(),
            kind: MoodboardKind.quote,
            content: quote.$1,
            author: quote.$2,
            quoteStyle: MoodboardQuoteStyle
                .values[(index * 2 + i) % MoodboardQuoteStyle.values.length],
          ),
        );
        final png = await _samplePicture(index * 2 + i);
        final path = await MoodboardStorage.save(
          XFile.fromData(
            png,
            name: 'sample-${area.name}-$i.png',
            mimeType: 'image/png',
          ),
        );
        items.add(
          MoodboardItem(id: nextId(), kind: MoodboardKind.photo, content: path),
        );
      }
      await moodboardRepository.save(area, items);
    }
    index++;
  }
}

AppStrings _stringsFor(String languageCode) => switch (languageCode) {
  'it' => const StringsIt(),
  'ro' => const StringsRo(),
  _ => const StringsEn(),
};

/// A portrait picture of soft colour and a few glowing discs, different for
/// every [seed]: stands in for a photo.
Future<Uint8List> _samplePicture(int seed) async {
  const width = 600.0;
  const height = 800.0;
  final hue = (seed * 47 + 20) % 360;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const rect = Rect.fromLTWH(0, 0, width, height);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.42).toColor(),
          HSLColor.fromAHSL(
            1,
            ((hue + 50) % 360).toDouble(),
            0.5,
            0.16,
          ).toColor(),
        ],
      ).createShader(rect),
  );
  for (var i = 0; i < 4; i++) {
    final dx = ((seed * 131 + i * 197) % 520) + 40;
    final dy = ((seed * 89 + i * 263) % 680) + 60;
    canvas.drawCircle(
      Offset(dx.toDouble(), dy.toDouble()),
      40.0 + (i * 23 + seed * 7) % 90,
      Paint()
        ..color = HSLColor.fromAHSL(
          0.28,
          ((hue + 30 * i) % 360).toDouble(),
          0.7,
          0.7,
        ).toColor(),
    );
  }
  final image = await recorder.endRecording().toImage(
    width.toInt(),
    height.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

class _AreaSampleContent {
  const _AreaSampleContent({
    required this.vision,
    required this.answers,
    required this.quotes,
  });

  /// The vision text for an area called [name].
  final String Function(String name) vision;
  final List<String> answers;
  final List<(String, String)> quotes;
}

_AreaSampleContent _contentFor(String languageCode) => switch (languageCode) {
  'it' => _it,
  'ro' => _ro,
  _ => _en,
};

final _en = _AreaSampleContent(
  vision: (name) =>
      'In a year, my $name area feels lighter and more intentional.\n\n'
      '- Small, steady steps every week\n'
      '- Less rushing, more presence\n'
      "- Celebrating what I've already done",
  answers: const [
    'Lately I notice small changes, and I want to keep going at this pace.',
    "It isn't always easy, but showing up regularly makes a real difference.",
    'I used to put this off; now I make a little room for it every day.',
    'I feel better when I stop comparing myself and look at where I started.',
  ],
  quotes: const [
    ('A journey of a thousand miles begins with a single step.', 'Lao Tzu'),
    (
      'What you do every day matters more than what you do once in a while.',
      '',
    ),
    ('Well begun is half done.', 'Aristotle'),
    ('Fall seven times, stand up eight.', 'Japanese proverb'),
  ],
);

final _it = _AreaSampleContent(
  vision: (name) =>
      "Tra un anno, la mia area $name è più leggera e più consapevole.\n\n"
      '- Piccoli passi costanti ogni settimana\n'
      '- Meno fretta, più presenza\n'
      '- Festeggiare ciò che ho già fatto',
  answers: const [
    'Ultimamente noto piccoli cambiamenti e voglio continuare a questo ritmo.',
    'Non è sempre facile, ma esserci con regolarità fa davvero la differenza.',
    'Prima rimandavo; ora ogni giorno gli faccio un po\' di spazio.',
    'Sto meglio quando smetto di confrontarmi e guardo da dove sono partito.',
  ],
  quotes: const [
    ('Un viaggio di mille miglia inizia con un singolo passo.', 'Lao Tzu'),
    ('Conta di più ciò che fai ogni giorno di ciò che fai ogni tanto.', ''),
    ('Chi ben comincia è a metà dell\'opera.', 'Proverbio'),
    ('Cadi sette volte, rialzati otto.', 'Proverbio giapponese'),
  ],
);

final _ro = _AreaSampleContent(
  vision: (name) =>
      'Peste un an, zona mea $name este mai ușoară și mai conștientă.\n\n'
      '- Pași mici și constanți în fiecare săptămână\n'
      '- Mai puțină grabă, mai multă prezență\n'
      '- Să sărbătoresc ce am făcut deja',
  answers: const [
    'În ultima vreme observ schimbări mici și vreau să continui în ritmul ăsta.',
    'Nu e mereu ușor, dar faptul că apar constant face o diferență reală.',
    'Înainte amânam; acum îi fac puțin loc în fiecare zi.',
    'Mă simt mai bine când nu mă mai compar și mă uit de unde am plecat.',
  ],
  quotes: const [
    ('O călătorie de o mie de mile începe cu un singur pas.', 'Lao Tzu'),
    (
      'Contează mai mult ce faci în fiecare zi decât ce faci din când în când.',
      '',
    ),
    ('Un început bun e jumătate din drum.', 'Proverb'),
    ('Cazi de șapte ori, ridică-te de opt.', 'Proverb japonez'),
  ],
);
