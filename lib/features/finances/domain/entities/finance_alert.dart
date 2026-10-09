/// Niveau de priorité d'une alerte financière.
enum PrioriteAlerteFinance {
  urgent('URGENT', 'Urgent', 0xFFDC2626),
  aSurveiller('A_SURVEILLER', 'À surveiller', 0xFFD97706),
  positif('POSITIF', 'Positif', 0xFF1E7E4E);

  const PrioriteAlerteFinance(this.code, this.libelle, this.couleurCode);
  final String code;
  final String libelle;
  final int couleurCode;
}

/// Alerte financière intelligente générée à partir des données réelles.
class AlerteFinanciere {
  const AlerteFinanciere({
    required this.id,
    required this.priorite,
    required this.titre,
    required this.description,
    this.actionRoute,
    this.actionLabel,
  });

  final String id;
  final PrioriteAlerteFinance priorite;
  final String titre;
  final String description;
  final String? actionRoute;
  final String? actionLabel;
}

/// Fait marquant dans la section « Ce qui change ».
class FaitMarquantFinance {
  const FaitMarquantFinance({
    required this.icone,
    required this.texte,
    this.positif = true,
  });

  final String icone;
  final String texte;
  final bool positif;
}
