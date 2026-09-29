import 'dart:async';

import 'package:flutter/material.dart';

import '../events/cell_focus_events.dart';
import '../events/filter_events.dart';
import '../os_grid_controller.dart';
import '../theming/os_grid_theme.dart';

/// Debug-mode developer overlay showing live grid model statistics.
///
/// Mounted automatically above every overlay when `showInspector` is enabled
/// on the grid widget, or placed manually inside a `Stack` / `Positioned`:
///
/// ```dart
/// Stack(
///   children: [
///     OsGrid(controller: controller, ...),
///     Positioned(
///       top: 8,
///       right: 8,
///       child: GridInspector(controller: controller),
///     ),
///   ],
/// )
/// ```
///
/// Displays, live-updating as the controller changes:
///
/// - Displayed row count vs total row count, plus page info when paginated
/// - Selected row count and the first five selected row IDs
/// - Focused cell position
/// - Quick filter active state and text
/// - Column count and hidden count
/// - Infinite row model state (cache loading, lastRow known) when applicable
/// - Explicit overlay override state
///
/// The panel is collapsible via its header bar. Styling uses a monospace
/// font on a semi-transparent dark background; section headers use the
/// grid theme's [OsGridTheme.accentColor] when an optional [style] is given.
class GridInspector<TData> extends StatefulWidget {
  /// Creates a grid inspector bound to [controller].
  const GridInspector({super.key, required this.controller, this.style});

  /// The grid controller whose model state is displayed.
  final OsGridController<TData> controller;

  /// Optional grid theme; only [OsGridTheme.accentColor] is consumed (for
  /// section headers). Defaults to a fixed blue accent when null.
  final OsGridTheme? style;

  @override
  State<GridInspector<TData>> createState() => _GridInspectorState<TData>();
}

class _GridInspectorState<TData> extends State<GridInspector<TData>> {
  static const Color _panelColor = Color(0xD90E1216);
  static const Color _borderColor = Color(0x33FFFFFF);
  static const Color _defaultAccent = Color(0xFF64B5F6);
  static const Color _textColor = Color(0xFFE0E0E0);
  static const Color _dimTextColor = Color(0xFF9E9E9E);

  static const TextStyle _monoStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    height: 1.45,
    color: _textColor,
  );

  bool _expanded = true;
  StreamSubscription<OsCellFocusedEvent>? _focusSubscription;
  StreamSubscription<OsFilterChangedEvent>? _filterSubscription;

  @override
  void initState() {
    super.initState();
    _subscribe(widget.controller);
  }

  @override
  void didUpdateWidget(covariant GridInspector<TData> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      _focusSubscription?.cancel();
      _filterSubscription?.cancel();
      _subscribe(widget.controller);
    }
  }

  void _subscribe(OsGridController<TData> controller) {
    controller.addListener(_handleControllerChanged);
    // Focus and filter mutations are delivered post-frame and do not always
    // notify the controller's ChangeNotifier — subscribe to both streams so
    // the focus and quick-filter lines stay live.
    _focusSubscription = controller.onCellFocused.listen(
      (_) => _handleControllerChanged(),
    );
    _filterSubscription = controller.onFilterChanged.listen(
      (_) => _handleControllerChanged(),
    );
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _focusSubscription?.cancel();
    _filterSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.style?.accentColor ?? _defaultAccent;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: _panelColor,
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              key: const Key('grid-inspector-toggle'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: _expanded ? 0 : -0.25,
                      duration: const Duration(milliseconds: 120),
                      child: Icon(Icons.expand_more, size: 14, color: accent),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'GRID INSPECTOR',
                      style: _monoStyle.copyWith(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildSections(accent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(Color accent) {
    final controller = widget.controller;
    final widgets = <Widget>[];

    // --- Model ---
    final displayed = controller.getDisplayedRowCount();
    final totalRows = controller.rowCount;
    widgets.add(_sectionHeader('MODEL', accent));
    widgets.add(_stat('rows $displayed/$totalRows'));
    final totalPages = controller.paginationGetTotalPages();
    if (totalPages > 1) {
      widgets.add(
        _stat(
          'page ${controller.paginationGetCurrentPage()}/$totalPages'
          ' · size ${controller.paginationGetPageSize()}',
        ),
      );
    }

    // --- Selection ---
    final selectedIds = controller.getSelectedIds().toList(growable: false);
    var selectionLine = 'sel ${selectedIds.length}';
    if (selectedIds.isNotEmpty) {
      final sample = selectedIds.take(5).join(', ');
      selectionLine += ' · $sample${selectedIds.length > 5 ? ', …' : ''}';
    }
    widgets.add(_sectionHeader('SELECTION', accent));
    widgets.add(_stat(selectionLine));

    // --- Interaction state ---
    final focusedCell = controller.getFocusedCell();
    final quickFilterText = controller.getQuickFilter();
    widgets.add(_sectionHeader('STATE', accent));
    if (focusedCell == null) {
      widgets.add(_stat('focus -', dim: true));
    } else {
      widgets.add(
        _stat('focus r${focusedCell.rowIndex} c${focusedCell.columnIndex}'),
      );
    }
    widgets.add(_stat('quick filter ${quickFilterLine(quickFilterText)}'));
    final override = controller.overlayOverride;
    widgets.add(_stat('overlay ${override == null ? 'auto' : override.name}'));

    // --- Columns ---
    final allColumns = controller.getColumns().length;
    final visibleColumns = controller.getAllDisplayedColumns().length;
    widgets.add(_sectionHeader('COLUMNS', accent));
    widgets.add(
      _stat(
        'cols $visibleColumns/$allColumns'
        ' · hidden ${allColumns - visibleColumns}',
      ),
    );

    // --- Infinite row model (only when applicable) ---
    final infiniteCount = controller.getInfiniteRowCount();
    final infiniteActive =
        infiniteCount != null ||
        controller.isLastRowFound() ||
        controller.isInfiniteCacheLoading;
    if (infiniteActive) {
      widgets.add(_sectionHeader('INFINITE', accent));
      widgets.add(
        _stat('loading ${controller.isInfiniteCacheLoading ? 'yes' : 'no'}'),
      );
      widgets.add(
        _stat('last row ${controller.isLastRowFound() ? 'found' : 'unknown'}'),
      );
      if (infiniteCount != null) {
        widgets.add(_stat('virtual rows $infiniteCount'));
      }
    }

    return widgets;
  }

  static String quickFilterLine(String? text) {
    final active = text != null && text.isNotEmpty;
    return active ? "on \"$text\"" : 'off';
  }

  Widget _sectionHeader(String label, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 1),
      child: Text(
        label,
        style: _monoStyle.copyWith(
          color: accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _stat(String value, {bool dim = false}) {
    return Text(
      value,
      style: dim ? _monoStyle.copyWith(color: _dimTextColor) : _monoStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
