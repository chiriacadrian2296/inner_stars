/// A stable integer seed for UUID-based visual placement on every platform.
/// Do not use String.hashCode: its value is not a persistent identity.
int idSeed(String id) {
  var seed = 0;
  for (final unit in id.codeUnits) {
    seed = (seed * 31 + unit) & 0x7fffffff;
  }
  return seed;
}
