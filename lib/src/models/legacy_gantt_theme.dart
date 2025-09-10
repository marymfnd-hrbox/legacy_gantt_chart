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

  /// The color of the lines drawn to represent task dependencies.
  final Color dependencyLineColor;

  /// The color for background highlights, such as holidays or weekends.
  /// This is used for tasks where `isTimeRangeHighlight` is true.
  final Color timeRangeHighlightColor;

  /// The background color for a task that is contained within another.
  final Color containedDependencyBackgroundColor;

  /// The background color for the highlight that appears when hovering over
  /// empty space in a row, indicating a new task can be created.
  final Color emptySpaceHighlightColor;

  /// The color of the add icon (+) that appears in the empty space highlight.
  final Color emptySpaceAddIconColor;
  final double barHeightRatio;
  final Radius barCornerRadius;
  final bool showRowBorders;
  final Color? rowBorderColor;

  LegacyGanttTheme({
    required this.barColorPrimary,
    required this.barColorSecondary,
    required this.textColor,
    required this.backgroundColor,
    this.gridColor = const Color(0x33888888), // Colors.grey.withAlpha(51)
    this.summaryBarColor = const Color(0x33000000), // Colors.black.withAlpha(51)
    this.conflictBarColor = const Color(0x80F44336), // Colors.red.withAlpha(128)
    this.ghostBarColor = const Color(0xB32196F3), // Colors.blue.withAlpha(179)
    TextStyle? axisTextStyle,
    this.taskTextStyle = const TextStyle(fontSize: 12, color: Colors.white),
    this.showRowBorders = false,
    this.rowBorderColor,
    this.dependencyLineColor = const Color(0xFF616161), // Colors.grey[700]
    this.timeRangeHighlightColor = const Color(0x0D000000), // Colors.black.withAlpha(13)
    this.containedDependencyBackgroundColor = const Color(0x1A000000), // Colors.black.withAlpha(26)
    this.emptySpaceHighlightColor = const Color(0x0F2196F3), // Colors.blue.withAlpha(15)
    this.emptySpaceAddIconColor = const Color(0xFF2196F3), // Colors.blue
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
    Color? dependencyLineColor,
    Color? timeRangeHighlightColor,
    Color? containedDependencyBackgroundColor,
    Color? emptySpaceHighlightColor,
    Color? emptySpaceAddIconColor,
    double? barHeightRatio,
    Radius? barCornerRadius,
    bool? showRowBorders,
    Color? rowBorderColor,
  }) =>
      LegacyGanttTheme(
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
        dependencyLineColor: dependencyLineColor ?? this.dependencyLineColor,
        timeRangeHighlightColor: timeRangeHighlightColor ?? this.timeRangeHighlightColor,
        containedDependencyBackgroundColor:
            containedDependencyBackgroundColor ?? this.containedDependencyBackgroundColor,
        emptySpaceHighlightColor: emptySpaceHighlightColor ?? this.emptySpaceHighlightColor,
        emptySpaceAddIconColor: emptySpaceAddIconColor ?? this.emptySpaceAddIconColor,
        barHeightRatio: barHeightRatio ?? this.barHeightRatio,
        barCornerRadius: barCornerRadius ?? this.barCornerRadius,
        showRowBorders: showRowBorders ?? this.showRowBorders,
        rowBorderColor: rowBorderColor ?? this.rowBorderColor,
      );

  /// Creates a default theme based on the application's [ThemeData].
  factory LegacyGanttTheme.fromTheme(ThemeData theme) => LegacyGanttTheme(
        barColorPrimary: theme.colorScheme.primary,
        barColorSecondary: theme.colorScheme.secondary,
        textColor: theme.colorScheme.onSurface,
        backgroundColor: theme.colorScheme.surface,
        gridColor: theme.colorScheme.onSurface.withAlpha(51),
        summaryBarColor: theme.colorScheme.onSurface.withAlpha(51),
        conflictBarColor: Colors.red.withAlpha(128),
        ghostBarColor: theme.colorScheme.primary.withAlpha(179),
        rowBorderColor: theme.colorScheme.onSurface.withAlpha(51),
        dependencyLineColor: theme.colorScheme.onSurface.withAlpha(204),
        timeRangeHighlightColor: theme.colorScheme.onSurface.withAlpha(13),
        containedDependencyBackgroundColor: theme.colorScheme.primary.withAlpha(26),
        emptySpaceHighlightColor: theme.colorScheme.primary.withAlpha(15),
        emptySpaceAddIconColor: theme.colorScheme.primary,
        axisTextStyle: theme.textTheme.bodySmall ?? TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
        taskTextStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary) ??
            const TextStyle(fontSize: 12, color: Colors.white),
      );
}
