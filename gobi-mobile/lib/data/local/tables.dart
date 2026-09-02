import 'package:drift/drift.dart';

/// Change Data Capture (CDC) events table for append-only distributed event sourcing
@DataClassName('CdcEventEntry')
class CdcEvents extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get entityType => text()(); // 'medication', 'dose_log', 'dependent', 'vital'
  TextColumn get entityId => text()(); // UUID of target row
  TextColumn get operation => text()(); // 'INSERT', 'UPDATE', 'DELETE'
  TextColumn get payload => text()(); // JSON string of delta
  TextColumn get hlcTimestamp => text()(); // "millis:counter:deviceId"
  TextColumn get deviceId => text()(); // Originating device UUID
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Medications table (Local-first primary source of truth)
@DataClassName('MedicationEntry')
class Medications extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()();
  TextColumn get dosage => text()(); // e.g. "500"
  TextColumn get unit => text()(); // e.g. "mg", "ml", "tablet", "capsule"
  TextColumn get frequencyType => text()(); // 'daily', 'as_needed', 'weekly', 'custom'
  TextColumn get timesOfDayJson => text()(); // JSON array e.g. ["08:00", "20:00"]
  IntColumn get inventoryCount => integer().withDefault(const Constant(0))();
  IntColumn get refillThreshold => integer().withDefault(const Constant(5))();
  TextColumn get dependentId => text().withDefault(const Constant('self'))();
  TextColumn get instructions => text().nullable()(); // e.g. "Take with food"
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dose logs table for adherence tracking
@DataClassName('DoseLogEntry')
class DoseLogs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get medicationId => text().references(Medications, #id)();
  DateTimeColumn get scheduledTime => dateTime()();
  DateTimeColumn get takenTime => dateTime().nullable()();
  TextColumn get status => text()(); // 'taken', 'skipped', 'pending'
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Family members / Dependents profiles
@DataClassName('DependentEntry')
class Dependents extends Table {
  TextColumn get id => text()(); // UUID or 'self'
  TextColumn get name => text()();
  TextColumn get relationship => text()(); // 'self', 'parent', 'child', 'spouse', 'other'
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Health metrics and vitals logs
@DataClassName('VitalLogEntry')
class VitalsLogs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get dependentId => text()();
  TextColumn get vitalType => text()(); // 'blood_pressure', 'blood_sugar', 'heart_rate', 'weight'
  TextColumn get valueJson => text()(); // JSON payload
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
