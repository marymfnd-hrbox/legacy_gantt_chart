import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/legacy_gantt_row.dart';
import 'models/legacy_gantt_task.dart';
import 'models/legacy_gantt_theme.dart';

// Helper painter to draw all bars as a single CustomPaint operation
class BarsCollectionPainter extends CustomPainter {
  final List<LegacyGanttTask> data;
  final List<LegacyGanttRow> visibleRows;
  final List<DateTime> domain;
  final Map<String, int> rowMaxStackDepth;
  final double Function(DateTime) scale;
  final double rowHeight;
  final String? draggedTaskId;
  final DateTime? ghostTaskStart;
  final DateTime? ghostTaskEnd;
  final LegacyGanttTheme theme;
  final bool hasCustomTaskBuilder;
  final bool hasCustomTaskContentBuilder;

  BarsCollectionPainter({
    required this.data,
    required this.domain,
    required this.visibleRows,
    required this.rowMaxStackDepth,
    required this.scale,
    required this.rowHeight,
    this.draggedTaskId,
    this.ghostTaskStart,
    this.ghostTaskEnd,
    required this.theme,
    this.hasCustomTaskBuilder = false,
    this.hasCustomTaskContentBuilder = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double cumulativeRowTop = 0;

    // Create a map for quick lookup of tasks by rowId for visible rows.
    // This is more efficient than filtering the entire dataset multiple times.
    final Map<String, List<LegacyGanttTask>> tasksByRow = {};
    final visibleRowIds = visibleRows.map((r) => r.id).toSet();
    for (final task in data) {
      if (visibleRowIds.contains(task.rowId)) {
        tasksByRow.putIfAbsent(task.rowId, () => []).add(task);
      }
    }

    for (var rowData in visibleRows) {
      final int stackDepth = rowMaxStackDepth[rowData.id] ?? 1;
      final double dynamicRowHeight = rowHeight * stackDepth;

      final tasksInThisRow = tasksByRow[rowData.id] ?? [];

      // 1. Draw highlight bars first (background)
      for (final task in tasksInThisRow.where((t) => t.isTimeRangeHighlight)) {
        final double barStartX = scale(task.start);
        final double barEndX = scale(task.end);
        final double barWidth = max(0, barEndX - barStartX);

        final rect = Rect.fromLTWH(barStartX, cumulativeRowTop, barWidth, dynamicRowHeight);
        final paint = Paint()..color = task.color ?? Colors.grey.withValues(alpha:0.2);
        canvas.drawRect(rect, paint);
      }

      // 2. Draw regular event bars
      if (!hasCustomTaskBuilder) {
        for (final task in tasksInThisRow.where((t) => !t.isTimeRangeHighlight && !t.isOverlapIndicator)) {
          // If a cell builder is provided for this task, the widget will handle rendering it.
          if (task.cellBuilder != null) continue;

          final isBeingDragged = task.id == draggedTaskId;

          final double barTop = cumulativeRowTop + (task.stackIndex * rowHeight);
          final double barHeight = rowHeight * theme.barHeightRatio;
          final double barVerticalCenterOffset = (rowHeight - barHeight) / 2;

          final bool hasSegments = task.segments != null && task.segments!.isNotEmpty;

          if (hasSegments) {
            // --- Draw Segmented Bar ---
            for (final segment in task.segments!) {
              final double barStartX = scale(segment.start);
              final double barEndX = scale(segment.end);
              if (barEndX <= barStartX) continue;

              final RRect segmentRRect = RRect.fromRectAndRadius(
                Rect.fromLTWH(barStartX, barTop + barVerticalCenterOffset, barEndX - barStartX, barHeight),
                theme.barCornerRadius,
              );

              final barPaint = Paint()..color = (segment.color ?? task.color ?? theme.barColorPrimary).withValues(alpha:isBeingDragged ? 0.3 : 1.0);
              canvas.drawRRect(segmentRRect, barPaint);
            }
          } else {
            // --- Draw Single Continuous Bar (existing logic) ---
            final double barStartX = scale(task.start);
            final double barEndX = scale(task.end);
            if (barEndX <= barStartX) continue;

            final RRect barRRect = RRect.fromRectAndRadius(
              Rect.fromLTWH(barStartX, barTop + barVerticalCenterOffset, barEndX - barStartX, barHeight),
              theme.barCornerRadius,
            );

            // Draw the bar
            final barPaint = Paint()..color = (task.color ?? theme.barColorPrimary).withValues(alpha:isBeingDragged ? 0.3 : 1.0);
            canvas.drawRRect(barRRect, barPaint);

            // Draw summary pattern if needed
            if (task.isSummary) {
              _drawSummaryPattern(canvas, barRRect);
            }
          }

          // --- Draw Text for the entire task ---
          if (task.name != null &&
              task.name!.isNotEmpty &&
              !hasCustomTaskBuilder &&
              !hasCustomTaskContentBuilder) {
            final double overallStartX = scale(task.start);
            final double overallEndX = scale(task.end);
            final double overallWidth = max(0, overallEndX - overallStartX);

            final textSpan = TextSpan(
              text: task.name!,
              style: theme.taskTextStyle,
            );
            final textPainter = TextPainter(
              text: textSpan,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              ellipsis: '...',
            );
            textPainter.layout(minWidth: 0, maxWidth: max(0, overallWidth - 8)); // 4px padding on each side

            final textOffset = Offset(
              overallStartX + 4,
              barTop + (rowHeight - textPainter.height) / 2,
            );

            // Clip text to the bar's overall rectangle to prevent overflow.
            canvas.save();
            canvas.clipRect(Rect.fromLTWH(overallStartX, barTop, overallWidth, rowHeight));
            textPainter.paint(canvas, textOffset);
            canvas.restore();
          }
        }
      }

      // 3. Draw overlap indicators on top (foreground)
      for (final task in tasksInThisRow.where((t) => t.isOverlapIndicator)) {
        final double barStartX = scale(task.start);
        final double barEndX = scale(task.end);
        final double barWidth = max(0, barEndX - barStartX);

        final double barHeight = rowHeight * theme.barHeightRatio; // Same height as the event bar
        final double barTop = cumulativeRowTop + (task.stackIndex * rowHeight) + (rowHeight - barHeight) / 2;

        final RRect barRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(barStartX, barTop, barWidth, barHeight),
          theme.barCornerRadius,
        );

        _drawOverlapPattern(canvas, barRRect);
      }

      // Draw row border line
      if (theme.showRowBorders) {
        final y = cumulativeRowTop + dynamicRowHeight - 0.5; // Center on the pixel line
        final borderPaint = Paint()
          ..color = theme.rowBorderColor ?? theme.gridColor
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), borderPaint);
      }

      cumulativeRowTop += dynamicRowHeight;
    }

    // 4. Draw ghost bar on top of everything if a task is being dragged
    if (draggedTaskId != null && ghostTaskStart != null && ghostTaskEnd != null) {
      final originalTask = data.firstWhere((t) => t.id == draggedTaskId, orElse: () => LegacyGanttTask(id: '', rowId: '', start: DateTime.now(), end: DateTime.now()));
      if (originalTask.id.isEmpty) return; // Should not happen

      // Find the y-offset for this task's row again.
      double ghostRowTop = 0;
      bool foundRow = false;
      for (var rowData in visibleRows) {
        if (rowData.id == originalTask.rowId) {
          foundRow = true;
          break;
        }
        final int stackDepth = rowMaxStackDepth[rowData.id] ?? 1;
        ghostRowTop += rowHeight * stackDepth;
      }

      if (foundRow) {
        final double barTop = ghostRowTop + (originalTask.stackIndex * rowHeight);
        final double barHeight = rowHeight * theme.barHeightRatio;
        final double barVerticalCenterOffset = (rowHeight - barHeight) / 2;

        final double barStartX = scale(ghostTaskStart!);
        final double barEndX = scale(ghostTaskEnd!);
        final double barWidth = max(0, barEndX - barStartX);

        final RRect barRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(barStartX, barTop + barVerticalCenterOffset, barWidth, barHeight),
          theme.barCornerRadius,
        );

        // Draw the ghost bar
        final barPaint = Paint()..color = (originalTask.color ?? theme.barColorPrimary).withValues(alpha:0.7);
        canvas.drawRRect(barRRect, barPaint);
        // Not drawing text on ghost bar for simplicity
      }
    }
  }

  // Reusable helper to draw angled line patterns within a rounded rectangle.
  void _drawAngledPattern(Canvas canvas, RRect rrect, Color color, double strokeWidth) {
    final patternPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRRect(rrect);

    const double lineSpacing = 8.0;
    // The loop needs to cover the full diagonal length to ensure the pattern is drawn across the entire clipped area.
    for (double i = -rrect.height; i < rrect.width; i += lineSpacing) {
      canvas.drawLine(
        Offset(rrect.left + i, rrect.top),
        Offset(rrect.left + i + rrect.height, rrect.bottom),
        patternPaint,
      );
    }
    canvas.restore();
  }

  void _drawOverlapPattern(Canvas canvas, RRect rrect) {
    // To ensure the conflict pattern is clear and not blended with underlying bars,
    // we first "erase" the area by drawing a solid block of the chart's background color. This
    // ensures that the semi-transparent conflict color is blended with a consistent
    // background, not the color of the task bar underneath.
    canvas.drawRRect(rrect, Paint()..color = theme.backgroundColor);

    // Next, draw the semi-transparent red background for the conflict area.
    final backgroundPaint = Paint()..color = theme.conflictBarColor.withValues(alpha:0.4);
    canvas.drawRRect(rrect, backgroundPaint);

    // Then, draw the angled lines on top of that new background.
    // A thin stroke width is crucial to keep the pattern precise, as noted in documentation.
    _drawAngledPattern(canvas, rrect, theme.conflictBarColor, 1.0);
  }

  void _drawSummaryPattern(Canvas canvas, RRect rrect) {
    // A thick stroke can make the pattern look muddy. 1.5 is a good balance.
    _drawAngledPattern(canvas, rrect, theme.summaryBarColor, 1.5);
  }

  @override
  bool shouldRepaint(covariant BarsCollectionPainter oldDelegate) {
    // Use listEquals and mapEquals for proper comparison of collections.
    // This prevents unnecessary repaints when the data hasn't actually changed.
    return !listEquals(oldDelegate.data, data) ||
        !listEquals(oldDelegate.visibleRows, visibleRows) ||
        !mapEquals(oldDelegate.rowMaxStackDepth, rowMaxStackDepth) ||
        !listEquals(oldDelegate.domain, domain) ||
        oldDelegate.rowHeight != rowHeight ||
        oldDelegate.draggedTaskId != draggedTaskId ||
        oldDelegate.ghostTaskStart != ghostTaskStart ||
        oldDelegate.ghostTaskEnd != ghostTaskEnd ||
        oldDelegate.theme != theme ||
        oldDelegate.hasCustomTaskBuilder != hasCustomTaskBuilder ||
        oldDelegate.hasCustomTaskContentBuilder != hasCustomTaskContentBuilder;
  }
}