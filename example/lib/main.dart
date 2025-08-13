
import 'package:flutter/material.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Legacy Gantt Chart Demo',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      themeMode: ThemeMode.system,
      home: const GanttChartDemo(),
    );
  }
}

class GanttChartDemo extends StatefulWidget {
  const GanttChartDemo({super.key});

  @override
  State<GanttChartDemo> createState() => _GanttChartDemoState();
}

class _GanttChartDemoState extends State<GanttChartDemo> {
  // State variables
  List<LegacyGanttTask> _tasks = [];
  bool _isLoading = true;
  late DateTime _visibleStartDate;
  late DateTime _visibleEndDate;
  final ScrollController _horizontalScrollController = ScrollController();

  final List<LegacyGanttRow> _rows = [
    const LegacyGanttRow(id: 'row1'),
    const LegacyGanttRow(id: 'row2'),
    const LegacyGanttRow(id: 'row3'),
  ];

  final Map<String, int> _rowMaxStackDepth = {
    'row1': 2,
    'row2': 1,
    'row3': 1,
  };

  final DateTime _totalStartDate = DateTime(2025, 1, 1);
  final DateTime _totalEndDate = DateTime(2025, 1, 25);

  @override
  void initState() {
    super.initState();
    _visibleStartDate = _totalStartDate;
    _visibleEndDate = _totalEndDate;
    _loadData();
    _horizontalScrollController.addListener(_onGanttScroll);
  }

  @override
  void dispose() {
    _horizontalScrollController.removeListener(_onGanttScroll);
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final tasks = await _fetchTasks(_totalStartDate, _totalEndDate);
    final holidays = await _fetchHolidays(_totalStartDate, _totalEndDate);
    setState(() {
      _tasks = [...tasks, ...holidays];
      _isLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _setInitialScroll());
  }

  void _onGanttScroll() {
    final position = _horizontalScrollController.position;
    final totalGanttWidth = position.maxScrollExtent + position.viewportDimension;
    if (totalGanttWidth <= 0) return;

    final totalDuration = _totalEndDate.difference(_totalStartDate).inMilliseconds;
    if (totalDuration <= 0) return;

    final startOffsetMs = (position.pixels / totalGanttWidth) * totalDuration;
    final newVisibleStart = _totalStartDate.add(Duration(milliseconds: startOffsetMs.round()));
    final visibleDuration = _visibleEndDate.difference(_visibleStartDate);
    final newVisibleEnd = newVisibleStart.add(visibleDuration);

    if (newVisibleStart != _visibleStartDate || newVisibleEnd != _visibleEndDate) {
      setState(() {
        _visibleStartDate = newVisibleStart;
        _visibleEndDate = newVisibleEnd;
      });
    }
  }

  double _calculateGanttWidth(double screenWidth) {
    final totalDuration = _totalEndDate.difference(_totalStartDate).inMilliseconds;
    final visibleDuration = _visibleEndDate.difference(_visibleStartDate).inMilliseconds;

    if (visibleDuration <= 0) return screenWidth;

    final zoomFactor = totalDuration / visibleDuration;
    return screenWidth * zoomFactor;
  }

  Future<List<LegacyGanttTask>> _fetchTasks(DateTime start, DateTime end) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final summaryTask = LegacyGanttTask(
      id: 'summary1',
      rowId: 'row1',
      name: 'Q1 Release Cycle',
      start: _totalStartDate,
      end: _totalStartDate.add(const Duration(days: 12)),
      isSummary: true,
    );

    final mainTasks = [
      summaryTask,
      // Development Tasks on child row 2
      LegacyGanttTask(
          id: 'task1',
          rowId: 'row2',
          name: 'Implement Feature A',
          start: _totalStartDate.add(const Duration(days: 1)),
          end: _totalStartDate.add(const Duration(days: 5)),
          color: Colors.blue.shade700),
      LegacyGanttTask(
          id: 'task2',
          rowId: 'row2',
          name: 'Implement Feature B',
          start: _totalStartDate.add(const Duration(days: 6)),
          end: _totalStartDate.add(const Duration(days: 10)),
          color: Colors.blue.shade700),
      LegacyGanttTask(
          id: 'task2.1',
          rowId: 'row2',
          name: 'Sub-task of Feature B',
          start: _totalStartDate.add(const Duration(days: 7)),
          end: _totalStartDate.add(const Duration(days: 9)),
          color: Colors.blue.shade400,
          stackIndex: 1),
      // QA Tasks on child row 3
      LegacyGanttTask(
          id: 'task3',
          rowId: 'row3',
          name: 'Test Feature A',
          start: _totalStartDate.add(const Duration(days: 5)),
          end: _totalStartDate.add(const Duration(days: 7)),
          color: Colors.orange.shade700),
    ];

    // Create a grey background highlight on child rows that spans the duration of the summary task.
    final childRowIds = ['row2', 'row3'];
    final summaryHighlights = childRowIds
        .map((rowId) => LegacyGanttTask(
              id: 'summary-highlight-$rowId',
              rowId: rowId,
              start: summaryTask.start,
              end: summaryTask.end,
              isTimeRangeHighlight: true,
              color: Colors.grey.withValues(alpha:0.2), // The grey background for the summary span
            ))
        .toList();

    return [...mainTasks, ...summaryHighlights];
  }

  Future<List<LegacyGanttTask>> _fetchHolidays(DateTime start, DateTime end) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final List<LegacyGanttTask> holidays = [];
    // Use a distinct color for actual holidays/weekends.
    final holidayColor = Theme.of(context).colorScheme.primary.withValues(alpha:0.3);

    // Generate highlights for weekends within the visible range.
    for (var day = start; day.isBefore(end); day = day.add(const Duration(days: 1))) {
      if (day.weekday == DateTime.saturday) {
        final weekendStart = day;
        final weekendEnd = day.add(const Duration(days: 2)); // Saturday + Sunday

        // Create a highlight for each row for this weekend.
        for (final row in _rows) {
          holidays.add(LegacyGanttTask(
            id: 'weekend-${row.id}-${day.toIso8601String()}',
            rowId: row.id,
            start: weekendStart,
            end: weekendEnd,
            isTimeRangeHighlight: true,
            color: holidayColor,
          ));
        }
      }
    }
    return holidays;
  }

  void _handleTaskUpdate(LegacyGanttTask task, DateTime newStart, DateTime newEnd) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated ${task.name}: ${newStart.toIso8601String()} - ${newEnd.toIso8601String()}'),
      ),
    );
    // In a real app, you would update your state and persist the changes.
    setState(() {
      // Create a mutable copy of the tasks list to perform updates.
      final newTasks = List<LegacyGanttTask>.from(_tasks);

      final index = newTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        final updatedTask = LegacyGanttTask(
          id: task.id,
          rowId: task.rowId,
          start: newStart,
          end: newEnd,
          name: task.name,
          color: task.color,
          textColor: task.textColor,
          stackIndex: task.stackIndex,
          originalId: task.originalId,
          isSummary: task.isSummary,
          isTimeRangeHighlight: task.isTimeRangeHighlight,
          isOverlapIndicator: task.isOverlapIndicator,
          segments: task.segments,
          cellBuilder: task.cellBuilder,
        );
        newTasks[index] = updatedTask;

        // If the updated task was a summary, find and update its corresponding highlights.
        if (updatedTask.isSummary) {
          for (int i = 0; i < newTasks.length; i++) {
            final currentTask = newTasks[i];
            // This condition assumes a naming convention for summary highlights.
            if (currentTask.id.startsWith('summary-highlight-')) {
              newTasks[i] = LegacyGanttTask(
                id: currentTask.id,
                rowId: currentTask.rowId,
                start: newStart, // Use the new start date from the summary task
                end: newEnd, // Use the new end date from the summary task
                isTimeRangeHighlight: true,
                color: currentTask.color,
              );
            }
          }
        }
      }
      _tasks = newTasks;
    });
  }

  void _setInitialScroll() {
    if (!_horizontalScrollController.hasClients) return;
    final totalDuration = _totalEndDate.difference(_totalStartDate).inMilliseconds;
    if (totalDuration <= 0) return;

    final position = _horizontalScrollController.position;
    final totalGanttWidth = position.maxScrollExtent + position.viewportDimension;
    if (totalGanttWidth <= 0) return;

    final startOffsetMs = _visibleStartDate.difference(_totalStartDate).inMilliseconds;
    final newScrollOffset = (startOffsetMs / totalDuration) * totalGanttWidth;
    _horizontalScrollController.jumpTo(newScrollOffset.clamp(0.0, position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    // Define the theme first so it can be used in the builder.
    final ganttTheme = LegacyGanttTheme.fromTheme(appTheme).copyWith(
      barColorPrimary: Colors.deepPurple,
      barColorSecondary: Colors.deepPurple.shade300,
      // Use the default text style from the theme but make it bold.
      // The default handles picking a good color (like onPrimary).
      taskTextStyle: LegacyGanttTheme.fromTheme(appTheme).taskTextStyle.copyWith(fontWeight: FontWeight.bold),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Full-Featured Gantt Chart'),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final ganttWidth = _calculateGanttWidth(constraints.maxWidth);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalScrollController,
                  child: SizedBox(
                    width: ganttWidth,
                    height: constraints.maxHeight,
                    child: LegacyGanttChartWidget(
                      data: _tasks,
                      visibleRows: _rows,
                      rowMaxStackDepth: _rowMaxStackDepth,
                      // By setting gridMin/Max to totalGridMin/Max, we tell the widget to
                      // render its entire width, letting the SingleChildScrollView handle scrolling.
                      gridMin: _totalStartDate.millisecondsSinceEpoch.toDouble(),
                      gridMax: _totalEndDate.millisecondsSinceEpoch.toDouble(),
                      totalGridMin: _totalStartDate.millisecondsSinceEpoch.toDouble(),
                      totalGridMax: _totalEndDate.millisecondsSinceEpoch.toDouble(),
                      enableDragAndDrop: true,
                      enableResize: true,
                      onTaskUpdate: _handleTaskUpdate,
                      theme: ganttTheme,
                      taskContentBuilder: (task) {
                        // Determine text color based on the bar's background color for high contrast.
                        final barColor = task.color ?? ganttTheme.barColorPrimary;
                        final textColor = ThemeData.estimateBrightnessForColor(barColor) == Brightness.dark ? Colors.white : Colors.black;
                        final textStyle = ganttTheme.taskTextStyle.copyWith(color: textColor);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            children: [
                              if (task.id.contains('task')) Icon(Icons.task, color: textColor, size: 16),
                              if (task.isSummary) Icon(Icons.summarize, color: textColor, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  task.name ?? '',
                                  style: textStyle,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          LegacyGanttTimelineScrubber(
            totalStartDate: _totalStartDate,
            totalEndDate: _totalEndDate,
            visibleStartDate: _visibleStartDate,
            visibleEndDate: _visibleEndDate,
            tasks: _tasks,
            onWindowChanged: (newStart, newEnd) {
              setState(() {
                _visibleStartDate = newStart;
                _visibleEndDate = newEnd;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) => _setInitialScroll());
            },
          ),
        ],
      ),
    );
  }
}
