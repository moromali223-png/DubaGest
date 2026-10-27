enum MembreStatut {
  actif('ACTIF'),
  suspendu('SUSPENDU');

  const MembreStatut(this.code);
  final String code;

  static MembreStatut parse(String code) =>
      values.firstWhere((s) => s.code == code, orElse: () => MembreStatut.suspendu);
}

/// Appartenance d'un utilisateur à une entreprise, avec un rôle et des
/// périmètres affectés. L'identité (auth.users) et le profil sont séparés.
class Membre {
  const Membre({
    required this.id,
    required this.userId,
    required this.roleCode,
    required this.statut,
    this.nomComplet,
    this.perimetreIds = const {},
  });

  final String id;
  final String userId;
  final String roleCode;
  final MembreStatut statut;
  final String? nomComplet;
  final Set<String> perimetreIds;

  String get nomAffiche => nomComplet ?? 'Utilisateur $id';

  bool get estActif => statut == MembreStatut.actif;
}
