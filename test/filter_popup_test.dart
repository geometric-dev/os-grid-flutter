import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('FilterPopup widget', () {
    testWidgets('renders with operation dropdown and text input', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Should show the header name
      expect(find.text('Name'), findsOneWidget);

      // Should show the operation dropdown with default 'Contains'
      expect(find.text('Contains'), findsOneWidget);

      // Should show Clear and Apply buttons
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);

      // Should show the AND/OR join buttons
      expect(find.text('AND'), findsOneWidget);
      expect(find.text('OR'), findsOneWidget);

      // Should show the '+ Condition' link
      expect(find.text('+ Condition'), findsOneWidget);
    });

    testWidgets('renders with number filter operations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'age',
              headerName: 'Age',
              filter: const OsNumberFilter(),
              currentModel: null,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Should show the header name
      expect(find.text('Age'), findsOneWidget);

      // Default number filter operation is 'Equals'
      expect(find.text('Equals'), findsOneWidget);
    });

    testWidgets('initialises from existing filter model', (tester) async {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'startsWith', filter: 'Al')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: model,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Should show 'Starts with' as the selected operation
      expect(find.text('Starts with'), findsOneWidget);

      // Should show the filter value in the text field
      expect(find.widgetWithText(TextField, 'Al'), findsOneWidget);
    });

    testWidgets('calls onApply when text is entered', (tester) async {
      OsColumnFilterModel? appliedModel;
      String? appliedColId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              theme: OsGridTheme.quartzDark(),
              onApply: (colId, model) {
                appliedColId = colId;
                appliedModel = model;
              },
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Enter text in the filter input
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Alice');
      await tester.pump();

      // Should have called onApply with the filter model
      expect(appliedColId, 'name');
      expect(appliedModel, isNotNull);
      expect(appliedModel!.conditions.length, 1);
      expect(appliedModel!.conditions.first.type, 'contains');
      expect(appliedModel!.conditions.first.filter, 'Alice');
    });

    testWidgets('calls onApply with null when Clear is tapped', (tester) async {
      OsColumnFilterModel? appliedModel;
      bool clearCalled = false;

      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'contains', filter: 'test')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: model,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, m) {
                appliedModel = m;
                clearCalled = true;
              },
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Tap the Clear button
      await tester.tap(find.text('Clear'));
      await tester.pump();

      expect(clearCalled, isTrue);
      expect(appliedModel, isNull);
    });

    testWidgets('calls onDismiss when Apply is tapped', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, __) {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // Tap the Apply button
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('calls onDismiss when close icon is tapped', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, __) {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // Tap the close icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('hides value input for blank/notBlank operations', (
      tester,
    ) async {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'blank')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: model,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Should show 'Blank' as the selected operation
      expect(find.text('Blank'), findsOneWidget);

      // Should NOT show a text input (blank needs no value)
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows second condition when + Condition is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Initially one text field
      expect(find.byType(TextField), findsOneWidget);

      // Tap '+ Condition'
      await tester.tap(find.text('+ Condition'));
      await tester.pump();

      // Now should have two text fields (one for each condition)
      expect(find.byType(TextField), findsNWidgets(2));

      // '+ Condition' should be gone
      expect(find.text('+ Condition'), findsNothing);
    });

    testWidgets('does not show + Condition when maxNumConditions is 1', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(maxNumConditions: 1),
              currentModel: null,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Should NOT show AND/OR or + Condition
      expect(find.text('AND'), findsNothing);
      expect(find.text('OR'), findsNothing);
      expect(find.text('+ Condition'), findsNothing);
    });

    testWidgets('respects custom filterOptions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(
                filterOptions: [
                  OsTextFilterOption.equals,
                  OsTextFilterOption.startsWith,
                ],
                defaultOption: OsTextFilterOption.equals,
              ),
              currentModel: null,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Should show 'Equals' as the default
      expect(find.text('Equals'), findsOneWidget);

      // Open the dropdown to verify options
      await tester.tap(find.text('Equals'));
      await tester.pumpAndSettle();

      // Should show both options in the dropdown
      expect(find.text('Equals'), findsWidgets);
      expect(find.text('Starts with'), findsOneWidget);

      // Should NOT show 'Contains' (not in filterOptions)
      expect(find.text('Contains'), findsNothing);
    });

    testWidgets('combined conditions produce correct model', (tester) async {
      OsColumnFilterModel? appliedModel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, model) => appliedModel = model,
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Enter text in first condition
      await tester.enterText(find.byType(TextField).first, 'Alice');
      await tester.pump();

      // Add second condition
      await tester.tap(find.text('+ Condition'));
      await tester.pump();

      // Enter text in second condition
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.last, 'Bob');
      await tester.pump();

      // Should have a combined model with AND operator
      expect(appliedModel, isNotNull);
      expect(appliedModel!.conditions.length, 2);
      expect(appliedModel!.operator, OsJoinOperator.and);
      expect(appliedModel!.conditions[0].filter, 'Alice');
      expect(appliedModel!.conditions[1].filter, 'Bob');
    });

    testWidgets('OR join operator produces correct model', (tester) async {
      OsColumnFilterModel? appliedModel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, model) => appliedModel = model,
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Enter text in first condition
      await tester.enterText(find.byType(TextField).first, 'Alice');
      await tester.pump();

      // Switch to OR
      await tester.tap(find.text('OR'));
      await tester.pump();

      // Add second condition
      await tester.tap(find.text('+ Condition'));
      await tester.pump();

      // Enter text in second condition
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.last, 'Bob');
      await tester.pump();

      // Should have OR operator
      expect(appliedModel, isNotNull);
      expect(appliedModel!.operator, OsJoinOperator.or);
    });

    testWidgets('number filter inRange shows two inputs', (tester) async {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [
          OsFilterCondition(type: 'inRange', filter: '10', filterTo: '50'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'age',
              headerName: 'Age',
              filter: const OsNumberFilter(),
              currentModel: model,
              theme: OsGridTheme.quartzDark(),
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Should show 'In range' as the selected operation
      expect(find.text('In range'), findsOneWidget);

      // Should show two text fields (From and To)
      expect(find.byType(TextField), findsNWidgets(2));

      // Should show the values
      expect(find.widgetWithText(TextField, '10'), findsOneWidget);
      expect(find.widgetWithText(TextField, '50'), findsOneWidget);
    });
  });

  group('FilterPopup integration with OsGrid', () {
    testWidgets('filter popup appears when header filter icon is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200,
                    filter: OsTextFilter(),
                  ),
                  const OsColumnDef(
                    field: 'age',
                    headerName: 'Age',
                    width: 100,
                    filter: OsNumberFilter(),
                  ),
                ],
                rowData: const [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                ],
                theme: OsGridTheme.quartzDark(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The filter icon is positioned at the right side of the header cell.
      // For a 200px wide column, the icon is at approximately:
      // colX + colWidth - filterIconRightPadding - menuIconWidth - filterIconSize/2
      // = 0 + 200 - 8 - 20 - 6 = ~166
      // Tap on the filter icon area of the first column header
      // Header height is 48px, so tap at y=24 (center of header)
      await tester.tapAt(const Offset(166, 24));
      await tester.pumpAndSettle();

      // The filter popup should appear
      expect(find.byType(FilterPopup), findsOneWidget);
      expect(find.text('Name'), findsWidgets); // Header name in popup
    });

    testWidgets('filter popup dismisses when tapping outside', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200,
                    filter: OsTextFilter(),
                  ),
                ],
                rowData: const [
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                ],
                theme: OsGridTheme.quartzDark(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the filter icon to open popup
      await tester.tapAt(const Offset(166, 24));
      await tester.pumpAndSettle();
      expect(find.byType(FilterPopup), findsOneWidget);

      // Tap outside the popup (on the scrim)
      // The scrim covers the entire grid area, so tap in the data area
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // Popup should be dismissed
      expect(find.byType(FilterPopup), findsNothing);
    });

    testWidgets('filter popup applies filter and updates grid data', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200,
                    filter: OsTextFilter(),
                  ),
                ],
                rowData: const [
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                  {'name': 'Charlie'},
                ],
                theme: OsGridTheme.quartzDark(),
                statusBar: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open filter popup
      await tester.tapAt(const Offset(166, 24));
      await tester.pumpAndSettle();

      // Enter filter text
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Ali');
      await tester.pumpAndSettle();

      // The filter should be applied (real-time as user types)
      // Tap Apply to dismiss
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Popup should be dismissed
      expect(find.byType(FilterPopup), findsNothing);
    });
  });

  group('HeaderFilterIconHit', () {
    test('creates with required fields', () {
      const hit = HeaderFilterIconHit(
        columnIndex: 2,
        colDef: OsColumnDef(field: 'name', headerName: 'Name'),
      );
      expect(hit.columnIndex, 2);
      expect(hit.colDef.field, 'name');
    });

    test('is a GridHitTestResult', () {
      const hit = HeaderFilterIconHit(
        columnIndex: 0,
        colDef: OsColumnDef(field: 'test'),
      );
      expect(hit, isA<GridHitTestResult>());
    });
  });

  group('FilterPopup theming, locale and overlay', () {
    testWidgets('localeText overrides labels and operation names', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              localeText: OsLocaleText.fromMap({
                'clear': 'Loeschen',
                'apply': 'Anwenden',
                'equals': 'Gleich',
                'andCondition': 'UND',
                'orCondition': 'ODER',
              }),
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Loeschen'), findsOneWidget);
      expect(find.text('Anwenden'), findsOneWidget);
      expect(find.text('UND'), findsOneWidget);
      expect(find.text('ODER'), findsOneWidget);
      expect(find.text('Clear'), findsNothing);
      expect(find.text('Apply'), findsNothing);

      // Open the dropdown and verify the localised option label renders.
      await tester.tap(find.text('Contains'));
      await tester.pumpAndSettle();
      expect(find.text('Gleich'), findsWidgets);
    });

    testWidgets('theme colours resolve from the grid theme', (tester) async {
      const bg = Color(0xFF141A21);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              theme: const OsGridTheme(backgroundColor: bg),
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Material && w.color == bg),
        findsOneWidget,
      );
    });

    testWidgets('panel escapes a narrow host box', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 120,
                  height: 60,
                  child: FilterPopup(
                    colId: 'name',
                    headerName: 'Name',
                    filter: const OsTextFilter(),
                    currentModel: null,
                    onApply: (_, __) {},
                    onDismiss: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final host = tester.getRect(find.byType(FilterPopup).first);
      final panel = tester.getRect(find.text('Apply'));
      expect(panel.right, greaterThan(host.right));
    });
  });

  group('FilterPopup input debouncing', () {
    testWidgets('debounceMs coalesces a keystroke burst into one apply', (
      tester,
    ) async {
      var applyCount = 0;
      OsColumnFilterModel? applied;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(debounceMs: 100),
              currentModel: null,
              onApply: (_, model) {
                applyCount++;
                applied = model;
              },
              onDismiss: () {},
            ),
          ),
        ),
      );

      final field = find.byType(TextField);

      // Burst of three keystrokes with sub-debounce gaps.
      await tester.enterText(field, 'a');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.enterText(field, 'ab');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.enterText(field, 'abc');
      await tester.pump(const Duration(milliseconds: 40));

      // Still inside the quiet period — nothing applied yet.
      expect(applyCount, 0);

      // Quiet period elapses → exactly one apply with the final value.
      await tester.pump(const Duration(milliseconds: 70));
      expect(applyCount, 1);
      expect(applied!.conditions.first.filter, 'abc');
    });

    testWidgets('debounceMs applies immediately for a single input', (
      tester,
    ) async {
      var applyCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(debounceMs: 100),
              currentModel: null,
              onApply: (_, __) => applyCount++,
              onDismiss: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump(const Duration(milliseconds: 120));

      expect(applyCount, 1);
    });

    testWidgets('number filter debounceMs defers apply until quiet', (
      tester,
    ) async {
      var applyCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'age',
              headerName: 'Age',
              filter: const OsNumberFilter(debounceMs: 80),
              currentModel: null,
              onApply: (_, __) => applyCount++,
              onDismiss: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '42');
      await tester.pump(const Duration(milliseconds: 30));
      expect(applyCount, 0);

      await tester.pump(const Duration(milliseconds: 60));
      expect(applyCount, 1);
    });

    testWidgets('null debounceMs keeps immediate per-keystroke apply', (
      tester,
    ) async {
      var applyCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              onApply: (_, __) => applyCount++,
              onDismiss: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump();
      expect(applyCount, 1);

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();
      expect(applyCount, 2);
    });

    testWidgets('inRange second input also honours debounceMs', (tester) async {
      var applyCount = 0;

      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [
          OsFilterCondition(type: 'inRange', filter: '10', filterTo: '50'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'age',
              headerName: 'Age',
              filter: const OsNumberFilter(debounceMs: 100),
              currentModel: model,
              onApply: (_, __) => applyCount++,
              onDismiss: () {},
            ),
          ),
        ),
      );

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));

      await tester.enterText(fields.first, '20');
      await tester.pump(const Duration(milliseconds: 30));
      await tester.enterText(fields.at(1), '60');
      await tester.pump(const Duration(milliseconds: 30));
      expect(applyCount, 0);

      await tester.pump(const Duration(milliseconds: 80));
      expect(applyCount, 1);
    });
  });

  group('FilterPopup Apply/Clear configurability', () {
    testWidgets('buttons are visible by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('showClearButton false hides Clear only', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              showClearButton: false,
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      expect(find.text('Clear'), findsNothing);
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('showApplyButton false hides Apply; Clear still applies', (
      tester,
    ) async {
      OsColumnFilterModel? applied;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: FilterPopup(
                colId: 'name',
                headerName: 'Name',
                filter: const OsTextFilter(),
                currentModel: const OsColumnFilterModel(
                  filterType: 'text',
                  conditions: [
                    OsFilterCondition(type: 'contains', filter: 'test'),
                  ],
                ),
                showApplyButton: false,
                onApply: (_, model) => applied = model,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Apply'), findsNothing);
      expect(find.text('Clear'), findsOneWidget);

      // Clear commits the cleared model programmatically.
      await tester.tap(find.text('Clear'));
      await tester.pump();

      expect(applied, isNull);
      expect(dismissed, isFalse);
    });

    testWidgets('both flags false remove the action row entirely', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              showApplyButton: false,
              showClearButton: false,
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      expect(find.text('Clear'), findsNothing);
      expect(find.text('Apply'), findsNothing);
    });

    testWidgets('closeOnApply false applies without dismissing', (
      tester,
    ) async {
      OsColumnFilterModel? applied;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              closeOnApply: false,
              onApply: (_, model) => applied = model,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Ali');
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(applied, isNotNull);
      expect(applied!.conditions.first.filter, 'Ali');
      expect(dismissed, isFalse);
    });

    testWidgets('closeOnApply default dismisses (existing behaviour)', (
      tester,
    ) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'name',
              headerName: 'Name',
              filter: const OsTextFilter(),
              currentModel: null,
              closeOnApply: true,
              onApply: (_, __) {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Apply'));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('set filter respects the visibility flags too', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPopup(
              colId: 'country',
              headerName: 'Country',
              filter: const OsSetFilter(values: ['Brazil', 'France']),
              currentModel: null,
              showApplyButton: false,
              showClearButton: false,
              valuesProvider: null,
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clear'), findsNothing);
      expect(find.text('Apply'), findsNothing);
      expect(find.text('Brazil'), findsOneWidget);
    });
  });
}
