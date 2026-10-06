import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'strings_en.dart';
import 'strings_it.dart';
import 'strings_ro.dart';

AppStrings stringsForLocale(String code) {
  switch (code) {
    case 'it':
      return const StringsIt();
    case 'ro':
      return const StringsRo();
    default:
      return const StringsEn();
  }
}

/// Delivers the current [AppStrings] down the widget tree, resolved from
/// [SettingsController.locale] — wraps [MaterialApp]'s `builder` in
/// `main.dart` so every screen can reach it via `context.strings`.
class StringsScope extends InheritedWidget {
  const StringsScope({super.key, required this.strings, required super.child});

  final AppStrings strings;

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StringsScope>();
    assert(
      scope != null,
      'No StringsScope found in context — is the app wrapped in one?',
    );
    return scope!.strings;
  }

  @override
  bool updateShouldNotify(StringsScope oldWidget) =>
      oldWidget.strings.languageCode != strings.languageCode;
}

extension AppStringsX on BuildContext {
  AppStrings get strings => StringsScope.of(this);
}
