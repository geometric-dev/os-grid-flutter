import 'package:flutter/widgets.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart' show OsColumnDef;
import 'package:os_grid_flutter/src/columns/os_column_def.dart'
    show OsColumnDef;

/// Styling properties for an individual cell.
///
/// Returned from [OsColumnDef.cellStyle] callback:
/// ```dart
/// cellStyle: (params) => OsCellStyle(
///   backgroundColor: params.value > 100 ? Colors.green.shade50 : null,
///   fontWeight: FontWeight.bold,
/// )
/// ```
class OsCellStyle {
  const OsCellStyle({
    this.backgroundColor,
    this.color,
    this.fontWeight,
    this.fontStyle,
    this.textAlign,
    this.padding,
  });

  /// Background colour for this cell.
  final Color? backgroundColor;

  /// Text colour for this cell.
  final Color? color;

  /// Font weight for this cell's text.
  final FontWeight? fontWeight;

  /// Font style (italic, normal) for this cell's text.
  final FontStyle? fontStyle;

  /// Text alignment within the cell.
  final TextAlign? textAlign;

  /// Padding inside the cell.
  final EdgeInsets? padding;
}
