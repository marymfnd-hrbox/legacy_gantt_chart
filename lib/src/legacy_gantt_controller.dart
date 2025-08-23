import 'package:flutter/material.dart';
import 'models/legacy_gantt_task.dart';
import 'models/legacy_gantt_dependency.dart';

/// A controller to programmatically manage a [LegacyGanttChartWidget].
///
/// This allows for external control over the visible date range and the
/// underlying task data, enabling dynamic interactions like custom navigation
/// buttons or data updates from external sources.
class LegacyGanttController extends ChangeNotifier {
  DateTime _visibleStartDate;
  DateTime _visibleEndDate;
  List<LegacyGanttTask> _tasks;
  List<LegacyGanttTask> _holidays;
  List<LegacyGanttTaskDependency> _dependencies;
  final Future<List<LegacyGanttTask>> Function(DateTime start, DateTime end)?
      tasksAsync;
  final Future<List<LegacyGanttTask>> Function(DateTime start, DateTime end)?
      holidaysAsync;
  bool _isLoading = false;
  bool _isHolidayLoading = false;

  /// The start of the currently visible date range.
  DateTime get visibleStartDate => _visibleStartDate;

  /// The end of the currently visible date range.
  DateTime get visibleEndDate => _visibleEndDate;

  /// The list of tasks currently managed by the controller.
  List<LegacyGanttTask> get tasks => _tasks;

  /// The list of holidays currently managed by the controller.
  ///
  /// Holidays are represented as [LegacyGanttTask]s, typically with
  /// `isTimeRangeHighlight` set to `true` to render them as background highlights.
  List<LegacyGanttTask> get holidays => _holidays;

  /// The list of dependencies currently managed by the controller.
  List<LegacyGanttTaskDependency> get dependencies => _dependencies;

  /// Whether the controller is currently fetching new tasks via `tasksAsync`.
  bool get isLoading => _isLoading;

  /// Whether the controller is currently fetching new holidays via `holidaysAsync`.
  bool get isHolidayLoading => _isHolidayLoading;

  /// Whether the controller is currently fetching tasks or holidays.
  bool get isOverallLoading => _isLoading || _isHolidayLoading;

  LegacyGanttController({
    required DateTime initialVisibleStartDate,
    required DateTime initialVisibleEndDate,
    List<LegacyGanttTask>? initialTasks,
    List<LegacyGanttTask>? initialHolidays,
    List<LegacyGanttTaskDependency>? initialDependencies,
    this.tasksAsync,
    this.holidaysAsync,
  })  : _visibleStartDate = initialVisibleStartDate,
        _visibleEndDate = initialVisibleEndDate,
        _tasks = initialTasks ?? const [],
        _holidays = initialHolidays ?? const [],
        _dependencies = initialDependencies ?? const [] {
    if (tasksAsync != null) {
      if (initialTasks != null && initialTasks.isNotEmpty) {
        debugPrint(
            'Warning: `initialTasks` are ignored when `tasksAsync` is provided.');
      }
      // Perform an initial fetch for the provided date range.
      fetchTasksForVisibleRange();
    }
    if (holidaysAsync != null) {
      if (initialHolidays != null && initialHolidays.isNotEmpty) {
        debugPrint(
            'Warning: `initialHolidays` are ignored when `holidaysAsync` is provided.');
      }
      // Perform an initial fetch for the provided date range.
      fetchHolidaysForVisibleRange();
    }
  }

  /// Updates the visible date range of the chart.
  ///
  /// If `tasksAsync` was provided to the controller, this will trigger a new
  /// data fetch for the given range. Otherwise, it simply updates the visible
  /// window over the existing data. If `holidaysAsync` is also provided, it
  /// will be fetched as well.
  ///
  /// This is useful for connecting the chart to a [LegacyGanttTimelineScrubber]
  /// or other custom navigation controls.
  void setVisibleRange(DateTime newStart, DateTime newEnd) {
    if (_visibleStartDate != newStart || _visibleEndDate != newEnd) {
      _visibleStartDate = newStart;
      _visibleEndDate = newEnd;

      final tasksFetched = tasksAsync != null;
      final holidaysFetched = holidaysAsync != null;

      if (tasksFetched) {
        fetchTasksForVisibleRange();
      }
      if (holidaysFetched) {
        fetchHolidaysForVisibleRange();
      }

      if (!tasksFetched && !holidaysFetched) {
        notifyListeners();
      }
    }
  }

  /// Replaces the current list of tasks with a new list and notifies listeners.
  ///
  /// Throws a [StateError] if the controller was constructed with a `tasksAsync`
  /// callback, as task management is handled automatically in that case.
  void setTasks(List<LegacyGanttTask> newTasks) {
    if (tasksAsync != null) {
      throw StateError(
          'Cannot call setTasks when a tasksAsync callback is provided.');
    }
    _tasks = newTasks;
    notifyListeners();
  }

  /// Replaces the current list of holidays with a new list and notifies listeners.
  ///
  /// Throws a [StateError] if the controller was constructed with a `holidaysAsync`
  /// callback, as holiday management is handled automatically in that case.
  void setHolidays(List<LegacyGanttTask> newHolidays) {
    if (holidaysAsync != null) {
      throw StateError(
          'Cannot call setHolidays when a holidaysAsync callback is provided.');
    }
    _holidays = newHolidays;
    notifyListeners();
  }

  /// Replaces the current list of dependencies with a new list and notifies listeners.
  void setDependencies(List<LegacyGanttTaskDependency> newDependencies) {
    // Dependencies are not typically fetched async, so no check is needed here.
    _dependencies = newDependencies;
    notifyListeners();
  }

  /// Moves the timeline forward by the given [duration], maintaining the
  /// same window size.
  void next({Duration duration = const Duration(days: 7)}) => setVisibleRange(
      _visibleStartDate.add(duration), _visibleEndDate.add(duration));

  /// Moves the timeline backward by the given [duration], maintaining the
  /// same window size.
  void prev({Duration duration = const Duration(days: 7)}) => setVisibleRange(
      _visibleStartDate.subtract(duration), _visibleEndDate.subtract(duration));

  /// Fetches tasks for the current visible date range using the `tasksAsync`
  /// callback.
  ///
  /// The UI will be notified of the loading state and again when the data
  /// has been fetched.
  Future<void> fetchTasksForVisibleRange() async {
    await _fetchData(
      fetcher: tasksAsync,
      onDataReceived: (tasks) => _tasks = tasks,
      setLoading: (loading) => _isLoading = loading,
      errorContext: 'tasks',
    );
  }

  /// Fetches holidays for the current visible date range using the `holidaysAsync`
  /// callback.
  ///
  /// The UI will be notified of the loading state and again when the data has been fetched.
  Future<void> fetchHolidaysForVisibleRange() async {
    await _fetchData(
      fetcher: holidaysAsync,
      onDataReceived: (holidays) => _holidays = holidays,
      setLoading: (loading) => _isHolidayLoading = loading,
      errorContext: 'holidays',
    );
  }

  /// A generic helper to fetch data (tasks or holidays), handle loading states, and errors.
  Future<void> _fetchData({
    required Future<List<LegacyGanttTask>> Function(DateTime, DateTime)?
        fetcher,
    required void Function(List<LegacyGanttTask>) onDataReceived,
    required void Function(bool) setLoading,
    required String errorContext,
  }) async {
    if (fetcher == null) {
      return;
    }

    setLoading(true);
    // Notify listeners to show a loading indicator, but keep the old data visible.
    notifyListeners();

    try {
      final data = await fetcher(_visibleStartDate, _visibleEndDate);
      onDataReceived(data);
    } catch (e, s) {
      debugPrint(
          'Error fetching Gantt $errorContext for range $_visibleStartDate - $_visibleEndDate: $e\n$s');
      onDataReceived(
          []); // On error, clear the data to avoid showing stale data.
    } finally {
      setLoading(false);
      // Notify again to update the UI with the new data and hide the indicator.
      notifyListeners();
    }
  }
}
