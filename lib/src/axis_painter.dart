import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import 'models/legacy_gantt_theme.dart';

/// A [CustomPainter] that draws the time axis and vertical grid lines for the Gantt chart,
/// but simplified to always show monthly ticks (May, June, July...).
class AxisPainter extends CustomPainter {
  final double x;
  final double y;
  final double width;
  final double height;
  final double Function(DateTime) scale;
  final List<DateTime> domain;
  final List<DateTime> visibleDomain;
  final LegacyGanttTheme theme;

  AxisPainter({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.scale,
    required this.domain,
    required this.visibleDomain,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1.0;

    if (domain.isEmpty || visibleDomain.isEmpty) return;

    // ثابت: تیک‌ها روی ماه
    final Duration tickInterval = const Duration(days: 30);
    final String Function(DateTime) labelFormat =
        (dt) => DateFormat('MMM').format(dt); // "May", "Jun", "Jul"

    final List<MapEntry<double, DateTime>> tickPositions = [];

    // شروع از ابتدای domain
    if (domain.first.isBefore(domain.last)) {
      DateTime currentTick = DateTime(domain.first.year, domain.first.month);

      while (currentTick.isBefore(domain.last)) {
        tickPositions.add(MapEntry(scale(currentTick), currentTick));
        // می‌ریم ماه بعد
        currentTick = DateTime(currentTick.year, currentTick.month + 1);
      }
    }

    for (final entry in tickPositions) {
      final tickX = entry.key;
      final tickTime = entry.value;
      final label = labelFormat(tickTime);

      // خط عمودی
      canvas.drawLine(
        Offset(tickX, y),
        Offset(tickX, y + height),
        paint,
      );

      // متن ماه
      final textStyle = theme.axisTextStyle;
      if (textStyle.color != Colors.transparent) {
        final textSpan = TextSpan(text: label, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(tickX - (textPainter.width / 2), y - textPainter.height),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AxisPainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.scale != scale ||
      !listEquals(oldDelegate.visibleDomain, visibleDomain) ||
      oldDelegate.width != width ||
      oldDelegate.height != height;
}
