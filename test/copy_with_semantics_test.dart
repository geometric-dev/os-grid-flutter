import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsColumnDef.copyWith', () {
    test('preserves all fields when nothing is overridden', () {
      const original = OsColumnDef<Map<String, dynamic>>(
        field: 'price',
        colId: 'priceCol',
        headerName: 'Price',
        width: 120,
        minWidth: 60,
        maxWidth: 300,
        flex: 2,
        sortable: false,
        resizable: false,
        editable: true,
        autoHeight: true,
        wrapText: true,
        tooltipField: 'priceNote',
        headerTooltip: 'Unit price',
        rowGroup: true,
        aggFunc: 'sum',
        pivot: true,
        pinned: OsColumnPin.left,
      );

      final copy = original.copyWith();

      expect(copy.field, original.field);
      expect(copy.colId, original.colId);
      expect(copy.headerName, original.headerName);
      expect(copy.width, original.width);
      expect(copy.minWidth, original.minWidth);
      expect(copy.maxWidth, original.maxWidth);
      expect(copy.flex, original.flex);
      expect(copy.sortable, original.sortable);
      expect(copy.resizable, original.resizable);
      expect(copy.editable, original.editable);
      expect(copy.autoHeight, original.autoHeight);
      expect(copy.wrapText, original.wrapText);
      expect(copy.tooltipField, original.tooltipField);
      expect(copy.headerTooltip, original.headerTooltip);
      expect(copy.rowGroup, original.rowGroup);
      expect(copy.aggFunc, original.aggFunc);
      expect(copy.pivot, original.pivot);
      expect(copy.pinned, original.pinned);
    });

    test('keeps pin state when pinned argument is omitted', () {
      const original = OsColumnDef<Map<String, dynamic>>(
        field: 'a',
        pinned: OsColumnPin.left,
      );

      expect(original.copyWith().pinned, OsColumnPin.left);
    });

    test('can pin, repin and explicitly unpin', () {
      const original = OsColumnDef<Map<String, dynamic>>(field: 'a');

      expect(
        original.copyWith(pinned: OsColumnPin.left).pinned,
        OsColumnPin.left,
      );
      expect(original.copyWith(pinned: null).pinned, isNull);

      final pinned = original.copyWith(pinned: OsColumnPin.right);
      expect(
        pinned.copyWith(pinned: null).pinned,
        isNull,
        reason: 'Unpinning must clear an existing pin override',
      );
    });
  });

  group('OsFilterCondition.copyWith', () {
    test('keeps values when arguments are omitted', () {
      const condition = OsFilterCondition(
        type: 'inRange',
        filter: 1,
        filterTo: 9,
      );

      final copy = condition.copyWith(type: 'equals');

      expect(copy.type, 'equals');
      expect(copy.filter, 1);
      expect(copy.filterTo, 9);
    });

    test('explicitly clears filterTo when null is passed', () {
      const condition = OsFilterCondition(
        type: 'inRange',
        filter: 1,
        filterTo: 9,
      );

      final copy = condition.copyWith(type: 'equals', filterTo: null);

      expect(copy.type, 'equals');
      expect(copy.filter, 1);
      expect(
        copy.filterTo,
        isNull,
        reason: 'Stale range bounds must not survive an operation change',
      );
    });

    test('toJson omits cleared filterTo', () {
      const condition = OsFilterCondition(
        type: 'inRange',
        filter: 1,
        filterTo: 9,
      );

      final json = condition.copyWith(type: 'equals', filterTo: null).toJson();

      expect(json.containsKey('filterTo'), isFalse);
    });
  });
}
