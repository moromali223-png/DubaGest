import '../entities/bien_immobilier.dart';
import '../entities/contrat_bail.dart';
import '../entities/echeance_loyer.dart';
import '../entities/locataire_immobilier.dart';
import '../entities/location_immobilier.dart';

/// Contrat du repository pour le module Immobilier (Biens, Propriétaires, Locataires, Locations, Contrats).
abstract interface class ImmobilierRepository {
  /// Flux réactif des biens de l'entreprise (avec fallback hors-ligne).
  Stream<List<BienImmobilier>> observerBiens(String entrepriseId);

  /// Récupérer un bien par son identifiant.
  Future<BienImmobilier?> getBien(String id);

  /// Créer ou mettre à jour un bien.
  Future<BienImmobilier> sauvegarderBien(BienImmobilier bien);

  /// Mettre à jour le statut d'un bien (disponible, réservé, occupé, en travaux).
  Future<void> changerStatutBien(String id, StatutBien nouveauStatut);

  /// Archiver un bien.
  Future<void> archiverBien(String id);

  /// Observer les biens appartenant à un propriétaire donné.
  Stream<List<BienImmobilier>> observerBiensParProprietaire(
    String entrepriseId,
    String proprietaireId,
  );

  // --- LOCATAIRES ---

  /// Flux réactif de tous les dossiers/profils locataires d'une entreprise.
  Stream<List<ProfilLocataire>> observerProfilsLocataires(String entrepriseId);

  /// Récupérer le dossier locataire associé à un contact donné.
  Future<ProfilLocataire?> getProfilLocataire(String contactId);

  /// Enregistrer ou mettre à jour le dossier locatif d'un locataire.
  Future<ProfilLocataire> sauvegarderProfilLocataire(ProfilLocataire profil);

  // --- LOCATIONS ---

  /// Flux réactif de toutes les locations de l'entreprise.
  Stream<List<LocationImmobilier>> observerLocations(String entrepriseId);

  /// Récupérer une location par son identifiant.
  Future<LocationImmobilier?> getLocation(String id);

  /// Enregistrer ou modifier une location (avec vérification anti-chevauchement).
  Future<LocationImmobilier> sauvegarderLocation(LocationImmobilier location);

  /// Clôturer une location (sortie des lieux) et mettre à jour le statut du bien.
  Future<void> cloturerLocation(
    String id, {
    required DateTime dateSortie,
    required String motif,
    required StatutBien futurStatutBien,
  });

  /// Observer les locations successives associées à un bien donné.
  Stream<List<LocationImmobilier>> observerLocationsParBien(String bienId);

  /// Observer les locations associées à un locataire donné.
  Stream<List<LocationImmobilier>> observerLocationsParLocataire(String locataireId);

  // --- CONTRATS DE BAIL ---

  /// Flux réactif de tous les contrats de bail de l'entreprise.
  Stream<List<ContratBail>> observerContrats(String entrepriseId);

  /// Récupérer un contrat de bail par son identifiant.
  Future<ContratBail?> getContrat(String id);

  /// Enregistrer ou modifier un contrat de bail.
  Future<ContratBail> sauvegarderContrat(ContratBail contrat);

  /// Mettre à jour le statut du contrat (activer, préavis, terminer, résilier).
  Future<void> changerStatutContrat(String id, StatutContratBail nouveauStatut);

  /// Apposer la signature du bailleur ou du locataire sur le contrat.
  Future<void> signerContrat(String id, {bool bailleur = false, bool locataire = false});

  /// Observer les contrats de bail d'un bien donné.
  Stream<List<ContratBail>> observerContratsParBien(String bienId);

  /// Observer les contrats de bail d'un locataire donné.
  Stream<List<ContratBail>> observerContratsParLocataire(String locataireId);

  // --- ÉCHÉANCES DE LOYERS & ENCAISSEMENTS ---

  /// Flux réactif des échéances de loyers d'une entreprise (filtrable par période).
  Stream<List<EcheanceLoyer>> observerEcheancesLoyers(String entrepriseId, {int? annee, int? mois});

  /// Récupérer une échéance de loyer par son identifiant.
  Future<EcheanceLoyer?> getEcheanceLoyer(String id);

  /// Sauvegarder ou modifier une échéance de loyer.
  Future<EcheanceLoyer> sauvegarderEcheanceLoyer(EcheanceLoyer echeance);

  /// Génération idempotente des appels de loyers mensuels pour tous les baux actifs.
  Future<List<EcheanceLoyer>> genererAppelsLoyersMensuels({
    required String entrepriseId,
    required int mois,
    required int annee,
  });

  /// Enregistrer un encaissement (loyer partiel ou total), avec mise à jour du statut
  /// de l'échéance et création d'un paiement comptable relié à l'engagement.
  Future<void> enregistrerPaiementLoyer({
    required String echeanceId,
    required int montantVerse,
    required String modePaiement,
    String? referencePaiement,
    String? note,
    DateTime? datePaiement,
    String? quittanceDocumentId,
    String? recuDocumentId,
  });

  /// Observer les échéances de loyer associées à un locataire donné.
  Stream<List<EcheanceLoyer>> observerEcheancesParLocataire(String locataireId);

  /// Observer les échéances de loyer associées à un bien donné.
  Stream<List<EcheanceLoyer>> observerEcheancesParBien(String bienId);
}
