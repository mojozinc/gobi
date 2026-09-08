import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gobi_mobile/core/services/api_service.dart';
import 'package:gobi_mobile/features/medications/widgets/review_schedule_bottom_sheet.dart';

void main() {
  testWidgets('ReviewScheduleBottomSheet pre-fills AI extracted values and renders properly', (WidgetTester tester) async {
    final apiService = ApiService(baseUrl: 'http://127.0.0.1:8000/api/v1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewScheduleBottomSheet(
            apiService: apiService,
            initialName: 'Metformin',
            initialDosage: '500mg',
            initialFrequency: 'twice daily',
            initialTimes: const ['08:00', '20:00'],
            initialDurationWeeks: 4,
            initialInstructions: 'Take with breakfast and dinner',
          ),
        ),
      ),
    );

    // Verify fields are prefilled
    expect(find.text('Review Medication Schedule'), findsOneWidget);
    expect(find.text('Metformin'), findsOneWidget);
    expect(find.text('500mg'), findsOneWidget);
    expect(find.text('twice daily'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('Take with breakfast and dinner'), findsOneWidget);
    expect(find.text('Confirm & Schedule'), findsOneWidget);
  });
}
