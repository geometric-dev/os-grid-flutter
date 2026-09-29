import 'dart:math' as math;

/// Parameters passed to the `getRowHeight` callback.
///
/// Provides the row data and index so the callback can determine
/// the appropriate height for each row.
class RowHeightParams<TData> {
  const RowHeightParams({required this.data, required this.rowIndex});

  /// The row data for this row.
  final TData data;

  /// The display index of this row (after sort/filter).
  final int rowIndex;
}

/// Pre-computed layout for variable row heights.
///
/// Stores per-row heights and cumulative Y offsets for O(1) row
/// positioning and O(log n) visible-row lookup via binary search.
///
/// When all rows have the same height (uniform mode), this class
/// falls back to simple multiplication for maximum performance.
class RowHeightLayout {
  /// Creates a uniform layout where all rows have the same height.
  RowHeightLayout.uniform({required int rowCount, required double rowHeight})
    : _rowHeights = null,
      _cumulativeOffsets = null,
      _uniformHeight = rowHeight,
      _rowCount = rowCount,
      _totalHeight = rowCount * rowHeight;

  /// Creates a variable layout from per-row heights.
  ///
  /// [heights] must have exactly [rowCount] entries.
  RowHeightLayout.variable({required List<double> heights})
    : _rowHeights = heights,
      _uniformHeight = null,
      _rowCount = heights.length,
      _cumulativeOffsets = _buildCumulativeOffsets(heights),
      _totalHeight = heights.isEmpty
          ? 0.0
          : _buildCumulativeOffsets(heights).last;

  final List<double>? _rowHeights;
  final List<double>? _cumulativeOffsets;
  final double? _uniformHeight;
  final int _rowCount;
  final double _totalHeight;

  /// Whether this layout uses uniform row heights.
  bool get isUniform => _uniformHeight != null;

  /// Total number of rows.
  int get rowCount => _rowCount;

  /// Total height of all rows combined.
  double get totalHeight => _totalHeight;

  /// Returns the height of the row at [index].
  double getRowHeight(int index) {
    if (_uniformHeight != null) return _uniformHeight;
    if (index < 0 || index >= _rowCount) return 0.0;
    return _rowHeights![index];
  }

  /// Returns the Y offset (top edge) of the row at [index].
  double getRowTop(int index) {
    if (_uniformHeight != null) return index * _uniformHeight;
    if (index <= 0) return 0.0;
    if (index >= _rowCount) return _totalHeight;
    return _cumulativeOffsets![index];
  }

  /// Returns the Y offset of the bottom edge of the row at [index].
  double getRowBottom(int index) {
    if (_uniformHeight != null) return (index + 1) * _uniformHeight;
    if (index < 0) return 0.0;
    if (index >= _rowCount) return _totalHeight;
    return _cumulativeOffsets![index + 1];
  }

  /// Finds the row index at the given Y offset using binary search.
  ///
  /// Returns the index of the row that contains [y], or -1 if [y]
  /// is outside the valid range.
  int getRowIndexAtY(double y) {
    if (y < 0 || _rowCount == 0) return -1;
    if (y >= _totalHeight) return -1;

    if (_uniformHeight != null) {
      return math.min((y / _uniformHeight).floor(), _rowCount - 1);
    }

    // Binary search on cumulative offsets.
    // _cumulativeOffsets[i] = top of row i, _cumulativeOffsets[i+1] = bottom of row i.
    final offsets = _cumulativeOffsets!;
    int lo = 0;
    int hi = _rowCount - 1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final top = offsets[mid];
      final bottom = offsets[mid + 1];
      if (y < top) {
        hi = mid - 1;
      } else if (y >= bottom) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return -1;
  }

  /// Returns the first visible row index for the given scroll offset.
  int getFirstVisibleRow(double scrollY) {
    final index = getRowIndexAtY(scrollY);
    return index < 0 ? 0 : index;
  }

  /// Returns the last visible row index for the given scroll offset
  /// and viewport height.
  int getLastVisibleRow(double scrollY, double viewportHeight) {
    final index = getRowIndexAtY(scrollY + viewportHeight);
    if (index < 0) return _rowCount - 1;
    return math.min(index, _rowCount - 1);
  }

  /// Builds cumulative offset array from heights.
  ///
  /// Returns an array of length `heights.length + 1` where:
  /// - `offsets[0] = 0`
  /// - `offsets[i] = sum of heights[0..i-1]`
  /// - `offsets[n] = total height`
  static List<double> _buildCumulativeOffsets(List<double> heights) {
    final offsets = List<double>.filled(heights.length + 1, 0.0);
    for (int i = 0; i < heights.length; i++) {
      offsets[i + 1] = offsets[i] + heights[i];
    }
    return offsets;
  }
}
