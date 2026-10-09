import '../../../contacts/domain/entities/contact.dart';
import 'finances.dart';

/// Statut de santé d'un dossier de dette / créance.
enum StatutDossierDette {
  /// Au moins une échéance passée non totalement réglée
  enRetard,

  /// Prochaine échéance dans les 7 prochains jours
  bientot,

  /// Toutes les échéances sont dans le futur
  aJour,

  /// Dossier totalement réglé (solde = 0)
  regle;

  String get label => switch (this) {
        StatutDossierDette.enRetard => 'En retard',
        StatutDossierDette.bientot => 'À payer bientôt',
        StatutDossierDette.aJour => 'À jour',
        StatutDossierDette.regle => 'Réglé',
      };
}

/// Statut individuel d'une échéance dans le calendrier.
enum StatutEcheanceItem {
  enRetard,
  aujourdhui,
  cetteSemaine,
  semaineProchaine,
  plusTard,
  reglee;

  String get label => switch (this) {
        StatutEcheanceItem.enRetard => 'En retard',
        StatutEcheanceItem.aujourdhui => 'Aujourd\'hui',
        StatutEcheanceItem.cetteSemaine => 'Cette semaine',
        StatutEcheanceItem.semaineProchaine => 'Semaine prochaine',
        StatutEcheanceItem.plusTard => 'Plus tard',
        StatutEcheanceItem.reglee => 'Réglée',
      };
}

/// Échéance individuelle liée à une créance ou dette.
class EcheanceDette {
  const EcheanceDette({
    required this.engagementId,
    required this.libelle,
    required this.dateEcheance,
    required this.montantInitial,
    required this.montantRegle,
    required this.montantReste,
    required this.statut,
    this.retardJours = 0,
    this.origineType = 'MANUEL',
    this.contactId,
    this.nomContact,
  });

  final String engagementId;
  final String libelle;
  final DateTime dateEcheance;
  final int montantInitial;
  final int montantRegle;
  final int montantReste;
  final StatutEcheanceItem statut;
  final int retardJours;
  final String origineType;
  final String? contactId;
  final String? nomContact;

  bool get estEnRetard => statut == StatutEcheanceItem.enRetard;
}

/// Type d'événement dans la timeline financière.
enum TypeEvenementDette {
  creationDette,
  paiementRecu,
  paiementEmis,
  annulation;

  String get label => switch (this) {
        TypeEvenementDette.creationDette => 'Nouvelle dette',
        TypeEvenementDette.paiementRecu => 'Paiement reçu',
        TypeEvenementDette.paiementEmis => 'Paiement effectué',
        TypeEvenementDette.annulation => 'Annulation',
      };
}

/// Événement unifié de l'historique financier d'un dossier.
class EvenementTimelineDette {
  const EvenementTimelineDette({
    required this.id,
    required this.date,
    required this.type,
    required this.montant,
    required this.libelle,
    this.mode,
    this.soldeProgressif = 0,
    this.engagementId,
    this.paiementId,
    this.reference,
    this.note,
  });

  final String id;
  final DateTime date;
  final TypeEvenementDette type;
  final int montant;
  final String libelle;
  final ModePaiement? mode;
  final int soldeProgressif;
  final String? engagementId;
  final String? paiementId;
  final String? reference;
  final String? note;

  bool get estPaiement =>
      type == TypeEvenementDette.paiementRecu || type == TypeEvenementDette.paiementEmis;
}

/// Point d'évolution du solde dans le temps (pour graphique).
class PointEvolutionSolde {
  const PointEvolutionSolde({required this.date, required this.solde});
  final DateTime date;
  final int solde;
}

/// Dossier consolidé d'une personne (Client ou Fournisseur).
/// « Une personne = un dossier financier complet ».
class DossierDette {
  const DossierDette({
    required this.dossierKey,
    this.contactId,
    this.contact,
    required this.nomAffiche,
    this.telephone,
    required this.sens,
    required this.engagements,
    required this.paiements,
    required this.totalDu,
    required this.totalPaye,
    required this.reste,
    required this.totalEnRetard,
    required this.nbDettesActives,
    required this.nbEcheancesEnRetard,
    this.prochaineEcheance,
    required this.statutGlobal,
    required this.echeances,
    required this.timeline,
    this.evolutionSolde = const [],
  });

  /// Identifiant unique du dossier (contactId ou libellé si non lié)
  final String dossierKey;
  final String? contactId;
  final Contact? contact;
  final String nomAffiche;
  final String? telephone;
  final SensEngagement sens;

  /// Toutes les dettes/créances individuelles de cette personne
  final List<EngagementSuivi> engagements;

  /// Tous les paiements associés
  final List<PaiementSuivi> paiements;

  /// Total cumulé historique dû
  final int totalDu;

  /// Total cumulé déjà payé
  final int totalPaye;

  /// Reste net à payer / recevoir
  final int reste;

  /// Montant total actuellement en retard
  final int totalEnRetard;

  /// Nombre de dettes non soldées
  final int nbDettesActives;

  /// Nombre d'échéances dépassées
  final int nbEcheancesEnRetard;

  /// Date de la prochaine échéance due
  final DateTime? prochaineEcheance;

  /// Statut global (enRetard, bientot, aJour, regle)
  final StatutDossierDette statutGlobal;

  /// Liste des échéances individuelles classées
  final List<EcheanceDette> echeances;

  /// Timeline complète chronologique
  final List<EvenementTimelineDette> timeline;

  /// Points d'évolution du solde dans le temps
  final List<PointEvolutionSolde> evolutionSolde;

  /// Taux de règlement en pourcentage (0.0 à 100.0)
  double get tauxReglement => totalDu > 0 ? (totalPaye / totalDu * 100).clamp(0.0, 100.0) : 100.0;

  bool get estSolde => reste <= 0;
  bool get estEnRetard => totalEnRetard > 0 || statutGlobal == StatutDossierDette.enRetard;
}
