import 'package:flutter/material.dart';

/// A single entry in the event log.
class EventLogEntry {
  const EventLogEntry({
    required this.type,
    required this.details,
    required this.timestamp,
  });

  /// The event type (e.g. 'cellValueChanged', 'rowDragEnd').
  final String type;

  /// Human-readable details about the event.
  final String details;

  /// When the event occurred.
  final DateTime timestamp;
}

/// A reusable scrollable event log widget.
///
/// Displays a list of [EventLogEntry] items with type, details, and timestamp.
/// Automatically scrolls to the latest entry when new entries are added.
/// The displayed entries are capped at [maxEntries] (default 50), showing only
/// the most recent entries.
class EventLog extends StatefulWidget {
  const EventLog({super.key, required this.entries, this.maxEntries = 50});

  /// The full list of event log entries to display.
  ///
  /// If the list exceeds [maxEntries], only the most recent entries are shown.
  final List<EventLogEntry> entries;

  /// Maximum number of entries to display. Defaults to 50.
  final int maxEntries;

  @override
  State<EventLog> createState() => _EventLogState();
}

class _EventLogState extends State<EventLog> {
  final _scrollController = ScrollController();

  /// Returns the visible entries, capped at [widget.maxEntries].
  List<EventLogEntry> get _visibleEntries {
    final entries = widget.entries;
    if (entries.length <= widget.maxEntries) return entries;
    return entries.sublist(entries.length - widget.maxEntries);
  }

  @override
  void didUpdateWidget(covariant EventLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.length != oldWidget.entries.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _visibleEntries;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'Event Log (${entries.length})',
            style: theme.textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    'No events yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: entries.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _EventLogTile(entry: entry);
                  },
                ),
        ),
      ],
    );
  }
}

class _EventLogTile extends StatelessWidget {
  const _EventLogTile({required this.entry});

  final EventLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = entry.timestamp;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              timeStr,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: Text(
              entry.type,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.details,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
