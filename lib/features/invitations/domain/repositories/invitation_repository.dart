import '../entities/invitation.dart';

/// Toutes les opérations passent par des RPC serveur : le rôle et les
/// périmètres d'une invitation ne sont jamais fixés par l'invité.
abstract interface class InvitationRepository {
  Future<InvitationCreee> creer({
    required String entrepriseId,
    required String email,
    required String roleCode,
    required List<String> perimetreIds,
  });
  Future<List<Invitation>> lister(String entrepriseId);
  Future<void> annuler(String invitationId);
  Future<InvitationApercu> verifier(String token);

  /// Retourne l'identifiant de l'entreprise rejointe.
  Future<String> accepter(String token);

  /// Jeton reçu par lien, conservé jusqu'à la connexion puis l'acceptation.
  String? get jetonEnAttente;
  Future<void> memoriserJeton(String token);
  Future<void> oublierJeton();
}
