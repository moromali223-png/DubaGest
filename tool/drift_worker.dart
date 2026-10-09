// Worker SQLite de la PWA, compilé avec les versions exactes de drift et
// sqlite3 du projet (le web/sqlite3.wasm doit venir de la même version de
// sqlite3) :
//   dart compile js -O2 -o web/drift_worker.js tool/drift_worker.dart
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
