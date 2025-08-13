// packages/gantt_chart/lib/src/models/gantt_chart_colors.dart
import 'package:flutter/material.dart';

/// Defines the color scheme for the Gantt chart.
@immutable
class LegacyGanttChartColors {
  final Color barColorPrimary;
  final Color barColorSecondary;
  final Color textColor;
  final Color backgroundColor;

  const LegacyGanttChartColors({
    required this.barColorPrimary,
    required this.barColorSecondary,
    required this.textColor,
    required this.backgroundColor,
  });
}
