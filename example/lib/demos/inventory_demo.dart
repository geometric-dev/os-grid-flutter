/// Inventory Demo — Product catalog with status filtering, pagination,
/// editable incoming stock, and computed profit.
///
/// Mirrors the OS Grid Inventory demo: https://ag-grid.com/example/
/// Uses Quartz Dark theme. Album artwork demonstrates the built-in image
/// cell renderer ([OsBuiltInCellRenderer.image] + [OsImageOptions]).
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'theme_selector.dart';

void main() => runApp(const InventoryDemoApp());

class InventoryDemoApp extends StatefulWidget {
  const InventoryDemoApp({super.key});

  @override
  State<InventoryDemoApp> createState() => _InventoryDemoAppState();
}

class _InventoryDemoAppState extends State<InventoryDemoApp> {
  GridThemePreset _themePreset = GridThemePreset.quartzDark;

  @override
  Widget build(BuildContext context) {
    final isDark = isPresetDark(_themePreset);
    return MaterialApp(
      title: 'OS Grid Flutter — Inventory Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: InventoryPage(
        themePreset: _themePreset,
        onThemeChanged: (preset) => setState(() => _themePreset = preset),
      ),
    );
  }
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.themePreset,
    required this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset> onThemeChanged;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String _quickFilter = '';
  String _statusFilter = 'all';

  static const _statusLabels = {
    'all': 'All',
    'active': 'Active',
    'paused': 'On Hold',
    'outOfStock': 'Out of Stock',
  };

  static final _products = <Map<String, dynamic>>[
    {
      'product': 'Dreams of You',
      'artist': 'David Nearing',
      'category': 'Soft Rock',
      'year': '1978',
      'status': 'active',
      'available': 8,
      'incoming': 20,
      'price': 32,
      'sold': 18,
      'priceIncrease': 5,
      'variants': 2,
    },
    {
      'product': 'Blue Skies',
      'artist': 'Maya Allen',
      'category': 'Pop',
      'year': '2022',
      'status': 'outOfStock',
      'available': 0,
      'incoming': 0,
      'price': 25,
      'sold': 12,
      'priceIncrease': 10,
      'variants': 1,
    },
    {
      'product': 'Heaven',
      'artist': 'Velvet Wave',
      'category': 'Synth-pop',
      'year': '1989',
      'status': 'active',
      'available': 10,
      'incoming': 5,
      'price': 20,
      'sold': 5,
      'priceIncrease': 10,
      'variants': 2,
    },
    {
      'product': 'Life Matters',
      'artist': 'Danielle James',
      'category': 'Rhythm & Blues',
      'year': '2007',
      'status': 'paused',
      'available': 4,
      'incoming': 15,
      'price': 28,
      'sold': 9,
      'priceIncrease': 5,
      'variants': 2,
    },
    {
      'product': 'Lonely Hearts',
      'artist': 'Emma Stone',
      'category': 'Alt-pop',
      'year': '2023',
      'status': 'active',
      'available': 14,
      'incoming': 24,
      'price': 34,
      'sold': 17,
      'priceIncrease': 12,
      'variants': 1,
    },
    {
      'product': 'Imaginary Groove',
      'artist': 'Leo Collins',
      'category': 'Jazz',
      'year': '1972',
      'status': 'active',
      'available': 6,
      'incoming': 10,
      'price': 30,
      'sold': 8,
      'priceIncrease': 8,
      'variants': 2,
    },
    {
      'product': 'Desert Bloom',
      'artist': 'Indigo Ray',
      'category': 'Electronic',
      'year': '2021',
      'status': 'paused',
      'available': 3,
      'incoming': 7,
      'price': 27,
      'sold': 11,
      'priceIncrease': 6,
      'variants': 1,
    },
    {
      'product': 'Golden Daze',
      'artist': 'The Marlowe Sound',
      'category': 'Rock',
      'year': '1985',
      'status': 'active',
      'available': 10,
      'incoming': 12,
      'price': 31,
      'sold': 15,
      'priceIncrease': 7,
      'variants': 2,
    },
    {
      'product': 'Fragments',
      'artist': 'Nova Elle',
      'category': 'Trance',
      'year': '2020',
      'status': 'active',
      'available': 5,
      'incoming': 9,
      'price': 29,
      'sold': 6,
      'priceIncrease': 4,
      'variants': 1,
    },
    {
      'product': 'Solstice City',
      'artist': 'Aurora Lines',
      'category': 'Ambient',
      'year': '2022',
      'status': 'outOfStock',
      'available': 0,
      'incoming': 0,
      'price': 26,
      'sold': 9,
      'priceIncrease': 0,
      'variants': 1,
    },
  ];

  /// Generates deterministic album art for the image cell renderer.
  ///
  /// A coloured tile with a diagonal stripe, derived from the row index, so
  /// the demo needs no network or bundled assets while still exercising the
  /// async loader + [ImageCellCache] path of [OsBuiltInCellRenderer.image].
  Future<ui.Image?> _loadAlbumArt(
    CellRendererParams<Map<String, dynamic>> params,
  ) async {
    final hue = ((params.rowIndex * 47) % 360).toDouble();
    final base = HSLColor.fromAHSL(1, hue, 0.55, 0.45).toColor();
    final stripe = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.6, 0.65).toColor();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 64, 64), Paint()..color = base);
    canvas.save();
    canvas.translate(32, 32);
    canvas.rotate(0.6);
    canvas.drawRect(
      const Rect.fromLTWH(-48, -8, 96, 16),
      Paint()..color = stripe,
    );
    canvas.restore();
    final picture = recorder.endRecording();
    return picture.toImage(64, 64);
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products
        .where((p) {
          if (_statusFilter != 'all' && p['status'] != _statusFilter) {
            return false;
          }
          return true;
        })
        .map((p) {
          // Add computed fields
          return {
            ...p,
            'inventory': '${p['available']} Stock / ${p['variants']} Variants',
            'profit': ((p['price'] as int) * (p['sold'] as int)) / 10,
          };
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2836),
      appBar: AppBar(
        title: const Text('Inventory Demo'),
        actions: [
          DropdownButton<GridThemePreset>(
            value: widget.themePreset,
            underline: const SizedBox.shrink(),
            dropdownColor: Theme.of(context).colorScheme.surface,
            items: GridThemePreset.values.map((preset) {
              return DropdownMenuItem(
                value: preset,
                child: Text(preset.label, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) widget.onThemeChanged(value);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Header bar with filter tabs and search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1F2836),
            child: Row(
              children: [
                // Status filter tabs
                ..._statusLabels.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterTab(entry.value, entry.key),
                  ),
                ),
                const Spacer(),
                // Search box
                SizedBox(
                  width: 220,
                  height: 36,
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search product...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF2A3545),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: const Color(0xFF3D4A5C)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: const Color(0xFF3D4A5C)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: const Color(0xFF2196F3)),
                      ),
                    ),
                    onChanged: (v) => setState(() => _quickFilter = v),
                  ),
                ),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: OsGrid(
              columnDefs: [
                OsColumnDef(
                  field: 'product',
                  headerName: 'Artwork',
                  width: 64,
                  sortable: false,
                  pinned: OsColumnPin.left,
                  builtInCellRenderer: OsBuiltInCellRenderer.image,
                  imageOptions: OsImageOptions(
                    imageForCell: _loadAlbumArt,
                    cornerRadius: 6,
                  ),
                ),
                OsColumnDef(
                  field: 'product',
                  headerName: 'Album Name',
                  width: 200,
                  sortable: true,
                ),
                OsColumnDef(
                  field: 'artist',
                  headerName: 'Artist',
                  width: 160,
                  sortable: true,
                ),
                OsColumnDef(
                  field: 'year',
                  headerName: 'Year',
                  width: 80,
                  sortable: true,
                ),
                OsColumnDef(
                  field: 'status',
                  headerName: 'Status',
                  width: 130,
                  sortable: true,
                  valueFormatter: (params) {
                    final status = params.value as String?;
                    return _statusLabels[status] ?? status ?? '';
                  },
                  cellStyle: (params) {
                    final status = params.value as String?;
                    return switch (status) {
                      'active' => const OsCellStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w500,
                      ),
                      'outOfStock' => const OsCellStyle(
                        color: Color(0xFFEF5350),
                        fontWeight: FontWeight.w500,
                      ),
                      'paused' => const OsCellStyle(
                        color: Color(0xFFFFA726),
                        fontWeight: FontWeight.w500,
                      ),
                      _ => const OsCellStyle(),
                    };
                  },
                ),
                OsColumnDef(
                  field: 'inventory',
                  headerName: 'Inventory',
                  width: 160,
                  sortable: false,
                ),
                OsColumnDef(
                  field: 'incoming',
                  headerName: 'Incoming',
                  width: 100,
                  sortable: true,
                  editable: true,
                ),
                OsColumnDef(
                  field: 'price',
                  headerName: 'Price',
                  width: 120,
                  sortable: true,
                  valueFormatter: (params) {
                    final price = params.value;
                    if (price == null) return '';
                    return '£$price';
                  },
                ),
                OsColumnDef(
                  field: 'sold',
                  headerName: 'Sold',
                  width: 80,
                  sortable: true,
                ),
                OsColumnDef(
                  field: 'profit',
                  headerName: 'Est. Profit',
                  width: 120,
                  sortable: true,
                  valueFormatter: (params) {
                    final profit = params.value;
                    if (profit == null) return '';
                    if (profit is double) {
                      return '£${profit.toStringAsFixed(1)}';
                    }
                    return '£$profit';
                  },
                ),
              ],
              rowData: _filteredProducts,
              rowHeight: 60,
              headerHeight: 44,
              quickFilterText: _quickFilter,
              pagination: OsPagination(
                pageSize: 10,
                showPageSizeSelector: true,
                pageSizeOptions: [5, 10, 20],
              ),
              theme: getThemeForPreset(widget.themePreset, context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isActive = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2A3545) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF3D4A5C) : const Color(0xFF3D4A5C),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
