import '../../domain/entities/vitrine_bien_immobilier.dart';
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_demande_visite.dart';
import '../../domain/entities/vitrine_galerie_item.dart';
import '../../domain/entities/vitrine_membre_equipe.dart';
import '../../domain/entities/vitrine_prestation.dart';
import '../../domain/entities/vitrine_produit_item.dart';
import '../../domain/entities/vitrine_publique_data.dart';
import '../../domain/entities/vitrine_rendez_vous.dart';
import '../../domain/repositories/vitrine_repository.dart';
import '../datasources/vitrine_remote_data_source.dart';

class VitrineRepositoryImpl implements VitrineRepository {
  const VitrineRepositoryImpl(this._remote);
  final VitrineRemoteDataSource _remote;

  // --- CONFIGURATION VITRINE ---

  @override
  Future<VitrineConfig?> chargerVitrine(String entrepriseId) {
    return _remote.chargerVitrine(entrepriseId);
  }

  @override
  Future<VitrineConfig> sauvegarderVitrine(VitrineConfig config) {
    return _remote.sauvegarderVitrine(config);
  }

  @override
  Future<VitrinePubliqueData> chargerVitrinePublique(String slugOuId) {
    return _remote.chargerVitrinePublique(slugOuId);
  }

  // --- PRESTATIONS ---

  @override
  Future<List<VitrinePrestation>> chargerPrestations(String vitrineId, String entrepriseId) {
    return _remote.chargerPrestations(vitrineId, entrepriseId);
  }

  @override
  Future<VitrinePrestation> sauvegarderPrestation(VitrinePrestation prestation) {
    return _remote.sauvegarderPrestation(prestation);
  }

  @override
  Future<void> supprimerPrestation(String prestationId) {
    return _remote.supprimerPrestation(prestationId);
  }

  // --- GALERIE ---

  @override
  Future<List<VitrineGalerieItem>> chargerGalerie(String vitrineId, String entrepriseId) {
    return _remote.chargerGalerie(vitrineId, entrepriseId);
  }

  @override
  Future<VitrineGalerieItem> ajouterPhotoGalerie(VitrineGalerieItem item) {
    return _remote.ajouterPhotoGalerie(item);
  }

  @override
  Future<void> supprimerPhotoGalerie(String photoId) {
    return _remote.supprimerPhotoGalerie(photoId);
  }

  // --- ÉQUIPE ---

  @override
  Future<List<VitrineMembreEquipe>> chargerEquipe(String vitrineId, String entrepriseId) {
    return _remote.chargerEquipe(vitrineId, entrepriseId);
  }

  @override
  Future<VitrineMembreEquipe> sauvegarderMembreEquipe(VitrineMembreEquipe membre) {
    return _remote.sauvegarderMembreEquipe(membre);
  }

  @override
  Future<void> supprimerMembreEquipe(String membreId) {
    return _remote.supprimerMembreEquipe(membreId);
  }

  // --- RENDEZ-VOUS ---

  @override
  Future<List<VitrineRendezVous>> chargerRendezVous(String entrepriseId) {
    return _remote.chargerRendezVous(entrepriseId);
  }

  @override
  Future<VitrineRendezVous> changerStatutRendezVous(
    String rdvId,
    StatutRendezVous statut, {
    String? reponse,
  }) {
    return _remote.changerStatutRendezVous(rdvId, statut, reponse: reponse);
  }

  @override
  Future<void> creerDemandeRendezVous(VitrineRendezVous rdv) {
    return _remote.creerDemandeRendezVous(rdv);
  }

  // --- BIENS IMMOBILIERS ---

  @override
  Future<List<VitrineBienImmobilier>> chargerBiens(String vitrineId, String entrepriseId) {
    return _remote.chargerBiens(vitrineId, entrepriseId);
  }

  @override
  Future<VitrineBienImmobilier> sauvegarderBien(VitrineBienImmobilier bien) {
    return _remote.sauvegarderBien(bien);
  }

  @override
  Future<void> supprimerBien(String bienId) {
    return _remote.supprimerBien(bienId);
  }

  // --- DEMANDES DE VISITE IMMOBILIÈRE ---

  @override
  Future<List<VitrineDemandeVisite>> chargerDemandesVisite(String entrepriseId) {
    return _remote.chargerDemandesVisite(entrepriseId);
  }

  @override
  Future<VitrineDemandeVisite> changerStatutDemandeVisite(String id, StatutDemandeVisite statut) {
    return _remote.changerStatutDemandeVisite(id, statut);
  }

  @override
  Future<void> creerDemandeVisite(VitrineDemandeVisite demande) {
    return _remote.creerDemandeVisite(demande);
  }

  // --- PRODUITS EN VITRINE ---

  @override
  Future<List<VitrineProduitItem>> chargerProduitsVitrine(String entrepriseId) {
    return _remote.chargerProduitsVitrine(entrepriseId);
  }

  @override
  Future<VitrineProduitItem> sauvegarderProduitVitrine(VitrineProduitItem item, String entrepriseId) {
    return _remote.sauvegarderProduitVitrine(item, entrepriseId);
  }

  @override
  Future<void> basculerPublicationProduit(String produitId, bool estPublie, {String? entrepriseId}) {
    return _remote.basculerPublicationProduit(produitId, estPublie, entrepriseId: entrepriseId);
  }

  @override
  Future<void> supprimerProduitVitrine(String produitId, {String? entrepriseId}) {
    return _remote.supprimerProduitVitrine(produitId, entrepriseId: entrepriseId);
  }
}
