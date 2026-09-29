import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/feature_panel.dart';
import '../widgets/demo_ui.dart';

/// Demonstrates tooltips, cell spanning, value cache, locale customisation,
/// and the star rating built-in cell renderer.
///
/// Covers Requirements 9.1–9.8 from the community features demo spec.
class TooltipsAdvancedPage extends StatefulWidget {
  const TooltipsAdvancedPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<TooltipsAdvancedPage> createState() => _TooltipsAdvancedPageState();
}

class _TooltipsAdvancedPageState extends State<TooltipsAdvancedPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;

  // Tooltip controls
  int _tooltipShowDelay = 500;
  int _tooltipHideDelay = 5000;
  bool _tooltipMouseTrack = false;

  // Value cache
  bool _valueCacheEnabled = false;
  int _valueGetterInvocationCount = 0;

  @override
  void initState() {
    super.initState();
    _rowData = generateSampleData(rowCount: 30);
    // Ensure some rows have null/empty notes to demonstrate null tooltip handling
    _rowData[2]['notes'] = null;
    _rowData[5]['notes'] = '';
    _rowData[8]['notes'] = null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);

    return Column(
      children: [
        FeaturePanel(
          title: 'Tooltips & Advanced Controls',
          children: [
            _buildNumericInput(
              label: 'Tooltip Show Delay (ms)',
              value: _tooltipShowDelay,
              min: 0,
              max: 3000,
              onChanged: (v) => setState(() => _tooltipShowDelay = v),
            ),
            _buildNumericInput(
              label: 'Tooltip Hide Delay (ms)',
              value: _tooltipHideDelay,
              min: 0,
              max: 10000,
              onChanged: (v) => setState(() => _tooltipHideDelay = v),
            ),
            DemoToggle(
              label: 'Tooltip Mouse Track',
              value: _tooltipMouseTrack,
              onChanged: (v) => setState(() => _tooltipMouseTrack = v),
            ),
            DemoToggle(
              label: 'Value Cache',
              value: _valueCacheEnabled,
              onChanged: (v) => setState(() {
                _valueCacheEnabled = v;
                _valueGetterInvocationCount = 0;
              }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'valueGetter calls: $_valueGetterInvocationCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            rowData: _rowData,
            tooltipShowDelay: _tooltipShowDelay,
            tooltipHideDelay: _tooltipHideDelay,
            tooltipMouseTrack: _tooltipMouseTrack,
            enableCellSpan: true,
            valueCacheEnabled: _valueCacheEnabled,
            localeText: _spanishLocale,
            columnDefs: _buildColumnDefs(),
          ),
        ),
      ],
    );
  }

  /// Spanish locale text for demonstrating locale customisation.
  static const _spanishLocale = OsLocaleText(
    noRowsToShow: 'No hay filas para mostrar',
    page: 'Página',
    of: 'de',
    to: 'a',
    next: 'Siguiente',
    previous: 'Anterior',
    first: 'Primera',
    last: 'Última',
    loadingOoo: 'Cargando...',
    selectAll: 'Seleccionar todo',
    searchOoo: 'Buscar...',
    filterOoo: 'Filtrar...',
    applyFilter: 'Aplicar filtro',
    resetFilter: 'Restablecer filtro',
    clearFilter: 'Limpiar filtro',
    equals: 'Igual a',
    notEqual: 'No igual a',
    contains: 'Contiene',
    notContains: 'No contiene',
    startsWith: 'Empieza con',
    endsWith: 'Termina con',
    lessThan: 'Menor que',
    lessThanOrEqual: 'Menor o igual que',
    greaterThan: 'Mayor que',
    greaterThanOrEqual: 'Mayor o igual que',
    inRange: 'En rango',
    blank: 'Vacío',
    notBlank: 'No vacío',
    andCondition: 'Y',
    orCondition: 'O',
    pinLeft: 'Fijar a la izquierda',
    pinRight: 'Fijar a la derecha',
    noPin: 'Sin fijar',
    autosizeThisColumn: 'Autoajustar esta columna',
    autosizeAllColumns: 'Autoajustar todas las columnas',
    resetColumns: 'Restablecer columnas',
    sortAscending: 'Orden ascendente',
    sortDescending: 'Orden descendente',
    clearSort: 'Limpiar orden',
  );

  List<OsColumnDef<Map<String, dynamic>>> _buildColumnDefs() {
    return [
      // Column with tooltipField — shows the 'name' value as tooltip
      OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        headerName: 'Name',
        sortable: true,
        tooltipField: 'name',
        flex: 2,
      ),
      // Column with tooltipValueGetter — dynamic tooltip with row context
      OsColumnDef<Map<String, dynamic>>(
        field: 'department',
        headerName: 'Department',
        sortable: true,
        tooltipValueGetter: (params) {
          final dept = params.data['department'] as String?;
          final country = params.data['country'] as String?;
          if (dept == null || dept.isEmpty) return null;
          return '$dept — $country';
        },
        width: 140,
      ),
      // Column with null/empty tooltip values — no tooltip displayed
      OsColumnDef<Map<String, dynamic>>(
        field: 'notes',
        headerName: 'Notes (nullable tooltip)',
        sortable: true,
        tooltipValueGetter: (params) {
          final notes = params.data['notes'];
          if (notes == null || (notes is String && notes.isEmpty)) return null;
          return notes.toString();
        },
        flex: 2,
      ),
      // Column with colSpan — spans 2 columns for department header rows
      OsColumnDef<Map<String, dynamic>>(
        field: 'country',
        headerName: 'Country (colSpan)',
        sortable: true,
        colSpan: (params) {
          // Span 2 columns for every 5th row to demonstrate colSpan
          return params.rowIndex % 5 == 0 ? 2 : 1;
        },
        width: 150,
      ),
      // Column with rowSpan — spans rows with same department
      OsColumnDef<Map<String, dynamic>>(
        field: 'age',
        headerName: 'Age (rowSpan)',
        sortable: true,
        rowSpan: (params) {
          // Span 2 rows for every 4th row to demonstrate rowSpan
          return params.rowIndex % 4 == 0 ? 2 : 1;
        },
        width: 120,
      ),
      // Column with valueGetter to demonstrate value cache
      OsColumnDef<Map<String, dynamic>>(
        field: 'salary',
        headerName: 'Salary (cached)',
        sortable: true,
        valueGetter: (params) {
          _valueGetterInvocationCount++;
          return params.data['salary'];
        },
        valueFormatter: (params) {
          if (params.value == null) return '';
          return '\$${(params.value as int).toString()}';
        },
        width: 140,
      ),
      // Star rating column using built-in cell renderer
      OsColumnDef<Map<String, dynamic>>(
        field: 'rating',
        headerName: 'Rating',
        sortable: true,
        builtInCellRenderer: OsBuiltInCellRenderer.starRating,
        width: 130,
      ),
    ];
  }

  Widget _buildNumericInput({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 220,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Slider(
                  value: value.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: (max - min) ~/ _sliderStep(min, max),
                  label: value.toString(),
                  onChanged: (v) => onChanged(v.round()),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${value}ms',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// Determines a reasonable slider step size based on the range.
  int _sliderStep(int min, int max) {
    final range = max - min;
    if (range <= 100) return 1;
    if (range <= 1000) return 10;
    return 100;
  }
}
