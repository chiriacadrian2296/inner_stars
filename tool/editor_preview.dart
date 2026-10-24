import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inner_stars/debug/dev_tools.dart';
import 'package:inner_stars/data/area_vision_repository.dart';
import 'package:inner_stars/data/reflection_repository.dart';
import 'package:inner_stars/l10n/strings_it.dart';
import 'package:inner_stars/l10n/strings_scope.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/screens/area_reflections_screen.dart';
import 'package:inner_stars/screens/vision_editor_screen.dart';
import 'package:inner_stars/theme/app_theme.dart';

/// Isolated manual checks on web/Android without reading or writing user data.
/// flutter run -t tool/editor_preview.dart -d web-server --web-port 8792
Future<void> main() async {
  if (!kDevTools) return;
  MarionetteBinding.ensureInitialized();
  // This standalone preview deliberately uses an ephemeral preferences store.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final visions = await AreaVisionRepository.create();
  final reflections = await ReflectionRepository.create();
  runApp(
    StringsScope(
      strings: const StringsIt(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('it'),
        supportedLocales: const [Locale('it'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    key: const ValueKey('preview-vision'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => VisionEditorScreen(
                          area: LifeArea.physical,
                          repository: visions,
                        ),
                      ),
                    ),
                    child: const Text('Visione'),
                  ),
                  TextButton(
                    key: const ValueKey('preview-reflections'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AreaReflectionsScreen(
                          area: LifeArea.physical,
                          repository: reflections,
                        ),
                      ),
                    ),
                    child: const Text('Riflessioni'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
