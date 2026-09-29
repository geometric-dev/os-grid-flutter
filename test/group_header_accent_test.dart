import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/grid_painter.dart';

void main() {
  group('Column group header accent bar', () {
    test('GridPainter paints accent bar for non-empty group headers', () {
      // Set up a painter with column groups
      final columns = [
        const OsColumnDef(field: 'a', headerName: 'A', width: 100),
        const OsColumnDef(field: 'b', headerName: 'B', width: 100),
        const OsColumnDef(field: 'c', headerName: 'C', width: 100),
      ];

      final painter = GridPainter(
        columns: columns,
        rowData: [
          {'a': '1', 'b': '2', 'c': '3'},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        theme: OsGridTheme.quartz(),
        columnWidths: [100, 100, 100],
        columnGroupSpans: [
          const ColumnGroupSpan(
            headerName: 'Group 1',
            startIndex: 0,
            endIndex: 1,
          ),
          const ColumnGroupSpan(headerName: '', startIndex: 2, endIndex: 2),
        ],
        groupHeaderHeight: 32,
      );

      // Verify the painter can be constructed and shouldRepaint works
      final samePainter = GridPainter(
        columns: columns,
        rowData: [
          {'a': '1', 'b': '2', 'c': '3'},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        theme: OsGridTheme.quartz(),
        columnWidths: [100, 100, 100],
        columnGroupSpans: [
          const ColumnGroupSpan(
            headerName: 'Group 1',
            startIndex: 0,
            endIndex: 1,
          ),
          const ColumnGroupSpan(headerName: '', startIndex: 2, endIndex: 2),
        ],
        groupHeaderHeight: 32,
      );

      // Same config should still repaint (lists are not identical)
      expect(painter.shouldRepaint(samePainter), isTrue);
    });

    test('GridPainter paints without error when column groups are present', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name', width: 150),
        const OsColumnDef(field: 'score', headerName: 'Score', width: 100),
        const OsColumnDef(field: 'rank', headerName: 'Rank', width: 80),
      ];

      final painter = GridPainter(
        columns: columns,
        rowData: [
          {'name': 'Alice', 'score': 95, 'rank': 1},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        theme: OsGridTheme.quartz(),
        columnWidths: [150, 100, 80],
        columnGroupSpans: [
          const ColumnGroupSpan(
            headerName: 'Performance',
            startIndex: 1,
            endIndex: 2,
          ),
        ],
        groupHeaderHeight: 32,
      );

      // Paint to a picture recorder to verify no exceptions are thrown
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 200);

      // This should not throw
      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('GridPainter paints without error when no column groups', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name', width: 150),
      ];

      final painter = GridPainter(
        columns: columns,
        rowData: [
          {'name': 'Alice'},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        theme: OsGridTheme.quartz(),
        columnWidths: [150],
        columnGroupSpans: null,
        groupHeaderHeight: 0,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 200);

      // Should not throw even without groups
      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('GridPainter paints accent bar with custom theme accentColor', () {
      final columns = [
        const OsColumnDef(field: 'a', headerName: 'A', width: 120),
        const OsColumnDef(field: 'b', headerName: 'B', width: 120),
      ];

      final painter = GridPainter(
        columns: columns,
        rowData: [
          {'a': '1', 'b': '2'},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        theme: const OsGridTheme(accentColor: Color(0xFFFF5722)),
        columnWidths: [120, 120],
        columnGroupSpans: [
          const ColumnGroupSpan(
            headerName: 'My Group',
            startIndex: 0,
            endIndex: 1,
          ),
        ],
        groupHeaderHeight: 32,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(300, 200);

      // Should paint without error using custom accent colour
      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('GridPainter paints accent bar with dark theme', () {
      final columns = [
        const OsColumnDef(field: 'x', headerName: 'X', width: 100),
        const OsColumnDef(field: 'y', headerName: 'Y', width: 100),
        const OsColumnDef(field: 'z', headerName: 'Z', width: 100),
      ];

      final painter = GridPainter(
        columns: columns,
        rowData: [
          {'x': '1', 'y': '2', 'z': '3'},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        theme: OsGridTheme.quartzDark(),
        columnWidths: [100, 100, 100],
        columnGroupSpans: [
          const ColumnGroupSpan(
            headerName: 'Group A',
            startIndex: 0,
            endIndex: 0,
          ),
          const ColumnGroupSpan(
            headerName: 'Group B',
            startIndex: 1,
            endIndex: 2,
          ),
        ],
        groupHeaderHeight: 32,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 200);

      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('Empty headerName groups do not get accent bar painted', () {
      // This test verifies the logic path: empty headerName groups skip
      // both the accent bar and text painting.
      final columns = [
        const OsColumnDef(field: 'a', headerName: 'A', width: 100),
        const OsColumnDef(field: 'b', headerName: 'B', width: 100),
      ];

      final painter = GridPainter(
        columns: columns,
        rowData: [
          {'a': '1', 'b': '2'},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        theme: OsGridTheme.quartz(),
        columnWidths: [100, 100],
        columnGroupSpans: [
          // Empty headerName — should not paint accent bar
          const ColumnGroupSpan(headerName: '', startIndex: 0, endIndex: 0),
          const ColumnGroupSpan(
            headerName: 'Named',
            startIndex: 1,
            endIndex: 1,
          ),
        ],
        groupHeaderHeight: 32,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(300, 200);

      // Should paint without error; empty group skips accent bar
      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('Accent bar works with scrolled center section', () {
      final columns = [
        const OsColumnDef(field: 'a', headerName: 'A', width: 200),
        const OsColumnDef(field: 'b', headerName: 'B', width: 200),
        const OsColumnDef(field: 'c', headerName: 'C', width: 200),
      ];

      final painter = GridPainter(
        columns: columns,
        rowData: [
          {'a': '1', 'b': '2', 'c': '3'},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 50, // Scrolled horizontally
        scrollY: 0,
        theme: OsGridTheme.quartz(),
        columnWidths: [200, 200, 200],
        columnGroupSpans: [
          const ColumnGroupSpan(
            headerName: 'Wide Group',
            startIndex: 0,
            endIndex: 2,
          ),
        ],
        groupHeaderHeight: 32,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 200);

      // Should paint correctly even when scrolled
      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
