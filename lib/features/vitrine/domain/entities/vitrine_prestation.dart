/// Prestation, soin ou service proposé sur la vitrine
class VitrinePrestation {
  const VitrinePrestation({
    required this.id,
    required this.vitrineId,
    required this.entrepriseId,
    required this.nom,
    this.description,
    required this.prix,
    this.prixBarre,
    this.dureeMinutes,
    this.categorie,
    this.photoUrl,
    this.audioUrl,
    this.ordre = 0,
    this.estActif = true,
  });

  final String id;
  final String vitrineId;
  final String entrepriseId;
  final String nom;
  final String? description;
  final int prix;
  final int? prixBarre;
  final int? dureeMinutes;
  final String? categorie;
  final String? photoUrl;
  final String? audioUrl;
  final int ordre;
  final bool estActif;

  String? get dureeFormatee {
    if (dureeMinutes == null || dureeMinutes! <= 0) return null;
    final h = dureeMinutes! ~/ 60;
    final m = dureeMinutes! % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h $m min';
  }

  String get prixFormate {
    final s = prix.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$s FCFA';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'vitrine_id': vitrineId,
        'entreprise_id': entrepriseId,
        'nom': nom,
        'description': description,
        'prix': prix,
        'prix_barre': prixBarre,
        'duree_minutes': dureeMinutes,
        'categorie': categorie,
        'photo_url': photoUrl,
        'audio_url': audioUrl,
        'ordre': ordre,
        'est_actif': estActif,
      };

  factory VitrinePrestation.fromJson(Map<String, dynamic> j) => VitrinePrestation(
        id: j['id'] as String? ?? '',
        vitrineId: j['vitrine_id'] as String? ?? '',
        entrepriseId: j['entreprise_id'] as String? ?? '',
        nom: j['nom'] as String? ?? '',
        description: j['description'] as String?,
        prix: (j['prix'] as num?)?.toInt() ?? 0,
        prixBarre: (j['prix_barre'] as num?)?.toInt(),
        dureeMinutes: (j['duree_minutes'] as num?)?.toInt(),
        categorie: j['categorie'] as String?,
        photoUrl: j['photo_url'] as String?,
        audioUrl: j['audio_url'] as String?,
        ordre: (j['ordre'] as num?)?.toInt() ?? 0,
        estActif: j['est_actif'] as bool? ?? true,
      );

  VitrinePrestation copyWith({
    String? id,
    String? vitrineId,
    String? entrepriseId,
    String? nom,
    String? description,
    int? prix,
    int? prixBarre,
    int? dureeMinutes,
    String? categorie,
    String? photoUrl,
    String? audioUrl,
    int? ordre,
    bool? estActif,
  }) =>
      VitrinePrestation(
        id: id ?? this.id,
        vitrineId: vitrineId ?? this.vitrineId,
        entrepriseId: entrepriseId ?? this.entrepriseId,
        nom: nom ?? this.nom,
        description: description ?? this.description,
        prix: prix ?? this.prix,
        prixBarre: prixBarre ?? this.prixBarre,
        dureeMinutes: dureeMinutes ?? this.dureeMinutes,
        categorie: categorie ?? this.categorie,
        photoUrl: photoUrl ?? this.photoUrl,
        audioUrl: audioUrl ?? this.audioUrl,
        ordre: ordre ?? this.ordre,
        estActif: estActif ?? this.estActif,
      );
}
