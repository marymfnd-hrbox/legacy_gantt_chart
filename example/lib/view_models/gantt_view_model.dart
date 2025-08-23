import 'package:flutter/material.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../services/gantt_schedule_service.dart';
import '../ui/dialogs/create_task_dialog.dart';
import '../ui/gantt_grid_data.dart';
import '../utils/task_helpers.dart';

enum ThemePreset {
  standard,
  forest,
  midnight,
}

class GanttViewModel extends ChangeNotifier {
  // State variables
  List<LegacyGanttTask> _ganttTasks = [];
  List<LegacyGanttTaskDependency> _dependencies = [];
  List<GanttGridData> _gridData = [];
  ThemePreset _selectedTheme = ThemePreset.standard;
  bool _dragAndDropEnabled = true;
  bool _resizeEnabled = true;
  bool _createTasksEnabled = true;
  DateTime _startDate = DateTime.now();
  final TimeOfDay _defaultStartTime = const TimeOfDay(hour: 9, minute: 0);
  final TimeOfDay _defaultEndTime = const TimeOfDay(hour: 17, minute: 0);
  int _range = 14; // Default range for data fetching

  // Date range state for the Gantt chart view and scrubber
  DateTime? _totalStartDate;
  DateTime? _totalEndDate;
  DateTime? _visibleStartDate;
  DateTime? _visibleEndDate;

  // Padding for the Gantt chart timeline to provide some space at the edges.
  final Duration _ganttStartPadding = const Duration(days: 7);
  final Duration _ganttEndPadding = const Duration(days: 7);

  Map<String, int> _rowMaxStackDepth = {}; // Stores max stack depth for each row
  final ScrollController _scrollController = ScrollController();
  final ScrollController _ganttHorizontalScrollController = ScrollController();
  bool _isScrubberUpdating = false; // Prevents feedback loop between scroller and scrubber

  OverlayEntry? _tooltipOverlay;
  String? _hoveredTaskId;
  Map<String, GanttEventData> _eventMap = {};

  final GanttScheduleService _scheduleService = GanttScheduleService();
  GanttResponse? _apiResponse;

  double? _gridWidth;

  // Getters for the UI
  List<LegacyGanttTask> get ganttTasks => _ganttTasks;
  List<LegacyGanttTaskDependency> get dependencies => _dependencies;
  List<GanttGridData> get gridData => _gridData;
  ThemePreset get selectedTheme => _selectedTheme;
  bool get dragAndDropEnabled => _dragAndDropEnabled;
  bool get resizeEnabled => _resizeEnabled;
  bool get createTasksEnabled => _createTasksEnabled;
  DateTime get startDate => _startDate;
  TimeOfDay get defaultStartTime => _defaultStartTime;
  TimeOfDay get defaultEndTime => _defaultEndTime;
  int get range => _range;
  DateTime? get totalStartDate => _totalStartDate;
  DateTime? get totalEndDate => _totalEndDate;
  DateTime? get visibleStartDate => _visibleStartDate;
  DateTime? get visibleEndDate => _visibleEndDate;
  DateTime? get effectiveTotalStartDate => _totalStartDate?.subtract(_ganttStartPadding);
  DateTime? get effectiveTotalEndDate => _totalEndDate?.add(_ganttEndPadding);
  Map<String, int> get rowMaxStackDepth => _rowMaxStackDepth;
  ScrollController get scrollController => _scrollController;
  ScrollController get ganttHorizontalScrollController => _ganttHorizontalScrollController;
  double? get gridWidth => _gridWidth;

  List<GanttGridData> get visibleGridData => _gridData;

  List<LegacyGanttRow> get visibleGanttRows {
    final List<LegacyGanttRow> rows = [];
    for (final item in visibleGridData) {
      rows.add(LegacyGanttRow(id: item.id));
      if (item.isParent && item.isExpanded) {
        rows.addAll(item.children.map((child) => LegacyGanttRow(id: child.id)));
      }
    }
    return rows;
  }

  GanttViewModel() {
    _ganttHorizontalScrollController.addListener(_onGanttScroll);
    fetchScheduleData();
  }

  @override
  void dispose() {
    _removeTooltip();
    _scrollController.dispose();
    _ganttHorizontalScrollController.removeListener(_onGanttScroll);
    _ganttHorizontalScrollController.dispose();
    super.dispose();
  }

  void setGridWidth(double? value) {
    _gridWidth = value;
    notifyListeners();
  }

  void setSelectedTheme(ThemePreset theme) {
    _selectedTheme = theme;
    notifyListeners();
  }

  void setDragAndDropEnabled(bool value) {
    _dragAndDropEnabled = value;
    notifyListeners();
  }

  void setResizeEnabled(bool value) {
    _resizeEnabled = value;
    notifyListeners();
  }

  void setCreateTasksEnabled(bool value) {
    _createTasksEnabled = value;
    notifyListeners();
  }

  Future<void> fetchScheduleData() async {
    _ganttTasks = [];
    _dependencies = [];
    _gridData = [];
    _rowMaxStackDepth = {};
    _totalStartDate = null;
    _totalEndDate = null;
    _visibleStartDate = null;
    _visibleEndDate = null;
    notifyListeners();

    try {
      final processedData = await _scheduleService.fetchAndProcessSchedule(
        startDate: _startDate,
        range: _range,
      );

      // --- Create sample dependencies for demonstration ---
      final newDependencies = <LegacyGanttTaskDependency>[];
      final ganttTasks = processedData.ganttTasks;

      // Find a suitable task to be the "successor" for all contained dependencies.
      // For this visual effect, the successor doesn't matter, only the predecessor.
      final successorForContainedDemo = ganttTasks.firstWhere(
        (t) => !t.isSummary && !t.isTimeRangeHighlight,
        orElse: () => ganttTasks.first, // Fallback
      );

      // 1. For every summary task, create a 'contained' dependency.
      for (final task in ganttTasks) {
        if (task.isSummary) {
          newDependencies.add(
            LegacyGanttTaskDependency(
              predecessorTaskId: task.id,
              successorTaskId: successorForContainedDemo.id, // The successor is arbitrary for the background to draw
              type: DependencyType.contained,
            ),
          );
        }
      }

      // 2. Find two tasks in the same row for a 'finishToStart' dependency
      final tasksByRow = <String, List<LegacyGanttTask>>{};
      for (final task in ganttTasks) {
        if (!task.isSummary && !task.isTimeRangeHighlight) {
          tasksByRow.putIfAbsent(task.rowId, () => []).add(task);
        }
      }

      for (final tasksInRow in tasksByRow.values) {
        if (tasksInRow.length > 1) {
          tasksInRow.sort((a, b) => a.start.compareTo(b.start));
          newDependencies.add(
            LegacyGanttTaskDependency(predecessorTaskId: tasksInRow[0].id, successorTaskId: tasksInRow[1].id),
          );
          break; // Just add one for demonstration
        }
      }

      _ganttTasks = processedData.ganttTasks;
      _dependencies = newDependencies;
      _gridData = processedData.gridData;
      _rowMaxStackDepth = processedData.rowMaxStackDepth;
      _eventMap = processedData.eventMap;
      _apiResponse = processedData.apiResponse;
      _totalStartDate = _startDate;
      _totalEndDate = _startDate.add(Duration(days: _range));
      _visibleStartDate = effectiveTotalStartDate;
      _visibleEndDate = effectiveTotalEndDate;

      notifyListeners();

      WidgetsBinding.instance.addPostFrameCallback((_) => _setInitialScroll());
    } catch (e) {
      debugPrint('Error fetching gantt schedule data: $e');
      // Consider showing an error message to the user
    }
  }

  // Helper to parse hex color strings
  Color _parseColorHex(String? hexString, Color defaultColor) {
    if (hexString == null || hexString.isEmpty) {
      return defaultColor;
    }
    String cleanHex = hexString.startsWith('#') ? hexString.substring(1) : hexString;
    if (cleanHex.length == 3) {
      cleanHex = cleanHex.split('').map((char) => char * 2).join();
    }
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

  void onRangeChange(int? newRange) {
    if (newRange != null) {
      _range = newRange;
      notifyListeners();
      fetchScheduleData(); // Re-fetch data for new range
    }
  }

  Future<void> onSelectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null && pickedDate != _startDate) {
      _startDate = pickedDate;
      notifyListeners();
      fetchScheduleData(); // Re-fetch data for new date
    }
  }

  void onScrubberWindowChanged(DateTime newStart, DateTime newEnd) {
    // Set a flag to prevent the scroll listener from firing and causing a loop.
    _isScrubberUpdating = true;

    // Update the state with the new visible window from the scrubber.
    // This will trigger a rebuild, which updates the Gantt chart's gridMin/gridMax
    // and recalculates its total width.
    _visibleStartDate = newStart;
    _visibleEndDate = newEnd;
    notifyListeners();

    // After the UI has rebuilt with the new dimensions, programmatically
    // scroll the Gantt chart to the correct position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (effectiveTotalStartDate != null &&
          effectiveTotalEndDate != null &&
          _ganttHorizontalScrollController.hasClients) {
        final totalDataDuration = effectiveTotalEndDate!.difference(effectiveTotalStartDate!).inMilliseconds;
        if (totalDataDuration <= 0) return;

        final position = _ganttHorizontalScrollController.position;
        final totalGanttWidth = position.maxScrollExtent + position.viewportDimension;
        if (totalGanttWidth > 0) {
          final startOffsetMs = newStart.difference(effectiveTotalStartDate!).inMilliseconds;
          final newScrollOffset = (startOffsetMs / totalDataDuration) * totalGanttWidth;

          _ganttHorizontalScrollController.jumpTo(newScrollOffset.clamp(0.0, position.maxScrollExtent));
        }
      }
      // Reset the flag after the update is complete.
      _isScrubberUpdating = false;
    });
  }

  void _onGanttScroll() {
    // If the scroll is happening because of the scrubber, do nothing.
    if (_isScrubberUpdating || effectiveTotalStartDate == null || effectiveTotalEndDate == null) return;

    final position = _ganttHorizontalScrollController.position;
    final totalGanttWidth = position.maxScrollExtent + position.viewportDimension;
    if (totalGanttWidth <= 0) return;

    final totalDataDuration = effectiveTotalEndDate!.difference(effectiveTotalStartDate!).inMilliseconds;
    if (totalDataDuration <= 0) return;
    final startOffsetMs = (position.pixels / totalGanttWidth) * totalDataDuration;
    final newVisibleStart = effectiveTotalStartDate!.add(Duration(milliseconds: startOffsetMs.round()));
    final newVisibleEnd = newVisibleStart.add(_visibleEndDate!.difference(_visibleStartDate!));

    // Only update if there's a significant change to prevent excessive rebuilds
    if (newVisibleStart != _visibleStartDate || newVisibleEnd != _visibleEndDate) {
      _visibleStartDate = newVisibleStart;
      _visibleEndDate = newVisibleEnd;
      notifyListeners();
    }
  }

  // Sets initial scroll position after data loads and layout is built.
  void _setInitialScroll() {
    if (!_ganttHorizontalScrollController.hasClients ||
        effectiveTotalStartDate == null ||
        effectiveTotalEndDate == null ||
        _visibleStartDate == null) {
      return;
    }

    final totalDuration = effectiveTotalEndDate!.difference(effectiveTotalStartDate!).inMilliseconds;
    if (totalDuration <= 0) return;

    final position = _ganttHorizontalScrollController.position;
    final totalGanttWidth = position.maxScrollExtent + position.viewportDimension;
    if (totalGanttWidth <= 0) return;

    final startOffsetMs = _visibleStartDate!.difference(effectiveTotalStartDate!).inMilliseconds;
    final newScrollOffset = (startOffsetMs / totalDuration) * totalGanttWidth;
    _ganttHorizontalScrollController.jumpTo(newScrollOffset.clamp(0.0, position.maxScrollExtent));
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  void showTooltip(BuildContext context, LegacyGanttTask task, Offset globalPosition) {
    _removeTooltip(); // Remove previous tooltip first

    final overlay = Overlay.of(context);

    // --- "Day X" Calculation ---
    int? dayNumber;

    // "Day X" is only for child shifts, not summary bars.
    if (!task.isSummary && task.originalId != null) {
      final childEvent = _eventMap[task.originalId];
      if (childEvent?.elementId != null) {
        final parentEvent = _eventMap[childEvent!.elementId];
        if (parentEvent?.utcStartDate != null) {
          final parentStartDate = DateTime.tryParse(parentEvent!.utcStartDate!);
          if (parentStartDate != null) {
            dayNumber = task.start.toUtc().difference(parentStartDate.toUtc()).inDays + 1;
          }
        }
      }
    }

    _tooltipOverlay = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        // Get status info from the original event data.
        final event = _eventMap[task.originalId];
        final statusText = event?.referenceData?.taskName;
        // The color from the API doesn't include '#', so we add it for parsing.
        final taskColorHex = event?.referenceData?.taskColor;
        final taskColor = taskColorHex != null ? _parseColorHex('#$taskColorHex', Colors.transparent) : null;
        final textStyle = theme.textTheme.bodySmall;
        final boldTextStyle = textStyle?.copyWith(fontWeight: FontWeight.bold);

        // Position the tooltip near the cursor
        return Positioned(
          left: globalPosition.dx + 15, // Offset from cursor
          top: globalPosition.dy + 15,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(4),
            color: Colors.transparent, // Make Material transparent to show Container's decor
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480), // Style: max-width
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Important for Column in Overlay
                children: [
                  if (dayNumber != null) Text('Day $dayNumber', style: boldTextStyle),
                  Text(task.name ?? '', style: boldTextStyle),
                  if (statusText != null && taskColor != null && taskColor != Colors.transparent)
                    Container(
                      margin: const EdgeInsets.only(top: 2, bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: taskColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: textStyle?.copyWith(
                          color: ThemeData.estimateBrightnessForColor(taskColor) == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text('Start: ${DateFormat.yMd().add_jm().format(task.start.toLocal())}', style: textStyle),
                  Text('End: ${DateFormat.yMd().add_jm().format(task.end.toLocal())}', style: textStyle),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_tooltipOverlay!);
    _hoveredTaskId = task.id;
    notifyListeners();
  }

  void onTaskHover(LegacyGanttTask? task, BuildContext context, Offset globalPosition) {
    if (_hoveredTaskId == task?.id) return;
    _hoveredTaskId = task?.id;
    _removeTooltip();
    if (task != null && !task.isTimeRangeHighlight) {
      // Don't show tooltip for highlights
      showTooltip(context, task, globalPosition);
    }
    notifyListeners();
  }

  void handleTaskUpdate(LegacyGanttTask task, DateTime newStart, DateTime newEnd) {
    final newTasks = List<LegacyGanttTask>.from(_ganttTasks);
    final index = newTasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      newTasks[index] = newTasks[index].copyWith(start: newStart, end: newEnd);
      if (_apiResponse != null) {
        final (recalculatedTasks, newMaxDepth) = _scheduleService.publicCalculateTaskStacking(newTasks, _apiResponse!);
        _ganttTasks = recalculatedTasks;
        _rowMaxStackDepth = newMaxDepth;
        notifyListeners();
      }
    }
  }

  void handleEmptySpaceClick(BuildContext context, String rowId, DateTime time) {
    if (!_createTasksEnabled) return;

    // Find the resource name from the grid data.
    String resourceName = 'Unknown Resource';
    for (final parent in _gridData) {
      if (parent.id == rowId) {
        resourceName = parent.name;
        break;
      }
      for (final child in parent.children) {
        if (child.id == rowId) {
          resourceName = '${parent.name} - ${child.name}';
          break;
        }
      }
    }

    showDialog<void>(
      context: context,
      builder: (context) => CreateTaskAlertDialog(
        initialTime: time,
        resourceName: resourceName,
        rowId: rowId,
        defaultStartTime: _defaultStartTime,
        defaultEndTime: _defaultEndTime,
        onCreate: (newTask) {
          _addNewTask(newTask);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<String?> _showTextInputDialog({
    required BuildContext context,
    required String title,
    required String label,
    String? initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> addContact(BuildContext context) async {
    final newContactName = await _showTextInputDialog(
      context: context,
      title: 'Add New Contact',
      label: 'Contact Name',
    );

    if (newContactName != null && newContactName.isNotEmpty) {
      final newResourceId = 'person_${DateTime.now().millisecondsSinceEpoch}';

      // Create new data objects
      final newResource = GanttResourceData(id: newResourceId, name: newContactName, children: []);
      final newGridItem =
          GanttGridData(id: newResourceId, name: newContactName, isParent: true, isExpanded: true, children: []);

      // Update the mock API response and the grid data
      _apiResponse?.resourcesData.add(newResource);
      _gridData.add(newGridItem);
      notifyListeners();
    }
  }

  Future<void> addLineItem(BuildContext context, String parentId) async {
    final parentGridItem = _gridData.firstWhere((g) => g.id == parentId);
    final newLineItemName = await _showTextInputDialog(
      context: context,
      title: 'Add New Line Item for ${parentGridItem.name}',
      label: 'Line Item Name',
    );

    if (newLineItemName != null && newLineItemName.isNotEmpty) {
      final newJobId = 'job_${DateTime.now().millisecondsSinceEpoch}';

      // Create new data objects
      final newJob = GanttJobData(
          id: newJobId,
          name: newLineItemName,
          taskName: newLineItemName,
          status: 'New',
          taskColor: '9E9E9E',
          completion: 0.0);
      final newGridItem = GanttGridData.fromJob(newJob);

      // Find the parent in both data structures and add the new child
      final parentResource = _apiResponse?.resourcesData.firstWhere((r) => r.id == parentId);
      parentResource?.children.add(newJob);
      parentGridItem.children.add(newGridItem);
      notifyListeners();
    }
  }

  void setParentTaskType(String parentId, bool isSummary) {
    if (_apiResponse == null) return;

    // Find the main task for the parent.
    final parentTaskIndex = _ganttTasks.indexWhere(
      (t) => t.rowId == parentId && !t.isTimeRangeHighlight,
    );

    if (isSummary) {
      // --- Making it a Summary Task ---
      if (parentTaskIndex != -1) {
        // Task already exists, just update its type.
        final existingTask = _ganttTasks[parentTaskIndex];
        _ganttTasks[parentTaskIndex] = existingTask.copyWith(isSummary: true);
      } else {
        // No task exists for this parent, so we create one.
        // Its duration will be the min/max of its children's tasks.
        final parentGridItem = _gridData.firstWhere((g) => g.id == parentId);
        final childIds = parentGridItem.children.map((c) => c.id).toSet();
        final childrenTasks = _ganttTasks.where((t) => childIds.contains(t.rowId)).toList();

        if (childrenTasks.isNotEmpty) {
          DateTime minStart = childrenTasks.first.start;
          DateTime maxEnd = childrenTasks.first.end;
          for (final task in childrenTasks) {
            if (task.start.isBefore(minStart)) minStart = task.start;
            if (task.end.isAfter(maxEnd)) maxEnd = task.end;
          }

          final newTask = LegacyGanttTask(
            id: 'summary-task-$parentId', // A new unique ID
            rowId: parentId,
            name: parentGridItem.name,
            start: minStart,
            end: maxEnd,
            isSummary: true,
          );
          _ganttTasks.add(newTask);
        }
      }

      // Add 'contained' dependency if it doesn't exist.
      final hasDependency =
          _dependencies.any((d) => d.predecessorTaskId == parentId && d.type == DependencyType.contained);
      if (!hasDependency) {
        final successorForContainedDemo =
            _ganttTasks.firstWhere((t) => !t.isSummary && !t.isTimeRangeHighlight, orElse: () => _ganttTasks.first);
        _dependencies.add(LegacyGanttTaskDependency(
            predecessorTaskId: parentId,
            successorTaskId: successorForContainedDemo.id,
            type: DependencyType.contained));
      }
    } else {
      // --- Making it a Regular Task ---
      if (parentTaskIndex != -1) {
        final existingTask = _ganttTasks[parentTaskIndex];
        if (existingTask.id.startsWith('summary-task-')) {
          _ganttTasks.removeAt(parentTaskIndex);
        } else {
          _ganttTasks[parentTaskIndex] = existingTask.copyWith(isSummary: false);
        }
      }
      _dependencies.removeWhere((d) => d.predecessorTaskId == parentId && d.type == DependencyType.contained);
    }

    final (recalculatedTasks, newMaxDepth) = _scheduleService.publicCalculateTaskStacking(_ganttTasks, _apiResponse!);
    _ganttTasks = recalculatedTasks;
    _rowMaxStackDepth = newMaxDepth;
    notifyListeners();
  }

  void _addNewTask(LegacyGanttTask newTask) {
    final newTasks = [..._ganttTasks, newTask];
    if (_apiResponse != null) {
      final (recalculatedTasks, newMaxDepth) = _scheduleService.publicCalculateTaskStacking(newTasks, _apiResponse!);
      _ganttTasks = recalculatedTasks;
      _rowMaxStackDepth = newMaxDepth;
      notifyListeners();
    }
  }

  double calculateGanttWidth(double screenWidth) {
    if (effectiveTotalStartDate == null ||
        effectiveTotalEndDate == null ||
        _visibleStartDate == null ||
        _visibleEndDate == null) {
      return screenWidth;
    }
    final totalDuration = effectiveTotalEndDate!.difference(effectiveTotalStartDate!).inMilliseconds;
    final visibleDuration = _visibleEndDate!.difference(_visibleStartDate!).inMilliseconds;

    if (visibleDuration <= 0) return screenWidth;

    final zoomFactor = totalDuration / visibleDuration;
    return screenWidth * zoomFactor;
  }

  void toggleExpansion(String id) {
    final item = _gridData.firstWhere((element) => element.id == id);
    item.isExpanded = !item.isExpanded;
    notifyListeners();
  }

  void handleCopyTask(LegacyGanttTask task) {
    if (_apiResponse == null) return;

    // Create a new task, slightly offset in time, with a new unique ID.
    final newTask = task.copyWith(
      id: 'copy_${task.id}_${DateTime.now().millisecondsSinceEpoch}',
      start: task.start.add(const Duration(days: 1)),
      end: task.end.add(const Duration(days: 1)),
    );

    final newTasks = [..._ganttTasks, newTask];
    // Recalculate stacking with the new task.
    final (recalculatedTasks, newMaxDepth) = _scheduleService.publicCalculateTaskStacking(newTasks, _apiResponse!);
    _ganttTasks = recalculatedTasks;
    _rowMaxStackDepth = newMaxDepth;
    notifyListeners();
  }

  void handleDeleteTask(LegacyGanttTask task) {
    if (_apiResponse == null) return;

    // Remove the task itself.
    _ganttTasks.removeWhere((t) => t.id == task.id);

    // Remove any dependencies connected to this task.
    _dependencies.removeWhere((d) => d.predecessorTaskId == task.id || d.successorTaskId == task.id);

    // After removing the task, recalculate stacking.
    final (recalculatedTasks, newMaxDepth) = _scheduleService.publicCalculateTaskStacking(_ganttTasks, _apiResponse!);
    _ganttTasks = recalculatedTasks;
    _rowMaxStackDepth = newMaxDepth;
    notifyListeners();
  }
}
