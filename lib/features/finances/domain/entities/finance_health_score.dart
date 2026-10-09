/// Niveau de santé financière calculé.
enum NiveauSanteFinanciere {
  bonne('BONNE', 'Bonne', 0xFF1E7E4E),
  stable('STABLE', 'Stable', 0xFF2A78D6),
  aSurveiller('A_SURVEILLER', 'À surveiller', 0xFFD97706),
  tension('TENSION', 'Tension financière', 0xFFDC2626);

  const NiveauSanteFinanciere(this.code, this.libelle, this.couleurCode);
  final String code;
  final String libelle;
  final int couleurCode;
}

/// Évaluation synthétique et expliquée de la santé financière.
class SanteFinanciere {
  const SanteFinanciere({
    required this.niveau,
    required this.score,
    required this.resumeCourt,
    required this.explication,
    this.pointsForts = const [],
    this.pointsVigilance = const [],
  });

  /// Niveau global : Bonne, Stable, À surveiller, Tension financière
  final NiveauSanteFinanciere niveau;

  /// Score calculé de 0 à 100
  final int score;

  /// Titre résumé (ex: "Situation stable", "Excellente santé")
  final String resumeCourt;

  /// Explication générée en français clair basée sur les données réelles
  final String explication;

  /// Faits positifs observés
  final List<String> pointsForts;

  /// Points d'attention réels
  final List<String> pointsVigilance;
}
