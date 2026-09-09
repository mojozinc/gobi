import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';

class TestDataHydrator {
  static const _uuid = Uuid();

  /// Automatically seeds sample datasets on startup if local database is empty.
  /// Strictly guarded by kDebugMode so it never executes in release builds.
  static Future<void> seedIfEmpty(AppDatabase db) async {
    if (!kDebugMode) return;
    try {
      final existing = await (db.select(db.medications)..where((t) => t.isDeleted.equals(false))).get();
      if (existing.isEmpty) {
        await seedSampleDatasets(db, clearExisting: false);
      }
    } catch (e) {
      debugPrint('TestDataHydrator.seedIfEmpty notice: $e');
    }
  }

  /// Wipes and/or populates the 3 rich sample datasets into local Drift SQLite.
  static Future<void> seedSampleDatasets(AppDatabase db, {bool clearExisting = false}) async {
    if (!kDebugMode) return;

    if (clearExisting) {
      await clearAllLocalData(db);
    }

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // ── 1. Dataset 1: Acute Short Course (Tier 1 — 5 Days Amoxicillin) ──
    final amoxId = 'sample-med-amoxicillin-5d';
    final amoxStartDate = todayMidnight.subtract(const Duration(days: 3)); // Day 4 is today
    await _seedMedicationWithDoses(
      db: db,
      id: amoxId,
      name: 'Amoxicillin',
      dosage: '500mg',
      unit: 'capsule',
      frequencyType: '3 times daily',
      timesOfDay: ['08:00', '14:00', '20:00'],
      durationWeeks: 1, // 5 days scheduled
      totalDays: 5,
      startDate: amoxStartDate,
      instructions: 'Finish full 5-day course with food.',
      inventoryCount: 15,
      doseDeltas: (dayIndex, timeStr) {
        // Day 0 (3d ago), Day 1 (2d ago): All taken
        if (dayIndex <= 1) return DoseState.taken;
        // Day 2 (yesterday): 08:00 & 14:00 taken, 20:00 missed
        if (dayIndex == 2) {
          return timeStr == '20:00' ? DoseState.missed : DoseState.taken;
        }
        // Day 3 (today): 08:00 taken, 14:00 & 20:00 pending
        if (dayIndex == 3) {
          return timeStr == '08:00' ? DoseState.taken : DoseState.pending;
        }
        // Day 4 (tomorrow): pending
        return DoseState.pending;
      },
    );

    // ── 2. Dataset 2: Medium Course (Tier 2 — 4 Weeks / 28 Days Prednisone) ──
    final predId = 'sample-med-prednisone-4w';
    final predStartDate = todayMidnight.subtract(const Duration(days: 14)); // Day 15 is today
    await _seedMedicationWithDoses(
      db: db,
      id: predId,
      name: 'Prednisone',
      dosage: '10mg',
      unit: 'tablet',
      frequencyType: 'twice daily',
      timesOfDay: ['08:00', '20:00'],
      durationWeeks: 4,
      totalDays: 28,
      startDate: predStartDate,
      instructions: 'Tapering dose. Take after breakfast and dinner.',
      inventoryCount: 40,
      doseDeltas: (dayIndex, timeStr) {
        // Days 0..9: All taken
        if (dayIndex < 10) return DoseState.taken;
        // Day 10: 1 of 2 taken
        if (dayIndex == 10) return timeStr == '08:00' ? DoseState.taken : DoseState.missed;
        // Day 11: 0 of 2 taken (missed day)
        if (dayIndex == 11) return DoseState.missed;
        // Days 12..13: All taken
        if (dayIndex < 14) return DoseState.taken;
        // Day 14 (today): 08:00 taken, 20:00 pending
        if (dayIndex == 14) return timeStr == '08:00' ? DoseState.taken : DoseState.pending;
        // Future days: pending
        return DoseState.pending;
      },
    );

    // ── 3. Dataset 3: Chronic Long Course (Tier 3 — 12 Weeks / 84 Days Metformin) ──
    final metId = 'sample-med-metformin-12w';
    final metStartDate = todayMidnight.subtract(const Duration(days: 42)); // Day 43 is today (Week 7)
    await _seedMedicationWithDoses(
      db: db,
      id: metId,
      name: 'Metformin',
      dosage: '500mg',
      unit: 'tablet',
      frequencyType: 'twice daily',
      timesOfDay: ['08:00', '20:00'],
      durationWeeks: 12,
      totalDays: 84,
      startDate: metStartDate,
      instructions: 'Take with evening meal to minimize GI upset.',
      inventoryCount: 120,
      doseDeltas: (dayIndex, timeStr) {
        // Past 42 days (Day 0..41): High adherence (~92%)
        if (dayIndex < 42) {
          // A couple of scattered missed doses in past weeks
          if (dayIndex == 12 && timeStr == '20:00') return DoseState.missed;
          if (dayIndex == 25 && timeStr == '08:00') return DoseState.missed;
          if (dayIndex == 34) return DoseState.missed; // 1 whole missed day
          return DoseState.taken;
        }
        // Day 42 (today): 08:00 taken, 20:00 pending
        if (dayIndex == 42) {
          return timeStr == '08:00' ? DoseState.taken : DoseState.pending;
        }
        // Future days: pending
        return DoseState.pending;
      },
    );
  }

  /// Clears all local medications, dose logs, and CDC events.
  static Future<void> clearAllLocalData(AppDatabase db) async {
    await db.transaction(() async {
      await db.delete(db.doseLogs).go();
      await db.delete(db.medications).go();
      await db.delete(db.cdcEvents).go();
    });
  }

  /// Collects database diagnostics counts.
  static Future<Map<String, int>> getDiagnostics(AppDatabase db) async {
    final activeMeds = await (db.select(db.medications)..where((t) => t.isDeleted.equals(false))).get();
    final todayMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final todayEnd = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
    final todayDoses = await (db.select(db.doseLogs)
          ..where((t) =>
              t.isDeleted.equals(false) &
              t.scheduledTime.isBiggerOrEqualValue(todayMidnight) &
              t.scheduledTime.isSmallerOrEqualValue(todayEnd)))
        .get();
    final totalDoses = await (db.select(db.doseLogs)..where((t) => t.isDeleted.equals(false))).get();
    final unsyncedCdc = await (db.select(db.cdcEvents)..where((t) => t.isSynced.equals(false))).get();

    return {
      'active_medications': activeMeds.length,
      'today_doses': todayDoses.length,
      'total_doses': totalDoses.length,
      'unsynced_cdc_events': unsyncedCdc.length,
    };
  }

  static Future<void> _seedMedicationWithDoses({
    required AppDatabase db,
    required String id,
    required String name,
    required String dosage,
    required String unit,
    required String frequencyType,
    required List<String> timesOfDay,
    required int durationWeeks,
    required int totalDays,
    required DateTime startDate,
    required String instructions,
    required int inventoryCount,
    required DoseState Function(int dayIndex, String timeStr) doseDeltas,
  }) async {
    final now = DateTime.now();

    await db.transaction(() async {
      // Upsert medication
      await db.into(db.medications).insertOnConflictUpdate(
            MedicationsCompanion.insert(
              id: id,
              name: name,
              dosage: dosage,
              unit: unit,
              frequencyType: frequencyType,
              timesOfDayJson: jsonEncode(timesOfDay),
              inventoryCount: Value(inventoryCount),
              refillThreshold: const Value(5),
              dependentId: const Value('self'),
              instructions: Value(instructions),
              createdAt: startDate,
              updatedAt: now,
              isDeleted: const Value(false),
            ),
          );

      // Clean existing doses for this med if any
      await (db.delete(db.doseLogs)..where((t) => t.medicationId.equals(id))).go();

      // Populate day by day
      for (int day = 0; day < totalDays; day++) {
        final dayDate = startDate.add(Duration(days: day));
        for (final timeStr in timesOfDay) {
          final parts = timeStr.split(':');
          final hour = int.tryParse(parts[0]) ?? 8;
          final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          final scheduledTime = DateTime(dayDate.year, dayDate.month, dayDate.day, hour, minute);

          final state = doseDeltas(day, timeStr);
          final status = state == DoseState.taken
              ? 'taken'
              : state == DoseState.missed
                  ? 'missed'
                  : 'pending';

          final takenTime = state == DoseState.taken
              ? scheduledTime.add(const Duration(minutes: 7))
              : null;

          await db.into(db.doseLogs).insert(
                DoseLogsCompanion.insert(
                  id: _uuid.v4(),
                  medicationId: id,
                  scheduledTime: scheduledTime,
                  takenTime: Value(takenTime),
                  status: status,
                  createdAt: startDate,
                  updatedAt: now,
                  isDeleted: const Value(false),
                ),
              );
        }
      }
    });
  }
}

enum DoseState {
  taken,
  missed,
  pending,
}
