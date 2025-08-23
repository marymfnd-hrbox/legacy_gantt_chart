import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';

/// A stateful widget for the "Create Task" dialog.
class CreateTaskAlertDialog extends StatefulWidget {
  final DateTime initialTime;
  final String resourceName;
  final String rowId;
  final Function(LegacyGanttTask) onCreate;
  final TimeOfDay defaultStartTime;
  final TimeOfDay defaultEndTime;

  const CreateTaskAlertDialog({
    super.key,
    required this.initialTime,
    required this.resourceName,
    required this.rowId,
    required this.onCreate,
    required this.defaultStartTime,
    required this.defaultEndTime,
  });

  @override
  State<CreateTaskAlertDialog> createState() => _CreateTaskAlertDialogState();
}

class _CreateTaskAlertDialogState extends State<CreateTaskAlertDialog> {
  late final TextEditingController _nameController;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'New Task for ${widget.resourceName}');
    // Select the default text so the user can easily overwrite it.
    _nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _nameController.text.length,
    );

    // Use the date part from where the user clicked, but apply the default times.
    final datePart = widget.initialTime;
    _startDate = DateTime(
      datePart.year,
      datePart.month,
      datePart.day,
      widget.defaultStartTime.hour,
      widget.defaultStartTime.minute,
    );
    _endDate = DateTime(
      datePart.year,
      datePart.month,
      datePart.day,
      widget.defaultEndTime.hour,
      widget.defaultEndTime.minute,
    );

    // Handle overnight case where end time is on the next day.
    if (_endDate.isBefore(_startDate)) {
      _endDate = _endDate.add(const Duration(days: 1));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.isNotEmpty) {
      final newTask = LegacyGanttTask(
          id: 'new_task_${DateTime.now().millisecondsSinceEpoch}',
          rowId: widget.rowId,
          name: _nameController.text,
          start: _startDate,
          end: _endDate);
      widget.onCreate(newTask);
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;

    final pickedDate = await showDatePicker(
        context: context, initialDate: initialDate, firstDate: DateTime(2000), lastDate: DateTime(2030));
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initialDate));
    if (pickedTime == null) return;

    setState(() {
      final newDateTime =
          DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
      if (isStart) {
        _startDate = newDateTime;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate.add(const Duration(hours: 1));
      } else {
        _endDate = newDateTime;
        if (_startDate.isAfter(_endDate)) _startDate = _endDate.subtract(const Duration(hours: 1));
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Create Task for ${widget.resourceName}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Task Name'),
              onSubmitted: (_) => _submit()),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Start:'),
            TextButton(
                onPressed: () => _selectDateTime(context, true),
                child: Text(DateFormat.yMd().add_jm().format(_startDate)))
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('End:'),
            TextButton(
                onPressed: () => _selectDateTime(context, false),
                child: Text(DateFormat.yMd().add_jm().format(_endDate)))
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: _submit, child: const Text('Create')),
        ],
      );
}
