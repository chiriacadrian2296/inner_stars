/// How “Vedi costellazione” arranges its numbered cards around the graph.
///
/// Persist the enum name, not its index, so new arrangements can be added
/// without changing an existing choice.
enum ConstellationCardLayout {
  bottomGrid,
  sideColumns,
  aroundShape;

  static ConstellationCardLayout fromName(String? value) {
    for (final layout in values) {
      if (layout.name == value) return layout;
    }
    return bottomGrid;
  }
}
