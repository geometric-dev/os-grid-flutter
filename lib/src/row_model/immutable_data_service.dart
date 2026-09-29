/// Service that implements immutable data mode for the client-side row model.
///
/// When `getRowId` is provided and `immutableData` is enabled (or implicitly
/// enabled by the presence of `getRowId`), the grid compares new `rowData`
/// with existing data using row IDs to automatically determine adds, removes,
/// and updates — without needing explicit `applyTransaction` calls.
///
/// This mirrors OS Grid's `ClientSideNodeManager.setImmutableRowData`.
class ImmutableDataService<TData> {
  ImmutableDataService({required this.getRowId});

  /// Function to derive a stable row ID from row data.
  final String Function(TData data) getRowId;

  /// Computes the minimal transaction (adds/removes/updates) needed to
  /// transform [oldData] into [newData] by comparing row IDs.
  ///
  /// Returns an [ImmutableDataResult] containing the categorised rows.
  /// If [oldData] is empty, all rows in [newData] are treated as adds.
  ImmutableDataResult<TData> computeDiff({
    required List<TData> oldData,
    required List<TData> newData,
  }) {
    if (oldData.isEmpty) {
      return ImmutableDataResult<TData>(
        adds: List.of(newData),
        removes: const [],
        updates: const [],
        orderChanged: false,
      );
    }

    if (newData.isEmpty) {
      return ImmutableDataResult<TData>(
        adds: const [],
        removes: List.of(oldData),
        updates: const [],
        orderChanged: false,
      );
    }

    // Build a map of old data by ID for O(1) lookup.
    final oldById = <String, _IndexedRow<TData>>{};
    for (int i = 0; i < oldData.length; i++) {
      final id = getRowId(oldData[i]);
      oldById[id] = _IndexedRow(index: i, data: oldData[i]);
    }

    final adds = <TData>[];
    final updates = <TData>[];
    final newIds = <String>{};
    bool orderChanged = false;
    int prevOldIndex = -1;

    for (int i = 0; i < newData.length; i++) {
      final row = newData[i];
      final id = getRowId(row);
      newIds.add(id);

      final existing = oldById[id];
      if (existing == null) {
        // New row — not in old data.
        adds.add(row);
      } else {
        // Existing row — check if data changed (by identity).
        if (!identical(existing.data, row)) {
          updates.add(row);
        }
        // Check if order changed.
        if (!orderChanged && existing.index <= prevOldIndex) {
          orderChanged = true;
        }
        prevOldIndex = existing.index;
      }
    }

    // Rows in old data but not in new data are removals.
    final removes = <TData>[];
    for (final entry in oldById.entries) {
      if (!newIds.contains(entry.key)) {
        removes.add(entry.value.data);
      }
    }

    // If sizes differ, order effectively changed.
    if (oldData.length != newData.length) {
      orderChanged = true;
    }

    return ImmutableDataResult<TData>(
      adds: adds,
      removes: removes,
      updates: updates,
      orderChanged: orderChanged,
    );
  }
}

/// Result of an immutable data diff operation.
///
/// Contains the categorised rows that need to be added, removed, or updated
/// to transform the old dataset into the new one.
class ImmutableDataResult<TData> {
  const ImmutableDataResult({
    required this.adds,
    required this.removes,
    required this.updates,
    required this.orderChanged,
  });

  /// Rows present in new data but not in old data.
  final List<TData> adds;

  /// Rows present in old data but not in new data.
  final List<TData> removes;

  /// Rows present in both but with different data (by identity).
  final List<TData> updates;

  /// Whether the order of existing rows changed between old and new data.
  final bool orderChanged;

  /// Whether any changes were detected.
  bool get hasChanges =>
      adds.isNotEmpty || removes.isNotEmpty || updates.isNotEmpty;
}

/// Internal helper pairing a row with its index in the old data list.
class _IndexedRow<TData> {
  const _IndexedRow({required this.index, required this.data});

  final int index;
  final TData data;
}
