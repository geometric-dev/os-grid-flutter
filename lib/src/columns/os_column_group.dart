import 'os_column_def.dart';

/// A group of columns displayed under a shared header.
///
/// ```dart
/// OsColumnGroup(
///   headerName: 'Personal Info',
///   children: [
///     OsColumnDef(field: 'name'),
///     OsColumnDef(field: 'age'),
///   ],
/// )
/// ```
class OsColumnGroup extends OsColumnDefBase {
  const OsColumnGroup({
    required this.headerName,
    required this.children,
    this.groupId,
    this.openByDefault = true,
    this.collapsible = false,
  });

  /// Display name for the column group header.
  final String headerName;

  /// Child columns or nested groups.
  final List<OsColumnDefBase> children;

  /// Unique identifier for this group.
  final String? groupId;

  /// Whether the group is expanded by default.
  final bool openByDefault;

  /// Whether the group can be collapsed/expanded by the user.
  final bool collapsible;
}

/// Partial defaults applied to column groups via `OsGrid.defaultColGroupDef`.
///
/// RESERVED for future use — group-level default application is not wired
/// yet; only [openByDefault] and [collapsible] are accepted today.
class OsColumnGroupDefaults {
  const OsColumnGroupDefaults({this.openByDefault, this.collapsible});

  /// Default [OsColumnGroup.openByDefault].
  final bool? openByDefault;

  /// Default [OsColumnGroup.collapsible].
  final bool? collapsible;
}
