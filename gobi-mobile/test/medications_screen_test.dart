import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:gobi_mobile/core/providers/app_providers.dart';
import 'package:gobi_mobile/core/services/api_service.dart';
import 'package:gobi_mobile/data/local/app_database.dart';
import 'package:gobi_mobile/data/repositories/medications_repository.dart';
import 'package:gobi_mobile/features/medications/screens/medications_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MockFailingApiService extends ApiService {
  MockFailingApiService()
      : super(
          baseUrl: 'http://offline-test:8000/api/v1',
          client: MockClient((request) async => http.Response('{"detail":"offline"}', 503)),
        );

  @override
  Future<List<dynamic>> getMedications({int? dependentId}) async {
    throw Exception('Offline network failure');
  }

  @override
  Future<List<dynamic>> getTodayDoses({int? dependentId}) async {
    throw Exception('Offline network failure');
  }

  @override
  Future<Map<String, dynamic>> createMedication(Map<String, dynamic> data) async {
    throw Exception('Offline network failure');
  }

  @override
  Future<Map<String, dynamic>> takeDose(int doseId) async {
    throw Exception('Offline network failure');
  }

  @override
  Future<Map<String, dynamic>> undoDose(int doseId) async {
    throw Exception('Offline network failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late MedicationsRepository repository;
  late ApiService apiService;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
      deviceId: 'test-device-uuid',
    );
    apiService = MockFailingApiService();
    repository = MedicationsRepository(db, apiService);
  });

  tearDown(() async {});

  testWidgets('MedicationsScreen renders locally without network errors in offline mode', (WidgetTester tester) async {
    await repository.addMedication({
      'name': 'Amoxicillin',
      'dosage': '500mg',
      'frequency': '3 times daily',
      'times': ['08:00', '14:00', '20:00'],
      'duration_weeks': 1,
      'instructions': 'Finish full course',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          medicationsRepositoryProvider.overrideWithValue(repository),
          apiServiceProvider.overrideWithValue(apiService),
        ],
        child: MaterialApp(
          home: MedicationsScreen(
            repository: repository,
            apiService: apiService,
          ),
        ),
      ),
    );

    // Initial pump and allow async post-frame cloud sync to complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify screen loaded with local data without showing raw exception
    expect(find.text('Medications & Adherence'), findsOneWidget);
    expect(find.text("Today's Schedule"), findsOneWidget);
    expect(find.text('Active Medications'), findsOneWidget);
    expect(find.text('Amoxicillin'), findsWidgets);
    expect(find.text('Take'), findsWidgets);
    expect(find.textContaining('Offline network failure'), findsNothing);

    // Test taking a dose from the UI
    final takeButton = find.widgetWithText(ElevatedButton, 'Take').first;
    await tester.tap(takeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify undo button appears after taking dose
    expect(find.text('Undo'), findsWidgets);
    expect(find.textContaining('Marked Amoxicillin as taken'), findsOneWidget);

    // Remove snackbar immediately to cancel its timer
    ScaffoldMessenger.of(tester.element(find.byType(MedicationsScreen))).removeCurrentSnackBar();
    await tester.pump(const Duration(milliseconds: 100));

    // Unmount widget cleanly
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Long pressing medication card opens action menu with Edit, Pause, and Delete', (WidgetTester tester) async {
    final medId = await repository.addMedication({
      'name': 'Metformin',
      'dosage': '500mg',
      'frequency': 'twice daily',
      'times': ['08:00', '20:00'],
      'duration_weeks': 2,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          medicationsRepositoryProvider.overrideWithValue(repository),
          apiServiceProvider.overrideWithValue(apiService),
        ],
        child: MaterialApp(
          home: MedicationsScreen(
            repository: repository,
            apiService: apiService,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Find active medication card
    final medCard = find.text('Metformin').last;
    expect(medCard, findsOneWidget);

    // Long press on active medication card
    await tester.longPress(medCard);
    await tester.pumpAndSettle();

    // Verify action sheet options are displayed
    expect(find.text('Edit Schedule'), findsOneWidget);
    expect(find.text('Pause / Resume Schedule'), findsOneWidget);
    expect(find.text('Delete Schedule'), findsOneWidget);

    // Tap Delete Schedule
    await tester.tap(find.text('Delete Schedule'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('Delete Medication Schedule'), findsOneWidget);
    expect(find.textContaining('Are you sure you want to delete'), findsOneWidget);

    // Confirm deletion
    final deleteConfirmBtn = find.widgetWithText(ElevatedButton, 'Delete');
    await tester.tap(deleteConfirmBtn);
    await tester.pumpAndSettle();

    // Verify snackbar feedback and removal from UI
    expect(find.textContaining('Deleted Metformin schedule'), findsOneWidget);

    // Clean up snackbars and unmount
    ScaffoldMessenger.of(tester.element(find.byType(MedicationsScreen))).removeCurrentSnackBar();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}




