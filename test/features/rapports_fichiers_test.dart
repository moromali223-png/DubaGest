import 'dart:typed_data';

import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/features/agenda/domain/entities/agenda.dart';
import 'package:dubagest/features/fichiers/data/fichiers_repository_impl.dart';
import 'package:dubagest/features/fichiers/domain/fichiers.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/rapports/domain/rapports.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/test_database.dart';

Matcher _regle(String code) => throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', code));

void main() {
  final maintenant = DateTime(2026, 10, 6, 12);
  final debut = DateTime(2026, 10, 1), fin = DateTime(2026, 10, 6);

  group('rapports', () {
    Paiement p(String id, int montant, DateTime d, {SensPaiement sens = SensPaiement.entree, String? annule}) =>
        Paiement(id: id, entrepriseId: entrepriseId, sens: sens, montant: montant, mode: ModePaiement.especes,
            datePaiement: d, annulePaiementId: annule);
    Engagement dette(String id, int total, String? contact, DateTime? echeance) => Engagement(
        id: id, entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: id, montantTotal: total,
        dateEngagement: DateTime(2026, 1, 1), echeance: echeance, contactId: contact);

    test('journal de trésorerie : lignes de la période, totaux hors annulations', () {
      final etat = EtatFinances(paiements: [
        p('a', 10000, DateTime(2026, 10, 2)),
        p('b', 3000, DateTime(2026, 10, 3), sens: SensPaiement.sortie),
        p('c', 5000, DateTime(2026, 10, 4)),
        p('xc', 5000, DateTime(2026, 10, 5), sens: SensPaiement.sortie, annule: 'c'),
        p('hors', 99, DateTime(2026, 9, 20)),
      ]);
      final j = Rapports.tresorerie(etat, debut, fin);
      expect(j.lignes.map((l) => (l.paiement.id, l.annule)), [('a', false), ('b', false), ('c', true), ('xc', false)]);
      expect((j.entrees, j.sorties, j.solde), (10000, 3000, 7000));
    });

    test('balance âgée : tranches selon le retard à date, par contact', () {
      final etat = EtatFinances(engagements: [
        dette('pas-echeance', 1000, 'c1', null),
        dette('futur', 2000, 'c1', DateTime(2026, 10, 20)),
        dette('10j', 3000, 'c1', DateTime(2026, 9, 26)),
        dette('45j', 4000, 'c2', DateTime(2026, 8, 22)),
        dette('75j', 5000, 'c2', DateTime(2026, 7, 23)),
        dette('200j', 6000, null, DateTime(2026, 3, 20)),
      ]);
      final b = Rapports.balanceAgee(etat, maintenant);
      final c1 = b.firstWhere((l) => l.contactId == 'c1');
      final c2 = b.firstWhere((l) => l.contactId == 'c2');
      final sans = b.firstWhere((l) => l.contactId == null);
      expect((c1.nonEchu, c1.jours30, c1.total), (3000, 3000, 6000));
      expect((c2.jours60, c2.jours90, c2.total), (4000, 5000, 9000));
      expect(sans.plus90, 6000);
      expect(b.first.contactId, 'c2', reason: 'trié du plus gros au plus petit');
    });

    test('dépenses par catégorie et clôtures de caisse de la période', () {
      final etat = EtatFinances(
        categories: const [CategorieDepense(id: 't', entrepriseId: entrepriseId, code: 'TRANSPORT')],
        depenses: [
          Depense(id: 'd1', entrepriseId: entrepriseId, categorieId: 't', libelle: 'x', montant: 2000,
              dateDepense: DateTime(2026, 10, 2), payeeImmediatement: true),
          Depense(id: 'd2', entrepriseId: entrepriseId, categorieId: 't', libelle: 'x', montant: 3000,
              dateDepense: DateTime(2026, 10, 3), payeeImmediatement: true),
          Depense(id: 'd3', entrepriseId: entrepriseId, categorieId: 't', libelle: 'x', montant: 9000,
              dateDepense: DateTime(2026, 10, 3), payeeImmediatement: true, annulee: true),
        ],
        caisses: const [Caisse(id: 'k', entrepriseId: entrepriseId, perimetreId: 'b', nom: 'Caisse')],
        sessions: [
          SessionCaisse(id: 's1', entrepriseId: entrepriseId, caisseId: 'k', perimetreId: 'b', ouverte: false,
              soldeInitial: 0, ouverteLe: DateTime(2026, 10, 2, 8), fermeeLe: DateTime(2026, 10, 2, 19),
              soldeTheorique: 15000, soldeReel: 14000, ecart: -1000),
          SessionCaisse(id: 's2', entrepriseId: entrepriseId, caisseId: 'k', perimetreId: 'b', ouverte: true,
              soldeInitial: 0, ouverteLe: DateTime(2026, 10, 6, 8)),
        ],
      );
      final d = Rapports.depenses(etat, debut, fin).single;
      expect((d.categorie?.code, d.nombre, d.montant), ('TRANSPORT', 2, 5000));
      expect(Rapports.caisses(etat, debut, fin).map((c) => c.session.ecart), [-1000]);
    });
  });

  group('notes et pièces jointes', () {
    late AppDatabase db;
    late DriftSyncQueueStore queue;
    late FichiersLocalDataSource local;
    late FichiersRepositoryImpl repo;
    final admin = contexte();
    final vendeur = contexte(role: 'VENDEUR');

    setUp(() {
      db = memoryDatabase();
      queue = DriftSyncQueueStore(db);
      local = FichiersLocalDataSource(db);
      repo = FichiersRepositoryImpl(
          local: local, queue: queue, client: () => null, currentUserId: () => userId, requestSync: () {});
    });
    tearDown(() => db.close());

    test('note : ajoutée hors-ligne, modifiée par son auteur, retirée ; envoyées dans l\'ordre', () async {
      final g = GererFichiers(repo);
      final n = await g.ajouterNote(admin, CibleType.contact, 'c-1', '  Appeler le matin ');
      expect(n.texte, 'Appeler le matin');
      var notes = await local.watchNotes(CibleType.contact, 'c-1').first;
      await g.modifierNote(admin, notes.single, 'Appeler après 10 h');
      notes = await local.watchNotes(CibleType.contact, 'c-1').first;
      expect(notes.single.texte, 'Appeler après 10 h');

      final server = FakeSyncServer();
      final cursors = DriftSyncCursorStore(db);
      final engine = SyncEngine(
        queue: queue, remote: server, cursors: cursors, connectivity: FakeConnectivity(),
        handlers: fichiersSyncHandlers(local, cursors), periodicInterval: const Duration(days: 1),
      );
      addTearDown(engine.dispose);
      await engine.setScope(const SyncScope(userId: userId, entrepriseId: entrepriseId));
      await engine.syncNow();
      expect(server.rows[n.id]?['texte'], 'Appeler après 10 h');

      await g.retirerNote(admin, (await local.watchNotes(CibleType.contact, 'c-1').first).single);
      expect(await local.watchNotes(CibleType.contact, 'c-1').first, isEmpty, reason: 'masquée tout de suite');
      await engine.syncNow();
      expect(server.rows[n.id]?['deleted_at'], isNotNull);
      expect(await queue.pendingCount(userId), 0);
    });

    test('droits : par type de fiche, comme le serveur ; l\'auteur seul modifie sa note', () async {
      expect(DroitsFiche.de(vendeur, CibleType.contact).ajout, isTrue);
      expect(DroitsFiche.de(vendeur, CibleType.engagement).lecture, isTrue);
      expect(DroitsFiche.de(vendeur, CibleType.engagement).ajout, isFalse, reason: 'pas de receivables.manage');
      expect(DroitsFiche.de(vendeur, CibleType.depense).lecture, isFalse, reason: 'pas d\'expenses.view');
      final g = GererFichiers(repo);
      await expectLater(g.ajouterNote(vendeur, CibleType.engagement, 'e1', 'X'), _regle(RuleCodes.permissionDenied));
      final autre = Note(id: 'n', cibleType: CibleType.contact, cibleId: 'c', texte: 'X', createdAt: maintenant, createdBy: 'u-autre');
      await expectLater(g.modifierNote(vendeur, autre, 'Y'), _regle(RuleCodes.permissionDenied));
      await expectLater(g.retirerNote(vendeur, autre), _regle(RuleCodes.permissionDenied));
    });

    test('pièce jointe : format et taille vérifiés ; sans réseau, message clair', () async {
      final g = GererFichiers(repo);
      await expectLater(
        g.ajouterPiece(admin, CibleType.depense, 'd1',
            FichierChoisi(nom: 'x.exe', octets: Uint8List(10), typeMime: 'application/octet-stream')),
        _regle(RuleCodes.fileTypeInvalid),
      );
      await expectLater(
        g.ajouterPiece(admin, CibleType.depense, 'd1',
            FichierChoisi(nom: 'x.pdf', octets: Uint8List(FichierChoisi.tailleMax + 1), typeMime: 'application/pdf')),
        _regle(RuleCodes.fileTooLarge),
      );
      await expectLater(
        g.ajouterPiece(admin, CibleType.depense, 'd1',
            FichierChoisi(nom: 'recu.jpg', octets: Uint8List(10), typeMime: 'image/jpeg')),
        throwsA(isA<Failure>().having((f) => f.kind, 'type', FailureKind.network)),
      );
      expect(FichierChoisi.typeDepuisNom('Facture.PDF'), 'application/pdf');
    });
  });
}
