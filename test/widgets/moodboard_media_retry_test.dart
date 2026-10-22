import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:inner_stars/data/app_media_local.dart';
import 'package:inner_stars/data/moodboard_repository.dart';
import 'package:inner_stars/l10n/strings_en.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/sync/media/media_hooks.dart';
import 'package:inner_stars/sync/media/media_queue.dart';
import 'package:inner_stars/sync/media/media_remote.dart';
import 'package:inner_stars/sync/media/media_sync.dart';
import 'package:inner_stars/theme/app_theme.dart';
import 'package:inner_stars/widgets/moodboard_grid.dart';
import 'package:inner_stars/widgets/photo_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets real file work and the test's simulated time both move forward.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  late InMemoryMediaRemote remote;

  Future<void> setUpCloud(WidgetTester tester) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('moodboard-retry'),
    ))!;
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may still hold a file for a moment; the temp folder is harmless.
      }
    });
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    remote = InMemoryMediaRemote();
    MediaHooks.instance = MediaSync(
      queue: MediaQueue(prefs),
      local: AppMediaLocal(),
      remoteFor: () => remote,
    );
    final savedDelays = PhotoImage.photoRetryDelays;
    PhotoImage.photoRetryDelays = const [Duration(milliseconds: 100)];
    addTearDown(() {
      MediaHooks.instance = null;
      PhotoImage.photoRetryDelays = savedDelays;
    });
  }

  Widget page() => MaterialApp(
    theme: buildAppTheme(),
    builder: (context, child) =>
        StringsScope(strings: StringsEn(), child: child!),
    home: const Scaffold(
      body: SizedBox(
        width: 120,
        height: 120,
        child: MoodboardMedia(
          item: MoodboardItem(
            id: 'm1',
            kind: MoodboardKind.photo,
            content: 'late-moodboard.jpg',
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'looks again for a picture that is not in the cloud yet, with no error shown',
    (tester) async {
      await setUpCloud(tester);
      await tester.pumpWidget(page());
      await _settle(tester);

      // Not there yet: a spinner, not the error message.
      expect(find.byType(Image), findsNothing);
      expect(
        find.text('Media unavailable or format unsupported.'),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(remote.downloads, 1);

      // The other device's file reaches the cloud a moment later.
      remote.files['moodboard/late-moodboard.jpg'] = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 4, height: 4)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await _settle(tester);

      expect(find.byType(Image), findsOneWidget);
      expect(remote.downloads, 2);
    },
  );

  testWidgets('after the last look it says the media is unavailable', (
    tester,
  ) async {
    await setUpCloud(tester);
    await tester.pumpWidget(page());
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await _settle(tester);

    expect(find.byType(Image), findsNothing);
    expect(
      find.text('Media unavailable or format unsupported.'),
      findsOneWidget,
    );
  });
}
