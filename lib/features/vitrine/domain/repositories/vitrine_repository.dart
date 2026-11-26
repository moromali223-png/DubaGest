import '../entities/vitrine_config.dart';
import '../entities/vitrine_galerie_item.dart';
import '../entities/vitrine_membre_equipe.dart';
import '../entities/vitrine_prestation.dart';
import '../entities/vitrine_publique_data.dart';
import '../entities/vitrine_rendez_vous.dart';

abstract class VitrineRepository {
  // --- CONFIGURATION DE LA VITRINE ---
  Future<VitrineConfig?> chargerVitrine(String entrepriseId);
  Future<VitrineConfig> sauvegarderVitrine(VitrineConfig config);
  Future<VitrinePubliqueData> chargerVitrinePublique(String slugOuId);

  // --- PRESTATIONS & SOINS ---
  Future<List<VitrinePrestation>> chargerPrestations(String vitrineId, String entrepriseId);
  Future<VitrinePrestation> sauvegarderPrestation(VitrinePrestation prestation);
  Future<void> supprimerPrestation(String prestationId);

  // --- GALERIE & RÉALISATIONS ---
  Future<List<VitrineGalerieItem>> chargerGalerie(String vitrineId, String entrepriseId);
  Future<VitrineGalerieItem> ajouterPhotoGalerie(VitrineGalerieItem item);
  Future<void> supprimerPhotoGalerie(String photoId);

  // --- ÉQUIPE DU SALON / INSTITUT ---
  Future<List<VitrineMembreEquipe>> chargerEquipe(String vitrineId, String entrepriseId);
  Future<VitrineMembreEquipe> sauvegarderMembreEquipe(VitrineMembreEquipe membre);
  Future<void> supprimerMembreEquipe(String membreId);

  // --- DEMANDES DE RENDEZ-VOUS ---
  Future<List<VitrineRendezVous>> chargerRendezVous(String entrepriseId);
  Future<VitrineRendezVous> changerStatutRendezVous(String rdvId, StatutRendezVous statut, {String? reponse});
  Future<void> creerDemandeRendezVous(VitrineRendezVous rdv);
}
