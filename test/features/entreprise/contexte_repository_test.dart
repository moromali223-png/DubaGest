import 'package:dubagest/core/database/json_cache_store.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/features/entreprise/data/datasources/contexte_local_data_source.dart';
import 'package:dubagest/features/entreprise/data/datasources/contexte_remote_data_source.dart';
import 'package:dubagest/features/entreprise/data/repositories/contexte_repository_impl.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/test_database.dart';

class _Remote implements ContexteRemoteDataSource {
  Object? error;
  Map<String, dynamic> response = contexteJson(role: 'VENDEUR', perimetres: [perimetreJson('b-1')]);

  @override
  Future<Map<String, dynamic>> fetch({String? entrepriseId}) async {
    if (error case final e?) throw e;
    return response;
  }
}

void main() {
  late _Remote remote;
  late ContexteRepositoryImpl repository;

  setUp(() {
    remote = _Remote();
    final db = memoryDatabase();
    addTearDown(db.close);
    repository = ContexteRepositoryImpl(
      remote: remote,
      local: DriftContexteLocalDataSource(JsonCacheStore(db)),
    );
  });

  test('en ligne : entreprise, abonnement, activités, rôle, permissions, périmètres', () async {
    final ctx = await repository.charger(userId);
    expect(ctx.depuisCache, isFalse);
    expect(ctx.etat, ContexteEtat.pret);
    expect(ctx.entreprise!.nom, 'Alpha');
    expect(ctx.abonnement!.planCode, 'MOYEN');
    expect(ctx.activites.single.activite.code, 'COMMERCE');
    expect(ctx.membre!.roleCode, 'VENDEUR');
    expect(ctx.permissions, contains('sales.create'));
    expect(ctx.perimetres.single.id, 'b-1');
  });

  test('hors-ligne : dernier contexte connu depuis l\'appareil', () async {
    await repository.charger(userId);
    remote.error = const Failure(FailureKind.network);
    final ctx = await repository.charger(userId);
    expect(ctx.depuisCache, isTrue);
    expect(ctx.membre!.roleCode, 'VENDEUR');
  });

  test('hors-ligne sans cache : l\'erreur remonte', () async {
    remote.error = const Failure(FailureKind.network);
    expect(() => repository.charger(userId), throwsA(isA<Failure>()));
  });

  test('accès refusé : pas de repli sur un cache potentiellement révoqué', () async {
    await repository.charger(userId);
    remote.error = const Failure(FailureKind.forbidden);
    expect(
      () => repository.charger(userId),
      throwsA(isA<Failure>().having((f) => f.kind, 'kind', FailureKind.forbidden)),
    );
  });
}
