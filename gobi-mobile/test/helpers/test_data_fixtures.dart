import '../data/local/test_data_hydrator.dart' if (dart.library.io) 'package:gobi_mobile/data/local/test_data_hydrator.dart';
import 'package:gobi_mobile/data/local/app_database.dart';

class TestDataFixtures {
  /// Seeds all 3 rich sample datasets (Amoxicillin, Prednisone, Metformin).
  static Future<void> seedAll(AppDatabase db) async {
    await TestDataHydrator.seedSampleDatasets(db, clearExisting: true);
  }

  /// Clears all local data.
  static Future<void> clear(AppDatabase db) async {
    await TestDataHydrator.clearAllLocalData(db);
  }

  /// Retrieves database statistics.
  static Future<Map<String, int>> getDiagnostics(AppDatabase db) async {
    return TestDataHydrator.getDiagnostics(db);
  }
}
