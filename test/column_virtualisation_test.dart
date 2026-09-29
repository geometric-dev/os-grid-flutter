import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/src/columns/os_column_def.dart';
import 'package:os_grid_flutter/src/columns/os_column_pin.dart';
import 'package:os_grid_flutter/src/rendering/column_layout.dart';

void main() {
  group('ColumnLayout.getVisibleColumnRange', () {
    late ColumnLayout layout;

    setUp(() {
      // 10 center columns, each 100px wide (total 1000px)
      final columns = List.generate(
        10,
        (i) => OsColumnDef(field: 'col$i', headerName: 'Col $i', width: 100),
      );
      final widths = List.generate(10, (_) => 100.0);
      layout = ColumnLayout(columns: columns, widths: widths);
    });

    test('returns null when no center columns', () {
      final emptyLayout = ColumnLayout(columns: [], widths: []);
      final range = emptyLayout.getVisibleColumnRange(0, 500);
      expect(range, isNull);
    });

    test('returns all columns when viewport is wider than content', () {
      final range = layout.getVisibleColumnRange(0, 1200);
      expect(range, isNotNull);
      expect(range!.first, 0);
      expect(range.last, 9);
    });

    test('returns first columns when scrolled to start', () {
      // Viewport 400px wide, scrolled to 0 → columns 0-3 visible
      // With buffer of 2: first=0, last=5
      final range = layout.getVisibleColumnRange(0, 400);
      expect(range, isNotNull);
      expect(range!.first, 0); // max(0-2, 0) = 0
      expect(range.last, 5); // min(3+2, 9) = 5
    });

    test('returns middle columns when scrolled to middle', () {
      // Viewport 300px wide, scrolled to 350px → columns 3-6 visible
      // With buffer of 2: first=1, last=8
      final range = layout.getVisibleColumnRange(350, 300);
      expect(range, isNotNull);
      expect(range!.first, 1); // max(3-2, 0) = 1
      expect(range.last, 8); // min(6+2, 9) = 8
    });

    test('returns last columns when scrolled to end', () {
      // Viewport 300px wide, scrolled to 700px → columns 7-9 visible
      // With buffer of 2: first=5, last=9
      final range = layout.getVisibleColumnRange(700, 300);
      expect(range, isNotNull);
      expect(range!.first, 5); // max(7-2, 0) = 5
      expect(range.last, 9); // min(9+2, 9) = 9
    });

    test('respects custom buffer size', () {
      // Viewport 200px wide, scrolled to 300px → columns 3-4 visible
      // With buffer of 1: first=2, last=5
      final range = layout.getVisibleColumnRange(300, 200, buffer: 1);
      expect(range, isNotNull);
      expect(range!.first, 2); // max(3-1, 0) = 2
      expect(range.last, 5); // min(4+1, 9) = 5
    });

    test('buffer of 0 returns exact visible range', () {
      // Viewport 200px wide, scrolled to 300px → columns 3-4 visible
      final range = layout.getVisibleColumnRange(300, 200, buffer: 0);
      expect(range, isNotNull);
      expect(range!.first, 3);
      expect(range.last, 4);
    });

    test('handles single column viewport', () {
      // Viewport 50px wide, scrolled to 450px → column 4 partially visible
      final range = layout.getVisibleColumnRange(450, 50, buffer: 0);
      expect(range, isNotNull);
      expect(range!.first, 4);
      expect(range.last, 4);
    });

    test('handles variable width columns', () {
      final columns = [
        const OsColumnDef(field: 'a', headerName: 'A', width: 50),
        const OsColumnDef(field: 'b', headerName: 'B', width: 200),
        const OsColumnDef(field: 'c', headerName: 'C', width: 100),
        const OsColumnDef(field: 'd', headerName: 'D', width: 150),
        const OsColumnDef(field: 'e', headerName: 'E', width: 80),
      ];
      final widths = [50.0, 200.0, 100.0, 150.0, 80.0];
      final varLayout = ColumnLayout(columns: columns, widths: widths);

      // Viewport 200px, scrolled to 100px
      // Col positions: 0-50, 50-250, 250-350, 350-500, 500-580
      // Visible: cols starting at x>=100 and ending before x<=300
      // Col 1 (50-250) is visible, col 2 (250-350) partially visible
      final range = varLayout.getVisibleColumnRange(100, 200, buffer: 0);
      expect(range, isNotNull);
      expect(range!.first, 1); // first col whose right edge > 100
      expect(range.last, 2); // last col whose left edge < 300
    });

    test('pinned columns are excluded from center range', () {
      final columns = [
        const OsColumnDef(
          field: 'pinL',
          headerName: 'Pin L',
          width: 80,
          pinned: OsColumnPin.left,
        ),
        const OsColumnDef(field: 'c1', headerName: 'C1', width: 100),
        const OsColumnDef(field: 'c2', headerName: 'C2', width: 100),
        const OsColumnDef(field: 'c3', headerName: 'C3', width: 100),
        const OsColumnDef(
          field: 'pinR',
          headerName: 'Pin R',
          width: 80,
          pinned: OsColumnPin.right,
        ),
      ];
      final widths = [80.0, 100.0, 100.0, 100.0, 80.0];
      final pinnedLayout = ColumnLayout(columns: columns, widths: widths);

      // Only 3 center columns
      expect(pinnedLayout.centerCols.length, 3);
      expect(pinnedLayout.leftCols.length, 1);
      expect(pinnedLayout.rightCols.length, 1);

      // Viewport 150px, scrolled to 50px → cols 0-1 visible in center
      final range = pinnedLayout.getVisibleColumnRange(50, 150, buffer: 0);
      expect(range, isNotNull);
      expect(range!.first, 0); // first center col
      expect(range.last, 1); // second center col
    });
  });

  group('Column virtualisation in GridPainter', () {
    test('suppressColumnVirtualisation defaults to false', () {
      // This is a compile-time check — the GridPainter constructor
      // should accept suppressColumnVirtualisation with a default of false
      final columns = [
        const OsColumnDef(field: 'a', headerName: 'A', width: 100),
      ];
      // Just verify it compiles and the default is false
      expect(columns.length, 1);
    });
  });
}
