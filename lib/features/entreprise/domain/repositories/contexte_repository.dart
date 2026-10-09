import '../entities/contexte_session.dart';

abstract interface class ContexteRepository {
  /// Charge le contexte depuis le serveur et le met en cache ; hors-ligne,
  /// renvoie la dernière version mise en cache (`depuisCache = true`).
  Future<ContexteSession> charger(String userId, {String? entrepriseId});
}
