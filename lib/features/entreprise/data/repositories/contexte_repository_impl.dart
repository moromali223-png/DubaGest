import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/contexte_session.dart';
import '../../domain/repositories/contexte_repository.dart';
import '../datasources/contexte_local_data_source.dart';
import '../datasources/contexte_remote_data_source.dart';
import '../models/contexte_session_model.dart';

class ContexteRepositoryImpl implements ContexteRepository {
  ContexteRepositoryImpl({
    required ContexteRemoteDataSource remote,
    required ContexteLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final ContexteRemoteDataSource _remote;
  final ContexteLocalDataSource _local;

  @override
  Future<ContexteSession> charger(String userId, {String? entrepriseId}) async {
    try {
      final json = await _remote.fetch(entrepriseId: entrepriseId);
      await _local.write(userId, json);
      return ContexteSessionModel.fromJson(
        json,
        userId: userId,
        chargeLe: DateTime.now(),
        depuisCache: false,
      );
    } catch (e, st) {
      final failure = ErrorMapper.map(e, st);
      // Seule une indisponibilité réseau/serveur autorise le repli sur le cache :
      // un refus d'accès ou une session expirée doit remonter.
      if (!failure.isTransient) throw failure;

      final cached = await _local.read(userId);
      if (cached == null) throw failure;
      AppLogger.info('Contexte chargé depuis le cache (${failure.kind})', tag: 'contexte');
      return ContexteSessionModel.fromJson(
        cached.data,
        userId: userId,
        chargeLe: cached.storedAt,
        depuisCache: true,
      );
    }
  }
}
