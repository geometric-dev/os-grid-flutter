import 'package:flutter/rendering.dart';

import '../columns/os_column_def.dart';
import '../columns/os_column_pin.dart';
import '../locale/os_locale_text.dart';
import '../render_api/cell_flash.dart';
import '../rendering/special_columns.dart';
import '../row_auto_height/row_height_layout.dart';
import '../row_grouping/row_group_service.dart';
import '../row_grouping/tree_data_service.dart';
import '../sorting/sort_direction.dart';
import '../sorting/sort_indicator_info.dart';

/// Resolves a locale key to a display string.
///
/// Mirrors [OsLocaleText.getLocaleText]: receives the canonical key and the
/// English default, returns the translated value. Pass
/// `(key, defaultValue) => localeText.getLocaleText(key, defaultValue)` to
/// route semantics through a custom locale.
typedef OsLocaleResolver = String Function(String key, String defaultValue);

/// Builds [CustomPainterSemantics] for the grid's visible cells.
///
/// This provides screen reader accessibility for the canvas-rendered grid
/// by generating semantic annotations for each visible header and data cell.
/// Flutter only builds the semantics tree when accessibility services are
/// active, so there is no performance cost when accessibility is disabled.
///
/// All generated labels are routed through [localeResolver], so screen reader
/// strings localise with the rest of the grid UI. When omitted, built-in
/// English defaults are used.
///
/// [textDirection] controls the announced reading direction of every label.
/// When null it falls back to [TextDirection.ltr]. Callers with a build
/// context should pass `Directionality.maybeOf(context) ??
/// TextDirection.ltr` (or `MediaQuery.maybeDirectionOf(context)`) so RTL
/// locales announce correctly.
///
/// ## ARIA grid pattern mapping (quality program v3 item 17)
///
/// The WAI-ARIA grid pattern is expressed through the semantics properties
/// Flutter can attach to canvas nodes. Because [CustomPainterSemantics] emits
/// a flat sibling list (real `SemanticsRole.table`/`row`/`cell` nesting is
/// assembled only by widget-tree render objects and is rejected by Flutter's
/// debug role-hierarchy checks when the parent node is not a row), each ARIA
/// concept maps onto per-node properties:
///
/// | ARIA concept            | Semantics property                                   |
/// |-------------------------|------------------------------------------------------|
/// | `role="gridcell"`       | cell nodes (the atomic semantics nodes of the grid)   |
/// | `aria-selected`         | `selected` on every cell of the row                   |
/// | `aria-checked`          | `checked` on checkbox-column cells                    |
/// | `aria-expanded`         | `expanded` on the group/tree row's first visible cell |
/// | `aria-rowindex`/`colindex` | `identifier` in 1-based `r<row>c<col>` form         |
/// | roving tab index        | `focused: true` on the focused cell only; every other cell reports `focused: false` (not focusable) |
/// | edit state              | `textField: true` + `', editing'` label suffix + optional `value` on the edited cell |
///
/// Usage: assign this as the `semanticsBuilder` on the grid painter.
List<CustomPainterSemantics> buildGridSemantics({
  required Size size,
  required List<OsColumnDef> columns,
  required List<Map<String, dynamic>> rowData,
  required double rowHeight,
  required double headerHeight,
  required double scrollX,
  required double scrollY,
  required double groupHeaderHeight,
  required double floatingFilterHeight,
  required Set<int> selectedRows,
  required int focusedRow,
  required int focusedCol,
  List<double>? columnWidths,
  Map<int, SortIndicatorInfo>? sortIndicators,
  RowHeightLayout? rowHeightLayout,
  OsLocaleResolver? localeResolver,
  TextDirection? textDirection,
  CellPosition? editingCell,
  String? editingValue,
}) {
  final resolve =
      localeResolver ??
      (key, defaultValue) =>
          OsLocaleText.defaultLocale.getLocaleText(key, defaultValue);
  final dir = textDirection ?? TextDirection.ltr;

  final semantics = <CustomPainterSemantics>[];

  final totalHeaderHeight =
      groupHeaderHeight + headerHeight + floatingFilterHeight;
  final dataAreaHeight = size.height - totalHeaderHeight;

  // Build column layout for positioning
  final widths = List.generate(columns.length, (i) {
    return columnWidths != null && i < columnWidths.length
        ? columnWidths[i]
        : columns[i].width ?? 150.0;
  });

  // Compute visible column ranges and positions
  final colPositions = _computeVisibleColumns(
    columns: columns,
    widths: widths,
    scrollX: scrollX,
    viewportWidth: size.width,
  );

  // --- Header cells ---
  for (final colPos in colPositions) {
    final col = columns[colPos.index];
    final headerName = col.headerName ?? col.field ?? '';

    // Build sort state label
    String label = headerName;
    final sortInfo = sortIndicators?[colPos.index];
    if (sortInfo != null) {
      final dirLabel = sortInfo.direction == OsSortDirection.ascending
          ? resolve('sortedAscending', 'sorted ascending')
          : resolve('sortedDescending', 'sorted descending');
      label = '$headerName, $dirLabel';
    }

    semantics.add(
      CustomPainterSemantics(
        rect: Rect.fromLTWH(
          colPos.x,
          groupHeaderHeight,
          colPos.width,
          headerHeight,
        ),
        properties: SemanticsProperties(
          label: label,
          textDirection: dir,
          header: true,
          // aria-rowindex/aria-colindex surrogate: the header band is grid
          // row 1 (1-based, matching AG Grid), so headers identify as r1cN.
          identifier: 'r1c${colPos.index + 1}',
          sortKey: OrdinalSortKey(colPos.index.toDouble()),
        ),
      ),
    );
  }

  // --- Data cells ---
  // Determine visible row range
  if (rowData.isEmpty) return semantics;

  final int firstVisibleRow;
  final int lastVisibleRow;

  if (rowHeightLayout != null) {
    firstVisibleRow = rowHeightLayout
        .getRowIndexAtY(scrollY)
        .clamp(0, rowData.length - 1);
    // Find last visible row by searching for the row at scrollY + dataAreaHeight
    final lastY = scrollY + dataAreaHeight;
    lastVisibleRow = rowHeightLayout
        .getRowIndexAtY(lastY)
        .clamp(0, rowData.length - 1);
  } else {
    firstVisibleRow = (scrollY / rowHeight).floor().clamp(
      0,
      rowData.length - 1,
    );
    lastVisibleRow = ((scrollY + dataAreaHeight) / rowHeight).ceil().clamp(
      0,
      rowData.length - 1,
    );
  }

  // Group rows carry their descriptive label on the first visible column
  // only (mirroring where the group cell renders); remaining cells stay empty
  // to avoid repeating a long label on every cell traversal.
  var firstVisibleIndex = -1;
  for (final colPos in colPositions) {
    if (firstVisibleIndex < 0 || colPos.index < firstVisibleIndex) {
      firstVisibleIndex = colPos.index;
    }
  }

  for (int rowIdx = firstVisibleRow; rowIdx <= lastVisibleRow; rowIdx++) {
    final row = rowData[rowIdx];
    final isSelected = selectedRows.contains(rowIdx);

    // Compute row Y position
    final double rowTop;
    final double rowH;
    if (rowHeightLayout != null) {
      rowTop = rowHeightLayout.getRowTop(rowIdx) - scrollY + totalHeaderHeight;
      rowH = rowHeightLayout.getRowHeight(rowIdx);
    } else {
      rowTop = rowIdx * rowHeight - scrollY + totalHeaderHeight;
      rowH = rowHeight;
    }

    // Group rows read raw fields as null; build a human-readable label from
    // the group metadata instead of announcing an empty cell.
    final groupLabel = _groupRowLabel(row, columns: columns, resolve: resolve);
    final isGroupRow = groupLabel != null;

    // aria-expanded lives on the expandable row's first visible cell. Group
    // services always stamp kGroupExpanded on group rows; a group row without
    // the key defaults to collapsed so the flag is always present (true or
    // false) exactly on expandable rows.
    final isRowExpanded =
        isGroupRow && (row[RowGroupKeys.kGroupExpanded] as bool? ?? false);

    for (final colPos in colPositions) {
      final col = columns[colPos.index];
      final field = col.field;

      // Get the display value
      String cellLabel;
      if (groupLabel != null) {
        cellLabel = colPos.index == firstVisibleIndex ? groupLabel : '';
      } else if (field != null && row.containsKey(field)) {
        cellLabel = row[field]?.toString() ?? '';
      } else {
        cellLabel = '';
      }

      // Determine if this is the focused cell. The roving tab index keeps
      // exactly one cell focusable: the focused cell reports focused: true,
      // all others report focused: false (explicitly not focusable) while
      // still exposing their position.
      final isFocused = rowIdx == focusedRow && colPos.index == focusedCol;

      // Determine if this is a checkbox column
      final isCheckbox = field == SpecialColumns.checkbox;

      // Edit state (see [editingCell]): the affected cell switches to a text
      // field role with an ', editing' suffix so screen readers announce the
      // mode change when onCellEditingStarted/Stopped trigger a rebuild.
      final isEditingCell =
          editingCell != null &&
          editingCell.rowIndex == rowIdx &&
          editingCell.colId == col.effectiveColId;

      var label = isCheckbox
          ? (isSelected
                ? resolve('selected', 'Selected')
                : resolve('notSelected', 'Not selected'))
          : cellLabel;

      String? value;
      if (isEditingCell) {
        final editingWord = resolve('editingCell', 'editing');
        label = label.isEmpty ? editingWord : '$label, $editingWord';
        if (editingValue != null) value = editingValue;
      }

      final properties = SemanticsProperties(
        label: label,
        value: value,
        textDirection: dir,
        selected: isSelected,
        focused: isFocused || isEditingCell,
        checked: isCheckbox ? isSelected : null,
        expanded: isGroupRow && colPos.index == firstVisibleIndex
            ? isRowExpanded
            : null,
        textField: isEditingCell ? true : null,
        // aria-rowindex/aria-colindex surrogate: 1-based cell position. The
        // header band is grid row 1, so data cells identify as rNcM with
        // N >= 2 (matching AG Grid's aria-rowindex).
        identifier: 'r${rowIdx + 2}c${colPos.index + 1}',
        sortKey: OrdinalSortKey(
          rowIdx * columns.length + colPos.index.toDouble(),
          name: 'cell',
        ),
      );

      semantics.add(
        CustomPainterSemantics(
          rect: Rect.fromLTWH(colPos.x, rowTop, colPos.width, rowH),
          properties: properties,
        ),
      );
    }
  }

  return semantics;
}

/// Builds the accessibility label for a group/tree row, or null when [row]
/// is an ordinary data row.
///
/// Column-group rows (which carry a backing `__groupField`) announce as
/// `'<header name>: <group key> — <n> children'`, resolving the friendly
/// header name from [columns] and falling back to the raw field. Tree-data
/// group rows have no backing column (their metadata uses the synthetic
/// `'__tree'` field), so they announce with the localized [OsLocaleText.rowGroup]
/// prefix instead: `'Row Group: <key> — <n> children'`. Each synthetic tree
/// node corresponds to one path segment, so its key plus child count fully
/// describe its position in the hierarchy.
String? _groupRowLabel(
  Map<String, dynamic> row, {
  required List<OsColumnDef> columns,
  required OsLocaleResolver resolve,
}) {
  if (row[RowGroupKeys.kIsGroupRow] != true) return null;

  final key = row[RowGroupKeys.kGroupKey]?.toString() ?? '';
  final field = row[RowGroupKeys.kGroupField] as String?;
  final childCount = (row[RowGroupKeys.kGroupChildCount] as int?) ?? 0;
  final childrenWord = resolve('children', 'children');
  final suffix = '$childCount $childrenWord';

  if (field == null || field == TreeDataService.treeFieldId) {
    return '${resolve('rowGroup', 'Row Group')}: $key — $suffix';
  }

  var headerName = field;
  for (final col in columns) {
    if (col.effectiveColId == field || col.field == field) {
      headerName = col.headerName ?? col.field ?? field;
      break;
    }
  }
  return '$headerName: $key — $suffix';
}

/// Represents a visible column's position in the viewport.
class _VisibleColumn {
  const _VisibleColumn({
    required this.index,
    required this.x,
    required this.width,
  });

  final int index;
  final double x;
  final double width;
}

/// Computes which columns are visible in the viewport and their x positions.
List<_VisibleColumn> _computeVisibleColumns({
  required List<OsColumnDef> columns,
  required List<double> widths,
  required double scrollX,
  required double viewportWidth,
}) {
  final result = <_VisibleColumn>[];

  // Separate columns into pinned left, center, and pinned right
  double leftWidth = 0;
  double rightWidth = 0;
  final leftCols = <int>[];
  final rightCols = <int>[];
  final centerCols = <int>[];

  for (int i = 0; i < columns.length; i++) {
    final pin = columns[i].pinned;
    if (pin == OsColumnPin.left) {
      leftCols.add(i);
      leftWidth += widths[i];
    } else if (pin == OsColumnPin.right) {
      rightCols.add(i);
      rightWidth += widths[i];
    } else {
      centerCols.add(i);
    }
  }

  final rightSectionX = viewportWidth - rightWidth;

  // Left pinned columns (always visible)
  double x = 0;
  for (final i in leftCols) {
    result.add(_VisibleColumn(index: i, x: x, width: widths[i]));
    x += widths[i];
  }

  // Center columns (scrolled, only include visible ones)
  x = leftWidth;
  double centerOffset = 0;
  for (final i in centerCols) {
    final colX = leftWidth + centerOffset - scrollX;
    final colRight = colX + widths[i];

    // Include if any part is visible in the center viewport
    if (colRight > leftWidth && colX < rightSectionX) {
      result.add(_VisibleColumn(index: i, x: colX, width: widths[i]));
    }
    centerOffset += widths[i];
  }

  // Right pinned columns (always visible)
  x = rightSectionX;
  for (final i in rightCols) {
    result.add(_VisibleColumn(index: i, x: x, width: widths[i]));
    x += widths[i];
  }

  return result;
}
