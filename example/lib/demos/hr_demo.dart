/// HR Demo — Employee directory with departments, salary, and payment status.
///
/// Mirrors the OS Grid HR demo: https://ag-grid.com/example/
/// Adapted for community features (no tree data — uses flat table with
/// department sorting and pinned columns for employee/contact).
library;

import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'theme_selector.dart';

void main() => runApp(const HrDemoApp());

class HrDemoApp extends StatefulWidget {
  const HrDemoApp({super.key});

  @override
  State<HrDemoApp> createState() => _HrDemoAppState();
}

class _HrDemoAppState extends State<HrDemoApp> {
  GridThemePreset _themePreset = GridThemePreset.quartzDark;

  @override
  Widget build(BuildContext context) {
    final isDark = isPresetDark(_themePreset);
    return MaterialApp(
      title: 'OS Grid Flutter — HR Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HrPage(
        themePreset: _themePreset,
        onThemeChanged: (preset) => setState(() => _themePreset = preset),
      ),
    );
  }
}

class HrPage extends StatelessWidget {
  const HrPage({
    super.key,
    required this.themePreset,
    required this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset> onThemeChanged;

  static final _employees = [
    {
      'name': 'Ashley Rivers',
      'jobTitle': 'CEO',
      'department': 'Executive',
      'employmentType': 'Permanent',
      'location': 'France',
      'joinDate': '2010-01-05',
      'salary': 3814,
      'currency': 'GBP',
      'paymentMethod': 'Bank Transfer',
      'status': 'paid',
    },
    {
      'name': 'Deborah Love',
      'jobTitle': 'CTO',
      'department': 'Legal',
      'employmentType': 'Permanent',
      'location': 'Spain',
      'joinDate': '2010-06-08',
      'salary': 8570,
      'currency': 'EUR',
      'paymentMethod': 'Bank Transfer',
      'status': 'paid',
    },
    {
      'name': 'Michael Allen',
      'jobTitle': 'Engineer',
      'department': 'Legal',
      'employmentType': 'Contract',
      'location': 'United Kingdom',
      'joinDate': '2000-04-16',
      'salary': 11865,
      'currency': 'EUR',
      'paymentMethod': 'Bank Transfer',
      'status': 'pending',
    },
    {
      'name': 'Peggy Williams',
      'jobTitle': 'Engineer',
      'department': 'Legal',
      'employmentType': 'Contract',
      'location': 'Netherlands',
      'joinDate': '2004-08-01',
      'salary': 3206,
      'currency': 'EUR',
      'paymentMethod': 'Bank Transfer',
      'status': 'pending',
    },
    {
      'name': 'Kristy Zuniga',
      'jobTitle': 'Engineer',
      'department': 'Legal',
      'employmentType': 'Permanent',
      'location': 'Portugal',
      'joinDate': '2020-08-10',
      'salary': 8971,
      'currency': 'EUR',
      'paymentMethod': 'Cash',
      'status': 'paid',
    },
    {
      'name': 'Joseph Howe',
      'jobTitle': 'CTO',
      'department': 'Design',
      'employmentType': 'Permanent',
      'location': 'United States',
      'joinDate': '2006-11-09',
      'salary': 10157,
      'currency': 'USD',
      'paymentMethod': 'Check',
      'status': 'pending',
    },
    {
      'name': 'Jeffrey Brown',
      'jobTitle': 'Designer',
      'department': 'Design',
      'employmentType': 'Contract',
      'location': 'France',
      'joinDate': '2023-09-26',
      'salary': 5268,
      'currency': 'USD',
      'paymentMethod': 'Check',
      'status': 'paid',
    },
    {
      'name': 'Nicole Jones',
      'jobTitle': 'VP Design',
      'department': 'Design',
      'employmentType': 'Permanent',
      'location': 'Portugal',
      'joinDate': '2014-07-16',
      'salary': 8352,
      'currency': 'USD',
      'paymentMethod': 'Bank Transfer',
      'status': 'pending',
    },
    {
      'name': 'Gary Garcia',
      'jobTitle': 'Head of Design',
      'department': 'Design',
      'employmentType': 'Permanent',
      'location': 'Netherlands',
      'joinDate': '2005-12-07',
      'salary': 11404,
      'currency': 'USD',
      'paymentMethod': 'Check',
      'status': 'pending',
    },
    {
      'name': 'Adrian Conner',
      'jobTitle': 'COO',
      'department': 'Executive',
      'employmentType': 'Permanent',
      'location': 'Netherlands',
      'joinDate': '2011-11-30',
      'salary': 7145,
      'currency': 'GBP',
      'paymentMethod': 'Check',
      'status': 'pending',
    },
    {
      'name': 'Steven Mann',
      'jobTitle': 'Head of Product',
      'department': 'Product',
      'employmentType': 'Permanent',
      'location': 'France',
      'joinDate': '2003-04-15',
      'salary': 8989,
      'currency': 'USD',
      'paymentMethod': 'Check',
      'status': 'pending',
    },
    {
      'name': 'Cheryl Browning',
      'jobTitle': 'CTO',
      'department': 'Support',
      'employmentType': 'Contract',
      'location': 'United States',
      'joinDate': '2015-09-07',
      'salary': 5967,
      'currency': 'EUR',
      'paymentMethod': 'Bank Transfer',
      'status': 'paid',
    },
    {
      'name': 'Clayton Conway',
      'jobTitle': 'Head of Support',
      'department': 'Support',
      'employmentType': 'Permanent',
      'location': 'Spain',
      'joinDate': '2020-06-05',
      'salary': 7388,
      'currency': 'EUR',
      'paymentMethod': 'Check',
      'status': 'paid',
    },
    {
      'name': 'Shelby Jenkins',
      'jobTitle': 'Support Lead',
      'department': 'Support',
      'employmentType': 'Permanent',
      'location': 'United Kingdom',
      'joinDate': '2006-08-14',
      'salary': 10529,
      'currency': 'EUR',
      'paymentMethod': 'Bank Transfer',
      'status': 'paid',
    },
    {
      'name': 'Lawrence Martinez',
      'jobTitle': 'Designer',
      'department': 'Design',
      'employmentType': 'Permanent',
      'location': 'United States',
      'joinDate': '2004-03-25',
      'salary': 3260,
      'currency': 'USD',
      'paymentMethod': 'Cash',
      'status': 'pending',
    },
    {
      'name': 'Breanna Ward',
      'jobTitle': 'VP Design',
      'department': 'Design',
      'employmentType': 'Permanent',
      'location': 'France',
      'joinDate': '2000-08-29',
      'salary': 14597,
      'currency': 'USD',
      'paymentMethod': 'Bank Transfer',
      'status': 'paid',
    },
    {
      'name': 'Melinda Harrington',
      'jobTitle': 'VP Product',
      'department': 'Product',
      'employmentType': 'Contract',
      'location': 'Portugal',
      'joinDate': '2012-10-13',
      'salary': 4051,
      'currency': 'USD',
      'paymentMethod': 'Check',
      'status': 'pending',
    },
    {
      'name': 'Rebecca Butler',
      'jobTitle': 'Engineer',
      'department': 'Product',
      'employmentType': 'Contract',
      'location': 'Spain',
      'joinDate': '2001-12-23',
      'salary': 2046,
      'currency': 'USD',
      'paymentMethod': 'Bank Transfer',
      'status': 'pending',
    },
    {
      'name': 'Barbara Alexander',
      'jobTitle': 'VP Product',
      'department': 'Product',
      'employmentType': 'Permanent',
      'location': 'Spain',
      'joinDate': '2004-08-11',
      'salary': 6598,
      'currency': 'USD',
      'paymentMethod': 'Check',
      'status': 'pending',
    },
    {
      'name': 'Eric Jensen',
      'jobTitle': 'Engineer',
      'department': 'Design',
      'employmentType': 'Permanent',
      'location': 'Spain',
      'joinDate': '2002-04-01',
      'salary': 9594,
      'currency': 'USD',
      'paymentMethod': 'Check',
      'status': 'paid',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final gridTheme = getThemeForPreset(themePreset, context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Demo — Employee Directory'),
        actions: [
          DropdownButton<GridThemePreset>(
            value: themePreset,
            underline: const SizedBox.shrink(),
            dropdownColor: Theme.of(context).colorScheme.surface,
            items: GridThemePreset.values.map((preset) {
              return DropdownMenuItem(
                value: preset,
                child: Text(preset.label, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) onThemeChanged(value);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: OsGrid(
        columnDefs: [
          OsColumnDef(
            field: 'name',
            headerName: 'Employee',
            width: 180,
            sortable: true,
            pinned: OsColumnPin.left,
            builtInCellRenderer: OsBuiltInCellRenderer.avatar,
            avatarOptions: OsAvatarOptions(
              palette: const [
                Colors.teal,
                Colors.indigo,
                Colors.orange,
                Colors.cyan,
              ],
              initialsGetter: (row) => ((row as Map?)?['department'] as String?)
                  ?.substring(0, 2)
                  .toUpperCase(),
            ),
          ),
          OsColumnDef(
            field: 'jobTitle',
            headerName: 'Job Title',
            width: 150,
            sortable: true,
          ),
          OsColumnDef(
            field: 'department',
            headerName: 'Department',
            width: 130,
            sortable: true,
          ),
          OsColumnDef(
            field: 'employmentType',
            headerName: 'Type',
            width: 110,
            sortable: true,
            editable: true,
            cellEditor: const OsSelectCellEditor(
              values: ['Contract', 'Permanent'],
            ),
          ),
          OsColumnDef(
            field: 'location',
            headerName: 'Location',
            width: 140,
            sortable: true,
            editable: true,
            cellEditor: const OsSelectCellEditor(
              values: [
                'France',
                'Spain',
                'United Kingdom',
                'Netherlands',
                'Portugal',
                'United States',
              ],
            ),
          ),
          OsColumnDef(
            field: 'joinDate',
            headerName: 'Join Date',
            width: 110,
            sortable: true,
          ),
          OsColumnDef(
            field: 'salary',
            headerName: 'Salary',
            width: 140,
            sortable: true,
            builtInCellRenderer: OsBuiltInCellRenderer.progressBar,
            progressBarOptions: OsProgressBarOptions(
              min: 0,
              max: 20000,
              colorBuilder: (value) =>
                  value > 10000 ? Colors.green : Colors.orange,
              labelBuilder: (value, progress) => '\$${value.toInt()}',
            ),
          ),
          OsColumnDef(
            field: 'currency',
            headerName: 'Ccy',
            width: 60,
            sortable: true,
          ),
          OsColumnDef(
            field: 'paymentMethod',
            headerName: 'Payment',
            width: 130,
            sortable: true,
            editable: true,
            cellEditor: const OsSelectCellEditor(
              values: ['Bank Transfer', 'Cash', 'Check'],
            ),
          ),
          OsColumnDef(
            field: 'status',
            headerName: 'Status',
            width: 90,
            sortable: true,
            pinned: OsColumnPin.right,
          ),
        ],
        rowData: _employees,
        rowHeight: 44,
        headerHeight: 42,
        rowDrag: true,
        rowSelection: OsRowSelection.single(),
        theme: gridTheme,
      ),
    );
  }
}
