import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gobi_mobile/core/services/intent_router_service.dart';
import 'package:gobi_mobile/data/local/app_database.dart';
import 'package:gobi_mobile/data/repositories/medication_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MedicationRepository repository;
  late IntentRouterService intentRouter;

  setUp(() {
    SharedPreferences.setMockInitialValues({'gobi_device_id': 'test-device-uuid-1234'});
    // In-memory SQLite database for deterministic tests
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = MedicationRepository(db);
    intentRouter = IntentRouterService(repository);
  });

  tearDown(() async {
    await db.close();
    intentRouter.dispose();
  });

  group('Step 1: SET SCHEDULE ("Hey Gemini, I need to take vitamin d, once every week for next 6 weeks")', () {
    test('setSchedule directly creates medication, 6 doses, and CDC events in SQLite', () async {
      final result = await repository.setSchedule(
        name: 'Vitamin D',
        frequencyType: 'weekly',
        durationWeeks: 6,
        dosage: '1',
        unit: 'capsule',
      );

      expect(result.medication.name, equals('Vitamin D'));
      expect(result.medication.frequencyType, equals('weekly'));
      expect(result.medication.inventoryCount, equals(6));
      expect(result.generatedDoses.length, equals(6));
      expect(result.summaryMessage, contains('once weekly for the next 6 weeks'));

      // Verify in DB
      final meds = await db.select(db.medications).get();
      expect(meds.length, equals(1));
      expect(meds.first.name, equals('Vitamin D'));

      final doses = await db.select(db.doseLogs).get();
      expect(doses.length, equals(6));
      expect(doses.every((d) => d.status == 'pending'), isTrue);

      // Verify CDC event log
      final cdcEvents = await db.select(db.cdcEvents).get();
      expect(cdcEvents.length, equals(7)); // 1 for med + 6 for doses
      expect(cdcEvents.first.entityType, equals('medication'));
      expect(cdcEvents.first.operation, equals('INSERT'));
    });

    test('Intent router handles gobi://intent/medication/set-schedule', () async {
      final uri = Uri.parse(
        'gobi://intent/medication/set-schedule?name=Vitamin+D&frequency=weekly&durationWeeks=6&dosage=1',
      );

      final event = await intentRouter.handleUri(uri);
      expect(event, isNotNull);
      expect(event!.action, equals('SET_SCHEDULE'));
      expect(event.statusMessage, contains('Vitamin D'));

      final meds = await db.select(db.medications).get();
      expect(meds.length, equals(1));
      expect(meds.first.name, equals('Vitamin D'));
    });
  });

  group('Step 2: GET SCHEDULE ("Did I take vit d this week?")', () {
    setUp(() async {
      await repository.setSchedule(
        name: 'Vitamin D',
        frequencyType: 'weekly',
        durationWeeks: 6,
      );
    });

    test('getScheduleStatus returns pending when not yet taken', () async {
      final status = await repository.getScheduleStatus(name: 'vit d');

      expect(status['found'], isTrue);
      expect(status['takenThisWeek'], isFalse);
      expect(status['pendingDose'], isNotNull);
      expect(status['message'], contains('No, you have not taken Vitamin D yet this week'));
    });

    test('Intent router handles gobi://intent/medication/get-schedule', () async {
      final uri = Uri.parse('gobi://intent/medication/get-schedule?name=vit+d');
      final event = await intentRouter.handleUri(uri);

      expect(event, isNotNull);
      expect(event!.action, equals('GET_SCHEDULE'));
      expect(event.statusMessage, contains('Vitamin D'));
    });
  });

  group('Step 3: RECORD DOSE ("I just took vit d in the morning")', () {
    setUp(() async {
      await repository.setSchedule(
        name: 'Vitamin D',
        frequencyType: 'weekly',
        durationWeeks: 6,
      );
    });

    test('recordDose marks dose as taken and deducts inventory', () async {
      final result = await repository.recordDose(name: 'vit d', status: 'taken');

      expect(result['success'], isTrue);
      expect(result['status'], equals('taken'));
      expect(result['remainingInventory'], equals(5));

      // Re-query status
      final status = await repository.getScheduleStatus(name: 'vit d');
      expect(status['takenThisWeek'], isTrue);
      expect(status['message'], contains('Yes, you took Vitamin D'));

      // Verify CDC event recorded
      final cdcEvents = await (db.select(db.cdcEvents)
            ..where((t) => t.entityType.equals('dose_log') & t.operation.equals('UPDATE')))
          .get();
      expect(cdcEvents.length, equals(1));
    });

    test('Intent router handles gobi://intent/medication/record-dose', () async {
      final uri = Uri.parse('gobi://intent/medication/record-dose?name=vit+d&status=taken');
      final event = await intentRouter.handleUri(uri);

      expect(event, isNotNull);
      expect(event!.action, equals('RECORD_DOSE'));
      expect(event.statusMessage, contains('Recorded Vitamin D as taken'));

      final status = await repository.getScheduleStatus(name: 'vit d');
      expect(status['takenThisWeek'], isTrue);
    });
  });
}
