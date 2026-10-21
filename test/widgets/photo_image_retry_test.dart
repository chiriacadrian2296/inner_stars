import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:inner_stars/data/app_media_local.dart';
import 'package:inner_stars/sync/media/media_hooks.dart';
import 'package:inner_stars/sync/media/media_queue.dart';
import 'package:inner_stars/sync/media/media_remote.dart';
import 'package:inner_stars/sync/media/media_sync.dart';
import 'package:inner_stars/widgets/photo_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets real file work and the test's simulated time both move forward.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('looks again for a photo that is not in the cloud yet', (
    tester,
  ) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('photo-retry'),
    ))!;
    addTearDown(() => dir.deleteSync(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final remote = InMemoryMediaRemote();
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

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 40,
          height: 40,
          child: PhotoImage(photoPath: 'late-photo.jpg', fit: BoxFit.cover),
        ),
      ),
    );
    await _settle(tester);
    expect(find.byType(Image), findsNothing);
    expect(remote.downloads, 1);

    // The other device's file reaches the cloud a moment later.
    remote.files['photos/late-photo.jpg'] = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 4, height: 4)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await _settle(tester);

    expect(find.byType(Image), findsOneWidget);
    expect(remote.downloads, 2);
  });
}
