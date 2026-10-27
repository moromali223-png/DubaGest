import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../entreprise/domain/entities/profil_entreprise.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../../finances/domain/services/etat_finances.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../../roles/domain/entities/role.dart';
import '../entities/document.dart';
import '../repositories/document_repository.dart';

const _uuid = Uuid();

class DroitsDocuments {
  const DroitsDocuments({this.voir = false, this.creer = false, this.imprimer = false, this.partager = false});

  factory DroitsDocuments.de(ContexteSession ctx) {
    bool peut(String p) =>
        ctx.accessPolicy().canPerform(moduleCode: ModuleCodes.communDocuments, permission: p).isAllowed;
    return DroitsDocuments(
      voir: peut(PermissionCodes.documentsView),
      creer: peut(PermissionCodes.documentsCreate),
      imprimer: peut(PermissionCodes.documentsPrint),
      partager: peut(PermissionCodes.documentsShare),
    );
  }

  final bool voir;
  final bool creer;
  final bool imprimer;
  final bool partager;
}

/// Garde une réserve de numéros sur l'appareil (appelé en ligne, en tâche de
/// fond) pour pouvoir émettre des documents hors-ligne.
class AssurerNumeros {
  const AssurerNumeros(this._repository);
  final DocumentRepository _repository;

  static const seuil = 10;
  static const taille = 50;

  Future<void> call(ContexteSession ctx, {required String appareilId, TypeDocument type = TypeDocument.recu}) async {
    if (!DroitsDocuments.de(ctx).creer) return;
    final blocs = await _repository.blocs(ctx.entreprise!.id, ctx.userId, type, DateTime.now().year);
    final restant = blocs.fold(0, (t, b) => t + b.restant);
    if (restant < seuil) {
      await _repository.reserverBloc(ctx.entreprise!.id, type, appareilId: appareilId, taille: taille);
    }
  }
}

/// Reçu d'un encaissement : numéroté (hors-ligne grâce aux blocs) et figé.
class EmettreRecu {
  const EmettreRecu(this._repository);
  final DocumentRepository _repository;

  Future<Document> call(
    ContexteSession ctx, {
    required EtatFinances etat,
    required Paiement paiement,
    required List<Document> existants,
    required String appareilId,
    ProfilEntreprise? profil,
    Contact? contact,
    String? emisPar,
  }) async {
    final decision = ctx.accessPolicy().canPerform(
      moduleCode: ModuleCodes.communDocuments,
      permission: PermissionCodes.documentsCreate,
      perimetreId: paiement.perimetreId,
    );
    if (decision case AccessDenied()) throw decision.toFailure();
    if (paiement.sens != SensPaiement.entree || paiement.estAnnulation || paiement.refuse || etat.estAnnule(paiement)) {
      throw const Failure.rule(RuleCodes.documentOriginInvalid);
    }
    if (existants.any((d) => d.origineId == paiement.id && d.type == TypeDocument.recu && !d.refuse)) {
      throw const Failure.rule(RuleCodes.documentExists);
    }

    final eid = ctx.entreprise!.id;
    final maintenant = DateTime.now();
    final contenu = <String, dynamic>{
      'entreprise': {
        'nom': profil?.nom ?? ctx.entreprise!.nom,
        'telephone': profil?.telephone,
        'adresse': profil?.adresse,
        'ville': profil?.ville,
        'identifiant_fiscal': profil?.identifiantFiscal,
        'registre_commerce': profil?.registreCommerce,
        'devise': profil?.devise ?? ctx.entreprise!.devise ?? 'XOF',
      },
      'contact': contact == null ? null : {'nom': contact.nomAffiche, 'telephone': contact.telephone},
      'paiement': {
        'montant': paiement.montant,
        'mode': paiement.mode.code,
        'date': paiement.datePaiement.toUtc().toIso8601String(),
        'reference': paiement.reference,
      },
      'lignes': [
        for (final a in paiement.affectations)
          if (etat.engagements.where((e) => e.id == a.engagementId).firstOrNull case final e?)
            {'libelle': e.libelle, 'montant': a.montant, 'reste': etat.suivi(e).reste},
      ],
      'emis_par': emisPar,
      'pied': profil?.piedRecu,
    };

    Document construire(NumeroBloc bloc, int sequence) => Document(
          id: _uuid.v4(),
          entrepriseId: eid,
          type: TypeDocument.recu,
          numero: formatNumero(bloc.prefixe, bloc.annee, sequence),
          blocId: bloc.id,
          sequence: sequence,
          langue: profil?.langueDocuments ?? 'fr',
          date: maintenant,
          montant: paiement.montant,
          origineType: 'PAIEMENT',
          origineId: paiement.id,
          perimetreId: paiement.perimetreId,
          contactId: paiement.contactId,
          contenu: contenu,
          syncStatus: RecordSyncStatus.pendingSync,
        );

    Future<Document?> tenter() => _repository.emettre(
          entrepriseId: eid,
          userId: ctx.userId,
          type: TypeDocument.recu,
          annee: maintenant.year,
          construire: construire,
        );

    final document = await tenter();
    if (document != null) return document;
    // Plus de numéro sur l'appareil : réservation immédiate (en ligne).
    try {
      await _repository.reserverBloc(eid, TypeDocument.recu, appareilId: appareilId, taille: AssurerNumeros.taille);
    } on Failure catch (f) {
      if (f.kind == FailureKind.network) throw const Failure.rule(RuleCodes.documentNumbersExhausted);
      rethrow;
    }
    return await tenter() ?? (throw const Failure.rule(RuleCodes.documentNumbersExhausted));
  }
}

class RetirerDocumentRefuse {
  const RetirerDocumentRefuse(this._repository);
  final DocumentRepository _repository;

  Future<void> call(String id) => _repository.retirerRefuse(id);
}

/// Émetteur universel pour tout type de document métier (factures, devis, bons, quittances, contrats).
class EmettreDocument {
  const EmettreDocument(this._repository);
  final DocumentRepository _repository;

  Future<Document> call(
    ContexteSession ctx, {
    required TypeDocument type,
    required String origineType,
    String? origineId,
    String? contactId,
    String? perimetreId,
    required int montant,
    required Map<String, dynamic> contenu,
    required String appareilId,
    String? langue,
  }) async {
    final decision = ctx.accessPolicy().canPerform(
      moduleCode: ModuleCodes.communDocuments,
      permission: PermissionCodes.documentsCreate,
      perimetreId: perimetreId,
    );
    if (decision case AccessDenied()) throw decision.toFailure();
    if (type == TypeDocument.bonCommande && ctx.membre?.roleCode == RoleCodes.superviseur) {
      throw const Failure.rule(RuleCodes.permissionDenied);
    }

    final eid = ctx.entreprise!.id;
    final maintenant = DateTime.now();
    final langueDoc = langue ?? 'fr';

    Document construire(NumeroBloc bloc, int sequence) => Document(
          id: _uuid.v4(),
          entrepriseId: eid,
          type: type,
          numero: formatNumero(bloc.prefixe, bloc.annee, sequence),
          blocId: bloc.id,
          sequence: sequence,
          langue: langueDoc,
          date: maintenant,
          montant: montant,
          origineType: origineType,
          origineId: origineId,
          perimetreId: perimetreId,
          contactId: contactId,
          contenu: contenu,
          syncStatus: RecordSyncStatus.pendingSync,
        );

    Future<Document?> tenter() => _repository.emettre(
          entrepriseId: eid,
          userId: ctx.userId,
          type: type,
          annee: maintenant.year,
          construire: construire,
        );

    final document = await tenter();
    if (document != null) return document;

    // Réserve immédiate si bloc épuisé sur l'appareil
    try {
      await _repository.reserverBloc(eid, type, appareilId: appareilId, taille: AssurerNumeros.taille);
    } on Failure catch (f) {
      if (f.kind == FailureKind.network) throw const Failure.rule(RuleCodes.documentNumbersExhausted);
      rethrow;
    }
    return await tenter() ?? (throw const Failure.rule(RuleCodes.documentNumbersExhausted));
  }
}

