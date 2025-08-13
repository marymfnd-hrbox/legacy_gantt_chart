
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
    return [
      // Development Tasks
      LegacyGanttTask(
        id: 'task1',
        rowId: 'row1',
        name: 'Implement Feature A',
        start: _totalStartDate.add(const Duration(days: 1)),
        end: _totalStartDate.add(const Duration(days: 5)),
        color: Colors.blue.shade700,
      ),
      LegacyGanttTask(
        id: 'task2',
        rowId: 'row1',
        name: 'Implement Feature B',
        start: _totalStartDate.add(const Duration(days: 6)),
        end: _totalStartDate.add(const Duration(days: 10)),
        color: Colors.blue.shade700,
      ),
      LegacyGanttTask(
        id: 'task2.1',
        rowId: 'row1',
        name: 'Sub-task of Feature B',
        start: _totalStartDate.add(const Duration(days: 7)),
        end: _totalStartDate.add(const Duration(days: 9)),
        color: Colors.blue.shade400,
        stackIndex: 1, // Stack on top of Feature B
      ),

      // QA Tasks
      LegacyGanttTask(
        id: 'task3',
        rowId: 'row2',
        name: 'Test Feature A',
        start: _totalStartDate.add(const Duration(days: 5)),
        end: _totalStartDate.add(const Duration(days: 7)),
        color: Colors.orange.shade700,
      ),

      // Summary Task
      LegacyGanttTask(
        id: 'summary1',
        rowId: 'row3',
        name: 'Q1 Release Cycle',
        start: _totalStartDate,
        end: _totalStartDate.add(const Duration(days: 12)),
        isSummary: true,
      ),
    ];
  }

  Future<List<LegacyGanttTask>> _fetchHolidays(DateTime start, DateTime end) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final holidayStart = DateTime(start.year, 1, 1);
    final holidayEnd = DateTime(start.year, 1, 2);

    // The current painter implementation requires highlights to be associated
    // with a specific row. To create a highlight that spans all rows, we
    // generate a separate highlight task for each row.
    return _rows.map((row) => LegacyGanttTask(
        id: 'holiday-${row.id}',
        rowId: row.id,
        name: 'New Year\'s Day',
        start: holidayStart,
        end: holidayEnd,
        isTimeRangeHighlight: true,
      )).toList();
  }

  void _handleTaskUpdate(LegacyGanttTask task, DateTime newStart, DateTime newEnd) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated ${task.name}: ${newStart.toIso8601String()} - ${newEnd.toIso8601String()}'),
      ),
    );
    // In a real app, you would update your state and persist the changes.
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
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
        _tasks[index] = updatedTask;
      }
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
