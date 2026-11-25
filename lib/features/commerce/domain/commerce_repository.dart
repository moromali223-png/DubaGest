import '../../finances/domain/entities/finances.dart';
import 'entities/commerce.dart';
import 'services/etat_commerce.dart';

abstract interface class CommerceRepository {
  Stream<EtatCommerce> watch(String entrepriseId);

  Future<void> creerCategorie(CategorieProduit c);
  Future<void> modifierCategorie(CategorieProduit avant, CategorieProduit apres);

  Future<void> creerProduit(Produit p, {MouvementStock? stockInitial, LotStock? lotInitial});
  Future<void> modifierProduit(Produit avant, Produit apres);
  Future<void> modifierLot(LotStock lot);
  Future<void> supprimerProduit(Produit p);

  Future<void> enregistrerMouvement(MouvementStock m, {LotStock? lotCree});
  Future<void> transferer(Transfert t,
      {required MouvementStock sortie,
      required MouvementStock entree,
      List<LotStock> lotsModifies = const [],
      List<LotStock> lotsCrees = const []});

  Future<void> creerAchat(Achat a,
      {Engagement? dette,
      Reception? reception,
      List<MouvementStock> entrees = const [],
      Achat? achatRecu,
      List<LotStock> lotsCrees = const []});
  Future<void> modifierAchat(Achat avant, Achat apres);
  Future<void> receptionner(Reception r,
      {required List<MouvementStock> entrees, required Achat achatRecu, List<LotStock> lotsCrees = const []});

  /// Enregistre la vente et lui donne son numéro de reçu (poste de l'appareil
  /// + compteur du jour), dans la même transaction. Renvoie la vente numérotée.
  Future<Vente> vendre(Vente v,
      {required List<MouvementStock> sorties,
      List<LotStock> lotsModifies = const [],
      Engagement? creance,
      Paiement? paiement,
      MouvementCaisse? mouvementCaisse});
  Future<void> annulerVente(Vente avant, Vente apres, {required List<MouvementStock> retours});

  /// L'utilisateur renonce à une écriture refusée par le serveur.
  Future<void> retirerRefuse(String table, String id);
}
