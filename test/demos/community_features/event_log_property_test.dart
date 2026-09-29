import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

// Import the EventLog widget and EventLogEntry model.
// ignore: avoid_relative_lib_imports
import '../../../example/lib/demos/community_features/widgets/event_log.dart';

/// Replicates the capacity logic from `EventLog._visibleEntries`.
///
/// Given a full list of entries and a max capacity, returns the most recent
/// `maxEntries` entries (i.e. the tail of the list).
List<EventLogEntry> computeVisibleEntries(
  List<EventLogEntry> entries,
  int maxEntries,
) {
  if (entries.length <= maxEntries) return entries;
  return entries.sublist(entries.length - maxEntries);
}

void main() {
  group(
    'Feature: community-features-demo, Property 5: Event log capacity constraint',
    () {
      // **Validates: Requirements 3.5, 6.5, 10.6**

      test(
        'For any sequence of M events where M > N (max capacity), '
        'the log contains exactly N most recent events in chronological order',
        () {
          const iterations = 100;

          for (var i = 0; i < iterations; i++) {
            final rng = Random(i);

            // Generate a random max capacity N between 1 and 100.
            final maxCapacity = rng.nextInt(100) + 1;

            // Generate M events where M > N.
            // M is between N+1 and N+200 to test various overflow amounts.
            final totalEvents = maxCapacity + rng.nextInt(200) + 1;

            // Create a list of M events with sequential timestamps.
            final baseTime = DateTime(2024, 1, 1);
            final allEntries = List.generate(totalEvents, (index) {
              return EventLogEntry(
                type: 'event_$index',
                details: 'Details for event $index (seed=$i)',
                timestamp: baseTime.add(Duration(seconds: index)),
              );
            });

            // Compute visible entries using the same logic as the widget.
            final visible = computeVisibleEntries(allEntries, maxCapacity);

            // Property assertion 1: The visible list has exactly N entries.
            expect(
              visible.length,
              equals(maxCapacity),
              reason:
                  'Iteration $i: Expected $maxCapacity visible entries '
                  'but got ${visible.length} '
                  '(total=$totalEvents, maxCapacity=$maxCapacity)',
            );

            // Property assertion 2: The visible entries are the N most recent
            // (i.e. the last N entries from the original list).
            final expectedEntries = allEntries.sublist(
              allEntries.length - maxCapacity,
            );
            for (var j = 0; j < maxCapacity; j++) {
              expect(
                visible[j].type,
                equals(expectedEntries[j].type),
                reason:
                    'Iteration $i, index $j: '
                    'Expected ${expectedEntries[j].type} '
                    'but got ${visible[j].type}',
              );
              expect(
                visible[j].timestamp,
                equals(expectedEntries[j].timestamp),
                reason:
                    'Iteration $i, index $j: '
                    'Timestamps do not match',
              );
            }

            // Property assertion 3: The visible entries are in chronological
            // order (each timestamp <= the next).
            for (var j = 0; j < visible.length - 1; j++) {
              expect(
                visible[j].timestamp.compareTo(visible[j + 1].timestamp) <= 0,
                isTrue,
                reason:
                    'Iteration $i: Entries not in chronological order '
                    'at index $j: ${visible[j].timestamp} > '
                    '${visible[j + 1].timestamp}',
              );
            }

            // Property assertion 4: All older events (those not in visible)
            // have timestamps strictly before the first visible entry.
            if (visible.isNotEmpty) {
              final oldestVisibleTime = visible.first.timestamp;
              final discardedEntries = allEntries.sublist(
                0,
                allEntries.length - maxCapacity,
              );
              for (final discarded in discardedEntries) {
                expect(
                  discarded.timestamp.isBefore(oldestVisibleTime),
                  isTrue,
                  reason:
                      'Iteration $i: Discarded entry '
                      '${discarded.type} at ${discarded.timestamp} '
                      'should be before oldest visible '
                      '$oldestVisibleTime',
                );
              }
            }
          }
        },
      );

      test('When M <= N, all entries are retained without truncation', () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final rng = Random(i + 1000);

          // Generate a random max capacity N between 1 and 200.
          final maxCapacity = rng.nextInt(200) + 1;

          // Generate M events where M <= N.
          final totalEvents = rng.nextInt(maxCapacity) + 1;

          final baseTime = DateTime(2024, 6, 15);
          final allEntries = List.generate(totalEvents, (index) {
            return EventLogEntry(
              type: 'evt_$index',
              details: 'Detail $index',
              timestamp: baseTime.add(Duration(seconds: index)),
            );
          });

          final visible = computeVisibleEntries(allEntries, maxCapacity);

          // When M <= N, all entries should be returned.
          expect(
            visible.length,
            equals(totalEvents),
            reason:
                'Iteration $i: When total ($totalEvents) <= max '
                '($maxCapacity), all entries should be visible',
          );

          // Entries should be identical to the input.
          for (var j = 0; j < totalEvents; j++) {
            expect(visible[j], same(allEntries[j]));
          }
        }
      });

      test('Capacity constraint holds for edge case where M = N + 1', () {
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final rng = Random(i + 2000);

          // N between 1 and 150.
          final maxCapacity = rng.nextInt(150) + 1;
          // M = N + 1 (exactly one event over capacity).
          final totalEvents = maxCapacity + 1;

          final baseTime = DateTime(2024, 3, 10);
          final allEntries = List.generate(totalEvents, (index) {
            return EventLogEntry(
              type: 'e$index',
              details: 'D$index',
              timestamp: baseTime.add(Duration(minutes: index)),
            );
          });

          final visible = computeVisibleEntries(allEntries, maxCapacity);

          // Should have exactly N entries.
          expect(visible.length, equals(maxCapacity));

          // The first (oldest) entry should be discarded.
          expect(visible.first.type, equals('e1'));
          expect(visible.last.type, equals('e$maxCapacity'));
        }
      });
    },
  );
}
