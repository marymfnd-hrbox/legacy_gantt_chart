import 'package:flutter/material.dart';

/// Defines the theme for the [LegacyGanttChartWidget].
///
/// This class encapsulates all the visual styling for the chart, including
/// colors, text styles, and dimensions.
@immutable
class LegacyGanttTheme {
  final Color barColorPrimary;
  final Color barColorSecondary;
  final Color textColor;
  final Color backgroundColor;
  final Color gridColor;
  final Color summaryBarColor;
  final Color conflictBarColor;
  final Color ghostBarColor;
  final TextStyle axisTextStyle;
  final TextStyle taskTextStyle;
  final double barHeightRatio;
  final Radius barCornerRadius;
  final bool showRowBorders;
  final Color? rowBorderColor;

  LegacyGanttTheme({
    required this.barColorPrimary,
    required this.barColorSecondary,
    required this.textColor,
    required this.backgroundColor,
    this.gridColor = const Color(0x33888888), // Colors.grey.withValues(alpha:0.2)
    this.summaryBarColor = const Color(0x33000000), // Colors.black.withValues(alpha:0.2)
    this.conflictBarColor = const Color(0x80F44336), // Colors.red.withValues(alpha:0.5)
    this.ghostBarColor = const Color(0xB32196F3), // Colors.blue.withValues(alpha:0.7)
    TextStyle? axisTextStyle,
    this.taskTextStyle = const TextStyle(fontSize: 12, color: Colors.white),
    this.showRowBorders = false,
    this.rowBorderColor,
    this.barHeightRatio = 0.7,
    this.barCornerRadius = const Radius.circular(4.0),
  }) : axisTextStyle = axisTextStyle ?? TextStyle(fontSize: 12, color: textColor);

  LegacyGanttTheme copyWith({
    Color? barColorPrimary,
    Color? barColorSecondary,
    Color? textColor,
    Color? backgroundColor,
    Color? gridColor,
    Color? summaryBarColor,
    Color? conflictBarColor,
    Color? ghostBarColor,
    TextStyle? axisTextStyle,
    TextStyle? taskTextStyle,
    double? barHeightRatio,
    Radius? barCornerRadius,
    bool? showRowBorders,
    Color? rowBorderColor,
  }) {
    return LegacyGanttTheme(
      barColorPrimary: barColorPrimary ?? this.barColorPrimary,
      barColorSecondary: barColorSecondary ?? this.barColorSecondary,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      gridColor: gridColor ?? this.gridColor,
      summaryBarColor: summaryBarColor ?? this.summaryBarColor,
      conflictBarColor: conflictBarColor ?? this.conflictBarColor,
      ghostBarColor: ghostBarColor ?? this.ghostBarColor,
      axisTextStyle: axisTextStyle ?? this.axisTextStyle,
      taskTextStyle: taskTextStyle ?? this.taskTextStyle,
      barHeightRatio: barHeightRatio ?? this.barHeightRatio,
      barCornerRadius: barCornerRadius ?? this.barCornerRadius,
      showRowBorders: showRowBorders ?? this.showRowBorders,
      rowBorderColor: rowBorderColor ?? this.rowBorderColor,
    );
  }

  /// Creates a default theme based on the application's [ThemeData].
  factory LegacyGanttTheme.fromTheme(ThemeData theme) {
    return LegacyGanttTheme(
      barColorPrimary: theme.colorScheme.primary,
      barColorSecondary: theme.colorScheme.secondary,
      textColor: theme.colorScheme.onSurface,
      backgroundColor: theme.colorScheme.surface,
      gridColor: theme.colorScheme.onSurface.withValues(alpha:0.2),
      summaryBarColor: theme.colorScheme.onSurface.withValues(alpha:0.2),
      conflictBarColor: Colors.red.withValues(alpha:0.5),
      ghostBarColor: theme.colorScheme.primary.withValues(alpha:0.7),
      rowBorderColor: theme.colorScheme.onSurface.withValues(alpha:0.2),
      axisTextStyle: theme.textTheme.bodySmall ?? TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
      taskTextStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary) ?? const TextStyle(fontSize: 12, color: Colors.white),
    );
  }
}