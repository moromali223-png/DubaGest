/// Élément de la galerie photo de réalisations (coiffures, avant/après, créations)
class VitrineGalerieItem {
  const VitrineGalerieItem({
    required this.id,
    required this.vitrineId,
    required this.entrepriseId,
    this.titre,
    this.categorie,
    required this.photoUrl,
    this.photoAvantUrl,
    this.ordre = 0,
  });

  final String id;
  final String vitrineId;
  final String entrepriseId;
  final String? titre;
  final String? categorie;
  final String photoUrl;
  final String? photoAvantUrl;
  final int ordre;

  bool get estAvantApres => photoAvantUrl != null && photoAvantUrl!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vitrine_id': vitrineId,
        'entreprise_id': entrepriseId,
        'titre': titre,
        'categorie': categorie,
        'photo_url': photoUrl,
        'photo_avant_url': photoAvantUrl,
        'ordre': ordre,
      };

  factory VitrineGalerieItem.fromJson(Map<String, dynamic> j) => VitrineGalerieItem(
        id: j['id'] as String? ?? '',
        vitrineId: j['vitrine_id'] as String? ?? '',
        entrepriseId: j['entreprise_id'] as String? ?? '',
        titre: j['titre'] as String?,
        categorie: j['categorie'] as String?,
        photoUrl: j['photo_url'] as String? ?? '',
        photoAvantUrl: j['photo_avant_url'] as String?,
        ordre: (j['ordre'] as num?)?.toInt() ?? 0,
      );

  VitrineGalerieItem copyWith({
    String? id,
    String? vitrineId,
    String? entrepriseId,
    String? titre,
    String? categorie,
    String? photoUrl,
    String? photoAvantUrl,
    int? ordre,
  }) =>
      VitrineGalerieItem(
        id: id ?? this.id,
        vitrineId: vitrineId ?? this.vitrineId,
        entrepriseId: entrepriseId ?? this.entrepriseId,
        titre: titre ?? this.titre,
        categorie: categorie ?? this.categorie,
        photoUrl: photoUrl ?? this.photoUrl,
        photoAvantUrl: photoAvantUrl ?? this.photoAvantUrl,
        ordre: ordre ?? this.ordre,
      );
}
