// packages/gantt_chart/lib/src/axis_painter.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter/foundation.dart' show listEquals;
import 'dart:ui' as ui; // Import for TextDirection

import 'models/legacy_gantt_theme.dart';

class AxisPainter extends CustomPainter {
  final double x;
  final double y;
  final double width;
  final double height;
  final double Function(DateTime) scale;
  final int ticks;
  final List<DateTime> domain;
  final LegacyGanttTheme theme;

  AxisPainter({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.scale,
    required this.ticks,
    required this.domain,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (domain.length < 2 || domain[0] == domain[1]) {
      return;
    }

    final totalDuration = domain[1].difference(domain[0]).inMilliseconds;
    if (totalDuration <= 0) {
      return;
    }

    final paint = Paint()..color = theme.gridColor;
    final textStyle = theme.axisTextStyle;

    for (int i = 0; i <= ticks; i++) {
      final tickDuration = (totalDuration / ticks) * i;
      final date = domain[0].add(Duration(milliseconds: tickDuration.round()));

      // Use the scale function to get the correct x position for both lines and text.
      final double tickX = scale(date);

      // Draw vertical grid line
      if (height > 0) {
        canvas.drawLine(Offset(tickX, y), Offset(tickX, y + height), paint);
      }

      // Draw date label
      if (textStyle.color != Colors.transparent) {
        final textSpan =
            TextSpan(text: DateFormat('M/d').format(date), style: textStyle);
        final textPainter = TextPainter(
            text: textSpan,
            textAlign: TextAlign.center,
            textDirection: ui.TextDirection.ltr);
        textPainter.layout();
        // Center the text on the tick mark
        textPainter.paint(canvas,
            Offset(tickX - (textPainter.width / 2), y - textPainter.height));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is AxisPainter) {
      // Repaint if any of the critical properties change.
      return oldDelegate.width != width ||
          oldDelegate.height != height ||
          !listEquals(oldDelegate.domain, domain) ||
          oldDelegate.ticks != ticks;
    }
    return true;
  }
}
