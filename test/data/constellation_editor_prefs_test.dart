import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/data/constellation_editor_prefs.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('hideHelp defaults to false when nothing has been saved yet', () async {
    final prefs = await ConstellationEditorPrefs.create();

    expect(prefs.hideHelp, isFalse);
  });

  test('setHideHelp(true) persists and survives reloading from the same storage', () async {
    final prefs = await ConstellationEditorPrefs.create();

    await prefs.setHideHelp(true);

    expect(prefs.hideHelp, isTrue);
    final reloaded = await ConstellationEditorPrefs.create();
    expect(reloaded.hideHelp, isTrue);
  });

  test('setHideHelp(false) can turn the flag back off', () async {
    final prefs = await ConstellationEditorPrefs.create();
    await prefs.setHideHelp(true);

    await prefs.setHideHelp(false);

    expect(prefs.hideHelp, isFalse);
  });
}
