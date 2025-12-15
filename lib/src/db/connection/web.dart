import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

LazyDatabase createDriftConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'life_tracker_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      print(
        'Using ${result.chosenImplementation} due to unsupported '
        'browser features: ${result.missingFeatures}',
      );
    }

    return result.resolvedExecutor;
  });
}
