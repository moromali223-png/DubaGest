enum AuditAction {
  creation('CREATION'),
  modification('MODIFICATION'),
  archivage('ARCHIVAGE'),
  restauration('RESTAURATION'),
  suppression('SUPPRESSION');

  const AuditAction(this.code);
  final String code;

  static AuditAction parse(String code) =>
      values.firstWhere((a) => a.code == code, orElse: () => AuditAction.modification);
}

/// Ligne du journal d'activité (écrite par le serveur, jamais par l'application).
class EntreeAudit {
  const EntreeAudit({
    required this.id,
    required this.action,
    required this.entiteType,
    required this.entiteId,
    required this.date,
    this.auteurId,
    this.auteurNom,
    this.avant = const {},
    this.apres = const {},
  });

  final int id;
  final AuditAction action;

  /// Nom technique de la table (traduit à l'affichage).
  final String entiteType;
  final String entiteId;
  final DateTime date;

  /// `null` : action du système (back-office, migration).
  final String? auteurId;
  final String? auteurNom;
  final Map<String, dynamic> avant;
  final Map<String, dynamic> apres;

  /// Champs concernés (modification : seulement ceux qui ont changé).
  Set<String> get champs => {...avant.keys, ...apres.keys};
}
