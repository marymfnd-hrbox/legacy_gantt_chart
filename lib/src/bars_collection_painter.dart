import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/legacy_gantt_row.dart';
import 'models/legacy_gantt_task.dart';
import 'models/legacy_gantt_dependency.dart';
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
  final List<LegacyGanttTaskDependency> dependencies;
  final String? hoveredRowId;
  final DateTime? hoveredDate;
  final bool hasCustomTaskBuilder;
  final bool hasCustomTaskContentBuilder;
  final bool enableDependencyCreation;
  final String? dependencyDragStartTaskId;
  final bool? dependencyDragStartIsFromStart;
  final Offset? dependencyDragCurrentPosition;
  final String? hoveredTaskForDependency;

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
    this.hoveredRowId,
    this.hoveredDate,
    this.dependencies = const [],
    this.hasCustomTaskBuilder = false,
    this.hasCustomTaskContentBuilder = false,
    this.enableDependencyCreation = false,
    this.dependencyDragStartTaskId,
    this.dependencyDragStartIsFromStart,
    this.dependencyDragCurrentPosition,
    this.hoveredTaskForDependency,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double cumulativeRowTop = 0;

    // Draw dependency backgrounds first, so they appear behind task bars.
    _drawDependencyBackgrounds(canvas, size);

    // Draw the empty space highlight for creating new tasks.
    _drawEmptySpaceHighlight(canvas, size);

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

        // Performance optimization: only draw if the bar is visible on screen.
        if (barEndX < 0 || barStartX > size.width) {
          continue;
        }

        final double barWidth = max(0, barEndX - barStartX);

        final rect = Rect.fromLTWH(
            barStartX, cumulativeRowTop, barWidth, dynamicRowHeight);
        final paint = Paint()
          ..color = task.color ?? theme.timeRangeHighlightColor;
        canvas.drawRect(rect, paint);
      }

      // 2. Draw regular event bars
      if (!hasCustomTaskBuilder) {
        for (final task in tasksInThisRow
            .where((t) => !t.isTimeRangeHighlight && !t.isOverlapIndicator)) {
          // If a cell builder is provided for this task, the widget will handle rendering it.
          if (task.cellBuilder != null) {
            continue;
          }

          // Performance optimization: Check if the task's overall time range is
          // visible at all. If not, we can skip all drawing for this task,
          // including segments and text.
          final double taskStartX = scale(task.start);
          final double taskEndX = scale(task.end);
          if (taskEndX < 0 || taskStartX > size.width) {
            continue;
          }

          // Don't draw zero-duration tasks.
          if (taskEndX <= taskStartX) {
            continue;
          }

          final isBeingDragged = task.id == draggedTaskId;

          final double barTop =
              cumulativeRowTop + (task.stackIndex * rowHeight);
          final double barHeight = rowHeight * theme.barHeightRatio;
          final double barVerticalCenterOffset = (rowHeight - barHeight) / 2;

          final bool hasSegments =
              task.segments != null && task.segments!.isNotEmpty;

          // Define the RRect for the whole task, used for dependency handles and non-segmented bars.
          final RRect barRRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(taskStartX, barTop + barVerticalCenterOffset,
                taskEndX - taskStartX, barHeight),
            theme.barCornerRadius,
          );

          if (hasSegments) {
            // --- Draw Segmented Bar ---
            for (final segment in task.segments!) {
              final double barStartX = scale(segment.start);
              final double barEndX = scale(segment.end);
              if (barEndX <= barStartX) {
                continue;
              }

              // A segment-level check is still useful as the overall task might
              // be visible, but this specific segment may not be.
              if (barEndX < 0 || barStartX > size.width) {
                continue;
              }

              final RRect segmentRRect = RRect.fromRectAndRadius(
                Rect.fromLTWH(barStartX, barTop + barVerticalCenterOffset,
                    barEndX - barStartX, barHeight),
                theme.barCornerRadius,
              );

              final barPaint = Paint()
                ..color = (segment.color ?? task.color ?? theme.barColorPrimary)
                    .withValues(alpha: isBeingDragged ? 0.3 : 1.0);
              canvas.drawRRect(segmentRRect, barPaint);
            }
          } else {
            // --- Draw Single Continuous Bar (existing logic) ---
            // We can reuse the start/end coordinates calculated earlier.
            // Draw the bar
            final barPaint = Paint()
              ..color = (task.color ?? theme.barColorPrimary)
                  .withValues(alpha: isBeingDragged ? 0.3 : 1.0);
            canvas.drawRRect(barRRect, barPaint);

            // Draw summary pattern if needed
            if (task.isSummary) {
              _drawSummaryPattern(canvas, barRRect);
            }
          }

          // --- Draw dependency handles ---
          if (enableDependencyCreation) {
            _drawDependencyHandles(canvas, barRRect, task, isBeingDragged);
          }

          // --- Draw Text for the entire task ---
          if (task.name != null &&
              task.name!.isNotEmpty &&
              !hasCustomTaskBuilder &&
              !hasCustomTaskContentBuilder) {
            // We can reuse the start/end coordinates calculated earlier.
            final double overallWidth = max(0, taskEndX - taskStartX);

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
            textPainter.layout(
                minWidth: 0,
                maxWidth: max(0, overallWidth - 8)); // 4px padding on each side

            final textOffset = Offset(
              taskStartX + 4,
              barTop + (rowHeight - textPainter.height) / 2,
            );

            // Clip text to the bar's overall rectangle to prevent overflow.
            canvas.save();
            canvas.clipRect(
                Rect.fromLTWH(taskStartX, barTop, overallWidth, rowHeight));
            textPainter.paint(canvas, textOffset);
            canvas.restore();
          }
        }
      }

      // 3. Draw overlap indicators on top (foreground)
      for (final task in tasksInThisRow.where((t) => t.isOverlapIndicator)) {
        final double barStartX = scale(task.start);
        final double barEndX = scale(task.end);

        // Performance optimization: only draw if the bar is visible on screen.
        if (barEndX < 0 || barStartX > size.width) {
          continue;
        }

        final double barWidth = max(0, barEndX - barStartX);

        final double barHeight =
            rowHeight * theme.barHeightRatio; // Same height as the event bar
        final double barTop = cumulativeRowTop +
            (task.stackIndex * rowHeight) +
            (rowHeight - barHeight) / 2;

        final RRect barRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(barStartX, barTop, barWidth, barHeight),
          theme.barCornerRadius,
        );

        _drawOverlapPattern(canvas, barRRect);
      }

      // Draw row border line
      if (theme.showRowBorders) {
        final y = cumulativeRowTop +
            dynamicRowHeight -
            0.5; // Center on the pixel line
        final borderPaint = Paint()
          ..color = theme.rowBorderColor ?? theme.gridColor
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), borderPaint);
      }

      cumulativeRowTop += dynamicRowHeight;
    }

    // Draw dependency lines on top of tasks.
    _drawDependencyLines(canvas, size);

    // Draw the in-progress dependency line.
    _drawInprogressDependencyLine(canvas, size);

    // 4. Draw ghost bar on top of everything if a task is being dragged
    if (draggedTaskId != null &&
        ghostTaskStart != null &&
        ghostTaskEnd != null) {
      final originalTask = data.firstWhere((t) => t.id == draggedTaskId,
          orElse: () => LegacyGanttTask(
              id: '', rowId: '', start: DateTime.now(), end: DateTime.now()));
      // Should not happen, but a good safeguard.
      if (originalTask.id.isEmpty) return;

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
        final double barTop =
            ghostRowTop + (originalTask.stackIndex * rowHeight);
        final double barHeight = rowHeight * theme.barHeightRatio;
        final double barVerticalCenterOffset = (rowHeight - barHeight) / 2;

        final double barStartX = scale(ghostTaskStart!);
        final double barEndX = scale(ghostTaskEnd!);
        final double barWidth = max(0, barEndX - barStartX);

        final RRect barRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
              barStartX, barTop + barVerticalCenterOffset, barWidth, barHeight),
          theme.barCornerRadius,
        );

        // Draw the ghost bar
        final barPaint = Paint()
          ..color = (originalTask.color ?? theme.ghostBarColor)
              .withValues(alpha: 0.7);
        canvas.drawRRect(barRRect, barPaint);
        // Not drawing text on ghost bar for simplicity
      }
    }
  }

  // Reusable helper to draw angled line patterns within a rounded rectangle.
  void _drawAngledPattern(
      Canvas canvas, RRect rrect, Color color, double strokeWidth) {
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
    // we first "erase" the area by drawing a solid block of the chart's background color. This,
    // ensures that the semi-transparent conflict color is blended with a consistent
    // background, not the color of the task bar underneath.
    canvas.drawRRect(rrect, Paint()..color = theme.backgroundColor);

    // Next, draw the semi-transparent red background for the conflict area.
    final backgroundPaint = Paint()
      ..color = theme.conflictBarColor.withValues(alpha: 0.4);
    canvas.drawRRect(rrect, backgroundPaint);

    // Then, draw the angled lines on top of that new background.
    // A thin stroke width is crucial to keep the pattern precise, as noted in documentation.
    _drawAngledPattern(canvas, rrect, theme.conflictBarColor, 1.0);
  }

  void _drawSummaryPattern(Canvas canvas, RRect rrect) {
    // A thick stroke can make the pattern look muddy. 1.5 is a good balance.
    _drawAngledPattern(canvas, rrect, theme.summaryBarColor, 1.5);
  }

  void _drawDependencyHandles(
      Canvas canvas, RRect rrect, LegacyGanttTask task, bool isBeingDragged) {
    if (isBeingDragged || task.isSummary) return;

    final handlePaint = Paint()
      ..color = theme.dependencyLineColor.withValues(alpha: 0.8);
    const handleRadius = 4.0;

    // Left handle
    final leftCenter = Offset(rrect.left, rrect.center.dy);
    canvas.drawCircle(leftCenter, handleRadius, handlePaint);

    // Right handle
    final rightCenter = Offset(rrect.right, rrect.center.dy);
    canvas.drawCircle(rightCenter, handleRadius, handlePaint);

    // Highlight task if it's being hovered over as a potential dependency target
    if (task.id == hoveredTaskForDependency) {
      final borderPaint = Paint()
        ..color = theme.dependencyLineColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(rrect.inflate(2.0), borderPaint);
    }
  }

  void _drawDependencyBackgrounds(Canvas canvas, Size size) {
    if (dependencies.isEmpty) return;
    for (final dependency in dependencies) {
      if (dependency.type == DependencyType.contained) {
        _drawContainedDependency(canvas, dependency);
      }
    }
  }

  void _drawInprogressDependencyLine(Canvas canvas, Size size) {
    if (dependencyDragStartTaskId == null ||
        dependencyDragCurrentPosition == null) {
      return;
    }

    final startTaskRect = _findTaskRect(dependencyDragStartTaskId!);
    if (startTaskRect == null) return;

    final startX = (dependencyDragStartIsFromStart ?? false)
        ? startTaskRect.left
        : startTaskRect.right;
    final startY = startTaskRect.center.dy;

    final endX = dependencyDragCurrentPosition!.dx;
    final endY = dependencyDragCurrentPosition!.dy;

    final paint = Paint()
      ..color = theme.dependencyLineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

    // Draw arrowhead at the end
    final arrowPath = Path();
    const arrowSize = 5.0;
    arrowPath.moveTo(endX - arrowSize, endY - arrowSize / 2);
    arrowPath.lineTo(endX, endY);
    arrowPath.lineTo(endX - arrowSize, endY + arrowSize / 2);
    canvas.drawPath(arrowPath, paint);
  }

  void _drawDependencyLines(Canvas canvas, Size size) {
    if (dependencies.isEmpty) return;
    for (final dependency in dependencies) {
      switch (dependency.type) {
        case DependencyType.finishToStart:
          _drawFinishToStartDependency(canvas, dependency);
          break;
        case DependencyType.startToStart:
          _drawStartToStartDependency(canvas, dependency);
          break;
        case DependencyType.finishToFinish:
          _drawFinishToFinishDependency(canvas, dependency);
          break;
        case DependencyType.startToFinish:
          _drawStartToFinishDependency(canvas, dependency);
          break;
        case DependencyType.contained:
          // Contained is a background, not a line.
          break;
      }
    }
  }

  void _drawFinishToStartDependency(
      Canvas canvas, LegacyGanttTaskDependency dependency) {
    final predecessorRect = _findTaskRect(dependency.predecessorTaskId);
    final successorRect = _findTaskRect(dependency.successorTaskId);

    if (predecessorRect == null || successorRect == null) return;

    final startX = predecessorRect.right;
    final startY = predecessorRect.center.dy;
    final endX = successorRect.left;
    final endY = successorRect.center.dy;

    final paint = Paint()
      ..color = theme.dependencyLineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(startX, startY);

    // Add a small horizontal segment before turning
    final controlXOffset =
        (endX - startX).abs() > 20 ? 10.0 : (endX - startX).abs() / 2;
    final controlX1 = startX + controlXOffset;
    final controlX2 = endX - controlXOffset;

    // Simple S-curve for vertical connections
    path.cubicTo(controlX1, startY, controlX2, endY, endX, endY);

    canvas.drawPath(path, paint);

    // Draw arrowhead
    final arrowPath = Path();
    const arrowSize = 5.0;
    arrowPath.moveTo(endX - arrowSize, endY - arrowSize / 2);
    arrowPath.lineTo(endX, endY);
    arrowPath.lineTo(endX - arrowSize, endY + arrowSize / 2);
    canvas.drawPath(arrowPath, paint);
  }

  void _drawStartToStartDependency(
      Canvas canvas, LegacyGanttTaskDependency dependency) {
    final predecessorRect = _findTaskRect(dependency.predecessorTaskId);
    final successorRect = _findTaskRect(dependency.successorTaskId);

    if (predecessorRect == null || successorRect == null) return;

    final startX = predecessorRect.left;
    final startY = predecessorRect.center.dy;
    final endX = successorRect.left;
    final endY = successorRect.center.dy;

    final paint = Paint()
      ..color = theme.dependencyLineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(startX, startY);

    final controlXOffset =
        (endX - startX).abs() > 20 ? 10.0 : (endX - startX).abs() / 2;
    final controlX1 = startX - controlXOffset;
    final controlX2 = endX - controlXOffset;

    path.cubicTo(controlX1, startY, controlX2, endY, endX, endY);
    canvas.drawPath(path, paint);

    // Draw arrowhead (points right, towards successor task body)
    final arrowPath = Path();
    const arrowSize = 5.0;
    arrowPath.moveTo(endX - arrowSize, endY - arrowSize / 2);
    arrowPath.lineTo(endX, endY);
    arrowPath.lineTo(endX - arrowSize, endY + arrowSize / 2);
    canvas.drawPath(arrowPath, paint);
  }

  void _drawFinishToFinishDependency(
      Canvas canvas, LegacyGanttTaskDependency dependency) {
    final predecessorRect = _findTaskRect(dependency.predecessorTaskId);
    final successorRect = _findTaskRect(dependency.successorTaskId);

    if (predecessorRect == null || successorRect == null) return;

    final startX = predecessorRect.right;
    final startY = predecessorRect.center.dy;
    final endX = successorRect.right;
    final endY = successorRect.center.dy;

    final paint = Paint()
      ..color = theme.dependencyLineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(startX, startY);

    final controlXOffset =
        (endX - startX).abs() > 20 ? 10.0 : (endX - startX).abs() / 2;
    final controlX1 = startX + controlXOffset;
    final controlX2 = endX + controlXOffset;

    path.cubicTo(controlX1, startY, controlX2, endY, endX, endY);
    canvas.drawPath(path, paint);

    // Draw arrowhead (points left, towards successor task body)
    final arrowPath = Path();
    const arrowSize = 5.0;
    arrowPath.moveTo(endX + arrowSize, endY - arrowSize / 2);
    arrowPath.lineTo(endX, endY);
    arrowPath.lineTo(endX + arrowSize, endY + arrowSize / 2);
    canvas.drawPath(arrowPath, paint);
  }

  void _drawStartToFinishDependency(
      Canvas canvas, LegacyGanttTaskDependency dependency) {
    final predecessorRect = _findTaskRect(dependency.predecessorTaskId);
    final successorRect = _findTaskRect(dependency.successorTaskId);

    if (predecessorRect == null || successorRect == null) return;

    final startX = predecessorRect.left;
    final startY = predecessorRect.center.dy;
    final endX = successorRect.right;
    final endY = successorRect.center.dy;

    final paint = Paint()
      ..color = theme.dependencyLineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // This can be a simple line as it's less common and less likely to need complex routing.
    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

    // Draw arrowhead (points left, towards successor task body)
    final arrowPath = Path();
    const arrowSize = 5.0;
    arrowPath.moveTo(endX + arrowSize, endY - arrowSize / 2);
    arrowPath.lineTo(endX, endY);
    arrowPath.lineTo(endX + arrowSize, endY + arrowSize / 2);
    canvas.drawPath(arrowPath, paint);
  }

  void _drawContainedDependency(
      Canvas canvas, LegacyGanttTaskDependency dependency) {
    // This logic finds the full vertical span of a summary task's group.
    // It assumes child rows immediately follow their parent in `visibleRows`
    // and a new group is denoted by the next summary task.
    final predecessorTask = _findTaskById(dependency.predecessorTaskId);
    if (predecessorTask == null || !predecessorTask.isSummary) {
      return;
    }

    double? groupStartY;
    double? groupEndY;

    double currentY = 0;
    bool inGroup = false;

    for (final rowData in visibleRows) {
      final int stackDepth = rowMaxStackDepth[rowData.id] ?? 1;
      final double rowHeightWithStack = rowHeight * stackDepth;

      if (inGroup) {
        // Check if the current row starts a new summary group.
        final bool isNewGroup =
            data.any((task) => task.rowId == rowData.id && task.isSummary);
        if (isNewGroup) {
          inGroup = false; // The current group has ended.
        } else {
          // This is a child row, so extend the group's bottom boundary.
          groupEndY = currentY + rowHeightWithStack;
        }
      }

      if (rowData.id == predecessorTask.rowId) {
        inGroup = true;
        groupStartY = currentY;
        groupEndY = currentY + rowHeightWithStack;
      }

      currentY += rowHeightWithStack;
    }

    if (groupStartY == null || groupEndY == null) return;

    final predecessorStartX = scale(predecessorTask.start);
    final predecessorEndX = scale(predecessorTask.end);

    final backgroundRect = Rect.fromLTRB(
        predecessorStartX, groupStartY, predecessorEndX, groupEndY);
    final paint = Paint()..color = theme.containedDependencyBackgroundColor;
    canvas.drawRect(backgroundRect, paint);
  }

  void _drawEmptySpaceHighlight(Canvas canvas, Size size) {
    if (hoveredRowId == null || hoveredDate == null) {
      return;
    }

    // Find the Y position of the hovered row.
    double? rowTop;
    double cumulativeRowTop = 0;
    for (final rowData in visibleRows) {
      if (rowData.id == hoveredRowId) {
        rowTop = cumulativeRowTop;
        break;
      }
      final int stackDepth = rowMaxStackDepth[rowData.id] ?? 1;
      cumulativeRowTop += rowHeight * stackDepth;
    }

    if (rowTop == null) return;

    // Calculate the start and end of the day.
    final dayStart =
        DateTime(hoveredDate!.year, hoveredDate!.month, hoveredDate!.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final startX = scale(dayStart);
    final endX = scale(dayEnd);

    final highlightRect =
        Rect.fromLTWH(startX, rowTop, endX - startX, rowHeight);

    // Draw the highlight box.
    final highlightPaint = Paint()..color = theme.emptySpaceHighlightColor;
    canvas.drawRect(highlightRect, highlightPaint);

    // Draw the plus icon in the center.
    final textPainter = TextPainter(
      text: TextSpan(
        text: '+',
        style: TextStyle(color: theme.emptySpaceAddIconColor, fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final iconOffset = Offset(highlightRect.center.dx - textPainter.width / 2,
        highlightRect.center.dy - textPainter.height / 2);
    textPainter.paint(canvas, iconOffset);
  }

  LegacyGanttTask? _findTaskById(String taskId) {
    try {
      return data.firstWhere((task) => task.id == taskId);
    } catch (e) {
      return null;
    }
  }

  Rect? _findTaskRect(String taskId) {
    final task = _findTaskById(taskId);
    if (task == null) return null;

    double cumulativeRowTop = 0;
    for (var rowData in visibleRows) {
      if (rowData.id == task.rowId) {
        final double barTop = cumulativeRowTop + (task.stackIndex * rowHeight);
        final double barHeight = rowHeight * theme.barHeightRatio;
        final double barVerticalCenterOffset = (rowHeight - barHeight) / 2;
        final double barStartX = scale(task.start);
        final double barEndX = scale(task.end);
        return Rect.fromLTWH(barStartX, barTop + barVerticalCenterOffset,
            barEndX - barStartX, barHeight);
      }
      final int stackDepth = rowMaxStackDepth[rowData.id] ?? 1;
      cumulativeRowTop += rowHeight * stackDepth;
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant BarsCollectionPainter oldDelegate) =>
      !listEquals(oldDelegate.data, data) ||
      !listEquals(oldDelegate.visibleRows, visibleRows) ||
      !mapEquals(oldDelegate.rowMaxStackDepth, rowMaxStackDepth) ||
      !listEquals(oldDelegate.dependencies, dependencies) ||
      oldDelegate.hoveredRowId != hoveredRowId ||
      oldDelegate.hoveredDate != hoveredDate ||
      !listEquals(oldDelegate.domain, domain) ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.draggedTaskId != draggedTaskId ||
      oldDelegate.ghostTaskStart != ghostTaskStart ||
      oldDelegate.ghostTaskEnd != ghostTaskEnd ||
      oldDelegate.theme != theme ||
      oldDelegate.enableDependencyCreation != enableDependencyCreation ||
      oldDelegate.dependencyDragStartTaskId != dependencyDragStartTaskId ||
      oldDelegate.dependencyDragStartIsFromStart !=
          dependencyDragStartIsFromStart ||
      oldDelegate.dependencyDragCurrentPosition !=
          dependencyDragCurrentPosition ||
      oldDelegate.hoveredTaskForDependency != hoveredTaskForDependency ||
      oldDelegate.hasCustomTaskBuilder != hasCustomTaskBuilder ||
      oldDelegate.hasCustomTaskContentBuilder != hasCustomTaskContentBuilder;
}
