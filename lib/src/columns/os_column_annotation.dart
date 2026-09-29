/// Declarative annotations for deriving `OsColumnDef`s from Dart data
/// classes.
///
/// These annotations are the single source of truth for both the runtime
/// column factory (`OsColumnDefs.fromType`) and the offline generator script
/// (`tool/os_column_gen.dart`). They are plain const classes — no code
/// generation is required to *read* them, only to *discover* them in source.
///
/// ```dart
/// @OsGridColumn(colIdPrefix: 'person.')
/// class Person {
///   @OsColumn(headerName: 'Name', width: 150)
///   final String name;
///
///   @OsColumn(headerName: 'Age', filter: OsColumnFilterHint.number)
///   final int age;
///
///   const Person(this.name, this.age);
/// }
/// ```
///
/// Only const-compatible primitives (strings, numbers, bools, enums) may be
/// used as annotation arguments. Behavioural members that cannot be `const`
/// (value getters with custom logic, comparators, cell renderers) are supplied
/// afterwards via the `overrides` parameter of the factory, keyed by field
/// name.
library;

import 'os_column_pin.dart';

/// Filter type hint for a generated column.
///
/// The default (`null`) infers a sensible filter from the declared field
/// type (String → text, num → number, DateTime → date). Use an explicit
/// hint to override the inference or suppress the filter entirely with
/// [OsColumnFilterHint.none].
enum OsColumnFilterHint {
  /// No filter is attached to the column.
  none,

  /// A [text filter](OsTextFilter) is attached to the column.
  text,

  /// A [number filter](OsNumberFilter) is attached to the column.
  number,

  /// A [date filter](OsDateFilter) is attached to the column.
  date,
}

/// Class-level annotation marking a data class as grid-column derivable.
///
/// Read by `tool/os_column_gen.dart` when scanning sources, and accepted by
/// [runtime schema registration](`OsColumnRegistry.register`) so both paths
/// share the same defaults.
class OsGridColumn {
  /// Creates a class-level configuration annotation.
  const OsGridColumn({
    this.colIdPrefix,
    this.defaultWidth,
    this.defaultSortable,
    this.defaultResizable,
    this.exclude = const <String>{},
  });

  /// Prefix prepended to every derived colId (e.g. `'person.'` produces
  /// colIds like `'person.name'`). Useful when the same field name appears
  /// in several classes on one grid.
  final String? colIdPrefix;

  /// Width applied to columns whose field annotation does not set one.
  final double? defaultWidth;

  /// Sortability applied to columns whose field annotation does not set it.
  ///
  /// When null, the grid-wide default (`false`) applies.
  final bool? defaultSortable;

  /// Resizability applied to columns whose field annotation does not set it.
  ///
  /// When null, the grid-wide default (`true`) applies.
  final bool? defaultResizable;

  /// Field names excluded from derivation entirely (e.g. cached internals).
  final Set<String> exclude;
}

/// Field-level annotation carrying per-column display and behaviour metadata.
///
/// All fields are optional; anything omitted falls back to type-based
/// inference (header name from the field name, filter from the declared
/// type). Non-const behaviour (custom value logic, renderers) belongs in the
/// factory's `overrides`, not here.
class OsColumn {
  /// Creates a field-level column annotation.
  const OsColumn({
    this.headerName,
    this.colId,
    this.width,
    this.minWidth,
    this.maxWidth,
    this.flex,
    this.sortable,
    this.resizable,
    this.hide,
    this.pinned,
    this.editable,
    this.singleClickEdit,
    this.autoHeight,
    this.wrapText,
    this.suppressMenu,
    this.lockVisible,
    this.lockPinned,
    this.lockPosition,
    this.rowGroup,
    this.pivot,
    this.aggFunc,
    this.tooltipField,
    this.headerTooltip,
    this.filter,
  });

  // --- Identity ---

  /// Display name shown in the header. Defaults to the capitalised field
  /// name (`'firstName'` → `'First name'`).
  final String? headerName;

  /// Explicit colId. Defaults to the (optionally prefixed) field name.
  final String? colId;

  // --- Sizing ---

  /// Initial width in logical pixels.
  final double? width;

  /// Minimum resizable width.
  final double? minWidth;

  /// Maximum resizable width.
  final double? maxWidth;

  /// Flex factor for distributing remaining space.
  final int? flex;

  // --- Behaviour ---

  /// Whether the column can be sorted. Overrides [OsGridColumn.defaultSortable].
  final bool? sortable;

  /// Whether the column can be resized. Overrides
  /// [OsGridColumn.defaultResizable].
  final bool? resizable;

  /// Whether the column starts hidden.
  final bool? hide;

  /// Pin side for the column.
  final OsColumnPin? pinned;

  /// Whether cells are editable. Editing additionally requires the target
  /// field to be writable (a non-`final` declaration, or a `setValue`
  /// callback registered at runtime).
  final bool? editable;

  /// Whether a single click starts editing.
  final bool? singleClickEdit;

  // --- Auto height ---

  /// Whether row height adapts to this column's content.
  final bool? autoHeight;

  /// Whether cell text wraps onto multiple lines.
  final bool? wrapText;

  // --- Menu / locking ---

  /// Whether the context menu is suppressed for this column.
  final bool? suppressMenu;

  /// Whether visibility changes are locked.
  final bool? lockVisible;

  /// Whether pin-state changes are locked.
  final bool? lockPinned;

  /// Whether position moves are locked.
  final bool? lockPosition;

  // --- Grouping / aggregation / pivot ---

  /// Whether the column drives row grouping.
  final bool? rowGroup;

  /// Whether the column is a pivot column.
  final bool? pivot;

  /// Built-in aggregation function name (`'sum'`, `'avg'`, …) applied when
  /// row grouping is active.
  final String? aggFunc;

  // --- Tooltip ---

  /// Field read for cell tooltips (dot notation supported).
  final String? tooltipField;

  /// Static tooltip shown over the column header.
  final String? headerTooltip;

  // --- Filtering ---

  /// Explicit filter hint overriding type inference. See
  /// [OsColumnFilterHint].
  final OsColumnFilterHint? filter;
}
