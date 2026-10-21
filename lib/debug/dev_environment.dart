import 'package:flutter/foundation.dart' show kDebugMode;

/// Keeps ordinary debug runs local-only and separate from the public app.
///
/// Release builds always keep the production account and sync flow.
const bool kOfflineDevMode = kDebugMode;
