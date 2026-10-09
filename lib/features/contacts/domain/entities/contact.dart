import '../../../../core/sync/sync_models.dart';

enum TypePersonne {
  personne('PERSONNE'),
  organisation('ORGANISATION');

  const TypePersonne(this.code);
  final String code;

  static TypePersonne parse(String? code) =>
      values.firstWhere((t) => t.code == code, orElse: () => TypePersonne.personne);
}

/// Relations possibles d'un contact avec l'entreprise (cumulables).
enum RelationContact {
  client('CLIENT'),
  fournisseur('FOURNISSEUR'),
  locataire('LOCATAIRE'),
  proprietaire('PROPRIETAIRE'),
  prestataire('PRESTATAIRE');

  const RelationContact(this.code);
  final String code;

  static RelationContact? tryParse(String code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

enum StatutContact {
  actif('ACTIF'),
  archive('ARCHIVE');

  const StatutContact(this.code);
  final String code;

  static StatutContact parse(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => StatutContact.actif);
}

/// Personne ou organisation en relation avec l'entreprise. Une seule fiche par
/// personne, même si elle est à la fois cliente, fournisseur et locataire.
class Contact {
  const Contact({
    required this.id,
    required this.entrepriseId,
    required this.nom,
    this.typePersonne = TypePersonne.personne,
    this.prenom,
    this.telephone,
    this.whatsapp,
    this.email,
    this.adresse,
    this.ville,
    this.remarque,
    this.relations = const {},
    this.statut = StatutContact.actif,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final TypePersonne typePersonne;
  final String nom;
  final String? prenom;
  final String? telephone;
  final String? whatsapp;
  final String? email;
  final String? adresse;
  final String? ville;
  final String? remarque;
  final Set<RelationContact> relations;
  final StatutContact statut;

  /// Version serveur connue ; `null` tant que la création n'est pas synchronisée.
  final int? version;
  final RecordSyncStatus syncStatus;

  String get nomAffiche =>
      typePersonne == TypePersonne.personne && (prenom?.trim().isNotEmpty ?? false) ? '$prenom $nom' : nom;

  String get initiales {
    final mots = nomAffiche.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
    return mots.take(2).map((m) => m.characters.first.toUpperCase()).join();
  }

  bool get estArchive => statut == StatutContact.archive;

  Contact copyWith({
    TypePersonne? typePersonne,
    String? nom,
    String? prenom,
    String? telephone,
    String? whatsapp,
    String? email,
    String? adresse,
    String? ville,
    String? remarque,
    Set<RelationContact>? relations,
    StatutContact? statut,
  }) =>
      Contact(
        id: id,
        entrepriseId: entrepriseId,
        typePersonne: typePersonne ?? this.typePersonne,
        nom: nom ?? this.nom,
        prenom: prenom ?? this.prenom,
        telephone: telephone ?? this.telephone,
        whatsapp: whatsapp ?? this.whatsapp,
        email: email ?? this.email,
        adresse: adresse ?? this.adresse,
        ville: ville ?? this.ville,
        remarque: remarque ?? this.remarque,
        relations: relations ?? this.relations,
        statut: statut ?? this.statut,
        version: version,
        syncStatus: syncStatus,
      );
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}

/// Critères de la liste des contacts.
class FiltreContacts {
  const FiltreContacts({this.recherche = '', this.relation, this.inclureArchives = false});

  final String recherche;
  final RelationContact? relation;
  final bool inclureArchives;

  FiltreContacts copyWith({String? recherche, RelationContact? Function()? relation, bool? inclureArchives}) =>
      FiltreContacts(
        recherche: recherche ?? this.recherche,
        relation: relation == null ? this.relation : relation(),
        inclureArchives: inclureArchives ?? this.inclureArchives,
      );

  @override
  bool operator ==(Object other) =>
      other is FiltreContacts &&
      other.recherche == recherche &&
      other.relation == relation &&
      other.inclureArchives == inclureArchives;

  @override
  int get hashCode => Object.hash(recherche, relation, inclureArchives);
}
