// packages/gantt_chart/lib/src/models/gantt_task.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Represents a single segment within a [LegacyGanttTask].
@immutable
class LegacyGanttTaskSegment {
  final DateTime start;
  final DateTime end;
  final Color? color;

  const LegacyGanttTaskSegment({
    required this.start,
    required this.end,
    this.color,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LegacyGanttTaskSegment &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          color == other.color;

  @override
  int get hashCode => start.hashCode ^ end.hashCode ^ color.hashCode;
}

/// Represents a single task or event bar in the Gantt chart.
///
/// For optimal performance, it's recommended to override `==` and `hashCode`
/// or use a package like `equatable` if your task objects might be frequently
/// rebuilt, to prevent unnecessary repaints.
@immutable
class LegacyGanttTask {
  final String id;
  final String rowId;
  final DateTime start;
  final DateTime end;
  final String? name;
  final Color? color;
  final Color? textColor;
  final int stackIndex;
  final String? originalId;
  final bool isSummary;
  final bool isTimeRangeHighlight;
  final bool isOverlapIndicator;
  final List<LegacyGanttTaskSegment>? segments;

  /// A builder to create a custom widget for each day cell this task spans.
  /// If provided, the default task bar will not be drawn for this task.
  final Widget Function(DateTime cellDate)? cellBuilder;

  const LegacyGanttTask({
    required this.id,
    required this.rowId,
    required this.start,
    required this.end,
    this.name,
    this.color,
    this.textColor,
    this.originalId,
    this.stackIndex = 0,
    this.isSummary = false,
    this.isTimeRangeHighlight = false,
    this.isOverlapIndicator = false,
    this.segments,
    this.cellBuilder,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LegacyGanttTask &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          rowId == other.rowId &&
          start == other.start &&
          end == other.end &&
          name == other.name &&
          color == other.color &&
          textColor == other.textColor &&
          stackIndex == other.stackIndex &&
          originalId == other.originalId &&
          isSummary == other.isSummary &&
          isTimeRangeHighlight == other.isTimeRangeHighlight &&
          isOverlapIndicator == other.isOverlapIndicator &&
          listEquals(segments, other.segments) &&
          cellBuilder == other.cellBuilder;

  @override
  int get hashCode =>
      id.hashCode ^
      rowId.hashCode ^
      start.hashCode ^
      end.hashCode ^
      name.hashCode ^
      color.hashCode ^
      textColor.hashCode ^
      stackIndex.hashCode ^
      originalId.hashCode ^
      isSummary.hashCode ^
      isTimeRangeHighlight.hashCode ^
      isOverlapIndicator.hashCode ^
      Object.hashAll(segments ?? []) ^
      cellBuilder.hashCode;
}
