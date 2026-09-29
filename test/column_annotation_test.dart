import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsGridColumn (class-level annotation)', () {
    test('exposes all configured metadata', () {
      const config = OsGridColumn(
        colIdPrefix: 'person.',
        defaultWidth: 120,
        defaultSortable: true,
        defaultResizable: false,
        exclude: {'internalCache'},
      );
      expect(config.colIdPrefix, 'person.');
      expect(config.defaultWidth, 120);
      expect(config.defaultSortable, true);
      expect(config.defaultResizable, false);
      expect(config.exclude, {'internalCache'});
    });

    test('is usable as a const annotation with defaults', () {
      @OsGridColumn()
      const marker = OsGridColumn();
      expect(marker.colIdPrefix, isNull);
      expect(marker.defaultWidth, isNull);
      expect(marker.defaultSortable, isNull);
      expect(marker.defaultResizable, isNull);
      expect(marker.exclude, isEmpty);
    });
  });

  group('OsColumn (field-level annotation)', () {
    test('extracts display and sizing metadata', () {
      const meta = OsColumn(headerName: 'Name', width: 150);
      expect(meta.headerName, 'Name');
      expect(meta.width, 150);
      expect(meta.minWidth, isNull);
      expect(meta.maxWidth, isNull);
      expect(meta.flex, isNull);
    });

    test('extracts behavioural metadata', () {
      const meta = OsColumn(
        colId: 'fullName',
        sortable: true,
        resizable: false,
        hide: true,
        pinned: OsColumnPin.left,
        editable: true,
        singleClickEdit: true,
        autoHeight: true,
        wrapText: true,
        suppressMenu: true,
        lockVisible: true,
        lockPinned: true,
        lockPosition: true,
        rowGroup: true,
        pivot: true,
        aggFunc: 'sum',
        tooltipField: 'details.summary',
        headerTooltip: 'Full name',
        filter: OsColumnFilterHint.text,
      );
      expect(meta.colId, 'fullName');
      expect(meta.sortable, true);
      expect(meta.resizable, false);
      expect(meta.hide, true);
      expect(meta.pinned, OsColumnPin.left);
      expect(meta.editable, true);
      expect(meta.singleClickEdit, true);
      expect(meta.autoHeight, true);
      expect(meta.wrapText, true);
      expect(meta.suppressMenu, true);
      expect(meta.lockVisible, true);
      expect(meta.lockPinned, true);
      expect(meta.lockPosition, true);
      expect(meta.rowGroup, true);
      expect(meta.pivot, true);
      expect(meta.aggFunc, 'sum');
      expect(meta.tooltipField, 'details.summary');
      expect(meta.headerTooltip, 'Full name');
      expect(meta.filter, OsColumnFilterHint.text);
    });

    test('defaults are null so type inference applies', () {
      const meta = OsColumn();
      expect(meta.headerName, isNull);
      expect(meta.filter, isNull);
      expect(meta.pinned, isNull);
      expect(meta.editable, isNull);
    });

    test('annotations are const-constructible in metadata position', () {
      // Compiles only if the class is genuinely const.
      const annotated = <OsColumn>[
        OsColumn(headerName: 'A'),
        OsColumn(width: 80, minWidth: 40, maxWidth: 200),
      ];
      expect(annotated, hasLength(2));
    });
  });

  group('OsColumnFilterHint', () {
    test('covers all explicit filter kinds', () {
      expect(
        OsColumnFilterHint.values,
        containsAll(const [
          OsColumnFilterHint.none,
          OsColumnFilterHint.text,
          OsColumnFilterHint.number,
          OsColumnFilterHint.date,
        ]),
      );
    });
  });
}
