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

  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  static const String _deviceIdPrefKey = 'gobi_device_id';
  static const _uuid = Uuid();
  String? _cachedDeviceId;
  HLC? _lastHlc;

  /// Retrieves or generates a persistent device UUID for CDC event attribution.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdPrefKey);
    if (id == null) {
      id = _uuid.v4();
      await prefs.setString(_deviceIdPrefKey, id);
    }
    _cachedDeviceId = id;
    return id;
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gobi_local.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
