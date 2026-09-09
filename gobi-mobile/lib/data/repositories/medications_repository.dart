import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../local/app_database.dart';
import '../../core/services/api_service.dart';

enum SyncStatus {
  idle,
  syncing,
  synced,
  offline,
}

class MedicationsRepository {
  final AppDatabase _db;
  final ApiService _apiService;

  MedicationsRepository(this._db, this._apiService);

  AppDatabase get db => _db;
  ApiService get apiService => _apiService;

  // ── Reactive Stream Watchers (Local SQLite) ─────────────────────────

  /// Observes active medications from local Drift SQLite.
  Stream<List<Map<String, dynamic>>> watchMedications({String? dependentId}) {
    return _db.watchAllMedications(dependentId: dependentId).map((entries) {
      return entries.map((med) {
        List<String> times = [];
        try {
          final decoded = jsonDecode(med.timesOfDayJson);
          if (decoded is List) {
            times = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}

        return {
          'id': med.id,
          'name': med.name,
          'dosage': med.dosage,
          'unit': med.unit,
          'frequency': med.frequencyType,
          'times': times.isNotEmpty ? times.join(', ') : '08:00',
          'times_list': times,
          'instructions': med.instructions,
          'dependent_id': med.dependentId,
          'inventory_count': med.inventoryCount,
          'created_at': med.createdAt.toIso8601String(),
        };
      }).toList();
    });
  }

  /// Observes today's dose logs joined with medication details from local SQLite.
  Stream<List<Map<String, dynamic>>> watchTodayDoses({String? dependentId, DateTime? date}) {
    return _db.watchTodayDosesWithMedication(dependentId: dependentId, date: date).map((dosesWithMed) {
      return dosesWithMed.map((item) => item.toJson()).toList();
    });
  }

  /// Gets current active medications snapshot from local database.
  Future<List<Map<String, dynamic>>> getMedications({String? dependentId}) async {
    final entries = await _db.getAllMedications(dependentId: dependentId);
    return entries.map((med) {
      List<String> times = [];
      try {
        final decoded = jsonDecode(med.timesOfDayJson);
        if (decoded is List) {
          times = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}

      return {
        'id': med.id,
        'name': med.name,
        'dosage': med.dosage,
        'unit': med.unit,
        'frequency': med.frequencyType,
        'times': times.isNotEmpty ? times.join(', ') : '08:00',
        'times_list': times,
        'instructions': med.instructions,
        'dependent_id': med.dependentId,
        'inventory_count': med.inventoryCount,
        'created_at': med.createdAt.toIso8601String(),
      };
    }).toList();
  }

  /// Gets today's doses snapshot from local database.
  Future<List<Map<String, dynamic>>> getTodayDoses({String? dependentId, DateTime? date}) async {
    final list = await _db.getTodayDosesWithMedication(dependentId: dependentId, date: date);
    return list.map((item) => item.toJson()).toList();
  }

  // ── Mutations (Local First + Background Cloud Sync) ──────────────────

  /// Adds a medication schedule locally to Drift SQLite and generates dose logs.
  Future<String> addMedication(Map<String, dynamic> data) async {
    final name = (data['name'] as String?)?.trim() ?? 'Medication';
    final dosage = (data['dosage'] as String?)?.trim() ?? '1 dose';
    final unit = (data['unit'] as String?)?.trim() ?? '';
    final frequency = (data['frequency'] as String?)?.trim() ?? 'daily';
    final durationWeeks = (data['duration_weeks'] as int?) ?? 1;
    final instructions = data['instructions'] as String?;
    final dependentId = data['dependent_id'] != null ? data['dependent_id'].toString() : 'self';

    List<String> times = ['08:00'];
    final rawTimes = data['times'];
    if (rawTimes is String && rawTimes.isNotEmpty) {
      times = rawTimes.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawTimes is List && rawTimes.isNotEmpty) {
      times = rawTimes.map((e) => e.toString()).toList();
    }

    // 1. Write immediately to local SQLite & generate dose logs
    final medId = await _db.createMedicationAndGenerateDoses(
      name: name,
      dosage: dosage,
      unit: unit,
      frequencyType: frequency,
      timesOfDay: times,
      durationWeeks: durationWeeks,
      instructions: instructions,
      dependentId: dependentId,
    );

    // 2. Trigger background sync to cloud API (fire-and-forget, does not block UI)
    _backgroundCloudCreate(data, medId);

    return medId;
  }

  /// Updates a medication schedule in local SQLite and updates upcoming doses.
  Future<void> updateMedication(String id, Map<String, dynamic> data) async {
    final name = (data['name'] as String?)?.trim() ?? 'Medication';
    final dosage = (data['dosage'] as String?)?.trim() ?? '1 dose';
    final unit = (data['unit'] as String?)?.trim() ?? '';
    final frequency = (data['frequency'] as String?)?.trim() ?? 'daily';
    final durationWeeks = (data['duration_weeks'] as int?) ?? 1;
    final instructions = data['instructions'] as String?;
    final inventoryCount = data['inventory_count'] as int?;

    List<String> times = ['08:00'];
    final rawTimes = data['times'];
    if (rawTimes is String && rawTimes.isNotEmpty) {
      times = rawTimes.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawTimes is List && rawTimes.isNotEmpty) {
      times = rawTimes.map((e) => e.toString()).toList();
    }

    await _db.updateMedicationAndDoses(
      medicationId: id,
      name: name,
      dosage: dosage,
      unit: unit,
      frequencyType: frequency,
      timesOfDay: times,
      durationWeeks: durationWeeks,
      instructions: instructions,
      inventoryCount: inventoryCount,
    );
  }

  /// Soft-deletes a medication from local SQLite and removes pending doses.
  Future<void> deleteMedication(String id) async {
    await _db.deleteMedication(medicationId: id);
  }

  /// Toggles pause status for a medication's upcoming pending doses.
  Future<bool> toggleMedicationPause(String id) async {
    return await _db.toggleMedicationPause(medicationId: id);
  }

  /// Marks a dose as taken in local SQLite with CDC logging, and syncs in background.
  Future<void> takeDose(dynamic doseId) async {
    final idStr = doseId.toString();
    await _db.updateDoseStatus(
      doseId: idStr,
      status: 'taken',
      takenTime: DateTime.now(),
    );

    // Background sync
    _backgroundCloudTakeDose(doseId);
  }

  /// Undoes a dose (sets status back to pending) in local SQLite.
  Future<void> undoDose(dynamic doseId) async {
    final idStr = doseId.toString();
    await _db.updateDoseStatus(
      doseId: idStr,
      status: 'pending',
      takenTime: null,
    );

    // Background sync
    _backgroundCloudUndoDose(doseId);
  }

  // ── Cloud Synchronization ──────────────────────────────────────────

  /// Synchronizes local SQLite database with cloud FastAPI / PostgreSQL backend.
  /// Catches all network errors gracefully and returns whether sync was successful.
  Future<bool> syncWithCloud({String? dependentId}) async {
    try {
      final int? depIdInt = dependentId != null ? int.tryParse(dependentId) : null;

      // 1. Fetch cloud medications and upsert to local DB
      final cloudMeds = await _apiService.getMedications(dependentId: depIdInt);
      for (final raw in cloudMeds) {
        if (raw is Map<String, dynamic>) {
          final medId = raw['id'] != null ? raw['id'].toString() : null;
          if (medId != null && medId.isNotEmpty) {
            final timesRaw = raw['times'];
            List<String> timesList = ['08:00'];
            if (timesRaw is String) {
              timesList = timesRaw.split(',').map((e) => e.trim()).toList();
            } else if (timesRaw is List) {
              timesList = timesRaw.map((e) => e.toString()).toList();
            }

            final entry = MedicationEntry(
              id: medId,
              name: raw['name'] ?? 'Medication',
              dosage: raw['dosage'] ?? '',
              unit: raw['unit'] ?? '',
              frequencyType: raw['frequency'] ?? 'daily',
              timesOfDayJson: jsonEncode(timesList),
              inventoryCount: raw['inventory_count'] ?? 0,
              refillThreshold: raw['refill_threshold'] ?? 5,
              dependentId: raw['dependent_id'] != null ? raw['dependent_id'].toString() : 'self',
              instructions: raw['instructions'] as String?,
              createdAt: raw['created_at'] != null ? DateTime.tryParse(raw['created_at']) ?? DateTime.now() : DateTime.now(),
              updatedAt: DateTime.now(),
              isDeleted: false,
            );
            await _db.upsertMedicationFromCloud(entry);
          }
        }
      }

      // 2. Fetch cloud today doses and upsert to local DB
      final cloudDoses = await _apiService.getTodayDoses(dependentId: depIdInt);
      for (final raw in cloudDoses) {
        if (raw is Map<String, dynamic>) {
          final doseId = raw['id'] != null ? raw['id'].toString() : null;
          final medId = raw['medication_id'] != null ? raw['medication_id'].toString() : null;
          if (doseId != null && medId != null) {
            final entry = DoseLogEntry(
              id: doseId,
              medicationId: medId,
              scheduledTime: raw['scheduled_time'] != null
                  ? DateTime.tryParse(raw['scheduled_time']) ?? DateTime.now()
                  : DateTime.now(),
              takenTime: raw['taken_time'] != null ? DateTime.tryParse(raw['taken_time']) : null,
              status: raw['status'] ?? 'pending',
              notes: raw['notes'] as String?,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              isDeleted: false,
            );
            await _db.upsertDoseLogFromCloud(entry);
          }
        }
      }

      // 3. Mark unsynced CDC events if any
      final unsynced = await _db.getUnsyncedCdcEvents();
      if (unsynced.isNotEmpty) {
        await _db.markEventsSynced(unsynced.map((e) => e.id).toList());
      }

      return true;
    } catch (e) {
      debugPrint('Background cloud sync notice (offline mode active): $e');
      return false;
    }
  }

  void _backgroundCloudCreate(Map<String, dynamic> data, String localMedId) async {
    try {
      await _apiService.createMedication(data);
    } catch (e) {
      debugPrint('Background cloud medication create deferred: $e');
    }
  }

  void _backgroundCloudTakeDose(dynamic doseId) async {
    final intId = int.tryParse(doseId.toString());
    if (intId != null) {
      try {
        await _apiService.takeDose(intId);
      } catch (e) {
        debugPrint('Background cloud take dose deferred: $e');
      }
    }
  }

  void _backgroundCloudUndoDose(dynamic doseId) async {
    final intId = int.tryParse(doseId.toString());
    if (intId != null) {
      try {
        await _apiService.undoDose(intId);
      } catch (e) {
        debugPrint('Background cloud undo dose deferred: $e');
      }
    }
  }
}
