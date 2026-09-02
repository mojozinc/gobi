import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class ScheduleResult {
  final MedicationEntry medication;
  final List<DoseLogEntry> generatedDoses;
  final String summaryMessage;

  ScheduleResult({
    required this.medication,
    required this.generatedDoses,
    required this.summaryMessage,
  });
}

class MedicationRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  MedicationRepository(this._db);

  AppDatabase get db => _db;

  /// Watch all active (non-deleted) medications
  Stream<List<MedicationEntry>> watchMedications({String dependentId = 'self'}) {
    return (_db.select(_db.medications)
          ..where((t) => t.dependentId.equals(dependentId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
        .watch();
  }

  /// Watch dose logs for a given date range
  Stream<List<DoseLogEntry>> watchDosesForDateRange(DateTime start, DateTime end) {
    return (_db.select(_db.doseLogs)
          ..where((t) =>
              t.scheduledTime.isBiggerOrEqualValue(start) &
              t.scheduledTime.isSmallerOrEqualValue(end) &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.scheduledTime, mode: OrderingMode.asc)]))
        .watch();
  }

  /// Watch today's doses
  Stream<List<DoseLogEntry>> watchTodayDoses() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return watchDosesForDateRange(startOfDay, endOfDay);
  }

  /// Step 1: SET SCHEDULE
  /// Voice example: "Hey Gemini, I need to take vitamin d, once every week for next 6 weeks"
  Future<ScheduleResult> setSchedule({
    required String name,
    String frequencyType = 'weekly', // 'daily', 'weekly', 'as_needed'
    int durationWeeks = 6,
    String dosage = '1',
    String unit = 'dose',
    List<String> timesOfDay = const ['09:00'],
    String dependentId = 'self',
    String? instructions,
  }) async {
    final cleanName = name.trim();
    final now = DateTime.now();

    // Check if medication with same name already exists for this dependent
    final existing = await (_db.select(_db.medications)
          ..where((t) =>
              t.name.lower().equals(cleanName.toLowerCase()) &
              t.dependentId.equals(dependentId) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();

    final medId = existing?.id ?? _uuid.v4();
    final calculatedInventory = (frequencyType.toLowerCase().contains('week')
            ? durationWeeks
            : durationWeeks * 7 * timesOfDay.length)
        .clamp(1, 1000);

    final medCompanion = MedicationsCompanion(
      id: Value(medId),
      name: Value(cleanName),
      dosage: Value(dosage),
      unit: Value(unit),
      frequencyType: Value(frequencyType),
      timesOfDayJson: Value(jsonEncode(timesOfDay)),
      inventoryCount: Value(calculatedInventory),
      refillThreshold: const Value(2),
      dependentId: Value(dependentId),
      instructions: Value(instructions ?? 'Take once weekly as scheduled'),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
      isDeleted: const Value(false),
    );

    if (existing == null) {
      await _db.into(_db.medications).insert(medCompanion);
      await _db.recordCdcEvent(
        entityType: 'medication',
        entityId: medId,
        operation: 'INSERT',
        payload: {
          'id': medId,
          'name': cleanName,
          'dosage': dosage,
          'unit': unit,
          'frequencyType': frequencyType,
          'timesOfDay': timesOfDay,
          'durationWeeks': durationWeeks,
        },
      );
    } else {
      await (_db.update(_db.medications)..where((t) => t.id.equals(medId))).write(medCompanion);
      await _db.recordCdcEvent(
        entityType: 'medication',
        entityId: medId,
        operation: 'UPDATE',
        payload: {
          'id': medId,
          'name': cleanName,
          'frequencyType': frequencyType,
          'durationWeeks': durationWeeks,
        },
      );
    }

    // Generate scheduled dose log entries for the duration
    final generatedDoses = <DoseLogEntry>[];
    final isWeekly = frequencyType.toLowerCase().contains('week');

    for (int i = 0; i < durationWeeks; i++) {
      final scheduledDate = isWeekly
          ? now.add(Duration(days: i * 7))
          : now.add(Duration(days: i));

      final doseId = _uuid.v4();
      final doseCompanion = DoseLogsCompanion.insert(
        id: doseId,
        medicationId: medId,
        scheduledTime: scheduledDate,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
        isDeleted: const Value(false),
      );

      await _db.into(_db.doseLogs).insert(doseCompanion);
      await _db.recordCdcEvent(
        entityType: 'dose_log',
        entityId: doseId,
        operation: 'INSERT',
        payload: {
          'id': doseId,
          'medicationId': medId,
          'scheduledTime': scheduledDate.toIso8601String(),
          'status': 'pending',
        },
      );
    }

    final savedMed = await (_db.select(_db.medications)..where((t) => t.id.equals(medId))).getSingle();
    final allMedDoses = await (_db.select(_db.doseLogs)
          ..where((t) => t.medicationId.equals(medId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.scheduledTime, mode: OrderingMode.asc)]))
        .get();

    final summary = isWeekly
        ? 'Scheduled $cleanName ($dosage $unit) once weekly for the next $durationWeeks weeks ($durationWeeks doses created).'
        : 'Scheduled $cleanName ($dosage $unit) for the next $durationWeeks weeks.';

    return ScheduleResult(
      medication: savedMed,
      generatedDoses: allMedDoses,
      summaryMessage: summary,
    );
  }

  /// Finds matching medication by name, substring, or abbreviation (e.g. "vit d" -> "Vitamin D")
  Future<MedicationEntry?> findMatchingMedication(String query, {String dependentId = 'self'}) async {
    final cleanQuery = query.trim().toLowerCase();
    final allMeds = await (_db.select(_db.medications)
          ..where((t) => t.dependentId.equals(dependentId) & t.isDeleted.equals(false)))
        .get();

    if (allMeds.isEmpty) return null;

    // 1. Exact match
    for (final med in allMeds) {
      if (med.name.toLowerCase() == cleanQuery) return med;
    }

    // 2. Substring match
    for (final med in allMeds) {
      final nameLower = med.name.toLowerCase();
      if (nameLower.contains(cleanQuery) || cleanQuery.contains(nameLower)) {
        return med;
      }
    }

    // 3. Normalized abbreviation / token match (e.g. "vit d" <-> "vitamin d")
    String normalize(String s) =>
        s.toLowerCase().replaceAll('vitamin', 'vit').replaceAll(RegExp(r'[^a-z0-9]'), '');

    final normQuery = normalize(cleanQuery);
    for (final med in allMeds) {
      final normName = normalize(med.name);
      if (normName.contains(normQuery) || normQuery.contains(normName)) {
        return med;
      }
    }

    return null;
  }

  /// Step 2: GET SCHEDULE / QUERY STATUS
  /// Voice example: "Did I take vit d this week?"
  Future<Map<String, dynamic>> getScheduleStatus({
    required String name,
    DateTime? referenceDate,
    String dependentId = 'self',
  }) async {
    final now = referenceDate ?? DateTime.now();

    // Find matching medication with fuzzy / abbreviation resolution
    final med = await findMatchingMedication(name, dependentId: dependentId);

    if (med == null) {
      return {
        'found': false,
        'message': 'No schedule found for "$name".',
      };
    }

    // Determine week bounds (Monday to Sunday)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endDay = startDay.add(const Duration(days: 7));

    final thisWeekDoses = await (_db.select(_db.doseLogs)
          ..where((t) =>
              t.medicationId.equals(med.id) &
              t.scheduledTime.isBiggerOrEqualValue(startDay) &
              t.scheduledTime.isSmallerOrEqualValue(endDay) &
              t.isDeleted.equals(false)))
        .get();

    final takenDose = thisWeekDoses.cast<DoseLogEntry?>().firstWhere(
          (d) => d?.status == 'taken',
          orElse: () => null,
        );

    final pendingDose = thisWeekDoses.cast<DoseLogEntry?>().firstWhere(
          (d) => d?.status == 'pending',
          orElse: () => null,
        );

    final bool taken = takenDose != null;
    final String message;

    if (taken) {
      message = 'Yes, you took ${med.name} on ${takenDose.takenTime?.toLocal().toString().split(' ')[0] ?? 'this week'}.';
    } else if (pendingDose != null) {
      message = 'No, you have not taken ${med.name} yet this week. Next scheduled dose: ${pendingDose.scheduledTime.toLocal().toString().split(' ')[0]}.';
    } else {
      message = 'You have no scheduled doses of ${med.name} for this week.';
    }

    return {
      'found': true,
      'medication': med,
      'takenThisWeek': taken,
      'takenDose': takenDose,
      'pendingDose': pendingDose,
      'allWeekDoses': thisWeekDoses,
      'message': message,
    };
  }

  /// Step 3: RECORD DOSE
  /// Voice example: "I just took vit d in the morning"
  Future<Map<String, dynamic>> recordDose({
    required String name,
    String status = 'taken',
    DateTime? takenTime,
    String dependentId = 'self',
  }) async {
    final now = takenTime ?? DateTime.now();

    final med = await findMatchingMedication(name, dependentId: dependentId);

    if (med == null) {
      return {
        'success': false,
        'message': 'Could not find medication "$name" to record dose.',
      };
    }

    // Find the nearest pending dose for this medication
    final pendingDose = await (_db.select(_db.doseLogs)
          ..where((t) => t.medicationId.equals(med.id) & t.status.equals('pending') & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.scheduledTime, mode: OrderingMode.asc)])
          ..limit(1))
        .getSingleOrNull();

    final doseId = pendingDose?.id ?? _uuid.v4();

    if (pendingDose != null) {
      await (_db.update(_db.doseLogs)..where((t) => t.id.equals(doseId))).write(
        DoseLogsCompanion(
          status: Value(status),
          takenTime: Value(now),
          updatedAt: Value(now),
        ),
      );
    } else {
      // If no pending dose found, insert an impromptu logged dose
      await _db.into(_db.doseLogs).insert(
        DoseLogsCompanion.insert(
          id: doseId,
          medicationId: med.id,
          scheduledTime: now,
          takenTime: Value(now),
          status: status,
          createdAt: now,
          updatedAt: now,
          isDeleted: const Value(false),
        ),
      );
    }

    // Deduct inventory if taken
    if (status == 'taken' && med.inventoryCount > 0) {
      await (_db.update(_db.medications)..where((t) => t.id.equals(med.id))).write(
        MedicationsCompanion(
          inventoryCount: Value(med.inventoryCount - 1),
          updatedAt: Value(now),
        ),
      );
    }

    // Record CDC event
    await _db.recordCdcEvent(
      entityType: 'dose_log',
      entityId: doseId,
      operation: pendingDose != null ? 'UPDATE' : 'INSERT',
      payload: {
        'id': doseId,
        'medicationId': med.id,
        'status': status,
        'takenTime': now.toIso8601String(),
      },
    );

    final remainingInventory = (med.inventoryCount - 1).clamp(0, 1000);
    final message = 'Recorded ${med.name} as $status. Remaining inventory: $remainingInventory ${med.unit}.';

    return {
      'success': true,
      'medication': med,
      'doseId': doseId,
      'status': status,
      'remainingInventory': remainingInventory,
      'message': message,
    };
  }
}
