/// Deliberate card-size steps for “Vedi costellazione”. The third value is
/// the desktop default; the slider can still move two steps smaller or one
/// step larger.
const List<double> kConstellationCardScales = [0.34, 0.45, 0.58, 0.72];
const int kConstellationCardDefaultSizeStep = 2;

int clampConstellationCardSizeStep(int value) =>
    value.clamp(0, kConstellationCardScales.length - 1);

double constellationCardScaleFor(int step) =>
    kConstellationCardScales[clampConstellationCardSizeStep(step)];
