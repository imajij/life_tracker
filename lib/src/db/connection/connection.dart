import 'package:drift/drift.dart';

// Conditional imports based on platform
import 'unsupported.dart'
    if (dart.library.html) 'web.dart'
    if (dart.library.io) 'native.dart';

LazyDatabase openConnection() {
  return createDriftConnection();
}
