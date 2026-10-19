// Explicit marketing capture: real Galaxy painters, isolated example projects.
// flutter test tool/capture_galaxy_clips_test.dart --no-pub
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inner_stars/data/constellation_presets.dart';
import 'package:inner_stars/models/life_area.dart';
import 'package:inner_stars/models/project.dart';
import 'package:inner_stars/models/star_kind.dart';
import 'package:inner_stars/widgets/constellation_field.dart';
import 'package:inner_stars/widgets/constellation_painter.dart';
import 'package:inner_stars/widgets/nebula_background.dart';
import 'package:inner_stars/widgets/sky_area_backdrop.dart';
import 'package:inner_stars/widgets/sky_clock.dart';
import 'package:inner_stars/widgets/sky_supernova.dart';

class CaptureClock extends SkyClock {
  CaptureClock(super.vsync);
  double at = 0;
  @override
  double get seconds => at;
}

void main() {
  testWidgets('capture Galaxy flights and connected energy wave', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(512, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final clock = CaptureClock(tester);
    final key = GlobalKey();
    late ui.FragmentProgram flare;
    await tester.runAsync(() async {
      flare = await ui.FragmentProgram.fromAsset(
        'shaders/constellation_flare.frag',
      );
    });
    final placed = <PlacedConstellation>[];
    for (var i = 0; i < 6; i++) {
      final preset = starsShapePresets.firstWhere(
        (p) => p.id == ['tree', 'mountain', 'heart', 'book', 'sun', 'house'][i],
        orElse: () => starsShapePresets[i],
      );
      final shape = preset.shape;
      placed.add(
        PlacedConstellation(
          project: Project(
            id: 'capture-project-$i',
            name: '',
            area: LifeArea.professional,
            iconSlug: preset.iconSlug,
            createdAt: DateTime(2026),
          ),
          shape: shape,
          worldPosition: constellationWorldPosition(LifeArea.professional, i),
          stars: const [],
          habits: const [],
          edges: shape.edges,
          renderStars: [
            for (var j = 0; j < shape.points.length; j++)
              ConstellationStar(
                entityId: 'capture-star-$j',
                position: shape.points[j],
                kind: StarKind.lit,
                lit: true,
                label: '',
                slotSequence: j + 1,
                intensity: 2 + j % 4,
              ),
          ],
        ),
      );
    }
    final area = areaWorldPosition(LifeArea.professional),
        project = placed.first.worldPosition;
    final frames = ValueNotifier<(Offset, double)>((area, .95));
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: ValueListenableBuilder<(Offset, double)>(
            valueListenable: frames,
            builder: (context, frame, _) {
              final camera = SkyCamera.lookingAt(
                azimuthTurns: frame.$1.dx,
                elevationTurns: frame.$1.dy,
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xff0d1220)),
                  NebulaBackground(
                    camera: camera,
                    zoom: frame.$2,
                    clock: clock,
                    supernovaLight: .8,
                    supernovaLevels: const [0, 0, 2, 0, 0, 0, 0, 0],
                  ),
                  SkySupernova(
                    camera: camera,
                    zoom: frame.$2,
                    clock: clock,
                    scale: .9,
                    intensity: .8,
                    intensityLevels: const [0, 0, 2, 0, 0, 0, 0, 0],
                  ),
                  AnimatedConstellationField(
                    placed: placed,
                    camera: camera,
                    zoom: frame.$2,
                    flareProgram: flare,
                    palette: kSkyStarPalette,
                    revision: 0,
                    clock: clock,
                  ),
                  SkyAreaBackdrop(camera: camera, zoom: frame.$2, opacity: .1),
                ],
              );
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
    }
    for (final name in ['fly', 'widen', 'energy']) {
      final output = Directory('landing/.capture/galaxy-$name')
        ..createSync(recursive: true);
      final count = name == 'energy' ? 84 : 48;
      for (var i = 0; i < count; i++) {
        final t = (i / (count - 1)).clamp(0.0, 1.0),
            eased = t * t * (3 - 2 * t);
        final flight = name == 'widen' ? 1 - eased : eased;
        final u = name == 'energy' ? 1.0 : flight;
        clock.at = 1.5 + i / 12;
        frames.value = (
          Offset.lerp(area, project, u)!,
          math.exp(math.log(.95) * (1 - u) + math.log(4.2) * u),
        );
        await tester.pump(const Duration(milliseconds: 83));
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('${output.path}/${i.toString().padLeft(3, '0')}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    clock.dispose();
    frames.dispose();
  });
}
