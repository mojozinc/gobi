import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'hlc.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  CdcEvents,
  Medications,
  DoseLogs,
  Dependents,
  VitalsLogs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(DatabaseConnection connection, {String? deviceId}) : super(connection) {
    _cachedDeviceId = deviceId ?? 'test-device-uuid';
  }

  @override
  int get schemaVersion => 1;

  static const String _deviceIdPrefKey = 'gobi_device_id';
  static const _uuid = Uuid();
  String? _cachedDeviceId;
  HLC? _lastHlc;

  /// Retrieves or generates a persistent device UUID for CDC event attribution.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_deviceIdPrefKey);
      if (id == null) {
        id = _uuid.v4();
        await prefs.setString(_deviceIdPrefKey, id);
      }
      _cachedDeviceId = id;
      return id;
    } catch (_) {
      _cachedDeviceId = _uuid.v4();
      return _cachedDeviceId!;
    }
  }


  /// Generates the next monotonic Hybrid Logical Clock timestamp for this device.
  Future<HLC> getNextHlc() async {
    final deviceId = await getDeviceId();
    _lastHlc = HLC.now(deviceId, _lastHlc);
    return _lastHlc!;
  }

  /// Appends a mutation to the CDC change event log.
  Future<void> recordCdcEvent({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final hlc = await getNextHlc();
    final deviceId = await getDeviceId();

    await into(cdcEvents).insert(
      CdcEventsCompanion.insert(
        id: _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: jsonEncode(payload),
        hlcTimestamp: hlc.toHlcString(),
        deviceId: deviceId,
        isSynced: const Value(false),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Fetches un-synced CDC events ready for transmission to the dumb sync relay.
  Future<List<CdcEventEntry>> getUnsyncedCdcEvents({int limit = 100}) {
    return (select(cdcEvents)
          ..where((t) => t.isSynced.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)])
          ..limit(limit))
        .get();
  }

  /// Marks a batch of CDC events as synced.
  Future<void> markEventsSynced(List<String> eventIds) async {
    await (update(cdcEvents)..where((t) => t.id.isIn(eventIds)))
        .write(const CdcEventsCompanion(isSynced: Value(true)));
  }

  // ── Medications & Dose Logs Queries ─────────────────────────────────

  /// Observes all active (non-deleted) medications.
  Stream<List<MedicationEntry>> watchAllMedications({String? dependentId}) {
    final query = select(medications)..where((tbl) => tbl.isDeleted.equals(false));
    if (dependentId != null && dependentId.isNotEmpty) {
      query.where((tbl) => tbl.dependentId.equals(dependentId));
    }
    return (query..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)])).watch();
  }

  /// Fetches all active medications as a Future list.
  Future<List<MedicationEntry>> getAllMedications({String? dependentId}) {
    final query = select(medications)..where((tbl) => tbl.isDeleted.equals(false));
    if (dependentId != null && dependentId.isNotEmpty) {
      query.where((tbl) => tbl.dependentId.equals(dependentId));
    }
    return (query..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)])).get();
  }

  /// Observes today's dose logs joined with their parent medication.
  Stream<List<DoseWithMedication>> watchTodayDosesWithMedication({String? dependentId, DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);

    final query = select(doseLogs).join([
      innerJoin(medications, medications.id.equalsExp(doseLogs.medicationId)),
    ])
      ..where(doseLogs.isDeleted.equals(false) &
          doseLogs.scheduledTime.isBiggerOrEqualValue(startOfDay) &
          doseLogs.scheduledTime.isSmallerOrEqualValue(endOfDay));

    if (dependentId != null && dependentId.isNotEmpty) {
      query.where(medications.dependentId.equals(dependentId));
    }

    query.orderBy([OrderingTerm(expression: doseLogs.scheduledTime, mode: OrderingMode.asc)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return DoseWithMedication(
          dose: row.readTable(doseLogs),
          medication: row.readTable(medications),
        );
      }).toList();
    });
  }

  /// Gets today's dose logs joined with medication details as a Future list.
  Future<List<DoseWithMedication>> getTodayDosesWithMedication({String? dependentId, DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);

    final query = select(doseLogs).join([
      innerJoin(medications, medications.id.equalsExp(doseLogs.medicationId)),
    ])
      ..where(doseLogs.isDeleted.equals(false) &
          doseLogs.scheduledTime.isBiggerOrEqualValue(startOfDay) &
          doseLogs.scheduledTime.isSmallerOrEqualValue(endOfDay));

    if (dependentId != null && dependentId.isNotEmpty) {
      query.where(medications.dependentId.equals(dependentId));
    }

    query.orderBy([OrderingTerm(expression: doseLogs.scheduledTime, mode: OrderingMode.asc)]);

    final rows = await query.get();
    return rows.map((row) {
      return DoseWithMedication(
        dose: row.readTable(doseLogs),
        medication: row.readTable(medications),
      );
    }).toList();
  }

  /// Inserts a new medication and immediately generates dose schedule logs for the schedule window.
  Future<String> createMedicationAndGenerateDoses({
    required String name,
    required String dosage,
    required String unit,
    required String frequencyType,
    required List<String> timesOfDay,
    int durationWeeks = 1,
    String? instructions,
    String dependentId = 'self',
    int inventoryCount = 0,
    String? customMedId,
  }) async {
    final medId = customMedId ?? _uuid.v4();
    final now = DateTime.now();

    final medCompanion = MedicationsCompanion.insert(
      id: medId,
      name: name,
      dosage: dosage,
      unit: unit,
      frequencyType: frequencyType,
      timesOfDayJson: jsonEncode(timesOfDay),
      inventoryCount: Value(inventoryCount),
      refillThreshold: const Value(5),
      dependentId: Value(dependentId),
      instructions: Value(instructions),
      createdAt: now,
      updatedAt: now,
      isDeleted: const Value(false),
    );

    await transaction(() async {
      await into(medications).insertOnConflictUpdate(medCompanion);

      await recordCdcEvent(
        entityType: 'medication',
        entityId: medId,
        operation: 'INSERT',
        payload: {
          'id': medId,
          'name': name,
          'dosage': dosage,
          'unit': unit,
          'frequency_type': frequencyType,
          'times_of_day': timesOfDay,
          'duration_weeks': durationWeeks,
          'instructions': instructions,
          'dependent_id': dependentId,
          'inventory_count': inventoryCount,
        },
      );

      final daysToGenerate = (durationWeeks * 7).clamp(1, 14);
      for (int dayOffset = 0; dayOffset < daysToGenerate; dayOffset++) {
        final date = now.add(Duration(days: dayOffset));
        for (final timeStr in timesOfDay) {
          final parts = timeStr.split(':');
          final hour = int.tryParse(parts[0]) ?? 8;
          final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          final scheduledTime = DateTime(date.year, date.month, date.day, hour, minute);
          final doseId = _uuid.v4();

          final doseCompanion = DoseLogsCompanion.insert(
            id: doseId,
            medicationId: medId,
            scheduledTime: scheduledTime,
            status: 'pending',
            createdAt: now,
            updatedAt: now,
            isDeleted: const Value(false),
          );

          await into(doseLogs).insert(doseCompanion);

          await recordCdcEvent(
            entityType: 'dose_log',
            entityId: doseId,
            operation: 'INSERT',
            payload: {
              'id': doseId,
              'medication_id': medId,
              'scheduled_time': scheduledTime.toIso8601String(),
              'status': 'pending',
            },
          );
        }
      }
    });

    return medId;
  }

  /// Updates status of a dose log ('taken', 'pending', 'skipped') and records CDC event.
  Future<void> updateDoseStatus({
    required String doseId,
    required String status,
    DateTime? takenTime,
  }) async {
    final now = DateTime.now();
    await (update(doseLogs)..where((tbl) => tbl.id.equals(doseId))).write(
      DoseLogsCompanion(
        status: Value(status),
        takenTime: Value(takenTime),
        updatedAt: Value(now),
      ),
    );

    await recordCdcEvent(
      entityType: 'dose_log',
      entityId: doseId,
      operation: 'UPDATE',
      payload: {
        'id': doseId,
        'status': status,
        'taken_time': takenTime?.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );
  }

  /// Upserts a medication record from cloud sync.
  Future<void> upsertMedicationFromCloud(MedicationEntry entry) async {
    await into(medications).insertOnConflictUpdate(entry);
  }

  /// Upserts a dose log from cloud sync.
  Future<void> upsertDoseLogFromCloud(DoseLogEntry entry) async {
    await into(doseLogs).insertOnConflictUpdate(entry);
  }
}

/// Joined domain representation of a dose log and its parent medication.
class DoseWithMedication {
  final DoseLogEntry dose;
  final MedicationEntry medication;

  DoseWithMedication({
    required this.dose,
    required this.medication,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': dose.id,
      'medication_id': medication.id,
      'medication_name': medication.name,
      'dosage': '${medication.dosage}${medication.unit.isNotEmpty ? ' ${medication.unit}' : ''}',
      'scheduled_time': dose.scheduledTime.toIso8601String(),
      'taken_time': dose.takenTime?.toIso8601String(),
      'status': dose.status,
      'instructions': medication.instructions,
    };
  }
}


LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gobi_local.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
