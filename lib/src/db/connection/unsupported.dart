import 'package:drift/drift.dart';

LazyDatabase createDriftConnection() {
  throw UnsupportedError(
    'No suitable database implementation was found on this platform.',
  );
}
