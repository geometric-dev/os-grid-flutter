import 'os_column_annotation.dart';

/// Coarse data kind of a registered field, driving type-based defaults
/// (filter, cell editor, built-in renderer) in the column factory.
enum OsColumnKind {
  /// String values → text filter, text editor.
  text,

  /// `int` values → number filter, number editor.
  integer,

  /// `double`/`num` values → number filter, number editor.
  number,

  /// `bool` values → checkbox renderer, checkbox editor when editable,
  /// no filter by default.
  boolean,

  /// [DateTime] values → date filter, date editor.
  date,

  /// Anything else — no inferred filter or editor.
  custom,
}

/// One derivable field of a data class: its name, an accessor, optional
/// write-back support, and the [OsColumn] metadata annotation.
///
/// Instances are typically produced by the generated part file
/// (`tool/os_column_gen.dart`) or written by hand when registering a schema
/// without code generation:
///
/// ```dart
/// OsColumnRegistry.instance.register<Person>([
///   OsColumnField.text('name', (p) => p.name,
///       meta: const OsColumn(headerName: 'Name', width: 150)),
///   OsColumnField.integer('age', (p) => p.age),
/// ]);
/// ```
class OsColumnField<TData> {
  /// Creates a field descriptor. Prefer the typed convenience constructors
  /// ([OsColumnField.text], [OsColumnField.integer], …) which set [kind].
  const OsColumnField({
    required this.name,
    required this.value,
    this.setValue,
    this.kind = OsColumnKind.custom,
    this.meta = const OsColumn(),
  });

  /// Field name; becomes the derived column's `field` and default colId.
  final String name;

  /// Reads the cell value from a row instance.
  final Object? Function(TData data) value;

  /// Writes an edited value back to a row instance. When null the column is
  /// treated as read-only regardless of `meta.editable`.
  final void Function(TData data, Object? newValue)? setValue;

  /// Data kind used for defaults inference.
  final OsColumnKind kind;

  /// Per-column annotation metadata (may be `const OsColumn()`).
  final OsColumn meta;

  /// Text-typed field ([OsColumnKind.text]).
  const OsColumnField.text(
    this.name,
    this.value, {
    this.setValue,
    this.meta = const OsColumn(),
  }) : kind = OsColumnKind.text;

  /// Integer-typed field ([OsColumnKind.integer]).
  const OsColumnField.integer(
    this.name,
    this.value, {
    this.setValue,
    this.meta = const OsColumn(),
  }) : kind = OsColumnKind.integer;

  /// Numeric-typed field ([OsColumnKind.number]).
  const OsColumnField.number(
    this.name,
    this.value, {
    this.setValue,
    this.meta = const OsColumn(),
  }) : kind = OsColumnKind.number;

  /// Boolean-typed field ([OsColumnKind.boolean]).
  const OsColumnField.boolean(
    this.name,
    this.value, {
    this.setValue,
    this.meta = const OsColumn(),
  }) : kind = OsColumnKind.boolean;

  /// Date-typed field ([OsColumnKind.date]).
  const OsColumnField.date(
    this.name,
    this.value, {
    this.setValue,
    this.meta = const OsColumn(),
  }) : kind = OsColumnKind.date;
}

/// The complete column derivation input for one data class: class-level
/// config plus ordered field descriptors.
///
/// [TData] flows through to every field descriptor, so a `Person`-typed
/// schema can only hold accessors that read from `Person`.
class OsColumnSchema<TData> {
  /// Builds a schema for [type] from [fields], honouring class-level
  /// [config].
  const OsColumnSchema({
    required this.type,
    required this.fields,
    this.config = const OsGridColumn(),
  });

  /// The reified row data type this schema describes.
  final Type type;

  /// Ordered field descriptors; derivation preserves this order.
  final List<OsColumnField<TData>> fields;

  /// Class-level annotation (`@OsGridColumn(...)`) defaults.
  final OsGridColumn config;

  /// Returns the descriptor for [name], or null.
  OsColumnField<TData>? fieldFor(String name) {
    for (final field in fields) {
      if (field.name == name) return field;
    }
    return null;
  }
}

/// Global registry mapping row data types to their [OsColumnSchema]s.
///
/// Populated either manually ([register]) or by generated registration code.
/// `OsColumnDefs.fromType` and `columnRef` resolve through this registry.
class OsColumnRegistry {
  /// Creates an isolated registry. Most callers should use [instance].
  factory OsColumnRegistry() => OsColumnRegistry._();

  OsColumnRegistry._();

  static final OsColumnRegistry _shared = OsColumnRegistry._();

  /// Shared process-wide registry instance.
  static OsColumnRegistry get instance => _shared;

  /// Values are the exact `OsColumnSchema<T>` instances handed to
  /// [register]/[registerSchema]; the `Object` value type erases only the
  /// static type, so [schemaFor]'s cast is always sound.
  final Map<Type, Object> _schemas = {};

  /// Registers the schema for `T`. Re-registering replaces any prior entry.
  void register<T extends Object>(
    List<OsColumnField<T>> fields, {
    OsGridColumn config = const OsGridColumn(),
  }) {
    registerSchema(OsColumnSchema<T>(type: T, fields: fields, config: config));
  }

  /// Registers a pre-built [schema], keyed by its reified [OsColumnSchema.type].
  void registerSchema<T extends Object>(OsColumnSchema<T> schema) {
    _schemas[schema.type] = schema;
  }

  /// Removes the schema for `T`, if present.
  void unregister<T extends Object>() => _schemas.remove(T);

  /// Removes every registered schema (test isolation helper).
  void clear() => _schemas.clear();

  /// Whether a schema is registered for `T`.
  bool isRegistered<T extends Object>() => _schemas.containsKey(T);

  /// All currently registered types, in registration order.
  Iterable<Type> get registeredTypes => _schemas.keys;

  /// Resolves the fully-typed schema for `T`.
  ///
  /// Throws a descriptive [StateError] when `T` has no registered schema —
  /// the most common cause being a missing registration or generated part
  /// include.
  OsColumnSchema<T> schemaFor<T extends Object>() {
    final schema = _trySchemaFor<T>();
    if (schema == null) {
      throw StateError(
        'No OsColumnSchema registered for $T. Register one via '
        'OsColumnRegistry.instance.register<$T>([...]) or include the '
        '*.g.part generated by tool/os_column_gen.dart.',
      );
    }
    return schema;
  }

  /// Looks up which registered field's accessor is identical to [accessor].
  ///
  /// Identity matching works reliably for top-level functions, static
  /// methods and tear-offs of them; anonymous closures create a fresh object
  /// per evaluation and will not match. Returns null when nothing matches.
  String? colIdForAccessor<T extends Object>(
    Object? Function(T) accessor, {
    OsColumnSchema<T>? schema,
  }) {
    final effectiveSchema = schema ?? _trySchemaFor<T>();
    if (effectiveSchema == null) return null;
    for (final field in effectiveSchema.fields) {
      if (identical(field.value, accessor) || field.value == accessor) {
        return _derivedColId(field, effectiveSchema.config);
      }
    }
    return null;
  }

  /// Whether [colId] exists in the schema for `T` (debug validation aid).
  bool hasColId<T extends Object>(String colId) {
    final schema = _trySchemaFor<T>();
    if (schema == null) return false;
    return schema.fields.any((f) => _derivedColId(f, schema.config) == colId);
  }

  /// Sound because stored schemas are keyed by their exact reified type.
  OsColumnSchema<T>? _trySchemaFor<T extends Object>() =>
      _schemas[T] as OsColumnSchema<T>?;

  /// Derived colId for a field: prefix + explicit id or field name.
  static String _derivedColId<T>(OsColumnField<T> field, OsGridColumn config) =>
      '${config.colIdPrefix ?? ''}${field.meta.colId ?? field.name}';
}
