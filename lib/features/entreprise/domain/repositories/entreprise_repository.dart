import '../../../activites/domain/entities/activite.dart';
import '../entities/offre_plan.dart';
import '../entities/profil_entreprise.dart';

abstract interface class EntrepriseRepository {
  Future<List<OffrePlan>> offres();

  /// Création transactionnelle côté serveur : entreprise, abonnement d'essai,
  /// activités, premier périmètre, et le créateur comme administrateur.
  Future<String> creer({
    required String nom,
    required String planCode,
    required List<ActiviteCode> activites,
  });

  Future<ProfilEntreprise> profil(String entrepriseId);

  /// En ligne : RLS (`entreprise.manage`) et privilèges colonnes côté serveur.
  Future<void> enregistrerProfil(ProfilEntreprise profil);

  /// En ligne : modes de paiement proposés et pied de reçu (`entreprise.manage`,
  /// modes vérifiés par le serveur).
  Future<void> enregistrerParametres(String entrepriseId, {required List<String> modesPaiement, String? piedRecu});

  /// Ajoute (ou réactive) une activité. Formule et limites sont revérifiées
  /// par le serveur (trigger `app.tg_verifier_activite`).
  Future<void> activerActivite({
    required String entrepriseId,
    required ActiviteCode activite,
    required bool dejaRattachee,
  });
}
