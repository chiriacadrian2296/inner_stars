import 'package:flutter/material.dart';
import 'package:inner_stars/screens/share_lab_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';

/// Standalone entry to preview the Share Lab on its own (web or desktop):
/// `flutter run -d web-server -t tool/share_lab_preview.dart`.
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const ShareLabScreen(),
    ),
  );
}
