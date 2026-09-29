import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/src/rendering/text_painter_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('TextPainterCache', () {
    late TextPainterCache cache;

    setUp(() {
      cache = TextPainterCache(maxSize: 10);
    });

    tearDown(() {
      cache.dispose();
    });

    TextPainter createPainter(String text, double maxWidth) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 13)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: maxWidth);
      return tp;
    }

    test('starts empty', () {
      expect(cache.isEmpty, isTrue);
      expect(cache.length, 0);
    });

    test('creates and caches a new entry', () {
      int createCount = 0;
      final tp = cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );

      expect(tp, isNotNull);
      expect(createCount, 1);
      expect(cache.length, 1);
    });

    test('returns cached entry on second call with same key', () {
      int createCount = 0;
      TextPainter creator() {
        createCount++;
        return createPainter('Alice', 100);
      }

      final tp1 = cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        create: creator,
      );

      final tp2 = cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        create: creator,
      );

      expect(createCount, 1); // Only created once
      expect(identical(tp1, tp2), isTrue); // Same instance
    });

    test('creates new entry when display value changes', () {
      int createCount = 0;

      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );

      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Bob',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Bob', 100);
        },
      );

      expect(createCount, 2);
      expect(cache.length, 2);
    });

    test('creates new entry when maxWidth changes significantly', () {
      int createCount = 0;

      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );

      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 200, // Significantly different
        create: () {
          createCount++;
          return createPainter('Alice', 200);
        },
      );

      expect(createCount, 2);
    });

    test('reuses entry when maxWidth changes by less than 0.5', () {
      int createCount = 0;

      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100.0,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );

      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100.3, // Within 0.5 tolerance
        create: () {
          createCount++;
          return createPainter('Alice', 100.3);
        },
      );

      expect(createCount, 1); // Reused
    });

    test('different rows are separate cache entries', () {
      int createCount = 0;

      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );

      cache.getOrCreate(
        rowIndex: 1,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );

      expect(createCount, 2);
      expect(cache.length, 2);
    });

    test('different columns are separate cache entries', () {
      int createCount = 0;

      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );

      cache.getOrCreate(
        rowIndex: 0,
        colId: 'age',
        displayValue: 'Alice',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );

      expect(createCount, 2);
      expect(cache.length, 2);
    });

    test('clear removes all entries', () {
      for (int i = 0; i < 5; i++) {
        cache.getOrCreate(
          rowIndex: i,
          colId: 'name',
          displayValue: 'Value $i',
          maxWidth: 100,
          create: () => createPainter('Value $i', 100),
        );
      }

      expect(cache.length, 5);
      cache.clear();
      expect(cache.length, 0);
      expect(cache.isEmpty, isTrue);
    });

    test('clearRow removes only entries for that row', () {
      for (int i = 0; i < 5; i++) {
        cache.getOrCreate(
          rowIndex: i,
          colId: 'name',
          displayValue: 'Value $i',
          maxWidth: 100,
          create: () => createPainter('Value $i', 100),
        );
      }

      expect(cache.length, 5);
      cache.clearRow(2);
      expect(cache.length, 4);

      // Row 2 should be recreated on next access
      int createCount = 0;
      cache.getOrCreate(
        rowIndex: 2,
        colId: 'name',
        displayValue: 'Value 2',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Value 2', 100);
        },
      );
      expect(createCount, 1);
    });

    test('clearColumn removes only entries for that column', () {
      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        create: () => createPainter('Alice', 100),
      );
      cache.getOrCreate(
        rowIndex: 0,
        colId: 'age',
        displayValue: '30',
        maxWidth: 80,
        create: () => createPainter('30', 80),
      );
      cache.getOrCreate(
        rowIndex: 1,
        colId: 'name',
        displayValue: 'Bob',
        maxWidth: 100,
        create: () => createPainter('Bob', 100),
      );

      expect(cache.length, 3);
      cache.clearColumn('name');
      expect(cache.length, 1); // Only 'age' entry remains
    });

    test('LRU eviction removes oldest entries when at capacity', () {
      // Cache with maxSize 5
      final smallCache = TextPainterCache(maxSize: 5);

      for (int i = 0; i < 5; i++) {
        smallCache.getOrCreate(
          rowIndex: i,
          colId: 'name',
          displayValue: 'Value $i',
          maxWidth: 100,
          create: () => createPainter('Value $i', 100),
        );
      }

      expect(smallCache.length, 5);

      // Add one more — should evict the oldest (row 0)
      smallCache.getOrCreate(
        rowIndex: 5,
        colId: 'name',
        displayValue: 'Value 5',
        maxWidth: 100,
        create: () => createPainter('Value 5', 100),
      );

      // After eviction, oldest entries are removed
      // Eviction removes ~10% = 1 entry (the oldest)
      expect(smallCache.length, 5);

      // Row 0 should have been evicted — accessing it should create a new one
      int createCount = 0;
      smallCache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Value 0',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Value 0', 100);
        },
      );
      expect(createCount, 1); // Had to recreate

      smallCache.dispose();
    });

    test('accessing a cached entry moves it to end (LRU refresh)', () {
      final smallCache = TextPainterCache(maxSize: 5);

      for (int i = 0; i < 5; i++) {
        smallCache.getOrCreate(
          rowIndex: i,
          colId: 'name',
          displayValue: 'Value $i',
          maxWidth: 100,
          create: () => createPainter('Value $i', 100),
        );
      }

      // Access row 0 (oldest) to refresh it
      smallCache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Value 0',
        maxWidth: 100,
        create: () => createPainter('Value 0', 100),
      );

      // Now add a new entry — row 1 should be evicted (it's now the oldest)
      smallCache.getOrCreate(
        rowIndex: 5,
        colId: 'name',
        displayValue: 'Value 5',
        maxWidth: 100,
        create: () => createPainter('Value 5', 100),
      );

      // Row 0 should still be cached (was refreshed)
      int createCount = 0;
      smallCache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Value 0',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Value 0', 100);
        },
      );
      expect(createCount, 0); // Still cached

      // Row 1 should have been evicted
      smallCache.getOrCreate(
        rowIndex: 1,
        colId: 'name',
        displayValue: 'Value 1',
        maxWidth: 100,
        create: () {
          createCount++;
          return createPainter('Value 1', 100);
        },
      );
      expect(createCount, 1); // Had to recreate

      smallCache.dispose();
    });

    test('default maxSize is 2000', () {
      final defaultCache = TextPainterCache();
      expect(defaultCache.maxSize, 2000);
      defaultCache.dispose();
    });

    test('same style instance reuses the cached painter', () {
      const style = TextStyle(fontSize: 13);
      int createCount = 0;
      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        style: style,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );
      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        style: style,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );
      expect(createCount, 1);
    });

    test('different style instance invalidates without manual clear()', () {
      // Simulates a theme change where clear() was forgotten: the new
      // TextStyle identity must miss the cache rather than return a painter
      // laid out with the old theme's style.
      const styleA = TextStyle(fontSize: 13, color: Color(0xFF111111));
      const styleB = TextStyle(fontSize: 15, color: Color(0xFF222222));

      int createCount = 0;
      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        style: styleA,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );
      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        style: styleB,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );

      expect(createCount, 2);
      expect(cache.length, 2); // both entries coexist, keyed by style
    });

    test('different text scaler value invalidates the entry', () {
      int createCount = 0;
      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        textScaler: TextScaler.noScaling,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );
      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        textScaler: const TextScaler.linear(1.5),
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );
      expect(createCount, 2);
    });

    test('equal-value scalers share an entry (noScaling == linear(1.0))', () {
      int createCount = 0;
      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        textScaler: TextScaler.noScaling,
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );
      cache.getOrCreate(
        rowIndex: 0,
        colId: 'name',
        displayValue: 'Alice',
        maxWidth: 100,
        textScaler: const TextScaler.linear(1.0),
        create: () {
          createCount++;
          return createPainter('Alice', 100);
        },
      );
      expect(createCount, 1);
    });
  });
}
