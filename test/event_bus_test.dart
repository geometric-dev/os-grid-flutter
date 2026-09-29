import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/events/grid_event_bus.dart';

Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

OsCellClickedEvent<String> _cellClickedEvent({dynamic value}) {
  return OsCellClickedEvent<String>(
    data: 'row-1',
    rowIndex: 0,
    colDef: const OsColumnDef<String>(field: 'name'),
    value: value,
  );
}

void main() {
  group('GridEventBus', () {
    test('delivers an emitted event to a typed listener', () async {
      final bus = GridEventBus();
      final received = <OsGridReadyEvent>[];
      final sub = bus.on<OsGridReadyEvent>().listen(received.add);

      bus.emit<OsGridReadyEvent>(const OsGridReadyEvent());
      await _flushMicrotasks();

      expect(received, hasLength(1));
      await sub.cancel();
      await bus.dispose();
    });

    test('isolates channels by event type', () async {
      final bus = GridEventBus();
      final ready = <OsGridReadyEvent>[];
      final sort = <OsSortChangedEvent>[];
      final readySub = bus.on<OsGridReadyEvent>().listen(ready.add);
      final sortSub = bus.on<OsSortChangedEvent>().listen(sort.add);

      bus.emit(const OsGridReadyEvent());
      await _flushMicrotasks();

      expect(ready, hasLength(1));
      expect(sort, isEmpty);

      await readySub.cancel();
      await sortSub.cancel();
      await bus.dispose();
    });

    test(
      'distinguishes generic instantiations of the same event class',
      () async {
        final bus = GridEventBus();
        final ints = <OsCellClickedEvent<int>>[];
        final strings = <OsCellClickedEvent<String>>[];
        final intsSub = bus.on<OsCellClickedEvent<int>>().listen(ints.add);
        final stringsSub = bus.on<OsCellClickedEvent<String>>().listen(
          strings.add,
        );

        bus.emit(
          const OsCellClickedEvent<int>(
            data: 1,
            rowIndex: 0,
            colDef: OsColumnDef<int>(field: 'id'),
            value: 42,
          ),
        );
        await _flushMicrotasks();

        expect(ints, hasLength(1));
        expect(strings, isEmpty);

        await intsSub.cancel();
        await stringsSub.cancel();
        await bus.dispose();
      },
    );

    test('supports multiple listeners on the same event type', () async {
      final bus = GridEventBus();
      final a = <OsGridReadyEvent>[];
      final b = <OsGridReadyEvent>[];
      final subA = bus.on<OsGridReadyEvent>().listen(a.add);
      final subB = bus.on<OsGridReadyEvent>().listen(b.add);

      bus.emit(const OsGridReadyEvent());
      await _flushMicrotasks();

      expect(a, hasLength(1));
      expect(b, hasLength(1));

      await subA.cancel();
      bus.emit(const OsGridReadyEvent());
      await _flushMicrotasks();

      expect(a, hasLength(1));
      expect(b, hasLength(2));

      await subB.cancel();
      await bus.dispose();
    });

    test('does not replay events to listeners added after emit', () async {
      final bus = GridEventBus();
      final received = <OsGridReadyEvent>[];

      bus.emit(const OsGridReadyEvent());
      final sub = bus.on<OsGridReadyEvent>().listen(received.add);
      await _flushMicrotasks();

      expect(received, isEmpty);

      await sub.cancel();
      await bus.dispose();
    });

    test('controllers are created lazily per event type', () async {
      final bus = GridEventBus();
      final received = <OsSortChangedEvent>[];
      final sub = bus.on<OsSortChangedEvent>().listen(received.add);

      bus.emit(const OsSortChangedEvent(sortModel: []));
      await _flushMicrotasks();

      expect(received, hasLength(1));

      await sub.cancel();
      await bus.dispose();
    });

    test('dispose closes every created channel', () async {
      final bus = GridEventBus();
      final closed = <String>[];
      final readySub = bus.on<OsGridReadyEvent>().listen(
        null,
        onDone: () => closed.add('ready'),
      );
      final sortSub = bus.on<OsSortChangedEvent>().listen(
        null,
        onDone: () => closed.add('sort'),
      );

      await bus.dispose();
      await _flushMicrotasks();

      expect(bus.isClosed, isTrue);
      expect(closed, containsAll(<String>['ready', 'sort']));

      await readySub.cancel();
      await sortSub.cancel();
    });

    test('dispose is safe to call multiple times', () async {
      final bus = GridEventBus();
      bus.on<OsGridReadyEvent>().listen(null, onDone: () {});

      await bus.dispose();
      await bus.dispose();

      expect(bus.isClosed, isTrue);
    });

    test('cannot be used after dispose', () async {
      final bus = GridEventBus();
      await bus.dispose();

      expect(() => bus.on<OsGridReadyEvent>(), throwsStateError);
      expect(() => bus.emit(const OsGridReadyEvent()), throwsStateError);
    });
  });

  group('OsGridController streams via the event bus', () {
    test('onCellClicked still works through the bus', () async {
      final controller = OsGridController<String>();
      final received = <OsCellClickedEvent<String>>[];
      final sub = controller.onCellClicked.listen(received.add);

      controller.emitCellClicked(_cellClickedEvent(value: 'Ada'));
      await _flushMicrotasks();

      expect(received, hasLength(1));
      expect(received.single.value, 'Ada');
      expect(received.single.data, 'row-1');

      await sub.cancel();
      controller.dispose();
    });

    test('onGridReady delivers events emitted through emitGridReady', () async {
      final controller = OsGridController<String>();
      final received = <OsGridReadyEvent>[];
      final sub = controller.onGridReady.listen(received.add);

      controller.emitGridReady();
      await _flushMicrotasks();

      expect(received, hasLength(1));

      await sub.cancel();
      controller.dispose();
    });

    test('supports multiple listeners on the same controller stream', () async {
      final controller = OsGridController<String>();
      final a = <OsGridReadyEvent>[];
      final b = <OsGridReadyEvent>[];
      final subA = controller.onGridReady.listen(a.add);
      final subB = controller.onGridReady.listen(b.add);

      controller.emitGridReady();
      await _flushMicrotasks();

      expect(a, hasLength(1));
      expect(b, hasLength(1));

      await subA.cancel();
      await subB.cancel();
      controller.dispose();
    });

    test(
      'does not replay controller events emitted before subscribing',
      () async {
        final controller = OsGridController<String>();
        final received = <OsCellClickedEvent<String>>[];

        controller.emitCellClicked(_cellClickedEvent());
        final sub = controller.onCellClicked.listen(received.add);
        await _flushMicrotasks();

        expect(received, isEmpty);

        await sub.cancel();
        controller.dispose();
      },
    );

    test('controller.dispose closes the event streams', () async {
      final controller = OsGridController<String>();
      var closed = false;
      final sub = controller.onGridReady.listen(
        null,
        onDone: () {
          closed = true;
        },
      );

      controller.dispose();
      await _flushMicrotasks();

      expect(closed, isTrue);

      await sub.cancel();
    });
  });
}
