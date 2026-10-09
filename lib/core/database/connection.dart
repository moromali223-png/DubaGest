import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Seul point qui connaît la plateforme de stockage :
/// - Android / iOS / desktop : SQLite natif (fichier dans le dossier applicatif)
/// - PWA : SQLite WASM persistant dans OPFS ou IndexedDB selon le navigateur
///   (fichiers `web/sqlite3.wasm` et `web/drift_worker.js`).
QueryExecutor openAppDatabaseConnection() => driftDatabase(
      name: 'dubagest',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
