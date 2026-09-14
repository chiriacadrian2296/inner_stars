import 'package:flutter/material.dart';

import '../data/settings_repository.dart';

/// In-memory, listenable view over [SettingsRepository] — the single
/// instance created in `main.dart` and threaded down to [MaterialApp] (for
/// theme/locale) and to [SettingsScreen] (for editing). Every setter
/// persists immediately, then notifies so the app re-renders.
class SettingsController extends ChangeNotifier {
  SettingsController(this._repository)
      : locale = _repository.locale,
        reminderEnabled = _repository.reminderEnabled,
        reminderHour = _repository.reminderHour,
        reminderMinute = _repository.reminderMinute,
        showGrid = _repository.showGrid,
        tutorialsEnabled = _repository.tutorialsEnabled;

  final SettingsRepository _repository;

  static Future<SettingsController> create() async {
    final repository = await SettingsRepository.create();
    return SettingsController(repository);
  }

  String locale;
  bool reminderEnabled;
  int reminderHour;
  int reminderMinute;
  bool showGrid;
  bool tutorialsEnabled;

  Future<void> setLocale(String code) async {
    if (code == locale) return;
    locale = code;
    await _repository.setLocale(code);
    notifyListeners();
  }

  Future<void> setReminder({required bool enabled, required int hour, required int minute}) async {
    reminderEnabled = enabled;
    reminderHour = hour;
    reminderMinute = minute;
    await _repository.setReminder(enabled: enabled, hour: hour, minute: minute);
    notifyListeners();
  }

  Future<void> setShowGrid(bool value) async {
    if (value == showGrid) return;
    showGrid = value;
    await _repository.setShowGrid(value);
    notifyListeners();
  }

  Future<void> setTutorialsEnabled(bool value) async {
    if (value == tutorialsEnabled) return;
    tutorialsEnabled = value;
    await _repository.setTutorialsEnabled(value);
    notifyListeners();
  }
}
