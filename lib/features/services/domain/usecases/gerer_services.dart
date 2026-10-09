import 'package:uuid/uuid.dart';

import '../entities/metier_template.dart';
import '../entities/prestation.dart';
import '../entities/service_catalogue.dart';
import '../repositories/services_repository.dart';

class GererServices {
  const GererServices(this._repository);

  final ServicesRepository _repository;
  static const _uuid = Uuid();

  // --- CATALOGUE ---

  Future<ServiceCatalogue> ajouterAuCatalogue({
    required String entrepriseId,
    required String nom,
    String? categorie,
    String? description,
    int prix = 0,
    UniteFacturation unite = UniteFacturation.forfait,
    int? dureeMinutes,
    String? icone,
  }) {
    final s = ServiceCatalogue(
      id: _uuid.v4(),
      entrepriseId: entrepriseId,
      nom: nom.trim(),
      categorie: categorie?.trim().isNotEmpty == true ? categorie!.trim() : null,
      description: description?.trim().isNotEmpty == true ? description!.trim() : null,
      prix: prix,
      unite: unite,
      dureeMinutes: dureeMinutes,
      icone: icone,
    );
    return _repository.sauvegarderService(s);
  }

  Future<ServiceCatalogue> modifierServiceCatalogue(ServiceCatalogue service) {
    return _repository.sauvegarderService(service);
  }

  Future<void> archiverServiceCatalogue(String serviceId) {
    return _repository.archiverService(serviceId);
  }

  // --- PRESTATIONS ---

  Future<Prestation> creerPrestation({
    required String entrepriseId,
    String? perimetreId,
    String? contactId,
    required String titre,
    String? description,
    required List<LignePrestation> lignes,
    int remise = 0,
    PrioritePrestation priorite = PrioritePrestation.normale,
    DateTime? debutPrevu,
    DateTime? echeanceJour,
    String? echeanceHeure,
    bool livraisonRequise = false,
    int? dureeMinutes,
    String? responsableId,
    String? lieu,
    String? note,
  }) {
    final sousTotal = lignes.fold<int>(0, (sum, l) => sum + l.totalLigne);
    final total = (sousTotal - remise).clamp(0, 1000000000000);

    final prestation = Prestation(
      id: _uuid.v4(),
      entrepriseId: entrepriseId,
      perimetreId: perimetreId,
      contactId: contactId,
      titre: titre.trim(),
      description: description?.trim(),
      lignes: lignes,
      remise: remise,
      total: total,
      statut: debutPrevu != null ? StatutPrestation.planifiee : StatutPrestation.aFaire,
      priorite: priorite,
      debutPrevu: debutPrevu,
      echeanceJour: echeanceJour,
      echeanceHeure: echeanceHeure,
      livraisonRequise: livraisonRequise,
      dureeMinutes: dureeMinutes,
      responsableId: responsableId,
      lieu: lieu?.trim(),
      note: note?.trim(),
    );

    return _repository.creerPrestation(prestation);
  }

  Future<Prestation> modifierPrestation(Prestation prestation) {
    final sousTotal = prestation.lignes.fold<int>(0, (sum, l) => sum + l.totalLigne);
    final total = (sousTotal - prestation.remise).clamp(0, 1000000000000);
    final updated = prestation.copyWith(total: total);
    return _repository.modifierPrestation(updated);
  }

  Future<void> changerStatutPrestation(String prestationId, StatutPrestation nouveauStatut) {
    return _repository.changerStatutPrestation(prestationId, nouveauStatut);
  }

  Future<void> demarrerPrestation(String prestationId) {
    return _repository.changerStatutPrestation(prestationId, StatutPrestation.enCours);
  }

  Future<void> terminerPrestation(String prestationId) {
    return _repository.changerStatutPrestation(prestationId, StatutPrestation.terminee);
  }

  Future<void> livrerPrestation(String prestationId) {
    return _repository.changerStatutPrestation(prestationId, StatutPrestation.livree);
  }

  Future<void> reporterPrestation({
    required String prestationId,
    required DateTime nouvelleEcheanceJour,
    String? nouvelleEcheanceHeure,
    required String motif,
  }) {
    return _repository.reporterPrestation(
      prestationId,
      nouvelleEcheanceJour,
      nouvelleEcheanceHeure,
      motif.trim(),
    );
  }

  Future<void> annulerPrestation({
    required String prestationId,
    required String motif,
  }) {
    return _repository.annulerPrestation(prestationId, motif.trim());
  }

  // --- DEVIS ---

  Future<DevisPrestation> creerDevis({
    required String entrepriseId,
    required String numero,
    String? perimetreId,
    String? contactId,
    MetierCode metierCode = MetierCode.generique,
    Map<String, dynamic> champsMetier = const {},
    required String titre,
    String? description,
    required List<LignePrestation> lignes,
    int remise = 0,
    required DateTime dateEmission,
    DateTime? dateValidite,
    int? acompteDemande,
    String? conditions,
    String? notes,
    List<PhotoPrestation> photos = const [],
  }) {
    final sousTotal = lignes.fold<int>(0, (sum, l) => sum + l.totalLigne);
    final total = (sousTotal - remise).clamp(0, 1000000000000);

    final devis = DevisPrestation(
      id: _uuid.v4(),
      entrepriseId: entrepriseId,
      numero: numero,
      perimetreId: perimetreId,
      contactId: contactId,
      metierCode: metierCode,
      champsMetier: champsMetier,
      titre: titre.trim(),
      description: description?.trim(),
      lignes: lignes,
      remise: remise,
      total: total,
      dateEmission: dateEmission,
      dateValidite: dateValidite,
      acompteDemande: acompteDemande,
      conditions: conditions?.trim(),
      notes: notes?.trim(),
      photos: photos,
    );

    return _repository.creerDevis(devis);
  }

  Future<void> envoyerDevis(String devisId) {
    return _repository.changerStatutDevis(devisId, StatutDevis.envoye);
  }

  Future<void> accepterDevis(String devisId) {
    return _repository.changerStatutDevis(devisId, StatutDevis.accepte);
  }

  Future<void> changerStatutDevis(String devisId, StatutDevis nouveauStatut) {
    return _repository.changerStatutDevis(devisId, nouveauStatut);
  }

  Future<Prestation> convertirDevisEnPrestation(String devisId) {
    return _repository.convertirDevisEnPrestation(devisId);
  }
}
