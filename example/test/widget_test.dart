// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() => testWidgets('GanttView smoke test', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify that the main view is present.
      expect(find.byType(GanttView), findsOneWidget);

      // It will be in a loading state initially, so let's pump and settle
      // to allow for async operations like data fetching to complete.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // After loading, we should see some controls from the example app's UI.
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Drag & Drop'), findsOneWidget);
    });
