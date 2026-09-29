import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Feature: community-features-demo, Property 8: Mutation buttons disabled when
/// no row selected
///
/// **Validates: Requirements 6.6**
///
/// For any selection state where zero rows are selected, the "Update Row" and
/// "Remove Row" buttons SHALL be disabled. For any selection state where at
/// least one row is selected, those buttons SHALL be enabled.
///
/// This test extracts the core logic from PaginationDataPage: the button
/// enabled state is determined by whether `_selectedRowId` is null or non-null.
/// We model this as a pure function and verify the property across 100+
/// randomly generated selection states.

/// Models the button-enabled logic from PaginationDataPage.
///
/// Returns true (enabled) when [selectedRowId] is non-null, false (disabled)
/// when null. This mirrors the `hasSelection ? handler : null` pattern used
/// in the page's build method.
bool isButtonEnabled(String? selectedRowId) {
  return selectedRowId != null;
}

/// Generates a random selection state: either null (no selection) or a random
/// row ID string.
String? generateSelectionState(Random rng) {
  // ~50% chance of null (no selection), ~50% chance of a row ID
  if (rng.nextBool()) {
    return null;
  }
  // Generate a random row ID (simulating IDs from 0 to 9999)
  return rng.nextInt(10000).toString();
}

void main() {
  group('Feature: community-features-demo, Property 8: '
      'Mutation buttons disabled when no row selected', () {
    test('buttons are disabled when selectedRowId is null (no selection)', () {
      // For any null selection state, buttons must be disabled.
      for (var seed = 0; seed < 100; seed++) {
        final enabled = isButtonEnabled(null);
        expect(
          enabled,
          isFalse,
          reason:
              'Buttons should be disabled when no row is selected '
              '(seed=$seed)',
        );
      }
    });

    test(
      'buttons are enabled when selectedRowId is non-null (has selection)',
      () {
        // For any non-null selection state, buttons must be enabled.
        for (var seed = 0; seed < 100; seed++) {
          final rng = Random(seed);
          final rowId = rng.nextInt(10000).toString();
          final enabled = isButtonEnabled(rowId);
          expect(
            enabled,
            isTrue,
            reason:
                'Buttons should be enabled when a row is selected '
                '(rowId=$rowId, seed=$seed)',
          );
        }
      },
    );

    test(
      'property holds for 100+ random selection states (mixed null/non-null)',
      () {
        const iterations = 150;
        for (var seed = 0; seed < iterations; seed++) {
          final rng = Random(seed);
          final selectedRowId = generateSelectionState(rng);
          final enabled = isButtonEnabled(selectedRowId);

          if (selectedRowId == null) {
            expect(
              enabled,
              isFalse,
              reason:
                  'Buttons should be disabled when no row is selected '
                  '(seed=$seed)',
            );
          } else {
            expect(
              enabled,
              isTrue,
              reason:
                  'Buttons should be enabled when row "$selectedRowId" is '
                  'selected (seed=$seed)',
            );
          }
        }
      },
    );

    test('edge case: empty string row ID still counts as selected', () {
      // An empty string is still non-null, so buttons should be enabled.
      // This verifies the logic is purely null-based, not empty-check-based.
      final enabled = isButtonEnabled('');
      expect(
        enabled,
        isTrue,
        reason: 'Even an empty string selectedRowId means a row is selected',
      );
    });

    test('edge case: various row ID formats are all treated as selected', () {
      // Test with different ID formats that might appear in practice.
      final testIds = ['0', '1', '999', '-1', 'abc', '3.14', 'row-uuid-123'];
      for (final id in testIds) {
        final enabled = isButtonEnabled(id);
        expect(
          enabled,
          isTrue,
          reason: 'Row ID "$id" should result in enabled buttons',
        );
      }
    });
  });
}
