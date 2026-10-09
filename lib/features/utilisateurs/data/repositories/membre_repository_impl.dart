import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/membre.dart';
import '../../domain/repositories/membre_repository.dart';
import '../datasources/membre_data_sources.dart';

class MembreRepositoryImpl implements MembreRepository {
  MembreRepositoryImpl({required MembreRemoteDataSource remote, required MembreLocalDataSource local})
      : _remote = remote,
        _local = local;

  final MembreRemoteDataSource _remote;
  final MembreLocalDataSource _local;

  @override
  Future<List<Membre>> lister(String entrepriseId) async {
    try {
      final rows = await _remote.lister(entrepriseId);
      await _local.ecrire(entrepriseId, rows);
      return rows.map(_fromJson).toList();
    } catch (e, st) {
      final failure = ErrorMapper.map(e, st);
      if (!failure.isTransient) throw failure;
      final cached = await _local.lire(entrepriseId);
      if (cached == null) throw failure;
      return cached.map(_fromJson).toList();
    }
  }

  @override
  Future<void> affecter({
    required String entrepriseId,
    required String membreId,
    required String perimetreId,
  }) =>
      _guard(() => _remote.affecter(
            entrepriseId: entrepriseId,
            membreId: membreId,
            perimetreId: perimetreId,
          ));

  @override
  Future<void> retirer({required String membreId, required String perimetreId}) =>
      _guard(() => _remote.retirer(membreId: membreId, perimetreId: perimetreId));

  @override
  Future<void> modifierRole({
    required String entrepriseId,
    required String membreId,
    required String roleCode,
  }) =>
      _guard(() => _remote.modifierRole(membreId: membreId, roleCode: roleCode));

  @override
  Future<void> modifierStatut({
    required String entrepriseId,
    required String membreId,
    required String statut,
  }) =>
      _guard(() => _remote.modifierStatut(membreId: membreId, statut: statut));

  @override
  Future<void> supprimer({
    required String entrepriseId,
    required String membreId,
  }) =>
      _guard(() => _remote.supprimer(membreId: membreId));

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  static Membre _fromJson(Map<String, dynamic> j) => Membre(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        roleCode: j['role_code'] as String,
        statut: MembreStatut.parse(j['statut'] as String),
        nomComplet: (j['profiles'] as Map<String, dynamic>?)?['nom_complet'] as String?,
        perimetreIds: {
          for (final a in (j['membre_perimetres'] as List? ?? const []).cast<Map<String, dynamic>>())
            a['perimetre_id'] as String,
        },
      );
}
