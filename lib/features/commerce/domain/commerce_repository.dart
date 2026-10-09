import '../../finances/domain/entities/finances.dart';
import 'entities/commerce.dart';
import 'services/etat_commerce.dart';

abstract interface class CommerceRepository {
  Stream<EtatCommerce> watch(String entrepriseId);

  Future<void> creerCategorie(CategorieProduit c);
  Future<void> modifierCategorie(CategorieProduit avant, CategorieProduit apres);

  Future<void> creerProduit(Produit p, {MouvementStock? stockInitial});
  Future<void> modifierProduit(Produit avant, Produit apres);

  Future<void> enregistrerMouvement(MouvementStock m);
  Future<void> transferer(Transfert t, {required MouvementStock sortie, required MouvementStock entree});

  Future<void> creerAchat(Achat a,
      {Engagement? dette, Reception? reception, List<MouvementStock> entrees, Achat? achatRecu});
  Future<void> modifierAchat(Achat avant, Achat apres);
  Future<void> receptionner(Reception r, {required List<MouvementStock> entrees, required Achat achatRecu});

  /// Enregistre la vente et lui donne son numéro de reçu (poste de l'appareil
  /// + compteur du jour), dans la même transaction. Renvoie la vente numérotée.
  Future<Vente> vendre(Vente v,
      {required List<MouvementStock> sorties, Engagement? creance, Paiement? paiement, MouvementCaisse? mouvementCaisse});
  Future<void> annulerVente(Vente avant, Vente apres, {required List<MouvementStock> retours});

  /// L'utilisateur renonce à une écriture refusée par le serveur.
  Future<void> retirerRefuse(String table, String id);
}
