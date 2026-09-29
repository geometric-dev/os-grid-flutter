import 'package:os_grid_flutter/os_grid_flutter.dart'
    show
        OsBigIntFilter,
        OsCustomFilter,
        OsDateFilter,
        OsNumberFilter,
        OsTextFilter;

/// Base class for all column filter configurations.
///
/// Subclasses define specific filter types:
/// - [OsTextFilter] for string columns
/// - [OsNumberFilter] for numeric columns
/// - [OsBigIntFilter] for large integer columns
/// - [OsDateFilter] for date columns
/// - [OsCustomFilter] for user-provided custom filter logic
abstract class OsFilter {
  const OsFilter();
}
