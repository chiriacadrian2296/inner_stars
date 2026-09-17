import '../models/life_area.dart';
import '../models/project.dart';

/// What a "take me there" tap inside [SkyExplorerView] resolved to — an
/// area, a whole project/constellation, or a single star/goal/dead
/// star/pulsar within one (which has no sky position of its own beyond its
/// constellation's, so it centers on the same spot a [SkyProjectTarget]
/// for that project would — only the zoom-to-fit level differs, see
/// `NebulaScreen._zoomFor`). Turning this into an actual camera position
/// is left to whoever receives it — `NebulaScreen`, the only place that
/// already builds the placed constellations an area's/project's sky
/// position depends on.
sealed class SkyNavigationTarget {
  const SkyNavigationTarget();
}

class SkyAreaTarget extends SkyNavigationTarget {
  const SkyAreaTarget(this.area);
  final LifeArea area;
}

class SkyProjectTarget extends SkyNavigationTarget {
  const SkyProjectTarget(this.project);
  final Project project;
}

/// A single star/goal/dead star/pulsar inside [project]'s constellation —
/// zooms all the way in (see `NebulaScreen._zoomFor`), unlike
/// [SkyProjectTarget]'s "fit the whole constellation" zoom.
///
/// [starId]/[habitId] name exactly which one, when the caller actually
/// knows (a search result card does; [StarReaderScreen]'s own "take me
/// there" does too, now that it forwards the star it's showing — see
/// `SkyScreen._flyToWithHoldFeedback`, which opens that entity's own
/// tooltip once it lands rather than just the constellation's). Both null
/// falls back to that coarser, constellation-only landing — the only
/// option before either caller threaded the id through.
class SkyStarTarget extends SkyNavigationTarget {
  const SkyStarTarget(this.project, {this.starId, this.habitId});
  final Project project;
  final int? starId;
  final int? habitId;
}
