# Internal Utilities

This document outlines some of the core internal utility functions and logic used throughout the Gantt chart package. These functions are not part of the public API but are crucial for rendering and interaction.

## Painting Utilities (`bars_collection_painter.dart`)

The `BarsCollectionPainter` uses several helper methods to draw complex patterns on the canvas efficiently.

### `_drawAngledPattern`

This is a generic helper function responsible for drawing repeating diagonal lines within a given rounded rectangle (`RRect`). It's the foundation for both summary and conflict bar styles.

-   **Purpose:** To create a striped pattern.
-   **Usage:** It is called by `_drawSummaryPattern` and `_drawOverlapPattern`.
-   **How it works:**
    1.  It takes a `Canvas`, the target `RRect`, a `Color`, and a `strokeWidth`.
    2.  It saves the canvas state and clips the drawing area to the provided `RRect` to ensure the pattern does not spill outside the bar's boundaries.
    3.  It iterates from outside the left edge to beyond the right edge of the rectangle, drawing diagonal lines at a constant spacing (`lineSpacing`).
    4.  Finally, it restores the canvas state.

### `_drawSummaryPattern`

Draws the visual indicator for a summary task.

-   **Purpose:** To visually distinguish summary bars from regular task bars.
-   **How it works:** It calls `_drawAngledPattern` with the `summaryBarColor` from the theme.

### `_drawOverlapPattern`

Draws the visual indicator for a task conflict or overlap.

-   **Purpose:** To highlight areas where tasks are overlapping in a way that is not allowed (i.e., exceeding the `rowMaxStackDepth`).
-   **How it works:**
    1.  It first draws a solid rectangle with the chart's `backgroundColor` to "erase" any content underneath it.
    2.  It then draws a semi-transparent background using the `conflictBarColor`.
    3.  Finally, it calls `_drawAngledPattern` with the `conflictBarColor` to draw the striped lines on top, creating a distinct warning pattern.

## Coordinate & Date Conversion Utilities

### `dateToX` (`legacy_gantt_timeline_scrubber.dart`)

A simple but critical function within the `_ScrubberPainter` that converts a `DateTime` object into a horizontal (X-axis) pixel coordinate.

-   **Purpose:** To position the timeline scrubber's window and task highlights correctly.
-   **How it works:** It calculates the percentage of time that has passed from the `totalStartDate` to the given `date` and multiplies that by the total available width of the scrubber widget.

### `vm.totalScale` (`legacy_gantt_view_model.dart` via `legacy_gantt_chart_widget.dart`)

While not a standalone function, the `totalScale` function object within the `LegacyGanttViewModel` is the primary utility for date-to-pixel conversion in the main chart view.

-   **Purpose:** To convert any `DateTime` into an X-coordinate for positioning grid lines, bars, and other elements on the main Gantt chart canvas.
-   **How it works:** The view model creates a linear scale that maps a domain (the total time range from `totalGridMin` to `totalGridMax`) to a range (the pixel width of the chart). The `totalScale(date)` function then returns the corresponding pixel value.

## Widget Building Utilities (`legacy_gantt_chart_widget.dart`)

The main widget uses helper methods to build lists of `Positioned` widgets when custom builders are provided.

### `_buildCustomTaskWidgets`

-   **Purpose:** To render custom widgets for each task when a `taskBarBuilder` or `taskContentBuilder` is provided.
-   **How it works:** It iterates through all visible tasks, calculates their position (`left`, `top`) and size (`width`, `height`) using the view model's `totalScale` and row layout information, and creates a `Positioned` widget for each one, using the provided builder function to create the child.

### `_buildCustomCellWidgets`

-   **Purpose:** To render custom widgets for each day within a task's date range when a `cellBuilder` is provided on a `LegacyGanttTask`.
-   **How it works:**
    1.  It iterates through tasks that have a `cellBuilder`.
    2.  For each task, it then iterates through each day from the task's start to its end.
    3.  For each day, it calculates the precise start and end coordinates for that day's segment within the task bar.
    4.  It creates a `Positioned` widget for that daily segment, using the `cellBuilder` to generate the content. This allows for day-by-day customization within a single task bar.