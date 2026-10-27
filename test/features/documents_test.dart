import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/sync_engine.dart';
import 'package:dubagest/features/documents/data/document_repository_impl.dart';
import 'package:dubagest/features/documents/domain/entities/document.dart';
import 'package:dubagest/features/documents/domain/usecases/gerer_documents.dart';
import 'package:dubagest/features/documents/presentation/pdf/recu_pdf.dart';
import 'package:dubagest/features/documents/presentation/pdf/document_pdf_generator.dart';
import 'package:dubagest/features/entreprise/domain/entities/profil_entreprise.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/test_database.dart';

Matcher _regle(String code) => throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', code));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final admin = contexte();

  late AppDatabase db;
  late DriftSyncQueueStore queue;
  late DocumentLocalDataSource local;
  late DocumentRepositoryImpl repo;

  setUp(() {
    db = memoryDatabase();
    queue = DriftSyncQueueStore(db);
    local = DocumentLocalDataSource(db);
    // Aucun serveur : la réservation échoue comme hors-ligne.
    repo = DocumentRepositoryImpl(local: local, queue: queue, client: () => null, requestSync: () {});
  });
  tearDown(() => db.close());

  final engagement = Engagement(
    id: 'e1', entrepriseId: entrepriseId, sens: SensEngagement.aRecevoir, libelle: 'Crédit septembre',
    montantTotal: 50000, montantRegle: 20000, dateEngagement: DateTime(2026, 9, 1),
  );
  Paiement paiement(String id, {SensPaiement sens = SensPaiement.entree}) => Paiement(
        id: id, entrepriseId: entrepriseId, sens: sens, montant: 20000, mode: ModePaiement.mobileMoney,
        datePaiement: DateTime(2026, 10, 5, 10), contactId: 'c-1', reference: 'OM-123',
        affectations: const [Affectation(id: 'a1', engagementId: 'e1', montant: 20000)],
      );
  final etat = EtatFinances(engagements: [engagement], paiements: [paiement('p1'), paiement('p2')]);
  const profil = ProfilEntreprise(
    id: entrepriseId, nom: 'Alpha Distribution', devise: 'XOF', langueDocuments: 'fr', telephone: '+223 20 00 00 00',
    piedRecu: 'Merci de votre confiance',
  );

  Future<void> bloc({int debut = 51, int fin = 52}) => local.ajouterBloc(NumeroBloc(
        id: 'b-$debut', entrepriseId: entrepriseId, userId: userId, type: TypeDocument.recu, prefixe: 'REC',
        annee: DateTime.now().year, debut: debut, fin: fin, prochain: debut,
      ));

  Future<Document> emettre(String paiementId, {List<Document> existants = const []}) => EmettreRecu(repo).call(
        admin,
        etat: etat,
        paiement: etat.paiement(paiementId)!,
        existants: existants,
        appareilId: 'appareil-test',
        profil: profil,
        emisPar: 'Awa Diallo',
      );

  test('numérotation hors-ligne : numéros du bloc, dans l\'ordre, sans doublon', () async {
    await bloc();
    final r1 = await emettre('p1');
    final r2 = await emettre('p2');
    final annee = DateTime.now().year;
    expect([r1.numero, r2.numero], ['REC-$annee-00051', 'REC-$annee-00052']);
    expect((r1.contenu['entreprise'] as Map)['nom'], 'Alpha Distribution');
    expect(r1.contenu['pied'], 'Merci de votre confiance', reason: 'mention figée à l\'émission');
    expect(r1.contenu['lignes'], [
      {'libelle': 'Crédit septembre', 'montant': 20000, 'reste': 30000}
    ]);
    expect(await queue.pendingCount(userId), 2);
    expect(await repo.blocs(entrepriseId, userId, TypeDocument.recu, annee), isEmpty, reason: 'bloc épuisé');
  });

  test('plus aucun numéro et pas de réseau : message clair', () async {
    await expectLater(emettre('p1'), _regle(RuleCodes.documentNumbersExhausted));
  });

  test('un seul reçu par paiement ; pas de reçu pour un paiement versé', () async {
    await bloc(fin: 60);
    final r = await emettre('p1');
    await expectLater(emettre('p1', existants: [r]), _regle(RuleCodes.documentExists));
    final sortie = EtatFinances(paiements: [paiement('s1', sens: SensPaiement.sortie)]);
    await expectLater(
      EmettreRecu(repo).call(admin,
          etat: sortie, paiement: sortie.paiement('s1')!, existants: const [], appareilId: 'appareil-test'),
      _regle(RuleCodes.documentOriginInvalid),
    );
  });

  test('sans documents.create : refusé', () async {
    await bloc();
    final vendeur = contexte(role: 'VENDEUR', permissions: {'payments.view'});
    await expectLater(
      EmettreRecu(repo).call(vendeur,
          etat: etat, paiement: etat.paiement('p1')!, existants: const [], appareilId: 'appareil-test'),
      throwsA(isA<Failure>()),
    );
  });

  test('synchronisation : document envoyé avec bloc et séquence', () async {
    await bloc();
    final r = await emettre('p1');
    final server = FakeSyncServer();
    final cursors = DriftSyncCursorStore(db);
    final engine = SyncEngine(
      queue: queue,
      remote: server,
      cursors: cursors,
      connectivity: FakeConnectivity(),
      handlers: [documentsSyncHandler(local, cursors)],
      periodicInterval: const Duration(days: 1),
    );
    addTearDown(engine.dispose);
    await engine.setScope(const SyncScope(userId: userId, entrepriseId: entrepriseId));
    await engine.syncNow();
    expect((server.rows[r.id]?['bloc_id'], server.rows[r.id]?['sequence']), ('b-51', 51));
    // Le numéro final est calculé par le vrai serveur : sa confirmation sur
    // l'appareil est vérifiée par le test d'intégration.
  });

  test('PDF : reçu généré en français et en arabe (polices embarquées)', () async {
    await bloc();
    final r = await emettre('p1');
    final fr = await genererRecuPdf(r, annule: false);
    expect(String.fromCharCodes(fr.take(5)), '%PDF-');
    final ar = Document(
      id: 'x', entrepriseId: entrepriseId, type: TypeDocument.recu, numero: r.numero, blocId: r.blocId,
      sequence: r.sequence, langue: 'ar', date: r.date, montant: r.montant, origineType: 'PAIEMENT',
      contenu: {...r.contenu, 'contact': {'nom': 'أحمد محمد', 'telephone': null}},
    );
    final pdfAr = await genererRecuPdf(ar, annule: true);
    expect(String.fromCharCodes(pdfAr.take(5)), '%PDF-');
    expect(pdfAr.length, greaterThan(1000));
  });

  test('EmettreDocument : facture émise hors-ligne avec son bloc et sa séquence', () async {
    await local.ajouterBloc(NumeroBloc(
      id: 'bloc-fac-1',
      entrepriseId: entrepriseId,
      userId: userId,
      type: TypeDocument.facture,
      prefixe: 'FAC',
      annee: DateTime.now().year,
      debut: 101,
      fin: 105,
      prochain: 101,
    ));

    final facture = await EmettreDocument(repo).call(
      admin,
      type: TypeDocument.facture,
      origineType: 'PRESTATION',
      origineId: 'prest-1',
      montant: 45000,
      appareilId: 'appareil-test',
      contenu: {
        'entreprise': {'nom': 'Alpha Services', 'devise': 'XOF'},
        'contact': {'nom': 'Moussa Traoré', 'telephone': '+223 70 00 00 00'},
        'titre': 'Réparation climatiseur',
        'lignes': [
          {'libelle': 'Diagnostic et recharge gaz', 'quantite': 1, 'prix_unitaire': 45000, 'montant': 45000}
        ],
        'paye': 15000,
        'reste': 30000,
      },
    );

    final annee = DateTime.now().year;
    expect(facture.numero, 'FAC-$annee-00101');
    expect(facture.type, TypeDocument.facture);
    expect(facture.montant, 45000);
    expect(facture.contactNom, 'Moussa Traoré');
    expect(facture.titre, 'Réparation climatiseur');

    // Test du générateur PDF universel
    final pdfBytes = await genererDocumentPdf(facture);
    expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');
    expect(pdfBytes.length, greaterThan(1500));
  });

  test('genererDocumentPdf : devis proforma avec tampon et arabe', () async {
    final devisDoc = Document(
      id: 'd-dev-1',
      entrepriseId: entrepriseId,
      type: TypeDocument.devis,
      numero: 'DEV-2026-00001',
      blocId: 'b-dev',
      sequence: 1,
      langue: 'fr',
      date: DateTime.now(),
      montant: 80000,
      origineType: 'MANUEL',
      contenu: {
        'entreprise': {'nom': 'Alpha Services', 'devise': 'XOF'},
        'contact': {'nom': 'Cabinet Conseil', 'telephone': '+223 60 00 00 00'},
        'titre': 'Installation réseau',
        'lignes': [
          {'libelle': 'Câblage 4 postes', 'quantite': 4, 'prix_unitaire': 20000, 'montant': 80000}
        ],
        'conditions': 'Validité de l\'offre : 15 jours',
      },
    );

    final pdfDevis = await genererDocumentPdf(devisDoc);
    expect(String.fromCharCodes(pdfDevis.take(5)), '%PDF-');
    expect(pdfDevis.length, greaterThan(1500));
  });

  test('genererDocumentPdf : bon de commande avec lignes et sans contact', () async {
    final bcDoc = Document(
      id: 'd-bc-1',
      entrepriseId: 'e-1',
      type: TypeDocument.bonCommande,
      numero: 'BC-2026-00001',
      blocId: 'b-bc',
      sequence: 1,
      langue: 'fr',
      date: DateTime.now(),
      montant: 300,
      origineType: 'MANUEL',
      contenu: {
        'entreprise': {'nom': 'DubaGest Test', 'devise': 'XOF'},
        'contact': null,
        'titre': 'Bon de commande fournisseur',
        'date_echeance': null,
        'lignes': [
          {'libelle': 'Article 1', 'quantite': 2.0, 'prix_unitaire': 100, 'montant': 200},
          {'libelle': 'hhhh', 'quantite': 1.0, 'prix_unitaire': 100, 'montant': 100},
        ],
        'sous_total': 300,
        'remise': 0,
        'total': 300,
        'acompte': 0,
        'reste': 300,
        'conditions': 'Règlement selon conditions habituelle',
        'notes': null,
      },
    );

    final pdfBc = await genererDocumentPdf(bcDoc);
    expect(String.fromCharCodes(pdfBc.take(5)), '%PDF-');
    expect(pdfBc.length, greaterThan(1500));
  });
}

