import '../entities/document.dart';

abstract interface class DocumentRepository {
  Stream<List<Document>> watch(String entrepriseId);

  /// Blocs encore utilisables sur cet appareil pour cet utilisateur.
  Future<List<NumeroBloc>> blocs(String entrepriseId, String userId, TypeDocument type, int annee);

  /// Réserve un nouveau bloc auprès du serveur (en ligne) et le garde localement.
  Future<NumeroBloc> reserverBloc(String entrepriseId, TypeDocument type, {required String appareilId, int taille});

  /// Prend le prochain numéro d'un bloc local, construit le document et
  /// l'enregistre (avec son envoi au serveur) dans une seule transaction.
  /// `null` si aucun numéro n'est disponible sur l'appareil.
  Future<Document?> emettre({
    required String entrepriseId,
    required String userId,
    required TypeDocument type,
    required int annee,
    required Document Function(NumeroBloc bloc, int sequence) construire,
  });

  Future<void> retirerRefuse(String id);
}
