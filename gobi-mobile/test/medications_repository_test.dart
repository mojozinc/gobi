import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:gobi_mobile/data/local/app_database.dart';
import 'package:gobi_mobile/data/repositories/medications_repository.dart';
import 'package:gobi_mobile/core/services/api_service.dart';

class FailingApiService extends ApiService {
  FailingApiService() : super(baseUrl: 'http://invalid-offline-host:9999/api/v1');

  @override
  Future<List<dynamic>> getMedications({int? dependentId}) async {
    throw Exception('Connection refused - Offline mode');
  }

  @override
  Future<List<dynamic>> getTodayDoses({int? dependentId}) async {
    throw Exception('Connection refused - Offline mode');
  }

  @override
  Future<Map<String, dynamic>> createMedication(Map<String, dynamic> data) async {
    throw Exception('Connection refused - Offline mode');
  }

  @override
  Future<Map<String, dynamic>> takeDose(int doseId) async {
    throw Exception('Connection refused - Offline mode');
  }

  @override
  Future<Map<String, dynamic>> undoDose(int doseId) async {
    throw Exception('Connection refused - Offline mode');
  }
}

class MockCloudApiService extends ApiService {
  MockCloudApiService() : super(baseUrl: 'http://mock-cloud:8000/api/v1');

  @override
  Future<List<dynamic>> getMedications({int? dependentId}) async {
    return [
      {
        'id': 'cloud-med-1',
        'name': 'Atorvastatin',
        'dosage': '20mg',
        'frequency': 'daily',
        'times': '21:00',
        'instructions': 'Take before bed',
        'dependent_id': 'self',
        'inventory_count': 30,
      }
    ];
  }

  @override
  Future<List<dynamic>> getTodayDoses({int? dependentId}) async {
    return [
      {
        'id': 'cloud-dose-1',
        'medication_id': 'cloud-med-1',
        'scheduled_time': DateTime.now().toIso8601String(),
        'status': 'pending',
      }
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
      deviceId: 'test-device-uuid',
    );
  });


  tearDown(() async {
    await db.close();
  });

  group('MedicationsRepository (Local-First)', () {
    test('addMedication saves locally and auto-generates today dose logs', () async {
      final failingApi = FailingApiService();
      final repository = MedicationsRepository(db, failingApi);

      final medId = await repository.addMedication({
        'name': 'Metformin',
        'dosage': '500mg',
        'frequency': 'twice daily',
        'times': ['08:00', '20:00'],
        'duration_weeks': 2,
        'instructions': 'Take with meals',
        'dependent_id': 'self',
      });

      expect(medId, isNotEmpty);

      // Verify active medications from local SQLite
      final meds = await repository.getMedications();
      expect(meds.length, 1);
      expect(meds.first['name'], 'Metformin');
      expect(meds.first['dosage'], '500mg');
      expect(meds.first['times_list'], ['08:00', '20:00']);

      // Verify today's generated doses in local SQLite
      final todayDoses = await repository.getTodayDoses();
      expect(todayDoses.length, 2);
      expect(todayDoses.first['medication_name'], 'Metformin');
      expect(todayDoses.first['status'], 'pending');

      // Verify CDC change event recorded with HLC timestamp
      final unsyncedEvents = await db.getUnsyncedCdcEvents();
      expect(unsyncedEvents, isNotEmpty);
      expect(unsyncedEvents.any((e) => e.entityType == 'medication'), isTrue);
      expect(unsyncedEvents.any((e) => e.entityType == 'dose_log'), isTrue);
    });

    test('takeDose and undoDose update status in local SQLite with CDC event', () async {
      final failingApi = FailingApiService();
      final repository = MedicationsRepository(db, failingApi);

      await repository.addMedication({
        'name': 'Lisinopril',
        'dosage': '10mg',
        'frequency': 'daily',
        'times': ['09:00'],
        'duration_weeks': 1,
      });

      final doses = await repository.getTodayDoses();
      expect(doses.length, 1);
      final doseId = doses.first['id'];

      // Mark dose as taken
      await repository.takeDose(doseId);

      var updatedDoses = await repository.getTodayDoses();
      expect(updatedDoses.first['status'], 'taken');
      expect(updatedDoses.first['taken_time'], isNotNull);

      // Undo dose
      await repository.undoDose(doseId);

      updatedDoses = await repository.getTodayDoses();
      expect(updatedDoses.first['status'], 'pending');
      expect(updatedDoses.first['taken_time'], isNull);
    });

    test('syncWithCloud reconciles cloud records into local SQLite and handles offline gracefully', () async {
      final mockCloudApi = MockCloudApiService();
      final repository = MedicationsRepository(db, mockCloudApi);

      // Sync from mock cloud
      final success = await repository.syncWithCloud();
      expect(success, isTrue);

      final meds = await repository.getMedications();
      expect(meds.length, 1);
      expect(meds.first['name'], 'Atorvastatin');
      expect(meds.first['dosage'], '20mg');

      // Now simulate offline sync - must not throw exception
      final offlineRepo = MedicationsRepository(db, FailingApiService());
      final offlineSuccess = await offlineRepo.syncWithCloud();
      expect(offlineSuccess, isFalse);

      // Data is still preserved locally
      final preservedMeds = await offlineRepo.getMedications();
      expect(preservedMeds.length, 1);
      expect(preservedMeds.first['name'], 'Atorvastatin');
    });

    test('updateMedication updates local schedule, regenerates doses, and records CDC UPDATE', () async {
      final repository = MedicationsRepository(db, FailingApiService());

      final medId = await repository.addMedication({
        'name': 'Ibuprofen',
        'dosage': '200mg',
        'frequency': 'daily',
        'times': ['08:00'],
        'duration_weeks': 1,
      });

      // Update medication
      await repository.updateMedication(medId, {
        'name': 'Ibuprofen',
        'dosage': '400mg',
        'frequency': 'twice daily',
        'times': ['08:00', '20:00'],
        'duration_weeks': 1,
        'instructions': 'Take with food',
      });

      final meds = await repository.getMedications();
      expect(meds.first['dosage'], '400mg');
      expect(meds.first['times_list'], ['08:00', '20:00']);
      expect(meds.first['instructions'], 'Take with food');

      final todayDoses = await repository.getTodayDoses();
      expect(todayDoses.length, 2);

      final cdcEvents = await db.getUnsyncedCdcEvents();
      expect(cdcEvents.any((e) => e.entityId == medId && e.operation == 'UPDATE'), isTrue);
    });

    test('deleteMedication soft-deletes medication and removes pending doses', () async {
      final repository = MedicationsRepository(db, FailingApiService());

      final medId = await repository.addMedication({
        'name': 'Omeprazole',
        'dosage': '20mg',
        'frequency': 'daily',
        'times': ['07:00'],
        'duration_weeks': 1,
      });

      expect((await repository.getMedications()).length, 1);
      expect((await repository.getTodayDoses()).length, 1);

      await repository.deleteMedication(medId);

      // Active medications list must no longer contain deleted medication
      expect((await repository.getMedications()).isEmpty, isTrue);

      // Pending doses must no longer be returned
      expect((await repository.getTodayDoses()).isEmpty, isTrue);

      final cdcEvents = await db.getUnsyncedCdcEvents();
      expect(cdcEvents.any((e) => e.entityId == medId && e.operation == 'DELETE'), isTrue);
    });

    test('toggleMedicationPause holds and resumes pending doses', () async {
      final repository = MedicationsRepository(db, FailingApiService());

      final medId = await repository.addMedication({
        'name': 'Sertraline',
        'dosage': '50mg',
        'frequency': 'daily',
        'times': ['09:00'],
        'duration_weeks': 1,
      });

      // Toggle to pause
      final isPaused = await repository.toggleMedicationPause(medId);
      expect(isPaused, isTrue);

      // Toggle to resume
      final isResumed = await repository.toggleMedicationPause(medId);
      expect(isResumed, isFalse);
    });
  });
}
