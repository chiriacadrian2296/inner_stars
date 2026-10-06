import '../models/artwork_blend.dart';
import '../models/artwork_layer.dart';

import 'package:flutter/material.dart';

import '../data/settings_repository.dart';
import 'sky_grid_size.dart';

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
      showSupernovae = _repository.showSupernovae,
      supernovaScale = _repository.supernovaScale,
      supernovaIntensity = _repository.supernovaIntensity,
      artworkOpacity = _repository.artworkOpacity,
      artworkBlend = _repository.artworkBlend,
      artworkScale = _repository.artworkScale,
      artworkColor = Color(_repository.artworkColor),
      artworkLayer = _repository.artworkLayer,
      tutorialsEnabled = _repository.tutorialsEnabled,
      skyGridView = _repository.skyGridView,
      skyGridSizeStep = _repository.skyGridSizeStep;

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
  bool showSupernovae;
  double supernovaScale;
  double supernovaIntensity;
  double artworkOpacity;
  ArtworkBlend artworkBlend;
  double artworkScale;
  Color artworkColor;
  ArtworkLayer artworkLayer;
  bool tutorialsEnabled;

  /// The Sky browser's list/grid choice and the grid's card size (an index
  /// into [kSkyGridTileExtents]) — one pair shared by all three levels.
  bool skyGridView;
  int skyGridSizeStep;

  Future<void> setSkyGridView(bool value) async {
    if (value == skyGridView) return;
    skyGridView = value;
    notifyListeners();
    await _repository.setSkyGridView(value);
  }

  Future<void> setSkyGridSizeStep(int value) async {
    final step = clampSkyGridSizeStep(value);
    if (step == skyGridSizeStep) return;
    skyGridSizeStep = step;
    notifyListeners();
    await _repository.setSkyGridSizeStep(step);
  }

  Future<void> setLocale(String code) async {
    if (code == locale) return;
    locale = code;
    await _repository.setLocale(code);
    notifyListeners();
  }

  Future<void> setReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
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

  Future<void> setShowSupernovae(bool value) async {
    if (value == showSupernovae) return;
    showSupernovae = value;
    await _repository.setShowSupernovae(value);
    notifyListeners();
  }

  Future<void> setSupernovaScale(double value) async {
    if (value == supernovaScale) return;
    supernovaScale = value;
    notifyListeners();
    await _repository.setSupernovaScale(value);
  }

  Future<void> setSupernovaIntensity(double value) async {
    if (value == supernovaIntensity) return;
    supernovaIntensity = value;
    notifyListeners();
    await _repository.setSupernovaIntensity(value);
  }

  Future<void> setArtworkOpacity(double value) async {
    if (value == artworkOpacity) return;
    artworkOpacity = value;
    notifyListeners();
    await _repository.setArtworkOpacity(value);
  }

  Future<void> setArtworkBlend(ArtworkBlend value) async {
    if (value == artworkBlend) return;
    artworkBlend = value;
    notifyListeners();
    await _repository.setArtworkBlend(value);
  }

  Future<void> setArtworkScale(double value) async {
    if (value == artworkScale) return;
    artworkScale = value;
    notifyListeners();
    await _repository.setArtworkScale(value);
  }

  Future<void> setArtworkColor(Color value) async {
    if (value == artworkColor) return;
    artworkColor = value;
    notifyListeners();
    await _repository.setArtworkColor(value.toARGB32());
  }

  Future<void> setArtworkLayer(ArtworkLayer value) async {
    if (value == artworkLayer) return;
    artworkLayer = value;
    notifyListeners();
    await _repository.setArtworkLayer(value);
  }

  Future<void> resetCosmoVisuals() async {
    showSupernovae = SettingsRepository.defaultShowSupernovae;
    supernovaScale = SettingsRepository.defaultSupernovaScale;
    supernovaIntensity = SettingsRepository.defaultSupernovaIntensity;
    artworkOpacity = SettingsRepository.defaultArtworkOpacity;
    artworkScale = SettingsRepository.defaultArtworkScale;
    artworkColor = const Color(SettingsRepository.defaultArtworkColor);
    artworkLayer = SettingsRepository.defaultArtworkLayer;
    artworkBlend = SettingsRepository.defaultArtworkBlend;
    notifyListeners();
    await _repository.resetCosmoVisuals();
  }

  Future<void> setTutorialsEnabled(bool value) async {
    if (value == tutorialsEnabled) return;
    tutorialsEnabled = value;
    await _repository.setTutorialsEnabled(value);
    notifyListeners();
  }
}
