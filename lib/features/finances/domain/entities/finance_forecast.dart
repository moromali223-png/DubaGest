/// Projection de trésorerie sur un horizon donné (7 jours, 30 jours, 90 jours).
class PrevisionHorizon {
  const PrevisionHorizon({
    required this.horizonJours,
    required this.libelle,
    required this.soldePrevu,
    required this.encaissementsAttendus,
    required this.decaissementsPrevus,
    required this.tensionDetectee,
    required this.message,
  });

  final int horizonJours;
  final String libelle;
  final int soldePrevu;
  final int encaissementsAttendus;
  final int decaissementsPrevus;
  final bool tensionDetectee;
  final String message;
}

/// Prévisions complètes de trésorerie (Aujourd'hui, 7j, 30j, 90j).
class PrevisionTresorerie {
  const PrevisionTresorerie({
    required this.soldeActuel,
    required this.horizon7Jours,
    required this.horizon30Jours,
    required this.horizon90Jours,
    required this.syntheseGlobale,
    required this.attentionRequise,
  });

  final int soldeActuel;
  final PrevisionHorizon horizon7Jours;
  final PrevisionHorizon horizon30Jours;
  final PrevisionHorizon horizon90Jours;
  final String syntheseGlobale;
  final bool attentionRequise;
}
