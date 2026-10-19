import 'package:flutter/foundation.dart';

/// Whether the internal tools (labs, sample data, reset, sound lab) are shown.
///
/// On in debug builds. A release build can show them too for a speed check:
/// `--dart-define=DEV_TOOLS=true`. The public build passes nothing and stays
/// clean.
const bool kDevTools = bool.fromEnvironment(
  'DEV_TOOLS',
  defaultValue: kDebugMode,
);
