// packages/gantt_chart/lib/src/axis_painter.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import 'models/legacy_gantt_theme.dart';

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

    final visibleDuration = visibleDomain.last.difference(visibleDomain.first);

    Duration tickInterval;
    String Function(DateTime) labelFormat;

    if (visibleDuration.inDays > 60) {
      tickInterval = const Duration(days: 7);
      labelFormat = (dt) => 'Week ${_weekNumber(dt)}';
    } else if (visibleDuration.inDays > 14) {
      tickInterval = const Duration(days: 2);
      labelFormat = (dt) => DateFormat('d MMM').format(dt);
    } else if (visibleDuration.inDays > 3) {
      tickInterval = const Duration(days: 1);
      labelFormat = (dt) => DateFormat('EEE d').format(dt);
    } else if (visibleDuration.inHours > 48) {
      tickInterval = const Duration(hours: 12);
      labelFormat = (dt) => DateFormat('ha').format(dt);
    } else if (visibleDuration.inHours > 24) {
      tickInterval = const Duration(hours: 6);
      labelFormat = (dt) => DateFormat('ha').format(dt);
    } else if (visibleDuration.inHours > 12) {
      tickInterval = const Duration(hours: 2);
      labelFormat = (dt) => DateFormat('h a').format(dt);
    } else if (visibleDuration.inHours > 6) {
      tickInterval = const Duration(hours: 1);
      labelFormat = (dt) => DateFormat('h:mm a').format(dt);
    } else if (visibleDuration.inHours > 3) {
      tickInterval = const Duration(minutes: 30);
      labelFormat = (dt) => DateFormat('h:mm a').format(dt);
    } else if (visibleDuration.inMinutes > 90) {
      tickInterval = const Duration(minutes: 15);
      labelFormat = (dt) => DateFormat('h:mm a').format(dt);
    } else if (visibleDuration.inMinutes > 30) {
      tickInterval = const Duration(minutes: 5);
      labelFormat = (dt) => DateFormat('h:mm').format(dt);
    } else {
      tickInterval = const Duration(minutes: 1);
      labelFormat = (dt) => DateFormat('h:mm:ss').format(dt);
    }

    final List<MapEntry<double, DateTime>> tickPositions = [];

    // Find the first tick position that is on or after the start of the total domain.
    // Round down to the nearest interval, then add intervals until we are in view.
    if (domain.first.isBefore(domain.last)) {
      DateTime currentTick = _roundDownTo(domain.first, tickInterval);
      if (currentTick.isBefore(domain.first)) {
        currentTick = currentTick.add(tickInterval);
      }

      // Generate ticks across the entire domain to ensure they are present when scrolling.
      while (currentTick.isBefore(domain.last)) {
        tickPositions.add(MapEntry(scale(currentTick), currentTick));
        currentTick = currentTick.add(tickInterval);
      }
    }

    for (final entry in tickPositions) {
      final tickX = entry.key;
      final tickTime = entry.value;
      final label = labelFormat(tickTime);

      canvas.drawLine(
        Offset(tickX, y),
        Offset(tickX, y + height),
        paint,
      );

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
  bool shouldRepaint(covariant AxisPainter oldDelegate) => oldDelegate.theme != theme ||
        oldDelegate.scale != scale ||
        !listEquals(oldDelegate.visibleDomain, visibleDomain) ||
        oldDelegate.width != width ||
        oldDelegate.height != height;

  DateTime _roundDownTo(DateTime dt, Duration delta) {
    final ms = dt.millisecondsSinceEpoch;
    final deltaMs = delta.inMilliseconds;
    return DateTime.fromMillisecondsSinceEpoch(
      (ms ~/ deltaMs) * deltaMs,
      isUtc: dt.isUtc,
    );
  }

  int _weekNumber(DateTime date) {
    // A simple week number calculation.
    final dayOfYear = int.parse(DateFormat('D').format(date));
    final woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (woy < 1) return 52; // Fallback for early days in the year.
    if (woy > 52) return 52; // Fallback for late days in the year.
    return woy;
  }
}
