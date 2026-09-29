import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/grid_paint_inputs.dart';
import 'package:os_grid_flutter/src/rendering/grid_painter.dart';

/// Tests for GridPainter dirty-region groundwork (quality program v2 item
/// 10): the [GridPaintInputs.diff] paint-input audit, the
/// [GridPainter.computeDamageRect] damage classifier (hover / focus /
/// flash-tick rules), and the clip application inside [GridPainter.paint].
void main() {
  final columns = [
    const OsColumnDef(field: 'a', headerName: 'A', width: 100),
    const OsColumnDef(field: 'b', headerName: 'B', width: 100),
    const OsColumnDef(field: 'c', headerName: 'C', width: 100),
  ];
  final rows = List.generate(
    6,
    (i) => <String, dynamic>{'a': i, 'b': i, 'c': i},
  );
  final widths = [100.0, 100.0, 100.0];
  final theme = OsGridTheme.quartz();
  const size = Size(300, 200);

  // Layout constants matching the painters below (no pins, LTR):
  // column i starts at x = i * 100; row r spans y = 48 + r * 42.
  const headerHeight = 48.0;
  const rowHeight = 42.0;
  Rect cellRect(int row, int col) =>
      Rect.fromLTWH(col * 100.0, headerHeight + row * rowHeight, 100.0, 42.0);
  Rect band(int row) => Rect.fromLTRB(
    0,
    headerHeight + row * rowHeight,
    size.width,
    headerHeight + (row + 1) * rowHeight,
  );

  CellPosition pos(int row, String colId) =>
      CellPosition(rowIndex: row, colId: colId);

  CellFlashState flashState(CellPosition position) => CellFlashState(
    position: position,
    startTime: Duration.zero,
    flashDuration: const Duration(milliseconds: 500),
    fadeDuration: const Duration(milliseconds: 500),
    flashDelay: Duration.zero,
    fadeDelay: Duration.zero,
  );

  GridPainter build({
    List<OsColumnDef>? columns_,
    List<Map<String, dynamic>>? rowData_,
    double rowHeight_ = rowHeight,
    double headerHeight_ = headerHeight,
    double scrollX = 0,
    double scrollY = 0,
    OsGridTheme? theme_,
    List<double>? columnWidths_,
    Set<int>? selectedRows,
    int? hoveredRow,
    String? hoveredColId,
    int sortColumnIndex = -1,
    bool sortAscending = true,
    Map<int, SortIndicatorInfo>? sortIndicators,
    List<ColumnGroupSpan>? columnGroupSpans,
    double groupHeaderHeight = 0,
    double floatingFilterHeight = 0,
    Map<String, String>? floatingFilterTexts,
    Map<String, String>? floatingFilterOperations,
    List<CellRange>? cellRanges,
    Map<int, OsRowStyle>? rowStyles,
    List<Map<String, dynamic>>? pinnedTopRowData,
    List<Map<String, dynamic>>? pinnedBottomRowData,
    Map<int, OsRowStyle>? pinnedTopRowStyles,
    Map<int, OsRowStyle>? pinnedBottomRowStyles,
    Map<CellPosition, CellFlashState>? cellFlashes,
    Duration flashElapsed = Duration.zero,
    CellSpanService? cellSpanService,
    RowHeightLayout? rowHeightLayout,
    bool suppressColumnVirtualisation = false,
    TextScaler textScaler = TextScaler.noScaling,
    TextDirection? textDirection,
    int focusedRow = 0,
    int focusedCol = 0,
  }) {
    return GridPainter(
      columns: columns_ ?? columns,
      rowData: rowData_ ?? rows,
      rowHeight: rowHeight_,
      headerHeight: headerHeight_,
      scrollX: scrollX,
      scrollY: scrollY,
      theme: theme_ ?? theme,
      columnWidths: columnWidths_ ?? widths,
      selectedRows: selectedRows ?? const {},
      hoveredRow: hoveredRow,
      hoveredColId: hoveredColId,
      sortColumnIndex: sortColumnIndex == -1 ? null : sortColumnIndex,
      sortAscending: sortAscending,
      sortIndicators: sortIndicators,
      columnGroupSpans: columnGroupSpans,
      groupHeaderHeight: groupHeaderHeight,
      floatingFilterHeight: floatingFilterHeight,
      floatingFilterTexts: floatingFilterTexts,
      floatingFilterOperations: floatingFilterOperations,
      cellRanges: cellRanges,
      rowStyles: rowStyles,
      pinnedTopRowData: pinnedTopRowData ?? const [],
      pinnedBottomRowData: pinnedBottomRowData ?? const [],
      pinnedTopRowStyles: pinnedTopRowStyles,
      pinnedBottomRowStyles: pinnedBottomRowStyles,
      cellFlashes: cellFlashes,
      flashElapsed: flashElapsed,
      cellSpanService: cellSpanService,
      rowHeightLayout: rowHeightLayout,
      suppressColumnVirtualisation: suppressColumnVirtualisation,
      textScaler: textScaler,
      textDirection: textDirection,
      focusedRow: focusedRow,
      focusedCol: focusedCol,
    );
  }

  /// Paints [painter] so its internal last-painted-size bookkeeping is
  /// populated, as it would be in a real frame.
  void prime(GridPainter painter) {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    recorder.endRecording();
  }

  /// Paints [painter] on a recording canvas and returns every clipRect
  /// issued, in order.
  List<Rect> paintRecordingClips(GridPainter painter) {
    final recorder = ui.PictureRecorder();
    final canvas = _ClipRecordingCanvas(Canvas(recorder));
    painter.paint(canvas, size);
    recorder.endRecording();
    return canvas.clips;
  }

  group('GridPaintInputs.diff — naming completeness', () {
    // The exact field list evaluated by GridPainter.shouldRepaint, in its
    // canonical order. Kept independent from the implementation so a new
    // shouldRepaint condition forces a conscious update here.
    const shouldRepaintFields = [
      'scrollX',
      'scrollY',
      'columns',
      'rowData',
      'pinnedTopRowData',
      'pinnedBottomRowData',
      'pinnedTopRowStyles',
      'pinnedBottomRowStyles',
      'cellSpanService',
      'rowHeight',
      'headerHeight',
      'theme',
      'selectedRows',
      'hoveredRow',
      'hoveredColId',
      'columnWidths',
      'sortColumnIndex',
      'sortAscending',
      'sortIndicators',
      'columnGroupSpans',
      'groupHeaderHeight',
      'floatingFilterHeight',
      'floatingFilterTexts',
      'floatingFilterOperations',
      'cellRanges',
      'rowStyles',
      'cellFlashes',
      'flashElapsed',
      'rowHeightLayout',
      'suppressColumnVirtualisation',
    ];
    const extraPaintAffectingFields = [
      'textScaler',
      'textDirection',
      'focusedRow',
      'focusedCol',
    ];

    test('every shouldRepaint condition appears in canonical order, '
        'followed by the extra paint-affecting inputs', () {
      expect(
        GridPaintInputs.fieldNames.take(shouldRepaintFields.length).toList(),
        shouldRepaintFields,
      );
      expect(
        GridPaintInputs.fieldNames.length,
        shouldRepaintFields.length + extraPaintAffectingFields.length,
      );
      expect(
        GridPaintInputs.fieldNames.skip(shouldRepaintFields.length).toList(),
        extraPaintAffectingFields,
      );
    });

    test('each input alone differing is reported by exactly its name', () {
      GridPainter variant(String field) => switch (field) {
        'scrollX' => build(scrollX: 10),
        'scrollY' => build(scrollY: 10),
        // New instance with equal contents: identity comparison must flag it.
        'columns' => build(columns_: [...columns]),
        'rowData' => build(
          rowData_: [for (final r in rows) Map<String, dynamic>.of(r)],
        ),
        'pinnedTopRowData' => build(
          pinnedTopRowData: [
            {'v': 1},
          ],
        ),
        'pinnedBottomRowData' => build(
          pinnedBottomRowData: [
            {'v': 1},
          ],
        ),
        'pinnedTopRowStyles' => build(
          pinnedTopRowStyles: const {0: OsRowStyle()},
        ),
        'pinnedBottomRowStyles' => build(
          pinnedBottomRowStyles: const {0: OsRowStyle()},
        ),
        'cellSpanService' => build(cellSpanService: CellSpanService()),
        'rowHeight' => build(rowHeight_: 43),
        'headerHeight' => build(headerHeight_: 49),
        'theme' => build(theme_: OsGridTheme.quartz()),
        'selectedRows' => build(selectedRows: {0}),
        'hoveredRow' => build(hoveredRow: 1),
        'hoveredColId' => build(hoveredColId: 'b'),
        'columnWidths' => build(columnWidths_: [100, 100, 101]),
        'sortColumnIndex' => build(sortColumnIndex: 0),
        'sortAscending' => build(sortAscending: false),
        'sortIndicators' => build(
          sortIndicators: {
            0: const SortIndicatorInfo(
              direction: OsSortDirection.ascending,
              priority: 1,
              isMultiSort: false,
            ),
          },
        ),
        'columnGroupSpans' => build(
          columnGroupSpans: [
            const ColumnGroupSpan(headerName: 'G', startIndex: 0, endIndex: 1),
          ],
        ),
        'groupHeaderHeight' => build(groupHeaderHeight: 24),
        'floatingFilterHeight' => build(floatingFilterHeight: 32),
        'floatingFilterTexts' => build(floatingFilterTexts: {'a': 'x'}),
        'floatingFilterOperations' => build(
          floatingFilterOperations: {'a': 'contains'},
        ),
        'cellRanges' => build(
          cellRanges: [
            const CellRange(
              startRow: 0,
              endRow: 1,
              startColumn: 0,
              endColumn: 0,
            ),
          ],
        ),
        'rowStyles' => build(rowStyles: {1: const OsRowStyle()}),
        'cellFlashes' => build(
          cellFlashes: {pos(2, 'b'): flashState(pos(2, 'b'))},
        ),
        'flashElapsed' => build(flashElapsed: const Duration(milliseconds: 10)),
        'rowHeightLayout' => build(
          rowHeightLayout: RowHeightLayout.uniform(
            rowCount: rows.length,
            rowHeight: rowHeight,
          ),
        ),
        'suppressColumnVirtualisation' => build(
          suppressColumnVirtualisation: true,
        ),
        'textScaler' => build(textScaler: const TextScaler.linear(1.5)),
        'textDirection' => build(textDirection: TextDirection.rtl),
        'focusedRow' => build(focusedRow: 2),
        'focusedCol' => build(focusedCol: 1),
        _ => fail('unaudited field name missing from fixture switch: $field'),
      };

      final base = build();
      for (final name in GridPaintInputs.fieldNames) {
        expect(GridPaintInputs.diff(base, variant(name)), [name], reason: name);
      }
    });

    test('identical-input painters produce an empty diff', () {
      expect(GridPaintInputs.diff(build(), build()), isEmpty);
    });

    test('two differing fields are both reported', () {
      final names = GridPaintInputs.diff(
        build(),
        build(scrollX: 5, hoveredRow: 2),
      );
      expect(names.toSet(), {'scrollX', 'hoveredRow'});
    });
  });

  group('section registry', () {
    test('every registered field is an audited input name', () {
      final known = GridPaintInputs.fieldNames.toSet();
      GridPaintInputs.sectionFields.forEach((section, fields) {
        for (final field in fields) {
          expect(known, contains(field), reason: '$section -> $field');
        }
      });
    });

    test('covers the logical bands header/left/center/right/footer', () {
      expect(
        GridPaintInputs.sectionFields.keys.toSet(),
        containsAll(['header', 'left', 'center', 'right', 'footer']),
      );
    });
  });

  group('computeDamageRect — classifier rules', () {
    test('hover-only change yields the union of prev+current row bands', () {
      final old = build(hoveredRow: 0);
      prime(old);
      final current = build(hoveredRow: 2);

      expect(current.computeDamageRect(old), band(0).expandToInclude(band(2)));
      expect(current.shouldRepaint(old), isTrue);
    });

    test('focus-only change yields the union of prev+current cell rects', () {
      final old = build(focusedRow: 0, focusedCol: 0);
      prime(old);
      final current = build(focusedRow: 2, focusedCol: 1);

      expect(current.diffFrom(old), ['focusedRow', 'focusedCol']);
      expect(
        current.computeDamageRect(old),
        cellRect(0, 0).expandToInclude(cellRect(2, 1)),
      );
      // Focus is not painted today (semantics only), so it must not start
      // scheduling repaints on its own — classifier output is groundwork.
      expect(current.shouldRepaint(old), isFalse);
    });

    test('focus clear (-1 sentinel) damages only the previous cell rect', () {
      final old = build(focusedRow: 1, focusedCol: 2);
      prime(old);
      final current = build(focusedRow: -1, focusedCol: -1);

      expect(current.computeDamageRect(old), cellRect(1, 2));
    });

    test(
      'flash tick over the same flash set yields the flashing-cell union',
      () {
        final shared = {
          pos(1, 'a'): flashState(pos(1, 'a')),
          pos(3, 'c'): flashState(pos(3, 'c')),
        };
        final old = build(
          cellFlashes: shared,
          flashElapsed: const Duration(milliseconds: 50),
        );
        prime(old);
        final current = build(
          cellFlashes: shared,
          flashElapsed: const Duration(milliseconds: 150),
        );

        expect(current.diffFrom(old), ['flashElapsed']);
        // Row 3's band runs past the 200px canvas, so the union is clamped
        // to the painted bounds (over-damage is never useful).
        expect(
          current.computeDamageRect(old),
          const Rect.fromLTRB(0, 90, 300, 200),
        );
        expect(current.shouldRepaint(old), isTrue);
      },
    );

    test(
      'flash completing between ticks keeps the previous rect to erase it',
      () {
        final shared = {pos(2, 'b'): flashState(pos(2, 'b'))};
        // total duration = 500 flash + 500 fade; at 400ms visible, at 1100ms done.
        final old = build(
          cellFlashes: shared,
          flashElapsed: const Duration(milliseconds: 400),
        );
        prime(old);
        final current = build(
          cellFlashes: shared,
          flashElapsed: const Duration(milliseconds: 1100),
        );

        expect(current.computeDamageRect(old), cellRect(2, 1));
      },
    );

    test('changed flash set alongside elapsed falls back to full repaint', () {
      final shared = {pos(2, 'b'): flashState(pos(2, 'b'))};
      final old = build(
        cellFlashes: shared,
        flashElapsed: const Duration(milliseconds: 50),
      );
      prime(old);
      final grown = {
        pos(2, 'b'): flashState(pos(2, 'b')),
        pos(4, 'a'): flashState(pos(4, 'a')),
      };
      final current = build(
        cellFlashes: grown,
        flashElapsed: const Duration(milliseconds: 150),
      );

      expect(current.computeDamageRect(old), isNull);
    });

    test('scroll change alongside flash tick falls back to full repaint', () {
      final shared = {pos(2, 'b'): flashState(pos(2, 'b'))};
      final old = build(
        cellFlashes: shared,
        flashElapsed: const Duration(milliseconds: 50),
      );
      prime(old);
      final current = build(
        cellFlashes: shared,
        flashElapsed: const Duration(milliseconds: 150),
        scrollY: 21,
      );

      expect(current.computeDamageRect(old), isNull);
    });

    test('hover move combined with focus move falls back to full repaint', () {
      final old = build(hoveredRow: 0, focusedRow: 0, focusedCol: 0);
      prime(old);
      final current = build(hoveredRow: 2, focusedRow: 3, focusedCol: 1);

      expect(current.computeDamageRect(old), isNull);
    });

    test('theme change alongside focus move falls back to full repaint', () {
      final old = build(focusedRow: 0, focusedCol: 0);
      prime(old);
      final current = build(
        focusedRow: 2,
        focusedCol: 1,
        theme_: OsGridTheme.quartzDark(),
      );

      expect(current.computeDamageRect(old), isNull);
    });

    test('column-hover-only change damages the union of both column bands', () {
      final old = build(hoveredRow: 0, hoveredColId: 'a');
      prime(old);
      final current = build(hoveredRow: 0, hoveredColId: 'b');

      // Columns a (x 0..100) and b (x 100..200) union into x 0..200.
      expect(
        current.computeDamageRect(old),
        Rect.fromLTRB(0.0, 0.0, 200.0, size.height),
      );
    });

    test('first transition before any paint falls back to full repaint', () {
      final focusOld = build(focusedRow: 0, focusedCol: 0);
      final focusNew = build(focusedRow: 1, focusedCol: 0);
      expect(focusNew.computeDamageRect(focusOld), isNull);

      final shared = {pos(2, 'b'): flashState(pos(2, 'b'))};
      final flashOld = build(cellFlashes: shared, flashElapsed: Duration.zero);
      final flashNew = build(
        cellFlashes: shared,
        flashElapsed: const Duration(milliseconds: 50),
      );
      expect(flashNew.computeDamageRect(flashOld), isNull);
    });

    test('identical painters classify as no damage and no repaint', () {
      final old = build(hoveredRow: 1);
      prime(old);
      final current = build(hoveredRow: 1);

      expect(current.computeDamageRect(old), isNull);
      expect(current.shouldRepaint(old), isFalse);
    });
  });

  group('paint() applies the damage clip', () {
    test('hover-only repaint clips to the hover band before painting', () {
      final old = build(hoveredRow: 0);
      prime(old);
      final current = build(hoveredRow: 2);
      expect(current.shouldRepaint(old), isTrue);

      final expectedDamage = band(0).expandToInclude(band(2));
      final clips = paintRecordingClips(current);

      expect(clips, isNotEmpty);
      // The very first clip of the frame is the damage restriction.
      expect(clips.first, expectedDamage);
    });

    test('flash-tick repaint clips to the flashing-cell union', () {
      final shared = {pos(2, 'b'): flashState(pos(2, 'b'))};
      final old = build(
        cellFlashes: shared,
        flashElapsed: const Duration(milliseconds: 50),
      );
      prime(old);
      final current = build(
        cellFlashes: shared,
        flashElapsed: const Duration(milliseconds: 150),
      );
      expect(current.shouldRepaint(old), isTrue);

      final clips = paintRecordingClips(current);

      expect(clips.first, cellRect(2, 1));
    });

    test('full repaints issue no damage-scoped first clip', () {
      final old = build(hoveredRow: 0);
      prime(old);
      final current = build(hoveredRow: 2, scrollY: 30);
      expect(current.shouldRepaint(old), isTrue);

      final clips = paintRecordingClips(current);

      // Without a proven damage rect the frame opens with the regular
      // center-section viewport clip covering the whole canvas, not the
      // hover band.
      expect(clips.first, isNot(band(0).expandToInclude(band(2))));
      expect(clips.first, Rect.fromLTWH(0, 0, size.width, size.height));
    });
  });
}

/// Canvas that records every [clipRect] while forwarding everything else to
/// a real recorder-backed canvas, proving that restricted repaints actually
/// apply their damage clip before painting.
class _ClipRecordingCanvas implements ui.Canvas {
  _ClipRecordingCanvas(this._delegate);

  final ui.Canvas _delegate;

  final List<Rect> clips = [];

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {
    clips.add(rect);
    _delegate.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  }

  @override
  Rect getDestinationClipBounds() => _delegate.getDestinationClipBounds();

  @override
  Rect getLocalClipBounds() => _delegate.getLocalClipBounds();

  @override
  Float64List getTransform() => _delegate.getTransform();

  @override
  int getSaveCount() => _delegate.getSaveCount();

  @override
  void restore() => _delegate.restore();

  @override
  void restoreToCount(int count) => _delegate.restoreToCount(count);

  @override
  void rotate(double radians) => _delegate.rotate(radians);

  @override
  void save() => _delegate.save();

  @override
  void saveLayer(Rect? bounds, Paint paint) =>
      _delegate.saveLayer(bounds, paint);

  @override
  void scale(double sx, [double? sy]) => _delegate.scale(sx, sy);

  @override
  void skew(double sx, double sy) => _delegate.skew(sx, sy);

  @override
  void transform(Float64List matrix4) => _delegate.transform(matrix4);

  @override
  void translate(double dx, double dy) => _delegate.translate(dx, dy);

  @override
  void clipPath(Path path, {bool doAntiAlias = true}) =>
      _delegate.clipPath(path, doAntiAlias: doAntiAlias);

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) =>
      _delegate.clipRRect(rrect, doAntiAlias: doAntiAlias);

  @override
  void clipRSuperellipse(
    ui.RSuperellipse rsuperellipse, {
    bool doAntiAlias = true,
  }) => _delegate.clipRSuperellipse(rsuperellipse, doAntiAlias: doAntiAlias);

  @override
  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) => _delegate.drawArc(rect, startAngle, sweepAngle, useCenter, paint);

  @override
  void drawAtlas(
    ui.Image atlas,
    List<ui.RSTransform> transforms,
    List<Rect> rects,
    List<Color>? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) => _delegate.drawAtlas(
    atlas,
    transforms,
    rects,
    colors,
    blendMode,
    cullRect,
    paint,
  );

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      _delegate.drawCircle(c, radius, paint);

  @override
  void drawColor(Color color, BlendMode blendMode) =>
      _delegate.drawColor(color, blendMode);

  @override
  void drawDRRect(RRect outer, RRect inner, Paint paint) =>
      _delegate.drawDRRect(outer, inner, paint);

  @override
  void drawImage(ui.Image image, Offset offset, Paint paint) =>
      _delegate.drawImage(image, offset, paint);

  @override
  void drawImageNine(ui.Image image, Rect src, Rect dst, Paint paint) =>
      _delegate.drawImageNine(image, src, dst, paint);

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) =>
      _delegate.drawImageRect(image, src, dst, paint);

  @override
  void drawRSuperellipse(ui.RSuperellipse rsuperellipse, Paint paint) =>
      _delegate.drawRSuperellipse(rsuperellipse, paint);

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      _delegate.drawLine(p1, p2, paint);

  @override
  void drawOval(Rect rect, Paint paint) => _delegate.drawOval(rect, paint);

  @override
  void drawPaint(Paint paint) => _delegate.drawPaint(paint);

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) =>
      _delegate.drawParagraph(paragraph, offset);

  @override
  void drawPath(Path path, Paint paint) => _delegate.drawPath(path, paint);

  @override
  void drawPicture(ui.Picture picture) => _delegate.drawPicture(picture);

  @override
  void drawPoints(ui.PointMode pointMode, List<Offset> points, Paint paint) =>
      _delegate.drawPoints(pointMode, points, paint);

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) =>
      _delegate.drawRawPoints(pointMode, points, paint);

  @override
  void drawRect(Rect rect, Paint paint) => _delegate.drawRect(rect, paint);

  @override
  void drawRRect(RRect rrect, Paint paint) => _delegate.drawRRect(rrect, paint);

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) => _delegate.drawRawAtlas(
    atlas,
    rstTransforms,
    rects,
    colors,
    blendMode,
    cullRect,
    paint,
  );

  @override
  void drawShadow(
    Path path,
    Color color,
    double elevation,
    bool transparentOccluder,
  ) => _delegate.drawShadow(path, color, elevation, transparentOccluder);

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      _delegate.drawVertices(vertices, blendMode, paint);
}
