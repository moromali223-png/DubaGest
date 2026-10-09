import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../core/errors/failure.dart';
import '../../../core/permissions/access_decision.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/sync/sync_models.dart';
import '../../agenda/domain/entities/agenda.dart';
import '../../entreprise/domain/entities/contexte_session.dart';
import '../../modules/domain/entities/app_module.dart';

const _uuid = Uuid();

/// Types de fiche pouvant porter des notes et des pièces jointes.
const ciblesFichiers = {CibleType.contact, CibleType.engagement, CibleType.paiement, CibleType.depense};

class Note {
  const Note({
    required this.id,
    required this.cibleType,
    required this.cibleId,
    required this.texte,
    required this.createdAt,
    this.auteurNom,
    this.createdBy,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final CibleType cibleType;
  final String cibleId;
  final String texte;
  final DateTime createdAt;
  final String? auteurNom;
  final String? createdBy;
  final int? version;
  final RecordSyncStatus syncStatus;
}

class PieceJointe {
  const PieceJointe({
    required this.id,
    required this.cibleType,
    required this.cibleId,
    required this.chemin,
    required this.nomFichier,
    required this.typeMime,
    required this.taille,
    required this.createdAt,
    this.auteurNom,
    this.createdBy,
    this.version,
  });

  final String id;
  final CibleType cibleType;
  final String cibleId;
  final String chemin;
  final String nomFichier;
  final String typeMime;
  final int taille;
  final DateTime createdAt;
  final String? auteurNom;
  final String? createdBy;
  final int? version;

  bool get estImage => typeMime.startsWith('image/');
}

/// Fichier choisi par l'utilisateur (photo, PDF).
class FichierChoisi {
  const FichierChoisi({required this.nom, required this.octets, required this.typeMime});
  final String nom;
  final Uint8List octets;
  final String typeMime;

  static const typesAcceptes = {'image/jpeg', 'image/png', 'image/webp', 'application/pdf'};
  static const tailleMax = 10 * 1024 * 1024;

  static String? typeDepuisNom(String nom) => switch (nom.split('.').last.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => null,
      };
}

/// Droits sur les notes / pièces jointes d'une fiche : ceux de la fiche
/// (même correspondance que `app.peut_cible` côté serveur).
class DroitsFiche {
  const DroitsFiche({this.lecture = false, this.ajout = false});

  factory DroitsFiche.de(ContexteSession ctx, CibleType type) {
    final (module, lecture, ajout) = switch (type) {
      CibleType.contact => (ModuleCodes.communContacts, PermissionCodes.contactsView, PermissionCodes.contactsUpdate),
      CibleType.engagement =>
        (ModuleCodes.financesCreances, PermissionCodes.receivablesView, PermissionCodes.receivablesManage),
      CibleType.paiement =>
        (ModuleCodes.financesPaiements, PermissionCodes.paymentsView, PermissionCodes.paymentsCreate),
      CibleType.depense =>
        (ModuleCodes.financesDepenses, PermissionCodes.expensesView, PermissionCodes.expensesCreate),
      CibleType.document => ('', '', ''),
    };
    bool peut(String p) =>
        module.isNotEmpty && ctx.accessPolicy().canPerform(moduleCode: module, permission: p).isAllowed;
    return DroitsFiche(lecture: peut(lecture), ajout: peut(ajout));
  }

  final bool lecture;
  final bool ajout;
}

abstract interface class FichiersRepository {
  Stream<List<Note>> notes(CibleType type, String cibleId);
  Stream<List<PieceJointe>> pieces(CibleType type, String cibleId);
  Future<void> ajouterNote(Note note, {required String entrepriseId});
  Future<void> modifierNote(Note avant, String texte);
  Future<void> retirerNote(Note note);

  /// En ligne : envoi du fichier, puis enregistrement de la pièce jointe.
  Future<PieceJointe> ajouterPiece({
    required String entrepriseId,
    required CibleType type,
    required String cibleId,
    required FichierChoisi fichier,
  });
  Future<void> retirerPiece(PieceJointe piece);

  /// Lien temporaire de lecture (en ligne).
  Future<String> lienTemporaire(String chemin);
}

class GererFichiers {
  const GererFichiers(this._repository);
  final FichiersRepository _repository;

  Future<Note> ajouterNote(ContexteSession ctx, CibleType type, String cibleId, String texte) async {
    _exiger(DroitsFiche.de(ctx, type).ajout);
    final t = texte.trim();
    if (t.isEmpty || t.length > 2000) throw const Failure.rule(RuleCodes.labelInvalid);
    final note = Note(
      id: _uuid.v4(),
      cibleType: type,
      cibleId: cibleId,
      texte: t,
      createdAt: DateTime.now(),
      auteurNom: ctx.nomComplet,
      createdBy: ctx.userId,
      syncStatus: RecordSyncStatus.pendingSync,
    );
    await _repository.ajouterNote(note, entrepriseId: ctx.entreprise!.id);
    return note;
  }

  Future<void> modifierNote(ContexteSession ctx, Note note, String texte) async {
    _exiger(note.createdBy == ctx.userId);
    final t = texte.trim();
    if (t.isEmpty || t.length > 2000) throw const Failure.rule(RuleCodes.labelInvalid);
    await _repository.modifierNote(note, t);
  }

  /// Auteur, ou administration de l'entreprise.
  Future<void> retirerNote(ContexteSession ctx, Note note) async {
    _exiger(note.createdBy == ctx.userId || ctx.permissionEngine.has(PermissionCodes.entrepriseManage));
    await _repository.retirerNote(note);
  }

  Future<PieceJointe> ajouterPiece(ContexteSession ctx, CibleType type, String cibleId, FichierChoisi f) async {
    _exiger(DroitsFiche.de(ctx, type).ajout);
    if (!FichierChoisi.typesAcceptes.contains(f.typeMime)) throw const Failure.rule(RuleCodes.fileTypeInvalid);
    if (f.octets.isEmpty || f.octets.length > FichierChoisi.tailleMax) {
      throw const Failure.rule(RuleCodes.fileTooLarge, {'max': 10});
    }
    return _repository.ajouterPiece(entrepriseId: ctx.entreprise!.id, type: type, cibleId: cibleId, fichier: f);
  }

  Future<void> retirerPiece(ContexteSession ctx, PieceJointe p) async {
    _exiger(p.createdBy == ctx.userId || ctx.permissionEngine.has(PermissionCodes.entrepriseManage));
    await _repository.retirerPiece(p);
  }

  static void _exiger(bool ok) {
    if (!ok) throw const Failure.rule(RuleCodes.permissionDenied);
  }
}
