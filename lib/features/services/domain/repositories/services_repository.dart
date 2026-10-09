import '../entities/prestation.dart';
import '../entities/service_catalogue.dart';

abstract class ServicesRepository {
  /// Catalogue des prestations types.
  Stream<List<ServiceCatalogue>> observerCatalogue(String entrepriseId);
  Future<ServiceCatalogue> sauvegarderService(ServiceCatalogue service);
  Future<void> archiverService(String serviceId);

  /// Prestations / Ordres de travail.
  Stream<List<Prestation>> observerPrestations(String entrepriseId, {String? perimetreId});
  Future<Prestation?> getPrestation(String prestationId);
  Future<Prestation> creerPrestation(Prestation prestation);
  Future<Prestation> modifierPrestation(Prestation prestation);
  Future<void> changerStatutPrestation(String prestationId, StatutPrestation nouveauStatut, {String? motif});
  Future<void> reporterPrestation(String prestationId, DateTime nouvelleEcheanceJour, String? nouvelleEcheanceHeure, String motif);
  Future<void> annulerPrestation(String prestationId, String motif);

  /// Historique des modifications d'une prestation.
  Stream<List<PrestationHistorique>> observerHistorique(String prestationId);

  /// Devis de prestations.
  Stream<List<DevisPrestation>> observerDevis(String entrepriseId, {String? perimetreId});
  Future<DevisPrestation> creerDevis(DevisPrestation devis);
  Future<DevisPrestation> modifierDevis(DevisPrestation devis);
  Future<void> changerStatutDevis(String devisId, StatutDevis nouveauStatut);
  Future<Prestation> convertirDevisEnPrestation(String devisId);
}
