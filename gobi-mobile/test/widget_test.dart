import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:gobi_mobile/main.dart';
import 'package:gobi_mobile/core/providers/app_providers.dart';
import 'package:gobi_mobile/core/services/api_service.dart';
import 'package:gobi_mobile/data/local/app_database.dart';

class TestMockApiService extends ApiService {
  TestMockApiService()
      : super(
          baseUrl: 'http://127.0.0.1:8000/api/v1',
          client: MockClient((request) async => http.Response('{"detail":"mock"}', 200)),
        );

  @override
  Future<Map<String, dynamic>> loginAnonymously({String? deviceId, String? name}) async {
    return {
      'token': 'mock-token',
      'user': {'id': 1, 'name': 'Guest User', 'email': 'guest@test.local'},
    };
  }

  @override
  Future<List<dynamic>> getMedications({int? dependentId}) async {
    return [];
  }

  @override
  Future<List<dynamic>> getTodayDoses({int? dependentId}) async {
    return [];
  }
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final testDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    final testApi = TestMockApiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appDatabaseProvider.overrideWithValue(testDb),
          apiServiceProvider.overrideWithValue(testApi),
        ],
        child: const GobiApp(),
      ),
    );

    // Allow splash timer to complete and navigate to home
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.byType(GobiApp), findsOneWidget);

    await testDb.close();
    await tester.pump(Duration.zero);
  });
}
