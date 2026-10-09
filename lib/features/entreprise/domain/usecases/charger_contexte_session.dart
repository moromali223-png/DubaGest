import '../entities/contexte_session.dart';
import '../repositories/contexte_repository.dart';

class ChargerContexteSession {
  const ChargerContexteSession(this._repository);
  final ContexteRepository _repository;

  Future<ContexteSession> call(String userId, {String? entrepriseId}) =>
      _repository.charger(userId, entrepriseId: entrepriseId);
}
