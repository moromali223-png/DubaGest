import '../entities/declassement_models.dart';

abstract class DeclassementRepository {
  /// Analyse les limites du plan cible par rapport à l'usage actuel de l'entreprise.
  Future<AnalyseDeclassement> analyserLimites({
    required String entrepriseId,
    required String planCibleCode,
  });

  /// Crée ou met à jour la demande de déclassement.
  Future<DemandeDeclassement> demanderDeclassement({
    required String entrepriseId,
    required String planCibleCode,
  });

  /// Récupère la demande active de déclassement s'il en existe une.
  Future<DemandeDeclassement?> getDemandeEnCours(String entrepriseId);

  /// Suspend ou désactive / réactive une ressource unitaire (utilisateur, périmètre, activité).
  Future<void> ajusterRessource({
    required String entrepriseId,
    required String typeRessource, // 'UTILISATEUR', 'PERIMETRE', 'ACTIVITE'
    required String ressourceId,
    required String action, // 'DESACTIVER', 'ACTIVER'
  });

  /// Valide et applique atomiquement le déclassement côté serveur.
  Future<Map<String, dynamic>> validerEtAppliquerDeclassement(String demandeId);

  /// Annule une demande de déclassement sans restaurer automatiquement les données désactivées.
  Future<void> annulerDemande(String demandeId);
}
