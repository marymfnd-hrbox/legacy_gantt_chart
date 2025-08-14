import 'package:flutter/material.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';
import '../gantt_grid_data.dart';

class GanttGrid extends StatelessWidget {
  final List<GanttGridData> gridData;
  final List<LegacyGanttRow> visibleGanttRows;
  final Map<String, int> rowMaxStackDepth;
  final ScrollController scrollController;
  final Function(String) onToggleExpansion;
  final bool isDarkMode;

  const GanttGrid({
    super.key,
    required this.gridData,
    required this.visibleGanttRows,
    required this.rowMaxStackDepth,
    required this.scrollController,
    required this.onToggleExpansion,
    required this.isDarkMode,
  });

  static const double _rowHeight = 27.0;

  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        color: isDarkMode ? Colors.grey[850] : Colors.white,
      ),
      child: Column(
        children: [
          _buildGridHeader(isDarkMode),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: visibleGanttRows.length,
              itemBuilder: (context, index) {
                final rowId = visibleGanttRows[index].id;
                GanttGridData? data;
                for (final parent in gridData) {
                  if (parent.id == rowId) {
                    data = parent;
                    break;
                  }
                  for (final child in parent.children) {
                    if (child.id == rowId) {
                      data = child;
                      break;
                    }
                  }
                  if (data != null) break;
                }

                if (data == null) {
                  return const SizedBox.shrink();
                }
                return _buildGridRow(data, isDarkMode);
              },
            ),
          ),
        ],
      ),
    );

  Widget _buildGridHeader(bool isDarkMode) => Container(
        height: _rowHeight,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
          border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
        ),
        child: Row(
          children: [
            Expanded(flex: 2, child: _buildHeaderCell('Name')),
            Expanded(flex: 1, child: _buildHeaderCell('Completed %')),
          ],
        ),
      );

  Widget _buildGridRow(GanttGridData data, bool isDarkMode) {
    final int stackDepth = rowMaxStackDepth[data.id] ?? 1;
    final double dynamicRowHeight = _rowHeight * stackDepth;
    return Container(
      height: dynamicRowHeight,
      decoration: BoxDecoration(
        color: data.isParent ? (isDarkMode ? Colors.grey[800] : Colors.grey[100]) : null,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.topLeft,
              child: _buildTreeCell(data),
            ),
          ),
          Expanded(
            flex: 1,
            child: _buildCompletionCell(data.completion),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _buildCell(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(text, overflow: TextOverflow.ellipsis),
      );

  Widget _buildTreeCell(GanttGridData data) => GestureDetector(
        onTap: data.isParent ? () => onToggleExpansion(data.id) : null,
        child: SizedBox(
          height: _rowHeight,
          child: Container(
            color: Colors.transparent,
            padding: EdgeInsets.only(left: data.isParent ? 8.0 : 28.0, right: 8.0),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                if (data.isParent)
                  Icon(data.isExpanded ? Icons.expand_more : Icons.chevron_right, size: 20),
                if (data.isParent) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data.name,
                    style: TextStyle(fontWeight: data.isParent ? FontWeight.bold : FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildCompletionCell(double? completion) {
    if (completion == null) {
      return _buildCell('');
    }

    final percentage = (completion * 100).clamp(0, 100);
    final percentageText = '${percentage.toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      child: Stack(
        children: [
          // Background bar and black text
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                percentageText,
                style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          // Foreground bar and white text, clipped to the completion percentage
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: completion,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(percentageText,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}