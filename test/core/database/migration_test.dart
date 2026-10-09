import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:dubagest/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Version future simulée (actuelle + 1) : ajoute une table, sans toucher aux données.
class _AppDatabaseV2 extends AppDatabase {
  _AppDatabaseV2(super.executor);

  @override
  int get schemaVersion => super.schemaVersion + 1;

  @override
  Future<void> migrerVers(Migrator m, int version) async {
    if (version == super.schemaVersion + 1) {
      await customStatement('CREATE TABLE nouveautes_v2 (id TEXT PRIMARY KEY)');
    } else {
      await super.migrerVers(m, version);
    }
  }
}

/// Version du schéma de l'application (sans ouvrir de base).
final _actuelle = AppDatabase(NativeDatabase.memory()).schemaVersion;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dossier;
  late File fichier;

  setUp(() {
    dossier = Directory.systemTemp.createTempSync('dubagest_migration_');
    fichier = File('${dossier.path}${Platform.pathSeparator}dubagest.sqlite');
  });
  tearDown(() => dossier.deleteSync(recursive: true));

  test('mise à jour du schéma : données conservées et sauvegarde préalable', () async {
    final v1 = AppDatabase(NativeDatabase(fichier));
    await v1.into(v1.jsonCache).insert(JsonCacheCompanion.insert(
          cle: 'contexte:u-1',
          contenu: '{"entreprise":"Alpha"}',
          majLe: DateTime(2026, 10, 5),
        ));
    await v1.close();

    final v2 = _AppDatabaseV2(NativeDatabase(fichier));
    final lignes = await v2.select(v2.jsonCache).get();
    expect(lignes.single.contenu, '{"entreprise":"Alpha"}', reason: 'aucune perte de données');
    final table = await v2.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'nouveautes_v2'",
    ).get();
    expect(table, hasLength(1), reason: 'étape suivante appliquée');
    await v2.close();

    final sauvegardes = dossier.listSync().whereType<File>().where((f) => f.path.contains('.v$_actuelle-')).toList();
    expect(sauvegardes, hasLength(1), reason: 'copie de la version actuelle avant migration');
    final copie = AppDatabase(NativeDatabase(sauvegardes.single));
    expect((await copie.select(copie.jsonCache).get()).single.cle, 'contexte:u-1');
    await copie.close();
  });

  test('version sans étape de migration : refus d\'ouvrir plutôt que de corrompre', () async {
    final v1 = AppDatabase(NativeDatabase(fichier));
    await v1.select(v1.jsonCache).get();
    await v1.close();

    final v3 = _AppDatabaseV3(NativeDatabase(fichier));
    await expectLater(v3.select(v3.jsonCache).get(), throwsA(anything));
    await v3.close();
  });

  test('ouverture répétée de la même version : rien ne change', () async {
    final a = AppDatabase(NativeDatabase(fichier));
    await a.into(a.jsonCache).insert(
        JsonCacheCompanion.insert(cle: 'k', contenu: '{}', majLe: DateTime(2026)));
    await a.close();
    final b = AppDatabase(NativeDatabase(fichier));
    expect(await b.select(b.jsonCache).get(), hasLength(1));
    await b.close();
    expect(dossier.listSync().where((f) => f.path.endsWith('.bak')), isEmpty);
  });
}

class _AppDatabaseV3 extends _AppDatabaseV2 {
  _AppDatabaseV3(super.executor);

  @override
  int get schemaVersion => super.schemaVersion + 1;
}
