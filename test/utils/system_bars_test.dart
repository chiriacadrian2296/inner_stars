import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/utils/system_bars.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final modes = <Object?>[];

  setUp(() {
    SystemBars.reset();
    modes.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            modes.add(call.arguments);
          }
          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  final hidden = SystemUiMode.immersiveSticky.toString();
  final shown = SystemUiMode.edgeToEdge.toString();

  test('the latest wish wins, so closing a screen never shows the bars '
      'over Galaxy', () {
    final galaxy = Object();
    final vedi = Object();

    SystemBars.set(galaxy, hidden: true); // Galaxy opens.
    expect(modes, [hidden]);

    SystemBars.release(galaxy); // Vedi pushed over it (upright)...
    SystemBars.set(vedi, hidden: false);
    expect(modes.last, shown);

    SystemBars.set(vedi, hidden: true); // ...turned sideways.
    expect(modes.last, hidden);
    SystemBars.set(vedi, hidden: false); // Upright again.
    expect(modes.last, shown);

    // Back to Galaxy: it asks again before Vedi's own cleanup runs.
    SystemBars.set(galaxy, hidden: true);
    SystemBars.release(vedi);
    expect(modes.last, hidden);
  });

  test('a wish already in effect sends nothing to the system', () {
    final galaxy = Object();
    SystemBars.set(galaxy, hidden: true);
    SystemBars.set(galaxy, hidden: true);
    expect(modes, [hidden]);
  });
}
