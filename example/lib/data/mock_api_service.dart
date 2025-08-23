import 'models.dart';

// --- Mock API Service ---
class MockApiService {
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? params}) async {
    // Determine the date range for mock data generation
    DateTime startDate = DateTime.now();
    // int rangeDays = 14; // Removed: Unused local variable
    if (params?['startDateIso'] != null) {
      startDate = DateTime.parse(params!['startDateIso'] as String);
    }
    if (params?['endDateIso'] != null) {
      // final endDate = DateTime.parse(params!['endDateIso'] as String); // Removed: Unused local variable
      // rangeDays = endDate.difference(startDate).inDays; // Removed: Unused local variable
    }

    // --- 1. Resources ---
    // Resources define the rows in the Gantt chart's grid. They can be hierarchical.
    // A top-level `GanttResourceData` is a parent row (e.g., a person).
    // Its `children` (a list of `GanttJobData`) are the child rows.
    // Generate mock data based on the requested range
    final mockResources = [
      GanttResourceData(
        id: 'person-1',
        name: 'John Doe',
        taskName: 'Team Lead',
        children: [
          GanttJobData(
              id: 'job-1-1',
              name: 'Personal',
              taskName: 'Pilot',
              status: 'Active',
              taskColor: '4CAF50',
              completion: 1.0), // 100%
          GanttJobData(
              id: 'job-1-2',
              name: 'Personal',
              taskName: 'Co-Pilot',
              status: 'Vacation',
              taskColor: 'FFC107',
              completion: 0.5), // 50%
        ],
      ),
      GanttResourceData(
        id: 'person-2',
        name: 'Jane Smith',
        taskName: 'Team Member',
        children: [
          GanttJobData(
              id: 'job-2-1',
              name: 'Flight Attendant A',
              taskName: 'Flight Attendant',
              status: 'Training',
              taskColor: '2196F3',
              completion: 0.25), // 25%
        ],
      ),
      GanttResourceData(
        id: 'person-3',
        name: 'Bob Johnson',
        taskName: 'Mechanic',
        children: [
          GanttJobData(
              id: 'job-3-1',
              name: 'Aero Mechanic 1',
              taskName: 'Lead Mechanic',
              status: 'Available',
              taskColor: '9E9E9E',
              completion: 0.75), // 75%
        ],
      ),
    ];

    final List<Map<String, dynamic>> mockEvents = [];
    final List<Map<String, dynamic>> mockAssignments = [];
    final List<Map<String, dynamic>> mockResourceTimeRanges = [];

    // --- 2. Events and Assignments ---
    // Events define the actual tasks (bars) that will be drawn on the chart.
    // They have a start date, end date, name, and other metadata.
    //
    // Assignments link an Event to a Resource. This is how the chart knows
    // which row to draw a task in.

    // --- Summary Tasks ---
    // A summary task is typically assigned to a parent resource (e.g., 'person-1').
    // It often represents the overall duration of all child tasks.
    // Base mock events for each person (summary events)
    final person1SummaryStart = startDate.add(const Duration(days: 1));
    final person1SummaryEnd = startDate.add(const Duration(days: 5));
    mockEvents.add({
      'id': 'event-person-1-summary',
      'name': 'John Doe - PTO',
      'utcStartDate': person1SummaryStart.toIso8601String(),
      'utcEndDate': person1SummaryEnd.toIso8601String(),
      'elementId': null, // A null elementId indicates a top-level event.
      'referenceData': {'taskName': 'On Duty', 'taskColor': '00BCD4'}, // Cyan
    });
    mockAssignments.add({
      'id': 'assignment-person-1-summary',
      'event': 'event-person-1-summary',
      'resource': 'person-1', // Assigns this event to the 'John Doe' row.
    });

    final person2SummaryStart = startDate.add(const Duration(days: 3));
    final person2SummaryEnd = startDate.add(const Duration(days: 8));
    mockEvents.add({
      'id': 'event-person-2-summary',
      'name': 'Ground Training - Jane',
      'utcStartDate': person2SummaryStart.toIso8601String(),
      'utcEndDate': person2SummaryEnd.toIso8601String(),
      'elementId': null,
      'referenceData': {'taskName': 'Training', 'taskColor': 'F44336'}, // Red
    });
    mockAssignments.add({
      'id': 'assignment-person-2-summary',
      'event': 'event-person-2-summary',
      'resource': 'person-2', // Assigns this event to the 'Jane Smith' row.
    });

    // --- Regular Tasks (Child Tasks) ---
    // These are assigned to child resources (jobs) and are visually nested under their parent.
    // The `elementId` links a child event to its parent summary event. This is useful
    // for logic like calculating "Day X of Y" in tooltips.

    // Job 1-1: Pilot A1's flight
    mockEvents.add({
      'id': 'event-job-1-1-flight',
      'name': 'Flight 123 to NYC',
      'utcStartDate': startDate.add(const Duration(days: 1, hours: 9)).toIso8601String(),
      'utcEndDate': startDate.add(const Duration(days: 1, hours: 17)).toIso8601String(),
      'elementId': 'event-person-1-summary', // Links to parent summary
      'referenceData': {'taskName': 'Active', 'taskColor': '8BC34A'}, // Light Green
    });
    mockAssignments.add({
      'id': 'assignment-job-1-1-flight',
      'event': 'event-job-1-1-flight',
      'resource': 'job-1-1', // Assigns to the 'Pilot' job row.
    });

    // Job 1-2: Co-Pilot A1's vacation
    mockEvents.add({
      'id': 'event-job-1-2-vacation',
      'name': 'Pick Up Kids',
      'utcStartDate': startDate.add(const Duration(days: 2)).toIso8601String(),
      'utcEndDate': startDate.add(const Duration(days: 4)).toIso8601String(),
      'elementId': 'event-person-1-summary',
      'referenceData': {'taskName': 'Vacation', 'taskColor': 'FFEB3B', 'taskTextColor': '000000'}, // Yellow, Black text
    });
    mockAssignments.add({
      'id': 'assignment-job-1-2-vacation',
      'event': 'event-job-1-2-vacation',
      'resource': 'job-1-2', // Assigns to the 'Co-Pilot' job row.
    });

    // --- Overlapping Tasks ---
    // To demonstrate task stacking, we can add multiple events for the same resource
    // that have overlapping time ranges. The Gantt chart will automatically stack them.
    // Job 2-1: Flight Attendant A's training (overlapping)
    mockEvents.add({
      'id': 'event-job-2-1-training-1',
      'name': 'Safety Course',
      'utcStartDate': startDate.add(const Duration(days: 3, hours: 9)).toIso8601String(),
      'utcEndDate': startDate.add(const Duration(days: 4, hours: 17)).toIso8601String(),
      'elementId': 'event-person-2-summary',
      'referenceData': {'taskName': 'In Class', 'taskColor': '673AB7'}, // Deep Purple
    });
    mockAssignments.add({
      'id': 'assignment-job-2-1-training-1',
      'event': 'event-job-2-1-training-1',
      'resource': 'job-2-1',
    });

    mockEvents.add({
      'id': 'event-job-2-1-training-2',
      'name': 'Advanced CRM',
      'utcStartDate': startDate.add(const Duration(days: 3, hours: 14)).toIso8601String(),
      'utcEndDate': startDate.add(const Duration(days: 5, hours: 10)).toIso8601String(),
      'elementId': 'event-person-2-summary',
      'referenceData': {'taskName': 'Online', 'taskColor': '9C27B0'}, // Purple
    });
    mockAssignments.add({
      'id': 'assignment-job-2-1-training-2',
      'event': 'event-job-2-1-training-2',
      'resource': 'job-2-1',
    });

    // --- 3. Resource Time Ranges (Background Highlights) ---
    // These are used to draw background highlights for a specific resource (row).
    // They are useful for indicating things like unavailability, maintenance, or holidays.
    // They are converted into `LegacyGanttTask`s with `isTimeRangeHighlight = true`.

    // John Doe's unavailable time
    mockResourceTimeRanges.add({
      'id': 'time-range-person-1-unavailable',
      'resourceId': 'person-1', // Applies to the 'John Doe' row.
      'utcStartDate': startDate.add(const Duration(days: 10)).toIso8601String(),
      'utcEndDate': startDate.add(const Duration(days: 12)).toIso8601String(),
    });

    // Pilot A1's maintenance window
    mockResourceTimeRanges.add({
      'id': 'time-range-job-1-1-maintenance',
      'resourceId': 'job-1-1', // Applies to the 'Pilot' job row.
      'utcStartDate': startDate.add(const Duration(days: 7)).toIso8601String(),
      'utcEndDate': startDate.add(const Duration(days: 9)).toIso8601String(),
    });

    return {
      'success': true,
      'resourcesData': mockResources.map((r) => r.toJson()).toList(),
      'eventsData': mockEvents,
      'assignmentsData': mockAssignments,
      'resourceTimeRangesData': mockResourceTimeRanges,
    };
  }
}
