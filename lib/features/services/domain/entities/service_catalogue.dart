import '../../../../core/sync/sync_models.dart';

/// Unité de facturation d'un service dans le catalogue.
enum UniteFacturation {
  forfait('FORFAIT', 'Forfait'),
  heure('HEURE', 'Heure'),
  jour('JOUR', 'Jour'),
  piece('PIECE', 'Pièce'),
  m2('M2', 'm²'),
  km('KM', 'km');

  const UniteFacturation(this.code, this.libelle);
  final String code;
  final String libelle;

  static UniteFacturation parse(String? code) =>
      values.firstWhere((u) => u.code == code, orElse: () => forfait);
}

/// Service type enregistré dans le catalogue de l'entreprise.
class ServiceCatalogue {
  const ServiceCatalogue({
    required this.id,
    required this.entrepriseId,
    required this.nom,
    this.categorie,
    this.description,
    this.prix = 0,
    this.unite = UniteFacturation.forfait,
    this.dureeMinutes,
    this.icone,
    this.estActif = true,
    this.ordre = 100,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final String nom;
  final String? categorie;
  final String? description;

  /// Prix indicatif par défaut (en entiers dans la devise de travail).
  final int prix;
  final UniteFacturation unite;
  final int? dureeMinutes;
  final String? icone;
  final bool estActif;
  final int ordre;
  final int? version;
  final RecordSyncStatus syncStatus;

  /// Durée formatée lisible (ex. « 45 min », « 1 h », « 1 h 30 min »).
  String? get dureeFormatee {
    if (dureeMinutes == null || dureeMinutes! <= 0) return null;
    final h = dureeMinutes! ~/ 60;
    final m = dureeMinutes! % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h $m min';
  }

  ServiceCatalogue copyWith({
    String? nom,
    String? categorie,
    String? description,
    int? prix,
    UniteFacturation? unite,
    int? dureeMinutes,
    String? icone,
    bool? estActif,
    int? ordre,
  }) =>
      ServiceCatalogue(
        id: id,
        entrepriseId: entrepriseId,
        nom: nom ?? this.nom,
        categorie: categorie ?? this.categorie,
        description: description ?? this.description,
        prix: prix ?? this.prix,
        unite: unite ?? this.unite,
        dureeMinutes: dureeMinutes ?? this.dureeMinutes,
        icone: icone ?? this.icone,
        estActif: estActif ?? this.estActif,
        ordre: ordre ?? this.ordre,
        version: version,
        syncStatus: syncStatus,
      );
}
