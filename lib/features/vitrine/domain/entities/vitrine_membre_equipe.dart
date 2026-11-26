/// Membre d'équipe ou professionnel du salon / institut
class VitrineMembreEquipe {
  const VitrineMembreEquipe({
    required this.id,
    required this.vitrineId,
    required this.entrepriseId,
    required this.nom,
    this.roleSpecialite,
    this.presentation,
    this.photoUrl,
    this.ordre = 0,
  });

  final String id;
  final String vitrineId;
  final String entrepriseId;
  final String nom;
  final String? roleSpecialite;
  final String? presentation;
  final String? photoUrl;
  final int ordre;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vitrine_id': vitrineId,
        'entreprise_id': entrepriseId,
        'nom': nom,
        'role_ou_specialite': roleSpecialite,
        'presentation': presentation,
        'photo_url': photoUrl,
        'ordre': ordre,
      };

  factory VitrineMembreEquipe.fromJson(Map<String, dynamic> j) => VitrineMembreEquipe(
        id: j['id'] as String? ?? '',
        vitrineId: j['vitrine_id'] as String? ?? '',
        entrepriseId: j['entreprise_id'] as String? ?? '',
        nom: j['nom'] as String? ?? '',
        roleSpecialite: j['role_ou_specialite'] as String?,
        presentation: j['presentation'] as String?,
        photoUrl: j['photo_url'] as String?,
        ordre: (j['ordre'] as num?)?.toInt() ?? 0,
      );

  VitrineMembreEquipe copyWith({
    String? id,
    String? vitrineId,
    String? entrepriseId,
    String? nom,
    String? roleSpecialite,
    String? presentation,
    String? photoUrl,
    int? ordre,
  }) =>
      VitrineMembreEquipe(
        id: id ?? this.id,
        vitrineId: vitrineId ?? this.vitrineId,
        entrepriseId: entrepriseId ?? this.entrepriseId,
        nom: nom ?? this.nom,
        roleSpecialite: roleSpecialite ?? this.roleSpecialite,
        presentation: presentation ?? this.presentation,
        photoUrl: photoUrl ?? this.photoUrl,
        ordre: ordre ?? this.ordre,
      );
}
