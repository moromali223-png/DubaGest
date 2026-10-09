import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:dubagest/core/database/app_database.dart';

/// Base SQLite en mémoire (même schéma que l'application).
AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}
