import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../entities/contact.dart';
import '../repositories/contact_repository.dart';

/// Même règle que la contrainte serveur `contacts_email_check`.
final _emailValide = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Données saisies dans le formulaire (avant validation).
class SaisieContact {
  const SaisieContact({
    required this.typePersonne,
    required this.nom,
    this.prenom,
    this.telephone,
    this.whatsapp,
    this.email,
    this.adresse,
    this.ville,
    this.remarque,
    this.relations = const {},
  });

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
}

class ObserverContacts {
  const ObserverContacts(this._repository);
  final ContactRepository _repository;

  Stream<List<Contact>> call(ContexteSession ctx, FiltreContacts filtre) {
    _verifier(_peut(ctx, PermissionCodes.contactsView));
    return _repository.watch(ctx.entreprise!.id, filtre);
  }

  Stream<Contact?> un(ContexteSession ctx, String id) {
    _verifier(_peut(ctx, PermissionCodes.contactsView));
    return _repository.watchUn(id);
  }
}

class DetecterDoublons {
  const DetecterDoublons(this._repository);
  final ContactRepository _repository;

  Future<List<Contact>> call(ContexteSession ctx, SaisieContact saisie, {String? saufId}) {
    if (saisie.nom.trim().isEmpty) return Future.value(const []);
    return _repository.doublonsPotentiels(
      ctx.entreprise!.id,
      telephone: _nullSiVide(saisie.telephone),
      nom: saisie.nom.trim(),
      prenom: saisie.typePersonne == TypePersonne.personne ? _nullSiVide(saisie.prenom) : null,
      saufId: saufId,
    );
  }
}

class CreerContact {
  CreerContact(this._repository, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final ContactRepository _repository;
  final Uuid _uuid;

  Future<Contact> call(ContexteSession ctx, SaisieContact saisie) async {
    _verifier(_peut(ctx, PermissionCodes.contactsCreate));
    return _repository.creer(_construire(
      Contact(id: _uuid.v4(), entrepriseId: ctx.entreprise!.id, nom: '', syncStatus: _attente),
      saisie,
    ));
  }
}

class ModifierContact {
  const ModifierContact(this._repository);
  final ContactRepository _repository;

  Future<void> call(ContexteSession ctx, Contact contact, SaisieContact saisie) async {
    _verifier(_peut(ctx, PermissionCodes.contactsUpdate));
    await _repository.modifier(contact, _construire(contact, saisie));
  }

  /// Ajoute une relation à une fiche existante (proposé quand un doublon est
  /// détecté : « Mariam est déjà cliente → l'ajouter comme fournisseur »).
  Future<void> ajouterRelation(ContexteSession ctx, Contact contact, Set<RelationContact> relations) async {
    _verifier(_peut(ctx, PermissionCodes.contactsUpdate));
    if (contact.relations.containsAll(relations)) return;
    await _repository.modifier(contact, contact.copyWith(relations: {...contact.relations, ...relations}));
  }
}

class ArchiverContact {
  const ArchiverContact(this._repository);
  final ContactRepository _repository;

  /// Archivé : masqué des listes, l'historique reste intact (jamais supprimé).
  Future<void> call(ContexteSession ctx, Contact contact, {required bool archiver}) async {
    _verifier(_peut(ctx, PermissionCodes.contactsArchive));
    final statut = archiver ? StatutContact.archive : StatutContact.actif;
    if (contact.statut == statut) return;
    await _repository.modifier(contact, contact.copyWith(statut: statut));
  }
}

/// Ce que l'utilisateur peut faire sur les contacts (pour l'interface).
class DroitsContacts {
  const DroitsContacts({required this.voir, required this.creer, required this.modifier, required this.archiver});

  factory DroitsContacts.de(ContexteSession ctx) => DroitsContacts(
        voir: _peut(ctx, PermissionCodes.contactsView).isAllowed,
        creer: _peut(ctx, PermissionCodes.contactsCreate).isAllowed,
        modifier: _peut(ctx, PermissionCodes.contactsUpdate).isAllowed,
        archiver: _peut(ctx, PermissionCodes.contactsArchive).isAllowed,
      );

  final bool voir;
  final bool creer;
  final bool modifier;
  final bool archiver;
}

const _attente = RecordSyncStatus.pendingSync;

/// Même limite que la contrainte serveur sur `contacts.remarque`.
const longueurMaxRemarque = 1000;

AccessDecision _peut(ContexteSession ctx, String permission) =>
    ctx.accessPolicy().canPerform(moduleCode: ModuleCodes.communContacts, permission: permission);

void _verifier(AccessDecision decision) {
  if (decision case AccessDenied()) throw decision.toFailure();
}

Contact _construire(Contact base, SaisieContact s) {
  final nom = s.nom.trim();
  if (nom.isEmpty || nom.length > 200) throw const Failure.rule(RuleCodes.nameInvalid);
  final email = _nullSiVide(s.email);
  if (email != null && !_emailValide.hasMatch(email)) throw const Failure.rule(RuleCodes.emailInvalid);
  final remarque = _nullSiVide(s.remarque);
  if (remarque != null && remarque.length > longueurMaxRemarque) {
    throw const Failure.rule(RuleCodes.textTooLong, {'max': longueurMaxRemarque});
  }
  final personne = s.typePersonne == TypePersonne.personne;
  return Contact(
    id: base.id,
    entrepriseId: base.entrepriseId,
    typePersonne: s.typePersonne,
    nom: nom,
    prenom: personne ? _nullSiVide(s.prenom) : null,
    telephone: _nullSiVide(s.telephone),
    whatsapp: _nullSiVide(s.whatsapp),
    email: email?.toLowerCase(),
    adresse: _nullSiVide(s.adresse),
    ville: _nullSiVide(s.ville),
    remarque: remarque,
    relations: s.relations,
    statut: base.statut,
    version: base.version,
    syncStatus: base.syncStatus,
  );
}

String? _nullSiVide(String? v) {
  final t = v?.trim();
  return t == null || t.isEmpty ? null : t;
}
