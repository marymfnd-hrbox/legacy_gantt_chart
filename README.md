# Legacy Gantt Chart

[![Pub Version](https://img.shields.io/pub/v/legacy_gantt_chart)](https://pub.dev/packages/legacy_gantt_chart)
[![Live Demo](https://img.shields.io/badge/live-demo-brightgreen)](https://barneysspeedshop.github.io/legacy_gantt_chart/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A flexible and performant Gantt chart widget for Flutter. Supports interactive drag-and-drop, resizing, dynamic data loading, and extensive theming.

## About the Name

The name `legacy_gantt_chart` is a tribute to the package's author, Patrick Legacy. It does not imply that the package is outdated or unmaintained. In fact, it is a modern, actively developed, and highly capable solution for building production-ready Flutter applications.

[![Legacy Gantt Chart Example](https://github.com/barneysspeedshop/legacy_gantt_chart/raw/main/assets/example.png)](https://barneysspeedshop.github.io/legacy_gantt_chart/)

---

## Features

-   **Robust Architecture:** The accompanying example application showcases a scalable Model-View-ViewModel (MVVM) architecture with `provider` for state management, providing a clear blueprint for real-world use. Please feel free to use the example as a starting point for integrating into your application. 
-   **Scalability:** Highly performant rendering for projects with over 10,000 tasks.
-   **Performant Rendering:** Uses `CustomPainter` for efficient rendering of a large number of tasks and grid lines.
-   **Dynamic Data Loading:** Fetch tasks asynchronously for the visible date range using a `LegacyGanttController`.
-   **Full CRUD Support:** Create, read, update, and delete tasks with intuitive UI interactions and callbacks.
-   **Task Options Menu:** Right-click or tap a task's option icon to access actions like copy, delete, and dependency management.
-   **Interactive Dependency Creation:** Users can visually create dependencies by dragging a connector from one task to another.
-   **Task Dependencies:** Define and visualize relationships between tasks. Supports Finish-to-Start, Start-to-Start, Finish-to-Finish, Start-to-Finish, and Contained dependency types.
-   **Task Stacking:** Automatically stacks overlapping tasks within the same row.
-   **Customization:**
    -   Extensive theming support via `LegacyGanttTheme`.
    -   Use custom builders (`taskBarBuilder`, `taskContentBuilder`) to render completely unique task widgets.
-   **Unique Timeline Scrubber:** Navigate vast timelines with ease using the `LegacyGanttTimelineScrubber`. Inspired by professional audio/visual editing software, this powerful widget provides a high-level overview of the entire project. It features dynamic viewbox zooming, which intelligently frames the selected date range for enhanced precision. Fade indicators at the edges and a convenient "Reset Zoom" button appear when zoomed, ensuring you never lose track of your position or struggle to get back to the full view. This advanced navigation system is unique among Gantt libraries on pub.dev and sets this package apart.
-   **Special Task Types & Visual Cues:** The chart uses specific visual patterns to convey important information at a glance:
    -   **Summary Bars (Angled Pattern):** A summary bar depicts a resource's overall time allocation (e.g., a developer's work week). The angled pattern signifies it's a container for other tasks. Child rows underneath show the specific tasks that consume this allocated time, making it easy to see how the resource's time is being used and whether they have availability.
    -   **Conflict Indicators (Red Angled Pattern):** This pattern is used to raise awareness of contemporaneous activity that exceeds capacity. It typically appears when more tasks are scheduled in a row than the `rowMaxStackDepth` allows, highlighting over-allocation or scheduling issues.
    -   **Background Highlights:** Simple colored rectangles used to denote special time ranges like weekends, holidays, or periods of unavailability for a specific resource.

---

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  legacy_gantt_chart: ^1.0.1 # Replace with the latest version
```

Then, you can install the package using the command-line:

```shell
flutter pub get
```

Now, import it in your Dart code:

```dart
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';
```

---

## Quick Start

Here is a minimal example of how to create a static Gantt chart.

```dart
import 'package:flutter/material.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';

class MinimalGanttChart extends StatelessWidget {
  const MinimalGanttChart({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Define your rows
    final rows = [
      LegacyGanttRow(id: 'row1', name: 'Development'),
      LegacyGanttRow(id: 'row2', name: 'QA'),
    ];

    // 2. Define your tasks
    final tasks = [
      LegacyGanttTask(
        id: 'task1',
        rowId: 'row1',
        name: 'Implement Feature A',
        start: DateTime.now().subtract(const Duration(days: 5)),
        end: DateTime.now().add(const Duration(days: 2)),
      ),
      LegacyGanttTask(
        id: 'task2',
        rowId: 'row1',
        name: 'Implement Feature B',
        start: DateTime.now().add(const Duration(days: 3)),
        end: DateTime.now().add(const Duration(days: 8)),
      ),
      LegacyGanttTask(
        id: 'task3',
        rowId: 'row2',
        name: 'Test Feature A',
        start: DateTime.now().add(const Duration(days: 2)),
        end: DateTime.now().add(const Duration(days: 4)),
      ),
    ];

    // 3. Create the widget
    return Scaffold(
      appBar: AppBar(title: const Text('Simple Gantt Chart')),
      body: LegacyGanttChartWidget(
        data: tasks,
        visibleRows: rows,
        rowMaxStackDepth: const {'row1': 2, 'row2': 1}, // Max overlapping tasks per row
        gridMin: DateTime.now().subtract(const Duration(days: 10)).millisecondsSinceEpoch.toDouble(),
        gridMax: DateTime.now().add(const Duration(days: 15)).millisecondsSinceEpoch.toDouble(),
      ),
    );
  }
}
```

## Running the Example

To see a full-featured demo of the `legacy_gantt_chart` in action, you can run the example application included in the repository.

1.  **Navigate to the `example` directory:**
    ```shell
    cd example
    ```

2.  **Install dependencies:**
    ```shell
    flutter pub get
    ```

3.  **Run the app:**
    ```shell
    flutter run
    ```

## API Documentation 

For a complete overview of all available classes, methods, and properties, please see the API reference on pub.dev.

## Advanced Usage

### Dynamic Data Loading with `LegacyGanttController`

For real-world applications, you'll often need to load data from a server based on the visible date range. The `LegacyGanttController` is designed for this purpose.

```dart
class DynamicGanttChartPage extends StatefulWidget {
  @override
  _DynamicGanttChartPageState createState() => _DynamicGanttChartPageState();
}

class _DynamicGanttChartPageState extends State<DynamicGanttChartPage> {
  late final LegacyGanttController _controller;
  final List<LegacyGanttRow> _rows = [LegacyGanttRow(id: 'row1')];

  @override
  void initState() {
    super.initState();
    _controller = LegacyGanttController(
      initialVisibleStartDate: DateTime.now().subtract(const Duration(days: 15)),
      initialVisibleEndDate: DateTime.now().add(const Duration(days: 15)),
      tasksAsync: _fetchTasks, // Your data fetching function
    );
  }

  Future<List<LegacyGanttTask>> _fetchTasks(DateTime start, DateTime end) async {
    print('Fetching tasks from $start to $end...');
    // In a real app, you would make a network request here.
    await Future.delayed(const Duration(seconds: 1));
    return [
      LegacyGanttTask(
        id: 'server_task_1',
        rowId: 'row1',
        name: 'Database Migration',
        start: start.add(const Duration(days: 2)),
        end: start.add(const Duration(days: 5)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dynamic Gantt Chart')),
      body: LegacyGanttChartWidget(
        controller: _controller,
        visibleRows: _rows,
        rowMaxStackDepth: const {'row1': 1},
      ),
    );
  }
}
```

### Timeline Navigation with `LegacyGanttTimelineScrubber`

Combine the `LegacyGanttController` with the `LegacyGanttTimelineScrubber` to provide users with a powerful way to navigate the chart's timeline.

```dart
Column(
  children: [
    Expanded(
      child: LegacyGanttChartWidget(
        controller: _controller,
        // ... other properties
      ),
    ),
    // The Scrubber
    LegacyGanttTimelineScrubber(
      totalStartDate: DateTime(2023, 1, 1),
      totalEndDate: DateTime(2024, 12, 31),
      visibleStartDate: _controller.visibleStartDate,
      visibleEndDate: _controller.visibleEndDate,
      tasks: _controller.tasks, // Show tasks in the scrubber overview
      onWindowChanged: (newStart, newEnd) {
        _controller.setVisibleRange(newStart, newEnd);
      },
    ),
  ],
)
```

### Interactive Tasks (Drag & Drop, Resize)

Enable interactivity and listen for updates using the `onTaskUpdate` callback.

```dart
LegacyGanttChartWidget(
  // ... other properties
  enableDragAndDrop: true,
  enableResize: true,
  onTaskUpdate: (task, newStart, newEnd) {
    // Here you would update your state and likely call an API
    // to persist the changes.
  },
)
```

### Custom Task Appearance

Use `taskContentBuilder` to replace the content *inside* the task bar, or `taskBarBuilder` to replace the *entire* task bar widget for full control.

```dart
LegacyGanttChartWidget(
  // ... other properties
  taskContentBuilder: (task) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.yellow, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              task.name ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  },
)
```

### Theming

Customize colors, text styles, and more by providing a `LegacyGanttTheme`.

```dart
LegacyGanttChartWidget(
  // ... other properties
  theme: LegacyGanttTheme.fromTheme(Theme.of(context)).copyWith(
    barColorPrimary: Colors.green,
    gridColor: Colors.grey.shade800,
  ),
)
```


## API Documentation

For a complete overview of all available classes, methods, and properties, please see the API reference on pub.dev.

---

## Contributing

Contributions are welcome! Please see our [Contributing Guidelines](CONTRIBUTING.md) for more details on how to get started, including our code style guide.


## License

This project is licensed under the MIT License.