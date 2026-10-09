import '../entities/finances.dart';
import '../services/etat_finances.dart';

/// Noyau financier : écriture locale (hors-ligne) puis synchronisation.
/// Les règles réelles (droits, reste dû, caisse ouverte, solde) sont
/// appliquées par le serveur ; l'application les vérifie aussi pour
/// prévenir l'utilisateur avant l'envoi.
abstract interface class FinancesRepository {
  Stream<EtatFinances> watch(String entrepriseId);

  Future<void> creerEngagement(Engagement engagement);
  Future<void> modifierEngagement(Engagement avant, Engagement apres);

  /// Paiement + ses affectations + son mouvement de caisse éventuel : une
  /// seule opération envoyée, appliquée en bloc par le serveur.
  Future<void> enregistrerPaiement(Paiement paiement, {MouvementCaisse? mouvement});

  Future<void> creerCaisse(Caisse caisse);
  Future<void> ouvrirSession(SessionCaisse session);
  Future<void> cloturerSession(SessionCaisse session, {required int soldeReel, String? note, MotifEcart? motifEcart});

  /// Transfert : une seule opération envoyée ; ses deux jambes (paiements,
  /// mouvements d'espèces) sont des copies locales de ce que créera le serveur.
  Future<void> enregistrerTransfert(
    TransfertTresorerie transfert, {
    required List<(Paiement, MouvementCaisse?)> jambes,
  });
  Future<void> annulerTransfert(
    TransfertTresorerie avant,
    TransfertTresorerie apres, {
    required List<(Paiement, MouvementCaisse?)> jambes,
  });
  Future<void> mouvementManuel(MouvementCaisse mouvement, {required String entrepriseId});

  /// Dépense + sa somme à payer liée + (payée maintenant) son paiement et sa
  /// sortie de caisse : une seule opération envoyée, appliquée en bloc.
  Future<void> enregistrerDepense(
    Depense depense, {
    required Engagement engagement,
    Paiement? paiement,
    MouvementCaisse? mouvement,
  });

  /// Texte, catégorie, date, ou annulation (montant non modifiable).
  Future<void> modifierDepense(Depense avant, Depense apres);

  /// Dépenses courantes (modèles) : jamais de suppression, on les arrête.
  Future<void> creerCourante(DepenseCourante courante);
  Future<void> modifierCourante(DepenseCourante avant, DepenseCourante apres);

  Future<void> creerCategorie(CategorieDepense categorie);
  Future<void> modifierCategorie(CategorieDepense avant, {String? nom, bool? estActive});

  /// Retire de l'appareil une écriture refusée par le serveur (elle n'a
  /// jamais existé côté serveur), avec ce qui en découle localement.
  Future<void> retirerRefuse(String table, String id);
}
