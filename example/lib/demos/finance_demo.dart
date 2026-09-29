/// Finance Demo — Real-time portfolio tracker with live price updates.
///
/// Mirrors the OS Grid Finance demo: https://ag-grid.com/example/
/// Uses the animateShowChange built-in cell renderer so edited values flash
/// their change direction, and a periodic timer to simulate live updates.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'theme_selector.dart';

void main() => runApp(const FinanceDemoApp());

class FinanceDemoApp extends StatefulWidget {
  const FinanceDemoApp({super.key});

  @override
  State<FinanceDemoApp> createState() => _FinanceDemoAppState();
}

class _FinanceDemoAppState extends State<FinanceDemoApp> {
  GridThemePreset _themePreset = GridThemePreset.quartzDark;

  @override
  Widget build(BuildContext context) {
    final isDark = isPresetDark(_themePreset);
    return MaterialApp(
      title: 'OS Grid Flutter — Finance Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: FinancePage(
        themePreset: _themePreset,
        onThemeChanged: (preset) => setState(() => _themePreset = preset),
      ),
    );
  }
}

class FinancePage extends StatefulWidget {
  const FinancePage({
    super.key,
    required this.themePreset,
    required this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset> onThemeChanged;

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  late List<Map<String, dynamic>> _rowData;
  Timer? _updateTimer;
  String _quickFilter = '';

  static final _instruments = [
    {
      'ticker': 'AAPL',
      'name': 'Apple Inc',
      'instrument': 'Stock',
      'quantity': 75,
      'purchasePrice': 145.0,
      'price': 150.0,
    },
    {
      'ticker': 'MSFT',
      'name': 'Microsoft Corp',
      'instrument': 'Stock',
      'quantity': 30,
      'purchasePrice': 280.0,
      'price': 300.0,
    },
    {
      'ticker': 'GOOGL',
      'name': 'Alphabet Inc',
      'instrument': 'Stock',
      'quantity': 15,
      'purchasePrice': 2300.0,
      'price': 2500.0,
    },
    {
      'ticker': 'TSLA',
      'name': 'Tesla Inc',
      'instrument': 'Stock',
      'quantity': 50,
      'purchasePrice': 860.0,
      'price': 880.0,
    },
    {
      'ticker': 'AMZN',
      'name': 'Amazon.com Inc',
      'instrument': 'Stock',
      'quantity': 20,
      'purchasePrice': 3200.0,
      'price': 3300.0,
    },
    {
      'ticker': 'NVDA',
      'name': 'NVIDIA Corporation',
      'instrument': 'Stock',
      'quantity': 40,
      'purchasePrice': 450.0,
      'price': 500.0,
    },
    {
      'ticker': 'BTC-USD',
      'name': 'Bitcoin',
      'instrument': 'Crypto',
      'quantity': 200,
      'purchasePrice': 30000.0,
      'price': 29000.0,
    },
    {
      'ticker': 'ETH-USD',
      'name': 'Ethereum',
      'instrument': 'Crypto',
      'quantity': 10,
      'purchasePrice': 1500.0,
      'price': 1800.0,
    },
    {
      'ticker': 'US10Y',
      'name': 'U.S. Treasury 10-Year',
      'instrument': 'Bond',
      'quantity': 1000,
      'purchasePrice': 100.0,
      'price': 102.5,
    },
    {
      'ticker': 'SPY',
      'name': 'SPDR S&P 500 ETF',
      'instrument': 'ETF',
      'quantity': 20,
      'purchasePrice': 420.0,
      'price': 430.0,
    },
    {
      'ticker': 'QQQ',
      'name': 'Invesco QQQ Trust',
      'instrument': 'ETF',
      'quantity': 25,
      'purchasePrice': 370.0,
      'price': 380.0,
    },
    {
      'ticker': 'JPM',
      'name': 'JPMorgan Chase',
      'instrument': 'Stock',
      'quantity': 45,
      'purchasePrice': 125.0,
      'price': 130.0,
    },
    {
      'ticker': 'V',
      'name': 'Visa Inc',
      'instrument': 'Stock',
      'quantity': 25,
      'purchasePrice': 210.0,
      'price': 215.0,
    },
    {
      'ticker': 'MA',
      'name': 'Mastercard Inc',
      'instrument': 'Stock',
      'quantity': 15,
      'purchasePrice': 350.0,
      'price': 360.0,
    },
    {
      'ticker': 'NFLX',
      'name': 'Netflix Inc',
      'instrument': 'Stock',
      'quantity': 20,
      'purchasePrice': 420.0,
      'price': 435.0,
    },
    {
      'ticker': 'GLD',
      'name': 'SPDR Gold Trust',
      'instrument': 'ETF',
      'quantity': 100,
      'purchasePrice': 170.0,
      'price': 172.0,
    },
    {
      'ticker': 'XOM',
      'name': 'Exxon Mobil',
      'instrument': 'Stock',
      'quantity': 100,
      'purchasePrice': 90.0,
      'price': 95.0,
    },
    {
      'ticker': 'PFE',
      'name': 'Pfizer Inc',
      'instrument': 'Stock',
      'quantity': 60,
      'purchasePrice': 39.0,
      'price': 40.0,
    },
    {
      'ticker': 'DIS',
      'name': 'Walt Disney Co',
      'instrument': 'Stock',
      'quantity': 35,
      'purchasePrice': 115.0,
      'price': 120.0,
    },
    {
      'ticker': 'BA',
      'name': 'Boeing Co',
      'instrument': 'Stock',
      'quantity': 30,
      'purchasePrice': 180.0,
      'price': 185.0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _rowData = _instruments.map((i) => Map<String, dynamic>.from(i)).toList();
    // Initialise computed fields
    for (final row in _rowData) {
      row['pnl'] =
          (row['quantity'] as int) *
          ((row['price'] as double) - (row['purchasePrice'] as double));
      row['totalValue'] = (row['quantity'] as int) * (row['price'] as double);
      row['__delta_pnl'] = 0.0;
      row['__delta_totalValue'] = 0.0;
    }
    _startUpdates();
  }

  void _startUpdates() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        final rng = Random();
        for (final row in _rowData) {
          if (rng.nextDouble() < 0.15) {
            final change = (rng.nextDouble() * 0.04) - 0.02; // ±2%
            final oldPrice = row['price'] as double;
            final price = oldPrice * (1 + change);
            row['price'] = double.parse(price.toStringAsFixed(2));

            final oldPnl = row['pnl'] as double? ?? 0.0;
            final newPnl =
                (row['quantity'] as int) *
                ((row['price'] as double) - (row['purchasePrice'] as double));
            row['__delta_pnl'] = newPnl - oldPnl;
            row['pnl'] = newPnl;

            final oldTotal = row['totalValue'] as double? ?? 0.0;
            final newTotal =
                (row['quantity'] as int) * (row['price'] as double);
            row['__delta_totalValue'] = newTotal - oldTotal;
            row['totalValue'] = newTotal;
          } else {
            // No change this tick — clear deltas
            row['__delta_pnl'] = 0.0;
            row['__delta_totalValue'] = 0.0;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gridTheme = getThemeForPreset(widget.themePreset, context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Demo — Live Portfolio'),
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
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Filter by ticker or name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _quickFilter = v),
            ),
          ),
          Expanded(
            child: OsGrid(
              columnDefs: [
                OsColumnDef(
                  field: 'ticker',
                  headerName: 'Ticker',
                  width: 100,
                  sortable: true,
                  pinned: OsColumnPin.left,
                ),
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  width: 220,
                  sortable: true,
                ),
                OsColumnDef(
                  field: 'instrument',
                  headerName: 'Instrument',
                  width: 100,
                  sortable: true,
                ),
                OsColumnDef(
                  field: 'quantity',
                  headerName: 'Quantity',
                  width: 90,
                  sortable: true,
                ),
                OsColumnDef(
                  field: 'purchasePrice',
                  headerName: 'Purchase Price',
                  width: 130,
                  sortable: true,
                  valueFormatter: (params) => params.value == null
                      ? ''
                      : '\$${(params.value as double).toStringAsFixed(2)}',
                ),
                OsColumnDef(
                  field: 'price',
                  headerName: 'Current Price',
                  width: 130,
                  sortable: true,
                  valueFormatter: (params) => params.value == null
                      ? ''
                      : '\$${(params.value as double).toStringAsFixed(2)}',
                ),
                OsColumnDef(
                  field: 'pnl',
                  headerName: 'P&L',
                  width: 160,
                  sortable: true,
                  builtInCellRenderer: OsBuiltInCellRenderer.animateShowChange,
                ),
                OsColumnDef(
                  field: 'totalValue',
                  headerName: 'Total Value',
                  width: 170,
                  sortable: true,
                  pinned: OsColumnPin.right,
                  builtInCellRenderer: OsBuiltInCellRenderer.animateShowChange,
                ),
              ],
              rowData: _rowData,
              rowHeight: 40,
              headerHeight: 44,
              quickFilterText: _quickFilter,
              rowSelection: OsRowSelection.single(),
              statusBar: true,
              theme: gridTheme,
            ),
          ),
        ],
      ),
    );
  }
}
