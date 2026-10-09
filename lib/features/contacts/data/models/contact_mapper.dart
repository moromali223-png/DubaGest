import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../core/utils/recherche.dart';
import '../../domain/entities/contact.dart';

abstract final class ContactMapper {
  static Set<RelationContact> _relationsDepuis(Iterable<String> codes) =>
      {for (final c in codes) ?RelationContact.tryParse(c)};

  static String _relationsVersTexte(Iterable<RelationContact> relations) =>
      (relations.map((r) => r.code).toList()..sort()).join(',');

  static String cleRecherche({String? nom, String? prenom, String? email, String? ville}) =>
      normaliserRecherche([prenom, nom, email, ville].whereType<String>().join(' '));

  static Contact fromRow(ContactRow r) => Contact(
        id: r.id,
        entrepriseId: r.entrepriseId,
        typePersonne: TypePersonne.parse(r.typePersonne),
        nom: r.nom,
        prenom: r.prenom,
        telephone: r.telephone,
        whatsapp: r.whatsapp,
        email: r.email,
        adresse: r.adresse,
        ville: r.ville,
        remarque: r.remarque,
        relations: _relationsDepuis(r.relations.isEmpty ? const [] : r.relations.split(',')),
        statut: StatutContact.parse(r.statut),
        version: r.version,
        syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      );

  static ContactsCompanion toLocal(Contact c, RecordSyncStatus statut) => ContactsCompanion.insert(
        id: c.id,
        entrepriseId: c.entrepriseId,
        typePersonne: c.typePersonne.code,
        nom: c.nom,
        prenom: Value(c.prenom),
        telephone: Value(c.telephone),
        whatsapp: Value(c.whatsapp),
        email: Value(c.email),
        adresse: Value(c.adresse),
        ville: Value(c.ville),
        remarque: Value(c.remarque),
        relations: Value(_relationsVersTexte(c.relations)),
        statut: c.statut.code,
        cleRecherche: Value(cleRecherche(nom: c.nom, prenom: c.prenom, email: c.email, ville: c.ville)),
        telephoneChiffres: Value(chiffresSeuls('${c.telephone ?? ''} ${c.whatsapp ?? ''}')),
        version: Value(c.version),
        syncStatus: statut.wire,
      );

  static ContactsCompanion fromServer(Map<String, dynamic> j, RecordSyncStatus statut) {
    final contact = Contact(
      id: j['id'] as String,
      entrepriseId: j['entreprise_id'] as String,
      typePersonne: TypePersonne.parse(j['type_personne'] as String?),
      nom: j['nom'] as String,
      prenom: j['prenom'] as String?,
      telephone: j['telephone'] as String?,
      whatsapp: j['whatsapp'] as String?,
      email: j['email'] as String?,
      adresse: j['adresse'] as String?,
      ville: j['ville'] as String?,
      remarque: j['remarque'] as String?,
      relations: _relationsDepuis(((j['relations'] as List?) ?? const []).cast<String>()),
      statut: StatutContact.parse(j['statut'] as String?),
      version: j['version'] as int?,
    );
    return toLocal(contact, statut).copyWith(
      updatedAt: Value(j['updated_at'] == null ? null : DateTime.parse(j['updated_at'] as String)),
    );
  }

  /// Charge utile envoyée au serveur (colonnes déclarées dans app.sync_tables).
  static Map<String, dynamic> payload(Contact c, {bool creation = false}) => {
        if (creation) 'entreprise_id': c.entrepriseId,
        'type_personne': c.typePersonne.code,
        'nom': c.nom,
        'prenom': c.prenom,
        'telephone': c.telephone,
        'whatsapp': c.whatsapp,
        'email': c.email,
        'adresse': c.adresse,
        'ville': c.ville,
        'remarque': c.remarque,
        'relations': (c.relations.map((r) => r.code).toList()..sort()),
        'statut': c.statut.code,
      };

  static bool memeContenu(ContactRow local, Map<String, dynamic> serveur) {
    final relationsServeur = (((serveur['relations'] as List?) ?? const []).cast<String>().toList()..sort()).join(',');
    return local.nom == serveur['nom'] &&
        local.prenom == serveur['prenom'] &&
        local.typePersonne == serveur['type_personne'] &&
        local.telephone == serveur['telephone'] &&
        local.whatsapp == serveur['whatsapp'] &&
        local.email == serveur['email'] &&
        local.adresse == serveur['adresse'] &&
        local.ville == serveur['ville'] &&
        local.remarque == serveur['remarque'] &&
        local.statut == serveur['statut'] &&
        local.relations == relationsServeur;
  }
}
