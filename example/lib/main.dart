import 'package:flutter/material.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';
import 'package:intl/intl.dart';

import 'data/models.dart';
import 'services/gantt_schedule_service.dart';
import 'ui/gantt_grid_data.dart';
import 'ui/widgets/gantt_grid.dart';
import 'utils/task_helpers.dart';
import 'ui/widgets/dashboard_header.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Legacy Gantt Chart Example',
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
        home: const GanttView(),
      );
}

class GanttView extends StatefulWidget {
  const GanttView({super.key});

  @override
  State<GanttView> createState() => _GanttViewState();
}

class _GanttViewState extends State<GanttView> {
  // State variables
  List<LegacyGanttTask> _ganttTasks = [];
  List<GanttGridData> _gridData = [];
  DateTime _startDate = DateTime.now();
  int _range = 14; // Default range for data fetching

  // Date range state for the Gantt chart view and scrubber
  DateTime? _totalStartDate;
  DateTime? _totalEndDate;
  DateTime? _visibleStartDate;
  DateTime? _visibleEndDate;

  // Padding for the Gantt chart timeline to provide some space at the edges.
  final Duration _ganttStartPadding = const Duration(days: 7);
  final Duration _ganttEndPadding = const Duration(days: 7);

  // Computed properties for padded total dates
  DateTime? get _effectiveTotalStartDate => _totalStartDate?.subtract(_ganttStartPadding);
  DateTime? get _effectiveTotalEndDate => _totalEndDate?.add(_ganttEndPadding);

  Map<String, int> _rowMaxStackDepth = {}; // Stores max stack depth for each row
  final ScrollController _scrollController = ScrollController();
  final ScrollController _ganttHorizontalScrollController = ScrollController();
  bool _isScrubberUpdating = false; // Prevents feedback loop between scroller and scrubber

  OverlayEntry? _tooltipOverlay;
  String? _hoveredTaskId;
  Map<String, GanttEventData> _eventMap = {};

  final GanttScheduleService _scheduleService = GanttScheduleService();
  GanttResponse? _apiResponse;

  bool _isInitialLoad = true;
  double? _gridWidth;

  @override
  void initState() {
    super.initState();
    _ganttHorizontalScrollController.addListener(_onGanttScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoad) {
      _fetchScheduleData();
      _isInitialLoad = false;
    }
  }

  @override
  void dispose() {
    _removeTooltip();
    _scrollController.dispose();
    _ganttHorizontalScrollController.removeListener(_onGanttScroll);
    _ganttHorizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchScheduleData() async {
    setState(() {
      _ganttTasks = [];
      _gridData = [];
      _rowMaxStackDepth = {};
      _totalStartDate = null;
      _totalEndDate = null;
      _visibleStartDate = null;
      _visibleEndDate = null;
    });

    try {
      final weekendColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
      final processedData = await _scheduleService.fetchAndProcessSchedule(
        startDate: _startDate,
        range: _range,
        weekendColor: weekendColor,
      );

      if (!mounted) return;
      setState(() {
        _ganttTasks = processedData.ganttTasks;
        _gridData = processedData.gridData;
        _rowMaxStackDepth = processedData.rowMaxStackDepth;
        _eventMap = processedData.eventMap;
        _apiResponse = processedData.apiResponse;
        _totalStartDate = _startDate;
        _totalEndDate = _startDate.add(Duration(days: _range));
        _visibleStartDate = _effectiveTotalStartDate;
        _visibleEndDate = _effectiveTotalEndDate;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _setInitialScroll());
    } catch (e) {
      debugPrint('Error fetching gantt schedule data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load schedule: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  void _onRangeChange(int? newRange) {
    if (newRange != null) {
      setState(() {
        _range = newRange;
      });
      _fetchScheduleData(); // Re-fetch data for new range
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null && pickedDate != _startDate) {
      setState(() {
        _startDate = pickedDate;
      });
      _fetchScheduleData(); // Re-fetch data for new date
    }
  }

  void _onScrubberWindowChanged(DateTime newStart, DateTime newEnd) {
    // Set a flag to prevent the scroll listener from firing and causing a loop.
    _isScrubberUpdating = true;

    // Update the state with the new visible window from the scrubber.
    // This will trigger a rebuild, which updates the Gantt chart's gridMin/gridMax
    // and recalculates its total width.
    setState(() {
      _visibleStartDate = newStart;
      _visibleEndDate = newEnd;
    });

    // After the UI has rebuilt with the new dimensions, programmatically
    // scroll the Gantt chart to the correct position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_effectiveTotalStartDate != null &&
          _effectiveTotalEndDate != null &&
          _ganttHorizontalScrollController.hasClients) {
        final totalDataDuration = _effectiveTotalEndDate!.difference(_effectiveTotalStartDate!).inMilliseconds;
        if (totalDataDuration <= 0) return;

        final position = _ganttHorizontalScrollController.position;
        final totalGanttWidth = position.maxScrollExtent + position.viewportDimension;
        if (totalGanttWidth > 0) {
          final startOffsetMs = newStart.difference(_effectiveTotalStartDate!).inMilliseconds;
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
    if (_isScrubberUpdating || _effectiveTotalStartDate == null || _effectiveTotalEndDate == null) return;

    final position = _ganttHorizontalScrollController.position;
    final totalGanttWidth = position.maxScrollExtent + position.viewportDimension;
    if (totalGanttWidth <= 0) return;

    final totalDataDuration = _effectiveTotalEndDate!.difference(_effectiveTotalStartDate!).inMilliseconds;
    if (totalDataDuration <= 0) return;
    final startOffsetMs = (position.pixels / totalGanttWidth) * totalDataDuration;
    final newVisibleStart = _effectiveTotalStartDate!.add(Duration(milliseconds: startOffsetMs.round()));
    final newVisibleEnd = newVisibleStart.add(_visibleEndDate!.difference(_visibleStartDate!));

    // Only update if there's a significant change to prevent excessive rebuilds
    if (newVisibleStart != _visibleStartDate || newVisibleEnd != _visibleEndDate) {
      setState(() {
        _visibleStartDate = newVisibleStart;
        _visibleEndDate = newVisibleEnd;
      });
    }
  }

  // Sets initial scroll position after data loads and layout is built.
  void _setInitialScroll() {
    if (!_ganttHorizontalScrollController.hasClients ||
        _effectiveTotalStartDate == null ||
        _effectiveTotalEndDate == null ||
        _visibleStartDate == null) {
      return;
    }

    final totalDuration = _effectiveTotalEndDate!.difference(_effectiveTotalStartDate!).inMilliseconds;
    if (totalDuration <= 0) return;

    final position = _ganttHorizontalScrollController.position;
    final totalGanttWidth = position.maxScrollExtent + position.viewportDimension;
    if (totalGanttWidth <= 0) return;

    final startOffsetMs = _visibleStartDate!.difference(_effectiveTotalStartDate!).inMilliseconds;
    final newScrollOffset = (startOffsetMs / totalDuration) * totalGanttWidth;
    _ganttHorizontalScrollController.jumpTo(newScrollOffset.clamp(0.0, position.maxScrollExtent));
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  void _showTooltip(BuildContext context, LegacyGanttTask task, Offset globalPosition) {
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
  }

  void _handleTaskUpdate(LegacyGanttTask task, DateTime newStart, DateTime newEnd) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Updated ${task.name}: ${DateFormat.yMd().format(newStart)} - ${DateFormat.yMd().format(newEnd)}'),
      ),
    );

    final newTasks = List<LegacyGanttTask>.from(_ganttTasks);
    final index = newTasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      newTasks[index] = newTasks[index].copyWith(start: newStart, end: newEnd);
      if (_apiResponse != null) {
        final (recalculatedTasks, newMaxDepth) = _scheduleService.publicCalculateTaskStacking(newTasks, _apiResponse!);
        setState(() {
          _ganttTasks = recalculatedTasks;
          _rowMaxStackDepth = newMaxDepth;
        });
      }
    }
  }

  // --- Grid Specific Logic ---
  static const double _rowHeight = 27.0; // Base row height

  List<GanttGridData> get _visibleGridData {
    if (_visibleStartDate == null || _visibleEndDate == null) {
      return _gridData; // Before dates are set, show everything from initial fetch
    }

    // 1. Find all row IDs that have tasks within the visible range.
    // We only care about actual event tasks, not background highlights.
    final activeRowIdsInView = _ganttTasks
        .where((task) =>
            !task.isTimeRangeHighlight && task.start.isBefore(_visibleEndDate!) && task.end.isAfter(_visibleStartDate!))
        .map((task) => task.rowId)
        .toSet();

    if (activeRowIdsInView.isEmpty) {
      return [];
    }

    // 2. Filter the master grid data based on these active rows.
    final List<GanttGridData> filteredData = [];
    for (final parent in _gridData) {
      // A child is visible if it has an active task in the current view.
      final visibleChildren = parent.children.where((child) => activeRowIdsInView.contains(child.id)).toList();

      // A parent is visible if it has a direct task OR any of its children are visible.
      final bool isParentActive = activeRowIdsInView.contains(parent.id);

      if (isParentActive || visibleChildren.isNotEmpty) {
        // We add a new GanttGridData object, but this time, it only contains
        // the children that are themselves visible.
        filteredData.add(GanttGridData(
            id: parent.id,
            name: parent.name,
            isParent: parent.isParent,
            taskName: parent.taskName,
            completion: parent.completion,
            isExpanded: parent.isExpanded,
            children: visibleChildren));
      }
    }
    return filteredData;
  }

  List<LegacyGanttRow> get _visibleGanttRows {
    final List<LegacyGanttRow> rows = [];
    for (final item in _visibleGridData) {
      rows.add(LegacyGanttRow(id: item.id));
      if (item.isParent && item.isExpanded) {
        rows.addAll(item.children.map((child) => LegacyGanttRow(id: child.id)));
      }
    }
    return rows;
  }

  double _calculateGanttWidth(double screenWidth) {
    if (_effectiveTotalStartDate == null ||
        _effectiveTotalEndDate == null ||
        _visibleStartDate == null ||
        _visibleEndDate == null) {
      return screenWidth;
    }
    final totalDuration = _effectiveTotalEndDate!.difference(_effectiveTotalStartDate!).inMilliseconds;
    final visibleDuration = _visibleEndDate!.difference(_visibleStartDate!).inMilliseconds;

    if (visibleDuration <= 0) return screenWidth;

    final zoomFactor = totalDuration / visibleDuration;
    return screenWidth * zoomFactor;
  }

  void _toggleExpansion(String id) {
    setState(() {
      final item = _gridData.firstWhere((element) => element.id == id);
      item.isExpanded = !item.isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final ganttTheme = LegacyGanttTheme.fromTheme(Theme.of(context)).copyWith(
      barColorPrimary: Colors.blue[800],
      barColorSecondary: Colors.blue[600],
      textColor: colorScheme.onSurface,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      showRowBorders: true,
      taskTextStyle: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
    );

    return Scaffold(
      body: Column(
        children: [
          DashboardHeader(
            selectedDate: _startDate,
            selectedRange: _range,
            onSelectDate: _selectDate,
            onRangeChange: _onRangeChange,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _gridWidth ??= constraints.maxWidth * 0.4;

                return Row(
                  children: [
                    // Gantt Grid (Left Side)
                    SizedBox(
                      width: _gridWidth,
                      child: GanttGrid(
                        gridData: _visibleGridData,
                        visibleGanttRows: _visibleGanttRows,
                        rowMaxStackDepth: _rowMaxStackDepth,
                        scrollController: _scrollController,
                        onToggleExpansion: _toggleExpansion,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    // Draggable Divider
                    GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          final newWidth = _gridWidth! + details.delta.dx;
                          // Clamp width to reasonable bounds
                          _gridWidth = newWidth.clamp(150.0, constraints.maxWidth - 150.0);
                        });
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: VerticalDivider(
                          width: 8,
                          thickness: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    // Gantt Chart (Right Side)
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, chartConstraints) {
                                // If data is still loading or not set, show a progress indicator
                                if (_ganttTasks.isEmpty && _gridData.isEmpty) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final ganttWidth = _calculateGanttWidth(chartConstraints.maxWidth);

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  controller: _ganttHorizontalScrollController,
                                  child: SizedBox(
                                    width: ganttWidth,
                                    height: chartConstraints.maxHeight, // Constraints from LayoutBuilder
                                    child: LegacyGanttChartWidget(
                                      scrollController: _scrollController, // Link to grid scroll controller
                                      data: _ganttTasks,
                                      visibleRows: _visibleGanttRows,
                                      rowHeight: _rowHeight,
                                      rowMaxStackDepth: _rowMaxStackDepth,
                                      axisHeight: _rowHeight, // Match grid header height
                                      gridMin: _visibleStartDate?.millisecondsSinceEpoch.toDouble(),
                                      gridMax: _visibleEndDate?.millisecondsSinceEpoch.toDouble(),
                                      totalGridMin: _effectiveTotalStartDate?.millisecondsSinceEpoch.toDouble(),
                                      totalGridMax: _effectiveTotalEndDate?.millisecondsSinceEpoch.toDouble(),
                                      enableDragAndDrop: true, // Enable drag and drop
                                      enableResize: true, // Enable resizing
                                      onTaskUpdate: _handleTaskUpdate, // Handle updates from drag/resize
                                      resizeTooltipDateFormat: (date) =>
                                          DateFormat('MMM d, h:mm a').format(date.toLocal()),
                                      resizeTooltipBackgroundColor: Colors.purple,
                                      resizeTooltipFontColor: Colors.white,
                                      onTaskHover: (task, globalPosition) {
                                        if (_hoveredTaskId == task?.id) return;
                                        setState(() {
                                          _hoveredTaskId = task?.id;
                                          _removeTooltip();
                                          if (task != null && !task.isTimeRangeHighlight) {
                                            // Don't show tooltip for highlights
                                            _showTooltip(context, task, globalPosition);
                                          }
                                        });
                                      },
                                      onPressTask: (task) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Tapped on task: ${task.name}')),
                                        );
                                      },
                                      theme: ganttTheme,
                                      taskContentBuilder: (task) {
                                        if (task.isTimeRangeHighlight) {
                                          return const SizedBox.shrink(); // Hide content for highlights
                                        }

                                        final barColor = task.color ?? ganttTheme.barColorPrimary;
                                        final textColor =
                                            ThemeData.estimateBrightnessForColor(barColor) == Brightness.dark
                                                ? Colors.white
                                                : Colors.black;
                                        final textStyle = ganttTheme.taskTextStyle.copyWith(color: textColor);

                                        return ClipRect(
                                          child: LayoutBuilder(builder: (context, constraints) {
                                            const double iconSize = 16.0;
                                            const double padding = 4.0;
                                            const double spacing = 4.0;

                                            final bool canShowIcon = constraints.maxWidth > iconSize + padding * 2;
                                            final bool canShowText = constraints.maxWidth >
                                                iconSize + spacing + padding * 2 + 10; // +10 for some text

                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: padding),
                                              child: Row(
                                                children: [
                                                  if (canShowIcon) ...[
                                                    if (task.isSummary)
                                                      Icon(Icons.summarize, color: textColor, size: iconSize)
                                                    else if (task.isOverlapIndicator)
                                                      const Icon(Icons.warning, color: Colors.yellow, size: iconSize)
                                                    else // Regular task
                                                      Icon(Icons.task, color: textColor, size: iconSize),
                                                  ],
                                                  if (canShowText) ...[
                                                    const SizedBox(width: spacing),
                                                    Expanded(
                                                      child: Text(
                                                        task.name ?? '',
                                                        style: textStyle,
                                                        overflow: TextOverflow.ellipsis,
                                                        softWrap: false,
                                                      ),
                                                    ),
                                                  ]
                                                ],
                                              ),
                                            );
                                          }),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // --- Timeline Scrubber ---
                          if (_totalStartDate != null &&
                              _totalEndDate != null &&
                              _visibleStartDate != null &&
                              _visibleEndDate != null)
                            Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              color: Theme.of(context).cardColor,
                              child: LegacyGanttTimelineScrubber(
                                totalStartDate: _totalStartDate!,
                                totalEndDate: _totalEndDate!,
                                visibleStartDate: _visibleStartDate!,
                                visibleEndDate: _visibleEndDate!,
                                onWindowChanged: _onScrubberWindowChanged,
                                tasks: _ganttTasks,
                                startPadding: _ganttStartPadding,
                                endPadding: _ganttEndPadding,
                              ),
                            ),
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
