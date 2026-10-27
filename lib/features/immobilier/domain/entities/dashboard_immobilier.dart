import 'package:flutter/material.dart';

/// Type d'alerte métier pour la gestion locative et immobilière.
enum TypeAlerteImmobilier {
  loyerEnRetard('LOYER_EN_RETARD', 'Impayé / Retard de loyer', Icons.warning_amber_rounded),
  finBailProche('FIN_BAIL_PROCHE', 'Échéance de bail proche', Icons.event_busy_rounded),
  bienVacant('BIEN_VACANT', 'Bien vacant / Inoccupé', Icons.door_front_door_outlined),
  cautionARestituer('CAUTION_A_RESTITUER', 'Dépôt de garantie à restituer', Icons.savings_outlined);

  const TypeAlerteImmobilier(this.code, this.libelle, this.icone);
  final String code;
  final String libelle;
  final IconData icone;
}

/// Niveau de criticité de l'alerte.
enum NiveauAlerte {
  critique('CRITIQUE', 'Urgent', Color(0xFFEF4444)),
  avertissement('AVERTISSEMENT', 'Important', Color(0xFFDF9540)),
  information('INFO', 'Information', Color(0xFF3B82F6));

  const NiveauAlerte(this.code, this.libelle, this.couleur);
  final String code;
  final String libelle;
  final Color couleur;
}

/// Alerte métier concrète, contextualisée et directement actionnable.
class AlerteImmobilier {
  const AlerteImmobilier({
    required this.id,
    required this.type,
    required this.niveau,
    required this.titre,
    required this.message,
    required this.dateReference,
    this.montantConcerne,
    this.bienId,
    this.bienNom,
    this.locataireId,
    this.locataireNom,
    this.contratId,
    this.echeanceId,
    this.actionRoute,
    this.actionLibelle,
  });

  final String id;
  final TypeAlerteImmobilier type;
  final NiveauAlerte niveau;
  final String titre;
  final String message;
  final DateTime dateReference;
  final int? montantConcerne;
  final String? bienId;
  final String? bienNom;
  final String? locataireId;
  final String? locataireNom;
  final String? contratId;
  final String? echeanceId;
  final String? actionRoute;
  final String? actionLibelle;
}

/// Données consolidées du Tableau de Bord Immobilier.
class DashboardImmobilierData {
  const DashboardImmobilierData({
    required this.totalBiens,
    required this.nbBiensOccupes,
    required this.nbBiensDisponibles,
    required this.nbBiensEnTravaux,
    required this.nbBiensReserves,
    required this.nbContratsActifs,
    required this.nbLocatairesActifs,
    required this.totalLoyersAppelesMois,
    required this.totalLoyersEncaissesMois,
    required this.totalImpayesMois,
    required this.totalCautionsEnDepot,
    required this.alertes,
  });

  final int totalBiens;
  final int nbBiensOccupes;
  final int nbBiensDisponibles;
  final int nbBiensEnTravaux;
  final int nbBiensReserves;
  final int nbContratsActifs;
  final int nbLocatairesActifs;
  final int totalLoyersAppelesMois;
  final int totalLoyersEncaissesMois;
  final int totalImpayesMois;
  final int totalCautionsEnDepot;
  final List<AlerteImmobilier> alertes;

  /// Taux d'occupation global du parc en pourcentage.
  double get tauxOccupation {
    final exploitables = totalBiens - nbBiensEnTravaux;
    if (exploitables <= 0) return 0.0;
    return ((nbBiensOccupes / exploitables) * 100).clamp(0.0, 100.0);
  }

  /// Taux de recouvrement financier pour le mois en cours.
  double get tauxRecouvrement {
    if (totalLoyersAppelesMois <= 0) return 100.0;
    return ((totalLoyersEncaissesMois / totalLoyersAppelesMois) * 100).clamp(0.0, 100.0);
  }

  /// Nombre d'alertes critiques nécessitant une action immédiate.
  int get nbAlertesCritiques =>
      alertes.where((a) => a.niveau == NiveauAlerte.critique).length;

  /// Nombre total d'alertes en cours.
  int get nbTotalAlertes => alertes.length;
}
