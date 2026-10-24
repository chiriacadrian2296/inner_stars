import 'package:fleather/fleather.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/rich_text_document.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'vision native payload travels with text and survives other-area writes',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = AreaVisionRepository(prefs);
      final doc = RichTextDocument.importMarkdown('<u>**Testo**</u>');
      final snap = RichTextDocument.capture(doc);
      doc.close();
      await repo.setVision(LifeArea.physical, snap.legacyText, richText: snap);
      await repo.setVision(LifeArea.social, 'Altro');
      expect(repo.getRichText(LifeArea.physical)!.toJson(), snap.toJson());
      final remote = Map<String, dynamic>.from(
        repo.syncCollection.readAll().firstWhere((r) => r['id'] == 'physical'),
      );
      remote['updatedAt'] = DateTime.now()
          .toUtc()
          .add(const Duration(days: 1))
          .toIso8601String();
      remote['value'] = 'Modificato da versione precedente';
      // Simulate an old client retaining unknown fields while editing legacy text.
      await repo.syncCollection.applyRemote([remote]);
      final resolved = RichTextDocument.resolve(
        repo.getVision(LifeArea.physical),
        repo.getRichText(LifeArea.physical),
      );
      expect(
        RichTextDocument.visibleText(resolved),
        'Modificato da versione precedente',
      );
      resolved.close();
    },
  );
  test('reflection sync preserves native styles and handles old-client field removal', () async {
    final repo = await ReflectionRepository.create();
    final doc = RichTextDocument.importMarkdown('Testo');
    doc.format(0, 5, ParchmentAttribute.underline);
    final snap = RichTextDocument.capture(doc);
    doc.close();
    final r = await repo.add(
      area: LifeArea.physical,
      title: 'Titolo',
      body: snap.legacyText,
      richText: snap,
    );
    await repo.add(area: LifeArea.social, title: 'Altro', body: 'Altro testo');
    expect(repo.find(r.id)!.richText!.toJson(), snap.toJson());
    await repo.update(r.id, title: 'Nuovo titolo', body: r.body);
    expect(repo.find(r.id)!.richText!.toJson(), snap.toJson());
    final remote = Map<String, dynamic>.from(
      repo.syncCollection.readAll().firstWhere((row) => row['id'] == r.id),
    );
    remote.remove('richText');
    remote['body'] = 'Nuovo testo legacy';
    remote['updatedAt'] = DateTime.now()
        .toUtc()
        .add(const Duration(days: 1))
        .toIso8601String();
    await repo.syncCollection.applyRemote([remote]);
    expect(repo.find(r.id)!.richText, null);
    expect(repo.find(r.id)!.body, 'Nuovo testo legacy');
  });
  test(
    'opening legacy content never changes persistence or sync clocks',
    () async {
      final repo = await AreaVisionRepository.create();
      await repo.setVision(LifeArea.physical, '**Vecchio testo**');
      final before = repo.syncCollection.readAll();
      final doc = RichTextDocument.resolve(
        repo.getVision(LifeArea.physical),
        repo.getRichText(LifeArea.physical),
      );
      doc.close();
      expect(repo.syncCollection.readAll(), before);
      expect(repo.getRichText(LifeArea.physical), null);
    },
  );
}
