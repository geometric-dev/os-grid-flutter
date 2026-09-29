/// Reserved field names for grid-synthesized columns.
///
/// These values are wire format: they appear as column fields/colIds in grid
/// state JSON and may be user-visible, so they must never change.
abstract final class SpecialColumns {
  static const String checkbox = '__checkbox__';
  static const String rowNumber = '__rowNumber__';
  static const String rowDrag = '__rowDrag__';

  /// Whether [field] is one of the reserved synthetic-column names.
  static bool isSpecial(String? field) =>
      field == checkbox || field == rowNumber || field == rowDrag;
}
