enum InvitationStatut {
  pending('PENDING'),
  accepted('ACCEPTED'),
  expired('EXPIRED'),
  cancelled('CANCELLED'),

  /// Jeton inconnu (aperçu uniquement).
  invalid('INVALIDE');

  const InvitationStatut(this.code);
  final String code;

  static InvitationStatut parse(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => InvitationStatut.invalid);
}

/// Invitation vue par l'administrateur (le jeton n'est jamais relu).
class Invitation {
  const Invitation({
    required this.id,
    required this.email,
    required this.roleCode,
    required this.statut,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String roleCode;
  final InvitationStatut statut;
  final DateTime expiresAt;
  final DateTime createdAt;

  /// Une invitation en attente dont la date est passée est expirée.
  InvitationStatut statutEffectif(DateTime now) =>
      statut == InvitationStatut.pending && !expiresAt.isAfter(now) ? InvitationStatut.expired : statut;
}

/// Aperçu public d'une invitation (avant connexion), sans donnée sensible.
class InvitationApercu {
  const InvitationApercu({
    required this.statut,
    this.entrepriseNom,
    this.roleCode,
    this.emailMasque,
    this.expiresAt,
  });

  final InvitationStatut statut;
  final String? entrepriseNom;
  final String? roleCode;
  final String? emailMasque;
  final DateTime? expiresAt;

  bool get acceptable => statut == InvitationStatut.pending;
}

/// Résultat d'une création : le jeton n'est disponible qu'à cet instant.
class InvitationCreee {
  const InvitationCreee({required this.id, required this.token, required this.expiresAt});
  final String id;
  final String token;
  final DateTime expiresAt;
}
