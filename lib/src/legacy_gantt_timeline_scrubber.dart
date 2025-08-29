import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'models/legacy_gantt_task.dart';

enum _DragType { none, leftHandle, rightHandle, window }

/// A widget that provides a timeline overview and allows users to navigate and
/// zoom the main Gantt chart's visible window.
///
/// It displays a "heatmap" of tasks over the total duration of the project
/// and overlays a draggable and resizable window that represents the currently
/// visible portion of the main chart.
///
/// This widget is typically used in conjunction with a `LegacyGanttController`
/// to link its state with a [LegacyGanttChartWidget].
class LegacyGanttTimelineScrubber extends StatefulWidget {
  /// The absolute start date of the entire dataset. This defines the left edge
  /// of the scrubber's timeline.
  final DateTime totalStartDate;

  /// The absolute end date of the entire dataset. This defines the right edge
  /// of the scrubber's timeline.
  final DateTime totalEndDate;

  /// The start date of the currently visible window. This is used to draw the
  /// draggable selection area on the scrubber.
  final DateTime visibleStartDate;

  /// The end date of the currently visible window.
  final DateTime visibleEndDate;

  /// A callback invoked when the user drags or resizes the selection window.
  /// It provides the new start and end dates for the visible window.
  final Function(DateTime, DateTime) onWindowChanged;

  /// A list of tasks to be drawn as a "heatmap" on the scrubber's background,
  /// giving a visual overview of task density over time.
  final List<LegacyGanttTask> tasks;

  /// Optional padding to add before the [totalStartDate], extending the timeline
  /// to provide extra space for navigation at the beginning.
  final Duration startPadding;

  /// Optional padding to add after the [totalEndDate], extending the timeline
  /// to provide extra space for navigation at the end.
  final Duration endPadding;

  const LegacyGanttTimelineScrubber({
    super.key,
    required this.totalStartDate,
    required this.totalEndDate,
    required this.visibleStartDate,
    required this.visibleEndDate,
    required this.onWindowChanged,
    required this.tasks,
    this.startPadding = Duration.zero,
    this.endPadding = Duration.zero,
  });

  @override
  State<LegacyGanttTimelineScrubber> createState() => _LegacyGanttTimelineScrubberState();
}

class _LegacyGanttTimelineScrubberState extends State<LegacyGanttTimelineScrubber> {
  _DragType _dragType = _DragType.none;
  double _dragStartDx = 0.0;
  late DateTime _dragStartVisibleStart;
  late DateTime _dragStartVisibleEnd;
  MouseCursor _cursor = SystemMouseCursors.basic;

  DateTime get _effectiveTotalStart => widget.totalStartDate.subtract(widget.startPadding);
  DateTime get _effectiveTotalEnd => widget.totalEndDate.add(widget.endPadding);

  _DragType _getDragTypeAtPosition(Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return _DragType.none;

    final totalDurationMs = _effectiveTotalEnd.difference(_effectiveTotalStart).inMilliseconds;
    if (totalDurationMs <= 0) return _DragType.none;

    final double startX =
        (widget.visibleStartDate.difference(_effectiveTotalStart).inMilliseconds / totalDurationMs) * box.size.width;
    final double endX =
        (widget.visibleEndDate.difference(_effectiveTotalStart).inMilliseconds / totalDurationMs) * box.size.width;

    // Use a generous hit area for the cursor change and drag initiation.
    // The if/else if order gives priority to the handles.
    const handleHitWidth = 20.0;
    if ((localPosition.dx - startX).abs() < handleHitWidth) {
      return _DragType.leftHandle;
    } else if ((localPosition.dx - endX).abs() < handleHitWidth) {
      return _DragType.rightHandle;
    } else if (localPosition.dx > startX && localPosition.dx < endX) {
      return _DragType.window;
    } else {
      return _DragType.none;
    }
  }

  void _onHover(PointerEvent event) {
    final dragType = _getDragTypeAtPosition(event.localPosition);
    MouseCursor newCursor;
    switch (dragType) {
      case _DragType.leftHandle:
      case _DragType.rightHandle:
        newCursor = SystemMouseCursors.resizeLeftRight;
        break;
      case _DragType.window:
        newCursor = SystemMouseCursors.move;
        break;
      case _DragType.none:
        newCursor = SystemMouseCursors.basic;
        break;
    }

    if (newCursor != _cursor) {
      setState(() {
        _cursor = newCursor;
      });
    }
  }

  void _onExit(PointerEvent event) {
    if (_cursor != SystemMouseCursors.basic) {
      setState(() {
        _cursor = SystemMouseCursors.basic;
      });
    }
  }

  void _onPanStart(DragStartDetails details) {
    _dragType = _getDragTypeAtPosition(details.localPosition);

    if (_dragType != _DragType.none) {
      _dragStartDx = details.localPosition.dx;
      _dragStartVisibleStart = widget.visibleStartDate;
      _dragStartVisibleEnd = widget.visibleEndDate;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragType == _DragType.none) return;

    final box = context.findRenderObject() as RenderBox;
    final totalDuration = _effectiveTotalEnd.difference(_effectiveTotalStart);
    if (totalDuration.inMilliseconds <= 0) return;

    final dx = details.localPosition.dx - _dragStartDx;
    final dDuration = Duration(milliseconds: (dx / box.size.width * totalDuration.inMilliseconds).round());

    DateTime newVisibleStart = _dragStartVisibleStart;
    DateTime newVisibleEnd = _dragStartVisibleEnd;

    switch (_dragType) {
      case _DragType.leftHandle:
        newVisibleStart = _dragStartVisibleStart.add(dDuration);
        break;
      case _DragType.rightHandle:
        newVisibleEnd = _dragStartVisibleEnd.add(dDuration);
        break;
      case _DragType.window:
        newVisibleStart = _dragStartVisibleStart.add(dDuration);
        newVisibleEnd = _dragStartVisibleEnd.add(dDuration);
        break;
      case _DragType.none:
        return;
    }

    // Clamp values to stay within bounds and maintain minimum duration
    const minWindowDuration = Duration(hours: 1);
    if (newVisibleEnd.difference(newVisibleStart) < minWindowDuration) {
      if (_dragType == _DragType.leftHandle) {
        newVisibleStart = newVisibleEnd.subtract(minWindowDuration);
      } else {
        newVisibleEnd = newVisibleStart.add(minWindowDuration);
      }
    }

    if (newVisibleStart.isBefore(_effectiveTotalStart)) {
      final correction = _effectiveTotalStart.difference(newVisibleStart);
      newVisibleStart = _effectiveTotalStart;
      if (_dragType == _DragType.window) {
        newVisibleEnd = newVisibleEnd.add(correction);
      }
    }

    if (newVisibleEnd.isAfter(_effectiveTotalEnd)) {
      final correction = _effectiveTotalEnd.difference(newVisibleEnd);
      newVisibleEnd = _effectiveTotalEnd;
      if (_dragType == _DragType.window) {
        newVisibleStart = newVisibleStart.add(correction);
      }
    }

    // Final clamp after adjustments
    newVisibleStart = newVisibleStart.isBefore(_effectiveTotalStart) ? _effectiveTotalStart : newVisibleStart;
    newVisibleEnd = newVisibleEnd.isAfter(_effectiveTotalEnd) ? _effectiveTotalEnd : newVisibleEnd;
    if (newVisibleEnd.isBefore(newVisibleStart)) {
      newVisibleEnd = newVisibleStart.add(minWindowDuration);
    }
    widget.onWindowChanged(newVisibleStart, newVisibleEnd);
  }

  void _onPanEnd(DragEndDetails details) {
    _dragType = _DragType.none;
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: _cursor,
        onHover: _onHover,
        onExit: _onExit,
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            painter: _ScrubberPainter(
              totalStartDate: _effectiveTotalStart,
              totalEndDate: _effectiveTotalEnd,
              visibleStartDate: widget.visibleStartDate,
              visibleEndDate: widget.visibleEndDate,
              tasks: widget.tasks,
              theme: Theme.of(context),
            ),
            size: const Size.fromHeight(40),
          ),
        ),
      );
}

/// A private [CustomPainter] that handles the visual rendering of the
/// [LegacyGanttTimelineScrubber].
///
/// It is responsible for drawing two main parts:
/// 1. A background "heatmap" of all tasks to give a sense of density.
/// 2. A foreground, interactive selection window that represents the visible
///    date range, complete with drag handles.
class _ScrubberPainter extends CustomPainter {
  /// The start of the full timeline, including any padding.
  final DateTime totalStartDate;

  /// The end of the full timeline, including any padding.
  final DateTime totalEndDate;

  /// The start of the highlighted selection window.
  final DateTime visibleStartDate;

  /// The end of the highlighted selection window.
  final DateTime visibleEndDate;

  /// The tasks to render as a heatmap in the background.
  final List<LegacyGanttTask> tasks;

  /// The application's [ThemeData] used for styling the scrubber.
  final ThemeData theme;

  _ScrubberPainter({
    required this.totalStartDate,
    required this.totalEndDate,
    required this.visibleStartDate,
    required this.visibleEndDate,
    required this.tasks,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalDurationMs = totalEndDate.difference(totalStartDate).inMilliseconds;
    if (totalDurationMs <= 0) return;

    // --- Helper function to convert date to x-coordinate ---
    double dateToX(DateTime date) {
      final dateDurationMs = date.difference(totalStartDate).inMilliseconds;
      return (dateDurationMs / totalDurationMs) * size.width;
    }

    // --- 1. Draw tasks ---
    final taskPaint = Paint();
    final nonHighlightTasks = tasks.where((t) => !t.isTimeRangeHighlight);
    for (final task in nonHighlightTasks) {
      final startX = dateToX(task.start);
      final endX = dateToX(task.end);
      taskPaint.color = task.color ?? theme.colorScheme.primary.withValues(alpha: 0.5);
      canvas.drawRect(Rect.fromLTRB(startX, size.height * 0.25, endX, size.height * 0.75), taskPaint);
    }

    // --- 2. Draw selection window ---
    final visibleStartX = dateToX(visibleStartDate);
    final visibleEndX = dateToX(visibleEndDate);

    final windowPaint = Paint()..color = theme.colorScheme.primary.withValues(alpha: 0.2);
    final borderPaint = Paint()
      ..color = theme.colorScheme.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final windowRect = Rect.fromLTRB(visibleStartX, 0, visibleEndX, size.height);
    canvas.drawRect(windowRect, windowPaint);
    canvas.drawRect(windowRect, borderPaint);

    // --- 3. Draw handles ---
    final handlePaint = Paint()..color = theme.colorScheme.primary;
    const handleWidth = 4.0;
    final leftHandleRect = Rect.fromLTWH(visibleStartX - handleWidth / 2, 0, handleWidth, size.height);
    final rightHandleRect = Rect.fromLTWH(visibleEndX - handleWidth / 2, 0, handleWidth, size.height);

    canvas.drawRect(leftHandleRect, handlePaint);
    canvas.drawRect(rightHandleRect, handlePaint);
  }

  @override
  bool shouldRepaint(covariant _ScrubberPainter oldDelegate) =>
      oldDelegate.totalStartDate != totalStartDate ||
      oldDelegate.totalEndDate != totalEndDate ||
      oldDelegate.visibleStartDate != visibleStartDate ||
      oldDelegate.visibleEndDate != visibleEndDate ||
      !listEquals(oldDelegate.tasks, tasks) ||
      oldDelegate.theme != theme;
}
