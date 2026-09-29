import '../editing/os_cell_editor.dart';
import '../editing/os_checkbox_cell_editor.dart';
import '../editing/os_date_cell_editor.dart';
import '../editing/os_number_cell_editor.dart';
import '../editing/os_text_cell_editor.dart';
import '../filtering/os_date_filter.dart';
import '../filtering/os_filter.dart';
import '../filtering/os_number_filter.dart';
import '../filtering/os_text_filter.dart';
import 'os_column_annotation.dart';
import 'os_column_def.dart';
import 'os_column_schema.dart';

/// Runtime factory deriving typed [OsColumnDef] lists from registered
/// [OsColumnSchema]s (annotation-driven metadata + type-based defaults).
///
/// This is the no-codegen path for quality-program-v3 item 8: register a
/// schema once, then derive columns anywhere:
///
/// ```dart
/// OsColumnRegistry.instance.register<Person>([
///   OsColumnField.text('name', (p) => p.name,
///       meta: const OsColumn(headerName: 'Name', width: 150)),
///   OsColumnField.integer('age', (p) => p.age),
/// ]);
///
/// final columns = OsColumnDefs.fromType<Person>();
/// ```
///
/// The generated part files emitted by `tool/os_column_gen.dart` route
/// through [fromSchema] too, so both paths share identical default rules.
class OsColumnDefs {
  OsColumnDefs._();

  /// Derives column definitions for the registered schema of `T`.
  ///
  /// [overrides] replaces whole definitions per field name; entries are
  /// back-filled with the schema's accessor/write-back and identity fields
  /// when the override omits them.
  ///
  /// Throws a descriptive [StateError] when `T` is not registered.
  static List<OsColumnDef<T>> fromType<T extends Object>({
    Map<String, OsColumnDef<T>> overrides = const {},
  }) {
    return fromSchema(
      OsColumnRegistry.instance.schemaFor<T>(),
      overrides: overrides,
    );
  }

  /// Derives column definitions from [schema].
  ///
  /// Resolution order per column: explicit [OsColumn] annotation value →
  /// class-level [OsGridColumn] defaults → type-inferred default.
  static List<OsColumnDef<T>> fromSchema<T>(
    OsColumnSchema<T> schema, {
    Map<String, OsColumnDef<T>> overrides = const {},
  }) {
    final columns = <OsColumnDef<T>>[];
    for (final field in schema.fields) {
      if (schema.config.exclude.contains(field.name)) continue;
      columns.add(_resolveOverride(schema, field, overrides[field.name]));
    }
    return List.unmodifiable(columns);
  }

  static OsColumnDef<T> _resolveOverride<T>(
    OsColumnSchema<T> schema,
    OsColumnField<T> field,
    OsColumnDef<T>? override,
  ) {
    if (override == null) return _buildDef(schema, field);
    // Replace-with-backfill: honour the override wholesale but restore the
    // plumbing it cannot express without the schema — accessor, write-back,
    // identity/header fallbacks, and type-inferred filter/editor/renderer
    // when the override leaves them unset.
    final meta = field.meta;
    final editable = meta.editable ?? false;
    var merged = override.copyWith(
      field: override.field ?? field.name,
      colId: override.colId ?? _colId(schema.config, field),
      headerName:
          override.headerValueGetter != null || override.headerName != null
          ? override.headerName
          : (meta.headerName ?? _capitalize(field.name)),
      valueGetter: override.valueGetter ?? (p) => field.value(p.data),
      valueSetter:
          override.valueSetter ?? (editable ? _setterFor(field) : null),
      cellEditor:
          override.cellEditor ?? (editable ? _editorFor(field.kind) : null),
    );
    if (override.filter == null) {
      merged = merged.copyWith(filter: _filterFor(meta.filter, field.kind));
    }
    if (override.builtInCellRenderer == null &&
        !editable &&
        field.kind == OsColumnKind.boolean) {
      merged = merged.copyWith(
        builtInCellRenderer: OsBuiltInCellRenderer.checkbox,
      );
    }
    return merged;
  }

  static OsColumnDef<T> _buildDef<T>(
    OsColumnSchema<T> schema,
    OsColumnField<T> field,
  ) {
    final meta = field.meta;
    final config = schema.config;
    final editable = meta.editable ?? false;

    return OsColumnDef<T>(
      field: field.name,
      colId: _colId(config, field),
      headerName: meta.headerName ?? _capitalize(field.name),
      width: meta.width ?? config.defaultWidth,
      minWidth: meta.minWidth,
      maxWidth: meta.maxWidth,
      flex: meta.flex,
      sortable: meta.sortable ?? config.defaultSortable ?? false,
      resizable: meta.resizable ?? config.defaultResizable ?? true,
      hide: meta.hide,
      pinned: meta.pinned,
      singleClickEdit: meta.singleClickEdit,
      suppressMenu: meta.suppressMenu,
      lockVisible: meta.lockVisible,
      lockPinned: meta.lockPinned,
      lockPosition: meta.lockPosition,
      rowGroup: meta.rowGroup,
      pivot: meta.pivot,
      aggFunc: meta.aggFunc,
      tooltipField: meta.tooltipField,
      headerTooltip: meta.headerTooltip,
      autoHeight: meta.autoHeight ?? false,
      wrapText: meta.wrapText ?? false,
      valueGetter: (params) => field.value(params.data),
      valueSetter: editable ? _setterFor(field) : null,
      filter: _filterFor(meta.filter, field.kind),
      cellEditor: editable ? _editorFor(field.kind) : null,
      builtInCellRenderer: field.kind == OsColumnKind.boolean && !editable
          ? OsBuiltInCellRenderer.checkbox
          : null,
    );
  }

  static String _colId<T>(OsGridColumn config, OsColumnField<T> field) =>
      '${config.colIdPrefix ?? ''}${field.meta.colId ?? field.name}';

  static bool Function(dynamic params)? _setterFor<T>(OsColumnField<T> field) {
    final setValue = field.setValue;
    if (setValue == null) return null;
    return (params) {
      setValue(params.data, params.newValue);
      return true;
    };
  }

  static OsFilter? _filterFor(OsColumnFilterHint? hint, OsColumnKind kind) {
    if (hint == OsColumnFilterHint.none) return null;
    if (hint != null) {
      return switch (hint) {
        OsColumnFilterHint.text => const OsTextFilter(),
        OsColumnFilterHint.number => const OsNumberFilter(),
        OsColumnFilterHint.date => const OsDateFilter(),
        OsColumnFilterHint.none => null,
      };
    }
    return switch (kind) {
      OsColumnKind.text => const OsTextFilter(),
      OsColumnKind.integer || OsColumnKind.number => const OsNumberFilter(),
      OsColumnKind.date => const OsDateFilter(),
      OsColumnKind.boolean || OsColumnKind.custom => null,
    };
  }

  static OsCellEditor? _editorFor(OsColumnKind kind) => switch (kind) {
    OsColumnKind.text => const OsTextCellEditor(),
    OsColumnKind.integer || OsColumnKind.number => const OsNumberCellEditor(),
    OsColumnKind.date => const OsDateCellEditor(),
    OsColumnKind.boolean => const OsCheckboxCellEditor(),
    OsColumnKind.custom => null,
  };

  static String _capitalize(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }
}
