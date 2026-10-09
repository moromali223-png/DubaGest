import '../../../../core/sync/sync_models.dart';
import '../../../finances/domain/entities/finances.dart';

enum TypeEcheance {
  rappel('RAPPEL'),
  rendezVous('RENDEZ_VOUS'),
  tache('TACHE'),
  relance('RELANCE');

  const TypeEcheance(this.code);
  final String code;
  static TypeEcheance parse(String? c) => values.firstWhere((t) => t.code == c, orElse: () => tache);
}

enum StatutEcheance {
  aFaire('A_FAIRE'),
  fait('FAIT'),
  annule('ANNULE');

  const StatutEcheance(this.code);
  final String code;
  static StatutEcheance parse(String? c) => values.firstWhere((s) => s.code == c, orElse: () => aFaire);
}

/// Fiche à laquelle une échéance est liée.
enum CibleType {
  contact('CONTACT'),
  engagement('ENGAGEMENT'),
  paiement('PAIEMENT'),
  document('DOCUMENT'),

  /// Notes et pièces jointes uniquement.
  depense('DEPENSE');

  const CibleType(this.code);
  final String code;
  static CibleType? tryParse(String? c) => values.where((t) => t.code == c).firstOrNull;
}

class Echeance {
  const Echeance({
    required this.id,
    required this.entrepriseId,
    required this.type,
    required this.titre,
    required this.dateHeure,
    this.perimetreId,
    this.note,
    this.rappelMinutes,
    this.responsableId,
    this.responsableNom,
    this.cibleType,
    this.cibleId,
    this.statut = StatutEcheance.aFaire,
    this.faitLe,
    this.createdBy,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String? perimetreId;
  final TypeEcheance type;
  final String titre;
  final String? note;
  final DateTime dateHeure;
  final int? rappelMinutes;
  final String? responsableId;
  final String? responsableNom;
  final CibleType? cibleType;
  final String? cibleId;
  final StatutEcheance statut;
  final DateTime? faitLe;
  final String? createdBy;
  final int? version;
  final RecordSyncStatus syncStatus;

  bool get aFaire => statut == StatutEcheance.aFaire;
  bool get refusee => syncStatus == RecordSyncStatus.syncError && version == null;

  /// Concerne cet utilisateur : confiée à lui, ou créée par lui sans responsable.
  bool concerne(String userId) => responsableId == userId || (responsableId == null && createdBy == userId);

  Echeance copyWith({
    TypeEcheance? type,
    String? titre,
    String? Function()? note,
    DateTime? dateHeure,
    int? Function()? rappelMinutes,
    String? Function()? responsableId,
    String? Function()? responsableNom,
    StatutEcheance? statut,
  }) =>
      Echeance(
        id: id,
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        type: type ?? this.type,
        titre: titre ?? this.titre,
        note: note == null ? this.note : note(),
        dateHeure: dateHeure ?? this.dateHeure,
        rappelMinutes: rappelMinutes == null ? this.rappelMinutes : rappelMinutes(),
        responsableId: responsableId == null ? this.responsableId : responsableId(),
        responsableNom: responsableNom == null ? this.responsableNom : responsableNom(),
        cibleType: cibleType,
        cibleId: cibleId,
        statut: statut ?? this.statut,
        faitLe: faitLe,
        createdBy: createdBy,
        version: version,
        syncStatus: syncStatus,
      );
}

enum TypeNotification {
  echeanceConfiee('ECHEANCE_CONFIEE'),
  echeanceFaite('ECHEANCE_FAITE');

  const TypeNotification(this.code);
  final String code;
  static TypeNotification? tryParse(String? c) => values.where((t) => t.code == c).firstOrNull;
}

/// Notification envoyée par le serveur à cet utilisateur.
class NotificationApp {
  const NotificationApp({
    required this.id,
    required this.type,
    required this.parametres,
    required this.createdAt,
    this.cibleId,
    this.auteurNom,
    this.lueLe,
    this.version,
  });

  final String id;
  final TypeNotification? type;
  final Map<String, dynamic> parametres;
  final String? cibleId;
  final String? auteurNom;
  final DateTime? lueLe;
  final DateTime createdAt;
  final int? version;

  bool get lue => lueLe != null;
}

/// Élément de l'agenda : échéance saisie, ou échéance d'une somme due
/// (affichée depuis les finances, jamais recopiée).
sealed class ElementAgenda {
  const ElementAgenda();
  DateTime get date;
}

class ElementEcheance extends ElementAgenda {
  const ElementEcheance(this.echeance);
  final Echeance echeance;
  @override
  DateTime get date => echeance.dateHeure;
}

class ElementSommeDue extends ElementAgenda {
  const ElementSommeDue(this.suivi);
  final EngagementSuivi suivi;
  @override
  DateTime get date => suivi.engagement.echeance!;
}

/// Agenda regroupé par période.
class Agenda {
  const Agenda({this.enRetard = const [], this.aujourdhui = const [], this.aVenir = const [], this.plusTard = const []});
  final List<ElementAgenda> enRetard;
  final List<ElementAgenda> aujourdhui;

  /// Les 7 prochains jours.
  final List<ElementAgenda> aVenir;
  final List<ElementAgenda> plusTard;

  bool get vide => enRetard.isEmpty && aujourdhui.isEmpty && aVenir.isEmpty && plusTard.isEmpty;
}

/// Alerte calculée à partir des données réelles (rien n'est inventé).
sealed class Alerte {
  const Alerte();
}

class AlerteEcheance extends Alerte {
  const AlerteEcheance(this.echeance, {required this.enRetard});
  final Echeance echeance;

  /// `false` : rappel ou échéance du jour.
  final bool enRetard;
}

class AlerteCreancesEnRetard extends Alerte {
  const AlerteCreancesEnRetard({required this.nombre, required this.montant});
  final int nombre;
  final int montant;
}

class AlerteCaisseOuverte extends Alerte {
  const AlerteCaisseOuverte(this.caisse, this.depuis);
  final Caisse caisse;
  final DateTime depuis;
}

class AlerteEcrituresRefusees extends Alerte {
  const AlerteEcrituresRefusees(this.nombre);
  final int nombre;
}
