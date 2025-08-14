import 'package:flutter/material.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';

// Defining the typedef for LegacyGanttTaskCellBuilder
typedef LegacyGanttTaskCellBuilder = Widget Function(LegacyGanttTask task);

// Extension to add copyWith to LegacyGanttTask (required for updates)
extension LegacyGanttTaskCopyWith on LegacyGanttTask {
  LegacyGanttTask copyWith({
    String? id,
    String? rowId,
    String? name,
    DateTime? start,
    DateTime? end,
    Color? color,
    Color? textColor,
    int? stackIndex,
    String? originalId,
    bool? isSummary,
    bool? isTimeRangeHighlight,
    bool? isOverlapIndicator,
    List<LegacyGanttTaskSegment>? segments,
    LegacyGanttTaskCellBuilder? cellBuilder,
  }) => LegacyGanttTask(
    id: id ?? this.id,
    rowId: rowId ?? this.rowId,
    name: name ?? this.name,
    start: start ?? this.start,
    end: end ?? this.end,
    color: color ?? this.color,
    textColor: textColor ?? this.textColor,
    stackIndex: stackIndex ?? this.stackIndex,
    originalId: originalId ?? this.originalId,
    isSummary: isSummary ?? this.isSummary,
    isTimeRangeHighlight: isTimeRangeHighlight ?? this.isTimeRangeHighlight,
    isOverlapIndicator: isOverlapIndicator ?? this.isOverlapIndicator,
    segments: segments ?? this.segments,
    cellBuilder: this.cellBuilder,
  );
}