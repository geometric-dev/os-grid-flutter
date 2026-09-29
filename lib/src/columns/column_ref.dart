import 'os_column_schema.dart';

/// Phantom-typed column identifier tying a colId to its row data type.
///
/// Cures the stringly-typed colId problem (quality-program-v3 item 38): APIs
/// that accept a colId can accept a [ColumnRef] instead, and the type
/// parameter makes cross-entity mix-ups a compile-time error rather than a
/// runtime bug.
///
/// ```dart
/// final nameCol = ColumnRef<Person>.unchecked('person.name');
/// String id = nameCol.colId; // 'person.name'
///
/// // Compile-time safety: ColumnRef<Person> is NOT a ColumnRef<Order>.
/// ```
///
/// Prefer deriving refs from registered schemas via the top-level
/// [columnRef] function, or from the constants emitted by
/// `tool/os_column_gen.dart` (`PersonCols.name`).
class ColumnRef<TData> {
  /// Creates an unvalidated reference.
  ///
  /// Intended for generated code and hand-written constants whose ids are
  /// already known-good. For registry-validated creation use the
  /// top-level [columnRef] function.
  const ColumnRef.unchecked(this.colId);

  const ColumnRef._(this.colId);

  /// The underlying colId string used by grid APIs.
  final String colId;

  @override
  bool operator ==(Object other) =>
      other is ColumnRef<TData> && other.colId == colId;

  @override
  int get hashCode => Object.hash(runtimeType, colId);

  @override
  String toString() => 'ColumnRef<$TData>($colId)';
}

/// Creates a compile-safe, registry-validated [ColumnRef] from a typed field
/// accessor.
///
/// The accessor must be identical to one registered in
/// [OsColumnRegistry] for `T` — pass a top-level function, a static method,
/// or a tear-off of either. Anonymous closures create a fresh object per
/// evaluation and cannot be matched:
///
/// ```dart
/// Object? personName(Person p) => p.name; // top-level: identity-stable
///
/// OsColumnRegistry.instance.register<Person>([
///   OsColumnField.text('name', personName),
/// ]);
///
/// final ref = columnRef<Person>(personName); // ColumnRef<Person>('name')
///
/// columnRef<Person>((p) => p.name);          // throws: anonymous closure
/// ```
///
/// Throws [ArgumentError] when no registered field's accessor matches.
ColumnRef<T> columnRef<T extends Object>(
  Object? Function(T) accessor, {
  OsColumnRegistry? registry,
}) {
  final effectiveRegistry = registry ?? OsColumnRegistry.instance;
  final colId = effectiveRegistry.colIdForAccessor<T>(accessor);
  if (colId == null) {
    throw ArgumentError.value(
      accessor,
      'accessor',
      'No registered OsColumnField accessor for $T matches this function. '
          'Reuse the exact accessor passed to OsColumnRegistry.register '
          '(top-level/static functions and tear-offs only — anonymous closures '
          'cannot be identified), or build the ref directly with '
          "ColumnRef<$T>.unchecked('<colId>').",
    );
  }
  return ColumnRef<T>._(colId);
}
