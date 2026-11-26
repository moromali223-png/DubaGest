/// Entité représentant un produit géré et affiché sur « Ma Vitrine » DubaGest.
class VitrineProduitItem {
  const VitrineProduitItem({
    required this.id,
    required this.nom,
    this.description,
    required this.prix,
    this.prixBarre,
    this.photoUrl,
    this.photos = const [],
    this.estPublie = true,
    this.categorie,
  });

  final String id;
  final String nom;
  final String? description;
  final int prix;
  final int? prixBarre;
  final String? photoUrl;
  final List<String> photos;
  final bool estPublie;
  final String? categorie;

  String? get photoPrincipale => photoUrl ?? (photos.isNotEmpty ? photos.first : null);

  bool get aPromotion => prixBarre != null && prixBarre! > prix;

  String get prixFormate {
    final s = prix.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  String? get prixBarreFormate {
    if (prixBarre == null) return null;
    final s = prixBarre.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  VitrineProduitItem copyWith({
    String? id,
    String? nom,
    String? description,
    int? prix,
    int? prixBarre,
    String? photoUrl,
    List<String>? photos,
    bool? estPublie,
    String? categorie,
  }) {
    return VitrineProduitItem(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      prix: prix ?? this.prix,
      prixBarre: prixBarre ?? this.prixBarre,
      photoUrl: photoUrl ?? this.photoUrl,
      photos: photos ?? this.photos,
      estPublie: estPublie ?? this.estPublie,
      categorie: categorie ?? this.categorie,
    );
  }

  factory VitrineProduitItem.fromJson(Map<String, dynamic> j) {
    final rawPhotos = j['photos'] ?? j['photos_v2'];
    final photosList = <String>[];
    if (rawPhotos is List) {
      for (final p in rawPhotos) {
        if (p is String && p.isNotEmpty) {
          photosList.add(p);
        } else if (p is Map && p['url'] is String) {
          photosList.add(p['url'] as String);
        }
      }
    }

    final pDetail = (j['prix_detail'] as num?)?.toInt() ?? 0;
    final pPublic = (j['prix_public'] as num?)?.toInt();
    final prixEffectif = (pPublic != null && pPublic > 0) ? pPublic : pDetail;

    return VitrineProduitItem(
      id: j['id'] as String? ?? '',
      nom: j['nom'] as String? ?? '',
      description: j['description'] as String?,
      prix: prixEffectif,
      prixBarre: (j['prix_barre'] as num?)?.toInt(),
      photoUrl: photosList.isNotEmpty ? photosList.first : null,
      photos: photosList,
      estPublie: (j['est_publie_catalogue'] as bool?) ?? false,
      categorie: j['categorie'] as String?,
    );
  }

  Map<String, dynamic> toJson({required String entrepriseId}) {
    final pList = photos.isNotEmpty ? photos : (photoUrl != null ? [photoUrl!] : <String>[]);
    return {
      if (id.isNotEmpty) 'id': id,
      'entreprise_id': entrepriseId,
      'nom': nom,
      'description': description,
      'prix_detail': prix,
      'prix_public': prix,
      'prix_barre': prixBarre,
      'photos': pList,
      'est_publie_catalogue': estPublie,
      'est_actif': true,
      'unite_base': 'Pièce',
    };
  }
}
