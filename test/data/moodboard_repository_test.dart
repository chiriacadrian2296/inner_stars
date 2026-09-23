import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/moodboard_repository.dart';
import 'package:inner_stars/data/moodboard_storage.dart';
import 'package:inner_stars/models/life_area.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'quotes persist independently per area, edit, remove and reset',
    () async {
      final repo = await MoodboardRepository.create();
      const item = MoodboardItem(
        id: 'a',
        kind: MoodboardKind.quote,
        content: 'A vision',
      );
      await repo.save(LifeArea.physical, [item]);
      await repo.save(LifeArea.social, [item]);
      final reopened = await MoodboardRepository.create();
      expect(reopened.getItems(LifeArea.physical).single.content, 'A vision');
      await reopened.save(LifeArea.physical, [
        const MoodboardItem(
          id: 'a',
          kind: MoodboardKind.quote,
          content: 'Edited',
        ),
      ]);
      expect(repo.getItems(LifeArea.physical).single.content, 'Edited');
      expect(repo.getItems(LifeArea.social).single.content, 'A vision');
      await repo.save(LifeArea.physical, []);
      expect(repo.getItems(LifeArea.physical), isEmpty);
      await repo.clear();
      expect(repo.getItems(LifeArea.social), isEmpty);
    },
  );
  test('media is copied to persistent storage and reset removes it', () async {
    final dir = await Directory.systemTemp.createTemp('moodboard-test');
    addTearDown(() => dir.delete(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final source = XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4]),
      name: 'sample.mp4',
    );
    final path = await MoodboardStorage.save(source);
    expect(await File(path).exists(), isTrue);
    expect(await MoodboardStorage.read(path), [1, 2, 3, 4]);
    final repo = await MoodboardRepository.create();
    await repo.save(LifeArea.physical, [
      MoodboardItem(id: 'v', kind: MoodboardKind.video, content: path),
    ]);
    await repo.clear();
    expect(await File(path).exists(), isFalse);
  });
}
