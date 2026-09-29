import 'package:os_grid_flutter/os_grid_flutter.dart' show OsColumnDef;
import 'package:os_grid_flutter/src/columns/os_column_def.dart'
    show OsColumnDef;

/// Parameters passed to [OsColumnDef.valueFormatter] callbacks.
///
/// Provides the raw value for formatting into a display string.
///
/// ```dart
/// valueFormatter: (params) => '\$${params.value}m',
/// ```
class ValueFormatterParams {
  const ValueFormatterParams({required this.value, required this.rowIndex});

  /// The raw cell value (from field lookup or valueGetter).
  final dynamic value;

  /// The row's display index.
  final int rowIndex;
}
