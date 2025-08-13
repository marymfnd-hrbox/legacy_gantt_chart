// packages/gantt_chart/lib/src/gantt_chart_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/legacy_gantt_task.dart';
import 'models/legacy_gantt_theme.dart';
import 'models/legacy_gantt_row.dart';
import 'axis_painter.dart';
import 'legacy_gantt_controller.dart';
import 'legacy_gantt_view_model.dart';
import 'bars_collection_painter.dart';

class LegacyGanttChartWidget extends StatefulWidget {
  final List<LegacyGanttTask>? data;

  /// A list of tasks to be rendered as background highlights, such as holidays
  /// or weekends. These tasks should have `isTimeRangeHighlight` set to `true`.
  /// This is ignored if a [controller] is provided.
  final List<LegacyGanttTask>? holidays;
  final List<LegacyGanttRow> visibleRows;
  final int numberOfTicks;
  final Function(LegacyGanttTask)? onPressTask; //
  final Function(LegacyGanttTask?, Offset globalPosition)? onTaskHover;
  final ScrollController? scrollController;
  final double? axisHeight;
  final Map<String, int> rowMaxStackDepth;
  final double rowHeight;
  final LegacyGanttTheme? theme;
  final double? gridMin; // Unix timestamp or milliseconds since epoch
  final double? gridMax; // Unix timestamp or milliseconds since epoch
  final double? totalGridMin; // The start of the entire dataset's time range
  final double? totalGridMax; // The end of the entire dataset's time range
  final bool enableDragAndDrop;
  final bool enableResize;

  /// A future that resolves to the list of tasks to display.
  /// This is ignored if a [controller] is provided.
  final Future<List<LegacyGanttTask>>? tasksFuture;

  /// A future that resolves to a list of holiday/highlight tasks.
  /// This is ignored if a [controller] is provided.
  final Future<List<LegacyGanttTask>>? holidaysFuture;
  final LegacyGanttController? controller;
  final Widget Function(LegacyGanttTask task)? taskBarBuilder;

  /// A builder to create custom content to be displayed inside a task bar.
  /// The chart will still draw the bar's background.
  /// This cannot be used simultaneously with [taskBarBuilder].
  final Widget Function(LegacyGanttTask task)? taskContentBuilder;
  final Function(LegacyGanttTask task, DateTime newStart, DateTime newEnd)?
      onTaskUpdate;

  const LegacyGanttChartWidget({
    super.key, // Use super.key
    this.data,
    this.holidays,
    required this.visibleRows,
    required this.rowMaxStackDepth,
    this.numberOfTicks = 4,
    this.onTaskHover,
    this.scrollController,
    this.axisHeight,
    this.rowHeight = 27.0,
    this.onPressTask,
    this.theme,
    this.gridMin,
    this.gridMax,
    this.totalGridMin,
    this.totalGridMax,
    this.enableDragAndDrop = false,
    this.enableResize = false,
    this.tasksFuture,
    this.holidaysFuture,
    this.controller,
    this.taskBarBuilder,
    this.taskContentBuilder,
    this.onTaskUpdate,
  })  : assert(
            controller != null ||
                ((data != null && tasksFuture == null) ||
                    (data == null && tasksFuture != null)),
            'If a controller is not used, exactly one of tasksFuture or data must be provided.'),
        assert(taskBarBuilder == null || taskContentBuilder == null,
            'Cannot provide both taskBarBuilder and taskContentBuilder. taskBarBuilder replaces the entire bar, while taskContentBuilder only replaces its content.'),
        assert(
            controller == null ||
                (data == null &&
                    tasksFuture == null &&
                    holidays == null &&
                    holidaysFuture == null &&
                    gridMin == null &&
                    gridMax == null),
            'When a controller is provided, data, tasksFuture, holidays, holidaysFuture, gridMin, and gridMax must be null, as they are managed by the controller.');

  @override
  State<LegacyGanttChartWidget> createState() => _LegacyGanttChartWidgetState();
}

class _LegacyGanttChartWidgetState extends State<LegacyGanttChartWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final LegacyGanttTheme effectiveTheme =
        widget.theme ?? LegacyGanttTheme.fromTheme(theme);

    if (widget.controller != null) {
      return AnimatedBuilder(
        animation: widget.controller!,
        builder: (context, child) {
          final controller = widget.controller!;
          final tasks = controller.tasks;
          final holidays = controller.holidays;
          final allItems = [...tasks, ...holidays];

          // Handle initial loading state when there are no tasks yet.
          if (controller.isOverallLoading && allItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (allItems.isEmpty && !controller.isOverallLoading) {
            return Center(
              child: Text('No data to display.',
                  style: TextStyle(color: effectiveTheme.textColor)),
            );
          }

          // Use a Stack to overlay a loading indicator on top of the existing chart
          // when reloading data. This provides a smoother user experience.
          return Stack(
            children: [
              _buildChart(
                context,
                allItems,
                effectiveTheme,
                gridMin: controller.visibleStartDate.millisecondsSinceEpoch
                    .toDouble(),
                gridMax:
                    controller.visibleEndDate.millisecondsSinceEpoch.toDouble(),
              ),
              if (controller.isLoading)
                Container(
                  color: effectiveTheme.backgroundColor.withValues(alpha: 0.5),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      );
    }

    if (widget.tasksFuture != null || widget.holidaysFuture != null) {
      return FutureBuilder<List<dynamic>>(
        future: Future.wait([
          widget.tasksFuture ?? Future.value(<LegacyGanttTask>[]),
          widget.holidaysFuture ?? Future.value(<LegacyGanttTask>[])
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final tasks = (snapshot.data?[0] as List<LegacyGanttTask>?) ?? [];
          final holidays = (snapshot.data?[1] as List<LegacyGanttTask>?) ?? [];
          final allItems = [...tasks, ...holidays];

          if (allItems.isEmpty) {
            return Center(
              child: Text('No data to display.',
                  style: TextStyle(color: effectiveTheme.textColor)),
            );
          }
          return _buildChart(context, allItems, effectiveTheme);
        },
      );
    } else {
      final tasks = widget.data ?? [];
      final holidays = widget.holidays ?? [];
      final allItems = [...tasks, ...holidays];
      if (allItems.isEmpty) {
        return Center(
          child: Text('No data to display.',
              style: TextStyle(color: effectiveTheme.textColor)),
        );
      }
      return _buildChart(context, allItems, effectiveTheme);
    }
  }

  Widget _buildChart(BuildContext context, List<LegacyGanttTask> tasks,
      LegacyGanttTheme effectiveTheme,
      {double? gridMin, double? gridMax}) {
    return ChangeNotifierProvider(
      // Use a key to ensure the ViewModel is recreated if the core data changes.
      key: ValueKey(tasks.hashCode ^
          widget.visibleRows.hashCode ^
          widget.rowMaxStackDepth.hashCode),
      create: (_) => LegacyGanttViewModel(
        data: tasks,
        // Pass all other widget properties to the ViewModel
        visibleRows: widget.visibleRows,
        rowMaxStackDepth: widget.rowMaxStackDepth,
        rowHeight: widget.rowHeight,
        axisHeight: widget.axisHeight,
        gridMin: gridMin ?? widget.gridMin,
        gridMax: gridMax ?? widget.gridMax,
        totalGridMin: widget.totalGridMin,
        totalGridMax: widget.totalGridMax,
        enableDragAndDrop: widget.enableDragAndDrop,
        enableResize: widget.enableResize,
        onTaskUpdate: widget.onTaskUpdate,
        onPressTask: widget.onPressTask,
        onTaskHover: widget.onTaskHover,
        taskBarBuilder: widget.taskBarBuilder,
        scrollController: widget.scrollController,
        // taskContentBuilder is handled directly in the widget's build method.
      ),
      child: Consumer<LegacyGanttViewModel>(
        builder: (context, vm, child) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth == 0 || constraints.maxHeight == 0) {
                return const SizedBox
                    .shrink(); // Avoid calculations if we have no space
              }

              // Inform the ViewModel of the available layout space.
              vm.updateLayout(constraints.maxWidth, constraints.maxHeight);

              // The rest of the UI rebuilds automatically when the VM's state changes.
              final double totalContentWidth = vm.totalDomain.isEmpty
                  ? 0
                  : vm.totalScale(vm.totalDomain.last);

              // Calculate the total height of all rows to provide the correct size to the painter.
              final double totalContentHeight = widget.visibleRows.fold<double>(
                0.0,
                (prev, row) =>
                    prev +
                    widget.rowHeight * (widget.rowMaxStackDepth[row.id] ?? 1),
              );

              return MouseRegion(
                cursor: vm.cursor,
                onHover: vm.onHover,
                onExit: vm.onHoverExit,
                child: GestureDetector(
                  onPanStart: vm.onPanStart,
                  onPanUpdate: vm.onPanUpdate,
                  onPanEnd: vm.onPanEnd,
                  onTapUp: vm.onTapUp,
                  child: Container(
                    color: effectiveTheme.backgroundColor,
                    child: Stack(
                      children: [
                        // Layer 1: Background Grid Lines.
                        Positioned.fill(
                          child: Transform.translate(
                            offset: Offset(-vm.scrollOffset, 0),
                            child: CustomPaint(
                              painter: AxisPainter(
                                x: 0,
                                y: vm.timeAxisHeight,
                                width: totalContentWidth,
                                height: constraints.maxHeight,
                                scale: vm.totalScale,
                                domain: vm.totalDomain,
                                ticks: widget.numberOfTicks,
                                theme: effectiveTheme.copyWith(
                                    axisTextStyle: const TextStyle(
                                        color: Colors.transparent)),
                              ),
                            ),
                          ),
                        ),

                        // Layer 2: Bars Layer (scrollable).
                        Positioned(
                          top: vm.timeAxisHeight,
                          left: 0,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight - vm.timeAxisHeight,
                          child: ClipRect(
                            child: Transform.translate(
                              offset: Offset(-vm.scrollOffset, vm.translateY),
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    painter: BarsCollectionPainter(
                                      data: tasks,
                                      domain: vm.totalDomain,
                                      visibleRows: widget.visibleRows,
                                      rowMaxStackDepth: widget.rowMaxStackDepth,
                                      scale: vm.totalScale,
                                      rowHeight: widget.rowHeight,
                                      draggedTaskId: vm.draggedTask?.id,
                                      ghostTaskStart: vm.ghostTaskStart,
                                      ghostTaskEnd: vm.ghostTaskEnd,
                                      theme: effectiveTheme,
                                      hasCustomTaskBuilder:
                                          widget.taskBarBuilder != null,
                                      hasCustomTaskContentBuilder:
                                          widget.taskContentBuilder != null,
                                    ),
                                    size: Size(
                                        totalContentWidth, totalContentHeight),
                                  ),
                                  if (widget.taskBarBuilder != null)
                                    ..._buildCustomTaskWidgets(
                                        vm, tasks, widget.taskBarBuilder!),
                                  if (widget.taskContentBuilder != null)
                                    ..._buildCustomTaskWidgets(
                                        vm, tasks, widget.taskContentBuilder!),
                                  ..._buildCustomCellWidgets(vm, tasks),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Layer 3: Header Foreground.
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: vm.timeAxisHeight,
                          child: Container(
                            color: effectiveTheme.backgroundColor,
                            child: ClipRect(
                              child: Transform.translate(
                                offset: Offset(-vm.scrollOffset, 0),
                                child: CustomPaint(
                                  size: Size(
                                      totalContentWidth, vm.timeAxisHeight),
                                  painter: AxisPainter(
                                    x: 0,
                                    y: vm.timeAxisHeight / 2,
                                    width: totalContentWidth,
                                    height: 0,
                                    scale: vm.totalScale,
                                    domain: vm.totalDomain,
                                    ticks: widget.numberOfTicks,
                                    theme: effectiveTheme,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildCustomTaskWidgets(
      LegacyGanttViewModel vm,
      List<LegacyGanttTask> tasks,
      Widget Function(LegacyGanttTask task) builder) {
    final List<Widget> customWidgets = [];
    double cumulativeRowTop = 0;

    final Map<String, List<LegacyGanttTask>> tasksByRow = {};
    final visibleRowIds = vm.visibleRows.map((r) => r.id).toSet();
    for (final task in tasks) {
      if (visibleRowIds.contains(task.rowId) &&
          !task.isTimeRangeHighlight &&
          !task.isOverlapIndicator) {
        tasksByRow.putIfAbsent(task.rowId, () => []).add(task);
      }
    }

    for (final rowData in vm.visibleRows) {
      final tasksInThisRow = tasksByRow[rowData.id] ?? [];
      for (final task in tasksInThisRow) {
        final startX = vm.totalScale(task.start);
        final endX = vm.totalScale(task.end);
        final width = endX - startX;

        if (width <= 0) {
          continue;
        }

        final top = cumulativeRowTop + (task.stackIndex * vm.rowHeight);

        customWidgets.add(Positioned(
            left: startX,
            top: top,
            width: width,
            height: vm.rowHeight,
            child: builder(task)));
      }
      final stackDepth = vm.rowMaxStackDepth[rowData.id] ?? 1;
      cumulativeRowTop += vm.rowHeight * stackDepth;
    }
    return customWidgets;
  }

  List<Widget> _buildCustomCellWidgets(
      LegacyGanttViewModel vm, List<LegacyGanttTask> tasks) {
    final List<Widget> customCells = [];
    double cumulativeRowTop = 0;

    final Map<String, List<LegacyGanttTask>> tasksByRow = {};
    final visibleRowIds = vm.visibleRows.map((r) => r.id).toSet();
    for (final task in tasks) {
      // Only consider tasks that have a cellBuilder
      if (visibleRowIds.contains(task.rowId) && task.cellBuilder != null) {
        tasksByRow.putIfAbsent(task.rowId, () => []).add(task);
      }
    }

    for (final rowData in vm.visibleRows) {
      final tasksInThisRow = tasksByRow[rowData.id] ?? [];
      for (final task in tasksInThisRow) {
        final taskStart = task.start;
        final taskEnd = task.end;

        // Iterate through each day the task spans
        var currentDate =
            DateTime(taskStart.year, taskStart.month, taskStart.day);
        while (currentDate.isBefore(taskEnd)) {
          final segmentStart =
              taskStart.isAfter(currentDate) ? taskStart : currentDate;
          final nextDay = currentDate.add(const Duration(days: 1));
          final segmentEnd = taskEnd.isBefore(nextDay) ? taskEnd : nextDay;

          final startX = vm.totalScale(segmentStart);
          final endX = vm.totalScale(segmentEnd);
          final width = endX - startX;

          if (width > 0) {
            final top = cumulativeRowTop + (task.stackIndex * vm.rowHeight);
            customCells.add(Positioned(
                left: startX,
                top: top,
                width: width,
                height: vm.rowHeight,
                child: task.cellBuilder!(currentDate)));
          }
          currentDate = nextDay;
        }
      }
      final stackDepth = vm.rowMaxStackDepth[rowData.id] ?? 1;
      cumulativeRowTop += vm.rowHeight * stackDepth;
    }
    return customCells;
  }
}
