import 'dart:math';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'models/legacy_gantt_task.dart';

enum _DragType { none, leftHandle, rightHandle, window }

class LegacyGanttTimelineScrubber extends StatefulWidget {
  final DateTime totalStartDate;
  final DateTime totalEndDate;
  final DateTime visibleStartDate;
  final DateTime visibleEndDate;
  final Function(DateTime, DateTime) onWindowChanged;
  final List<LegacyGanttTask> tasks;
  final Duration startPadding;
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
  late DateTime _dragStartDisplayStart;
  late DateTime _dragStartDisplayEnd;
  MouseCursor _cursor = SystemMouseCursors.basic;

  DateTime get _effectiveTotalStart => widget.totalStartDate.subtract(widget.startPadding);
  DateTime get _effectiveTotalEnd => widget.totalEndDate.add(widget.endPadding);

  (DateTime, DateTime) _calculateDisplayRange(DateTime visibleStart, DateTime visibleEnd) {
    final visibleDuration = visibleEnd.difference(visibleStart);
    final totalDuration = _effectiveTotalEnd.difference(_effectiveTotalStart);

    if (visibleDuration >= totalDuration) {
      return (_effectiveTotalStart, _effectiveTotalEnd);
    }

    final bufferDuration = Duration(milliseconds: (visibleDuration.inMilliseconds * 0.25).round());

    DateTime displayStart = visibleStart.subtract(bufferDuration);
    DateTime displayEnd = visibleEnd.add(bufferDuration);

    if (displayStart.isBefore(_effectiveTotalStart)) {
      displayStart = _effectiveTotalStart;
    }
    if (displayEnd.isAfter(_effectiveTotalEnd)) {
      displayEnd = _effectiveTotalEnd;
    }

    if (displayEnd.difference(displayStart) < visibleDuration) {
      if (displayStart == _effectiveTotalStart) {
        displayEnd = displayStart.add(visibleDuration);
      } else if (displayEnd == _effectiveTotalEnd) {
        displayStart = displayEnd.subtract(visibleDuration);
      }
    }

    if (displayEnd.isAfter(_effectiveTotalEnd)) {
      displayEnd = _effectiveTotalEnd;
    }
    if (displayStart.isBefore(_effectiveTotalStart)) {
      displayStart = _effectiveTotalStart;
    }

    return (displayStart, displayEnd);
  }

  _DragType _getDragTypeAtPosition(Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return _DragType.none;

    final (displayStart, displayEnd) = _calculateDisplayRange(widget.visibleStartDate, widget.visibleEndDate);
    final displayDurationMs = displayEnd.difference(displayStart).inMilliseconds;
    if (displayDurationMs <= 0) return _DragType.none;

    final double startX =
        (widget.visibleStartDate.difference(displayStart).inMilliseconds / displayDurationMs) * box.size.width;
    final double endX =
        (widget.visibleEndDate.difference(displayStart).inMilliseconds / displayDurationMs) * box.size.width;

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

      final (displayStart, displayEnd) = _calculateDisplayRange(widget.visibleStartDate, widget.visibleEndDate);
      _dragStartDisplayStart = displayStart;
      _dragStartDisplayEnd = displayEnd;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragType == _DragType.none) return;

    final box = context.findRenderObject() as RenderBox;
    final dragDisplayDuration = _dragStartDisplayEnd.difference(_dragStartDisplayStart);
    if (dragDisplayDuration.inMilliseconds <= 0) return;

    final dx = details.localPosition.dx - _dragStartDx;
    final dDuration = Duration(milliseconds: (dx / box.size.width * dragDisplayDuration.inMilliseconds).round());

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
  Widget build(BuildContext context) {
    final (displayStart, displayEnd) =
        _calculateDisplayRange(widget.visibleStartDate, widget.visibleEndDate);

    final totalDuration = _effectiveTotalEnd.difference(_effectiveTotalStart);
    final isZoomed = displayEnd.difference(displayStart).inMicroseconds < totalDuration.inMicroseconds;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        MouseRegion(
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
                displayStartDate: displayStart,
                displayEndDate: displayEnd,
                visibleStartDate: widget.visibleStartDate,
                visibleEndDate: widget.visibleEndDate,
                tasks: widget.tasks,
                theme: Theme.of(context),
              ),
              size: const Size.fromHeight(40),
            ),
          ),
        ),
        if (isZoomed)
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: IconButton(
              icon: const Icon(Icons.zoom_out_map),
              iconSize: 20.0,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
              tooltip: 'Reset Zoom',
              onPressed: () {
                widget.onWindowChanged(_effectiveTotalStart, _effectiveTotalEnd);
              },
            ),
          ),
      ],
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  final DateTime totalStartDate;
  final DateTime totalEndDate;
  final DateTime displayStartDate;
  final DateTime displayEndDate;
  final DateTime visibleStartDate;
  final DateTime visibleEndDate;
  final List<LegacyGanttTask> tasks;
  final ThemeData theme;

  _ScrubberPainter({
    required this.totalStartDate,
    required this.totalEndDate,
    required this.displayStartDate,
    required this.displayEndDate,
    required this.visibleStartDate,
    required this.visibleEndDate,
    required this.tasks,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final displayDurationMs = displayEndDate.difference(displayStartDate).inMilliseconds;
    if (displayDurationMs <= 0) return;

    double dateToX(DateTime date) {
      if (date.isBefore(displayStartDate)) return 0.0;
      if (date.isAfter(displayEndDate)) return size.width;
      final dateDurationMs = date.difference(displayStartDate).inMilliseconds;
      return (dateDurationMs / displayDurationMs) * size.width;
    }

    final taskPaint = Paint();
    final nonHighlightTasks = tasks.where((t) => !t.isTimeRangeHighlight);
    for (final task in nonHighlightTasks) {
      final startX = dateToX(task.start);
      final endX = dateToX(task.end);
      taskPaint.color = task.color ?? theme.colorScheme.primary.withAlpha(128);
      canvas.drawRect(Rect.fromLTRB(startX, size.height * 0.25, endX, size.height * 0.75), taskPaint);
    }

    final visibleStartX = dateToX(visibleStartDate);
    final visibleEndX = dateToX(visibleEndDate);

    final windowPaint = Paint()..color = theme.colorScheme.primary.withAlpha(50);
    final borderPaint = Paint()
      ..color = theme.colorScheme.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final windowRect = Rect.fromLTRB(visibleStartX, 0, visibleEndX, size.height);
    canvas.drawRect(windowRect, windowPaint);
    canvas.drawRect(windowRect, borderPaint);

    final handlePaint = Paint()..color = theme.colorScheme.primary;
    const handleWidth = 4.0;
    final leftHandleRect = Rect.fromLTWH(visibleStartX - handleWidth / 2, 0, handleWidth, size.height);
    final rightHandleRect = Rect.fromLTWH(visibleEndX - handleWidth / 2, 0, handleWidth, size.height);

    canvas.drawRect(leftHandleRect, handlePaint);
    canvas.drawRect(rightHandleRect, handlePaint);

    const fadeWidth = 20.0;
    // Use a color that has contrast with the background for the fade effect.
    final shadowColor = theme.colorScheme.onSurface.withAlpha(40);

    if (displayStartDate.isAfter(totalStartDate)) {
      final leftFadeRect = Rect.fromLTWH(0, 0, fadeWidth, size.height);
      final leftGradient = LinearGradient(
        colors: [shadowColor, shadowColor.withAlpha(0)],
      );
      canvas.drawRect(leftFadeRect, Paint()..shader = leftGradient.createShader(leftFadeRect));
    }

    if (displayEndDate.isBefore(totalEndDate)) {
      final rightFadeRect = Rect.fromLTWH(size.width - fadeWidth, 0, fadeWidth, size.height);
      final rightGradient = LinearGradient(
        colors: [shadowColor.withAlpha(0), shadowColor],
      );
      canvas.drawRect(rightFadeRect, Paint()..shader = rightGradient.createShader(rightFadeRect));
    }
  }

  @override
  bool shouldRepaint(covariant _ScrubberPainter oldDelegate) =>
      oldDelegate.totalStartDate != totalStartDate ||
      oldDelegate.totalEndDate != totalEndDate ||
      oldDelegate.displayStartDate != displayStartDate ||
      oldDelegate.displayEndDate != displayEndDate ||
      oldDelegate.visibleStartDate != visibleStartDate ||
      oldDelegate.visibleEndDate != visibleEndDate ||
      !listEquals(oldDelegate.tasks, tasks) ||
      oldDelegate.theme != theme;
}
