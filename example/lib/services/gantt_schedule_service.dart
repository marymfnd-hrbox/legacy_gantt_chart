import 'package:flutter/material.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';
import '../data/mock_api_service.dart';
import '../data/models.dart';
import '../ui/gantt_grid_data.dart';
import '../utils/task_helpers.dart';

// A view model to hold the processed data ready for the UI
class ProcessedScheduleData {
  final List<LegacyGanttTask> ganttTasks;
  final List<GanttGridData> gridData;
  final Map<String, int> rowMaxStackDepth;
  final Map<String, GanttEventData> eventMap;
  final GanttResponse apiResponse;

  ProcessedScheduleData({
    required this.ganttTasks,
    required this.gridData,
    required this.rowMaxStackDepth,
    required this.eventMap,
    required this.apiResponse,
  });
}

class GanttScheduleService {
  final MockApiService _apiService = MockApiService();

  Future<ProcessedScheduleData> fetchAndProcessSchedule({
    required DateTime startDate,
    required int range,
  }) async {
    final formattedStartDate = _formatDateToISO(startDate);
    final formattedEndDate = _formatDateToISO(startDate.add(Duration(days: range)));

    final apiResponseJson = await _apiService.get(
      'yeah',
      params: {'startDateIso': formattedStartDate, 'endDateIso': formattedEndDate},
    );

    final apiResponse = GanttResponse.fromJson(apiResponseJson);

    if (!apiResponse.success) {
      throw Exception(apiResponse.error ?? 'Failed to load schedule data');
    }

    // 1. Create a map of all events for quick lookup
    final eventMap = {for (var event in apiResponse.eventsData) event.id: event};

    // 2. Identify top-level person resource IDs
    final parentResourceIds = apiResponse.resourcesData.map((r) => r.id).toSet();

    // 3. Process assignments to create Gantt tasks FIRST, so we know which rows are active.
    final List<LegacyGanttTask> fetchedTasks = [];
    for (var assignment in apiResponse.assignmentsData) {
      final event = eventMap[assignment.event];
      if (event != null && event.utcStartDate != null && event.utcEndDate != null) {
        final colorHex = event.referenceData?.taskColor;
        final textColorHex = event.referenceData?.taskTextColor;
        final isSummary = parentResourceIds.contains(assignment.resource);

        fetchedTasks.add(LegacyGanttTask(
          id: assignment.id,
          rowId: assignment.resource,
          name: event.name ?? 'Unnamed Task',
          start: DateTime.parse(event.utcStartDate!),
          end: DateTime.parse(event.utcEndDate!),
          color: _parseColorHex(colorHex != null ? '#$colorHex' : null, Colors.blue),
          textColor: _parseColorHex(textColorHex != null ? '#$textColorHex' : null, Colors.white),
          originalId: event.id,
          isSummary: isSummary,
        ));
      }
    }

    // Create a map of job assignments to their events' durations
    final Map<String, List<Duration>> jobEventDurations = {};
    for (final assignment in apiResponse.assignmentsData) {
      final event = eventMap[assignment.event];
      if (event != null && event.utcStartDate != null && event.utcEndDate != null) {
        final start = DateTime.parse(event.utcStartDate!);
        final end = DateTime.parse(event.utcEndDate!);
        if (end.isAfter(start)) {
          jobEventDurations.putIfAbsent(assignment.resource, () => []).add(end.difference(start));
        }
      }
    }

    // Get a set of all row IDs that have tasks assigned to them.
    final activeRowIds = fetchedTasks.map((task) => task.rowId).toSet();

    // 4. Process resources to build the hierarchical grid data, filtering out rows with no tasks.
    final List<GanttGridData> processedGridData = [];
    bool isFirstParent = true;
    for (final resource in apiResponse.resourcesData) {
      // Filter children to only include those that have tasks.
      final visibleChildren = resource.children
          .where((job) => activeRowIds.contains(job.id))
          .map((job) => GanttGridData.fromJob(job))
          .toList();

      // A parent row is visible if it has a direct summary task OR if it has any visible children.
      final bool hasDirectTask = activeRowIds.contains(resource.id);
      if (hasDirectTask || visibleChildren.isNotEmpty) {
        // Calculate the parent's completion percentage based on its visible children.
        double totalWeightedDurationMs = 0;
        double totalDurationMs = 0;

        for (final job in resource.children) {
          // Only consider jobs that are visible when calculating parent completion
          if (activeRowIds.contains(job.id)) {
            final durations = jobEventDurations[job.id] ?? [];
            final jobCompletion = job.completion ?? 0.0;
            for (final duration in durations) {
              totalDurationMs += duration.inMilliseconds;
              totalWeightedDurationMs += duration.inMilliseconds * jobCompletion;
            }
          }
        }

        final double parentCompletion = totalDurationMs > 0 ? totalWeightedDurationMs / totalDurationMs : 0.0;

        processedGridData.add(GanttGridData(
          id: resource.id,
          name: resource.name,
          isParent: true,
          children: visibleChildren,
          taskName: resource.taskName,
          isExpanded: isFirstParent, // Default to collapsed
          completion: parentCompletion,
        ));
        isFirstParent = false;
      }
    }

    // 5. Process resource time ranges for background highlights
    for (var timeRange in apiResponse.resourceTimeRangesData) {
      if (timeRange.utcStartDate.isNotEmpty && timeRange.utcEndDate.isNotEmpty) {
        fetchedTasks.add(LegacyGanttTask(
          id: timeRange.id,
          rowId: timeRange.resourceId,
          start: DateTime.parse(timeRange.utcStartDate),
          end: DateTime.parse(timeRange.utcEndDate),
          isTimeRangeHighlight: true,
        ));
      }
    }

    // Add highlights for parent summary events
    for (var resource in apiResponse.resourcesData) {
      final summaryEvent = apiResponse.eventsData.firstWhere(
        (event) => event.id == 'event-${resource.id}-summary',
        orElse: () => GanttEventData(id: '', utcStartDate: null, utcEndDate: null),
      );
      if (summaryEvent.utcStartDate != null && summaryEvent.utcEndDate != null) {
        fetchedTasks.add(LegacyGanttTask(
          id: 'summary-highlight-${summaryEvent.id}',
          rowId: resource.id,
          start: DateTime.parse(summaryEvent.utcStartDate!),
          end: DateTime.parse(summaryEvent.utcEndDate!),
          isTimeRangeHighlight: true,
        ));
      }
    }

    // Add weekend highlights
    final allRows = processedGridData.expand((e) => [e, ...e.children]).map((e) => LegacyGanttRow(id: e.id)).toList();
    fetchedTasks.addAll(_generateWeekendHighlights(allRows, startDate, startDate.add(Duration(days: range))));

    // 6. Calculate task stacking and conflicts
    final (stackedTasks, maxDepthPerRow) = publicCalculateTaskStacking(fetchedTasks, apiResponse);

    return ProcessedScheduleData(
      ganttTasks: stackedTasks,
      gridData: processedGridData,
      rowMaxStackDepth: maxDepthPerRow,
      eventMap: eventMap,
      apiResponse: apiResponse,
    );
  }

  String _formatDateToISO(DateTime date) => date.toIso8601String().substring(0, 19);

  Color _parseColorHex(String? hexString, Color defaultColor) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    String cleanHex = hexString.startsWith('#') ? hexString.substring(1) : hexString;
    if (cleanHex.length == 3) cleanHex = cleanHex.split('').map((char) => char * 2).join();
    if (cleanHex.length == 6) {
      try {
        return Color(int.parse(cleanHex, radix: 16) + 0xFF000000);
      } catch (e) {
        debugPrint('Error parsing hex color "$hexString": $e');
        return defaultColor;
      }
    }
    return defaultColor;
  }

  List<LegacyGanttTask> _generateWeekendHighlights(List<LegacyGanttRow> rows, DateTime start, DateTime end) {
    if (rows.length > 100) {
      return [];
    }
    final List<LegacyGanttTask> holidays = [];
    for (var day = start; day.isBefore(end); day = day.add(const Duration(days: 1))) {
      if (day.weekday == DateTime.saturday) {
        final weekendStart = day;
        final weekendEnd = day.add(const Duration(days: 2));
        for (final row in rows) {
          holidays.add(LegacyGanttTask(
            id: 'weekend-${row.id}-${day.toIso8601String()}',
            rowId: row.id,
            start: weekendStart,
            end: weekendEnd,
            isTimeRangeHighlight: true,
          ));
        }
      }
    }
    return holidays;
  }

  (List<LegacyGanttTask>, Map<String, int>) publicCalculateTaskStacking(
      List<LegacyGanttTask> tasks, GanttResponse apiResponse) {
    final Map<String, List<LegacyGanttTask>> eventTasksByRow = {};
    final List<LegacyGanttTask> nonStackableTasks = [];
    final List<LegacyGanttTask> actualEventTasks = [];

    for (var task in tasks) {
      if (task.isTimeRangeHighlight) {
        nonStackableTasks.add(task); // Only add highlights, indicators are regenerated
      } else if (!task.isOverlapIndicator) {
        actualEventTasks.add(task);
      }
    }

    for (var task in actualEventTasks) {
      eventTasksByRow.putIfAbsent(task.rowId, () => []).add(task);
    }

    final List<LegacyGanttTask> stackedTasks = [];
    final Map<String, int> rowMaxDepth = {};

    eventTasksByRow.forEach((rowId, rowTasks) {
      rowTasks.sort((a, b) => a.start.compareTo(b.start));
      final List<DateTime> stackEndTimes = [];
      for (var currentTask in rowTasks) {
        int currentStackIndex = -1;
        for (int i = 0; i < stackEndTimes.length; i++) {
          if (stackEndTimes[i].isBefore(currentTask.start) || stackEndTimes[i] == currentTask.start) {
            currentStackIndex = i;
            break;
          }
        }

        if (currentStackIndex == -1) {
          currentStackIndex = stackEndTimes.length;
          stackEndTimes.add(currentTask.end);
        } else {
          stackEndTimes[currentStackIndex] = currentTask.end;
        }

        stackedTasks.add(currentTask.copyWith(stackIndex: currentStackIndex));
      }
      rowMaxDepth[rowId] = stackEndTimes.length;
    });

    final Map<String, String> lineItemToContactMap = {
      for (final resource in apiResponse.resourcesData)
        for (final child in resource.children) child.id: resource.id
    };
    final parentResourceIds = apiResponse.resourcesData.map((r) => r.id).toSet();

    final conflictDetector = LegacyGanttConflictDetector();
    final conflictIndicators = conflictDetector.run<String>(
      tasks: stackedTasks,
      taskGrouper: (task) {
        final resourceId = task.rowId;
        return lineItemToContactMap[resourceId] ?? (parentResourceIds.contains(resourceId) ? resourceId : null);
      },
    );

    final finalTasks = [...stackedTasks, ...conflictIndicators, ...nonStackableTasks];
    return (finalTasks, rowMaxDepth);
  }
}
