import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/finances/data/datasources/finances_local_data_source.dart';
import 'package:dubagest/features/finances/data/repositories/finances_repository_impl.dart';
import 'package:dubagest/features/finances/domain/entities/caisse_tresorerie_models.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/caisse_tresorerie_service.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/domain/usecases/gerer_finances.dart';
import 'package:dubagest/features/finances/domain/usecases/gerer_operations_caisse.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/test_database.dart';

Matcher _regle(String code) => throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', code));

/// Mercredi 7 octobre 2026, 15 h : dates fixes, résultats reproductibles.
final _maintenant = DateTime(2026, 10, 7, 15);
DateTime _il(int jours, [int heure = 10]) => DateTime(2026, 10, 7 - jours, heure);

Engagement _du(String id, String origine, int montant, DateTime date, {SensEngagement sens = SensEngagement.aRecevoir}) =>
    Engagement(
      id: id,
      entrepriseId: entrepriseId,
      perimetreId: 'b1',
      sens: sens,
      libelle: id,
      montantTotal: montant,
      dateEngagement: DateTime(date.year, date.month, date.day),
      origineType: origine,
    );

Paiement _paye(String id, int montant, DateTime date,
        {SensPaiement sens = SensPaiement.entree,
        ModePaiement mode = ModePaiement.especes,
        String? regle,
        String site = 'b1',
        NaturePaiement? nature,
        String? transfertId}) =>
    Paiement(
      id: id,
      entrepriseId: entrepriseId,
      perimetreId: site,
      sens: sens,
      montant: montant,
      mode: mode,
      datePaiement: date,
      affectations: [if (regle != null) Affectation(id: 'a-$id', engagementId: regle, montant: montant)],
      nature: nature,
      transfertId: transfertId,
    );

void main() {
  const service = CaisseTresorerieService();

  group('Cas réels : la caisse ne compte que l\'argent réellement entré ou sorti', () {
    ResumeTresorerie jour(EtatFinances e) => service.resumePeriode(e, FiltrePeriode.aujourdhui, maintenant: _maintenant);

    test('cas 1 — vente comptant 100 000 : caisse +100 000, origine « Vente »', () {
      final e = EtatFinances(
        engagements: [_du('v1', 'VENTE', 100000, _il(0))],
        paiements: [_paye('p1', 100000, _il(0), regle: 'v1')],
      );
      expect(jour(e).entrees, 100000);
      expect(service.origine(e, e.paiements.single), OrigineMouvement.vente);
    });

    test('cas 2 et 3 — vente à crédit : caisse +0 ; payée en partie : +40 000 seulement', () {
      final credit = EtatFinances(engagements: [_du('v1', 'VENTE', 100000, _il(0))]);
      expect(jour(credit).entrees, 0);

      final partielle = EtatFinances(
        engagements: [_du('v1', 'VENTE', 100000, _il(0))],
        paiements: [_paye('p1', 40000, _il(0), regle: 'v1')],
      );
      expect(jour(partielle).entrees, 40000, reason: 'jamais +100 000 : le reste est une créance');
    });

    test('cas 4 — le client paie sa dette plus tard : « Paiement client », caisse +60 000', () {
      final e = EtatFinances(
        engagements: [_du('v1', 'VENTE', 100000, _il(3))],
        paiements: [_paye('p1', 40000, _il(3), regle: 'v1'), _paye('p2', 60000, _il(0), regle: 'v1')],
      );
      expect(jour(e).entrees, 60000);
      expect(service.origine(e, e.paiements.last), OrigineMouvement.paiementClient);
    });

    test('cas 5 — dépense 25 000 en espèces : sortie « Dépense »', () {
      final e = EtatFinances(
        engagements: [_du('d1', 'DEPENSE', 25000, _il(0), sens: SensEngagement.aPayer)],
        paiements: [_paye('p1', 25000, _il(0), sens: SensPaiement.sortie, regle: 'd1')],
      );
      expect(jour(e).sorties, 25000);
      expect(service.repartition(e, FiltrePeriode.aujourdhui, entrees: false, maintenant: _maintenant).single.origine,
          OrigineMouvement.depense);
    });

    test('cas 6, 7, 8 — achat comptant, à crédit (+0), puis paiement fournisseur', () {
      final e = EtatFinances(
        engagements: [
          _du('a1', 'ACHAT', 500000, _il(0), sens: SensEngagement.aPayer),
          _du('a2', 'ACHAT', 500000, _il(5), sens: SensEngagement.aPayer),
        ],
        paiements: [
          _paye('p1', 500000, _il(0), sens: SensPaiement.sortie, mode: ModePaiement.virement, regle: 'a1'),
          _paye('p2', 100000, _il(0), sens: SensPaiement.sortie, mode: ModePaiement.virement, regle: 'a2'),
        ],
      );
      expect(jour(e).sorties, 600000, reason: 'achat à crédit : aucune sortie tant que rien n\'est payé');
      expect(service.origine(e, e.paiements.first), OrigineMouvement.achat);
      expect(service.origine(e, e.paiements.last), OrigineMouvement.paiementFournisseur);
    });

    test('cas 9 — paiement multiple : espèces et Mobile Money comptés chacun dans leur moyen', () {
      final e = EtatFinances(
        engagements: [_du('v1', 'VENTE', 200000, _il(0))],
        paiements: [
          _paye('p1', 100000, _il(0), regle: 'v1'),
          _paye('p2', 50000, _il(0), mode: ModePaiement.mobileMoney, regle: 'v1'),
        ],
      );
      expect(jour(e).entrees, 150000);
      final modes = service.moyensPaiementEncaissement(e, FiltrePeriode.aujourdhui, maintenant: _maintenant);
      expect({for (final m in modes) m.mode: m.montant}, {ModePaiement.especes: 100000, ModePaiement.mobileMoney: 50000});
    });

    test('cas 10 et 11 — transferts : soldes déplacés, total inchangé, ni entrée ni sortie', () {
      final e = EtatFinances(
        paiements: [
          _paye('apport', 300000, _il(1), mode: ModePaiement.virement, nature: NaturePaiement.soldeInitial),
          // Boutique A → B
          _paye('t1-s', 100000, _il(0), sens: SensPaiement.sortie, mode: ModePaiement.virement, transfertId: 't1'),
          _paye('t1-e', 100000, _il(0), mode: ModePaiement.virement, site: 'b2', transfertId: 't1'),
          // Banque → Mobile Money (même boutique)
          _paye('t2-s', 50000, _il(0), sens: SensPaiement.sortie, mode: ModePaiement.virement, transfertId: 't2'),
          _paye('t2-e', 50000, _il(0), mode: ModePaiement.mobileMoney, transfertId: 't2'),
        ],
      );
      final r = jour(e);
      expect((r.entrees, r.sorties), (0, 0), reason: 'un transfert n\'est ni un revenu ni une dépense');
      expect(r.tresorerieTotale, 300000);
      expect(service.soldesParMode(e, perimetreId: 'b1'), containsPair(ModePaiement.virement, 150000));
      expect(service.soldesParMode(e, perimetreId: 'b1'), containsPair(ModePaiement.mobileMoney, 50000));
      expect(service.soldesParMode(e, perimetreId: 'b2'), containsPair(ModePaiement.virement, 100000));
      expect(service.origine(e, e.paiements[1]), OrigineMouvement.transfert);
    });

    test('opération annulée : sortie des totaux, mais toujours visible (barrée)', () {
      final e = EtatFinances(paiements: [
        _paye('p1', 30000, _il(0), nature: NaturePaiement.apport),
        Paiement(
          id: 'p1-inv',
          entrepriseId: entrepriseId,
          perimetreId: 'b1',
          sens: SensPaiement.sortie,
          montant: 30000,
          mode: ModePaiement.especes,
          datePaiement: _il(0, 11),
          annulePaiementId: 'p1',
          nature: NaturePaiement.apport,
        ),
      ]);
      expect(jour(e).entrees, 0);
      final historique = service.historique(e, filtre: FiltrePeriode.aujourdhui, maintenant: _maintenant);
      expect(historique.map((o) => (o.id, o.estAnnule || o.estAnnulation)), contains(('p1', true)));
    });
  });

  group('Soldes, comparaisons, alertes : jamais de faux chiffre', () {
    const caisse = Caisse(id: 'c1', entrepriseId: entrepriseId, perimetreId: 'b1', nom: 'Caisse A');

    test('caisse fermée : les espèces restent celles comptées à la clôture', () {
      final e = EtatFinances(caisses: [caisse], sessions: [
        SessionCaisse(
          id: 's1',
          entrepriseId: entrepriseId,
          caisseId: 'c1',
          perimetreId: 'b1',
          ouverte: false,
          soldeInitial: 0,
          ouverteLe: _il(1, 8),
          fermeeLe: _il(1, 19),
          soldeTheorique: 425000,
          soldeReel: 420000,
          ecart: -5000,
        ),
      ]);
      expect(service.soldeEspeces(e), 420000);
      final alertes = service.alertes(e, maintenant: _maintenant);
      expect(alertes.single.type, TypeAlerteTresorerie.ecartCaisse);
      expect(alertes.single.montant, -5000);
    });

    test('pas de pourcentage sans période comparable ; hausse des sorties > 35 % signalée', () {
      final sansBase = EtatFinances(paiements: [_paye('p1', 1000, _il(0), sens: SensPaiement.sortie, nature: NaturePaiement.autre)]);
      final c = service.comparaisonPeriode(sansBase, FiltrePeriode.cetteSemaine, maintenant: _maintenant)!;
      expect(c.evolutionSorties, isNull);
      expect(service.alertes(sansBase, maintenant: _maintenant), isEmpty);

      final hausse = EtatFinances(paiements: [
        _paye('avant', 10000, _il(7, 9), sens: SensPaiement.sortie, nature: NaturePaiement.autre),
        _paye('maintenant', 20000, _il(0, 9), sens: SensPaiement.sortie, nature: NaturePaiement.autre),
      ]);
      final a = service.alertes(hausse, maintenant: _maintenant).single;
      expect((a.type, a.pourcentage), (TypeAlerteTresorerie.sortiesEnHausse, 100));
    });

    test('évolution : le dernier point est le solde actuel, reconstruit depuis les mouvements', () {
      final e = EtatFinances(paiements: [
        _paye('p1', 50000, _il(2), mode: ModePaiement.mobileMoney, nature: NaturePaiement.apport),
        _paye('p2', 20000, _il(0), sens: SensPaiement.sortie, mode: ModePaiement.mobileMoney, nature: NaturePaiement.autre),
      ]);
      final points = service.evolution(e, 7, maintenant: _maintenant);
      expect(points.map((p) => p.solde), [0, 0, 0, 0, 50000, 50000, 30000]);
    });
  });

  group('Opérations de caisse (base locale, hors connexion)', () {
    final admin = contexte(perimetres: [perimetreJson('b1'), perimetreJson('b2')]);
    final superviseur = contexte(
      role: 'SUPERVISEUR',
      perimetres: [perimetreJson('b1')],
      permissions: {'cash.view', 'cash.open', 'cash.move', 'cash.close', 'payments.view', 'payments.create'},
    );
    late AppDatabase db;
    late DriftSyncQueueStore queue;
    late FinancesLocalDataSource local;
    late FinancesRepositoryImpl repo;
    late GererOperationsCaisse caisse;

    setUp(() {
      db = memoryDatabase();
      queue = DriftSyncQueueStore(db);
      local = FinancesLocalDataSource(db);
      repo = FinancesRepositoryImpl(local: local, queue: queue, currentUserId: () => userId, requestSync: () {});
      caisse = GererOperationsCaisse(repo, EnregistrerPaiement(repo));
    });
    tearDown(() => db.close());

    Future<EtatFinances> etat() => local.charger(entrepriseId);

    Future<SessionCaisse> caisseOuverte(String site, int fond) async {
      final g = GererCaisse(repo);
      final c = await g.creer(admin, perimetreId: site, nom: 'Caisse $site');
      return g.ouvrir(admin, await etat(), c, soldeInitial: fond);
    }

    test('apport en espèces : passe par la caisse ouverte, nature conservée', () async {
      await caisseOuverte('b1', 200000);
      final p = await caisse.ajouter(admin, await etat(),
          sens: SensPaiement.entree,
          nature: NaturePaiement.apport,
          montant: 100000,
          mode: ModePaiement.especes,
          motif: 'Apport du propriétaire',
          perimetreId: 'b1');
      final e = await etat();
      expect(e.solde(e.sessions.single), 300000);
      expect(service.origine(e, e.paiement(p.id)!), OrigineMouvement.apport);
    });

    test('transfert boutique → boutique : une seule opération envoyée, total inchangé', () async {
      await caisseOuverte('b1', 200000);
      await caisseOuverte('b2', 0);
      final avant = await queue.pendingCount(userId);
      final t = await caisse.transferer(admin, await etat(),
          montant: 100000,
          modeSource: ModePaiement.especes,
          modeDest: ModePaiement.especes,
          perimetreSourceId: 'b1',
          perimetreDestId: 'b2');

      expect(await queue.pendingCount(userId) - avant, 1, reason: 'deux jambes, une seule opération : jamais de demi-transfert');
      var e = await etat();
      expect(service.soldeEspeces(e, perimetreId: 'b1'), 100000);
      expect(service.soldeEspeces(e, perimetreId: 'b2'), 100000);
      expect(service.soldeEspeces(e), 200000);
      expect(service.resumePeriode(e, FiltrePeriode.aujourdhui).entrees, 0);

      // Une jambe ne s'annule pas seule ; le transfert s'annule d'un bloc, avec motif.
      await expectLater(AnnulerPaiement(repo).call(admin, e, e.paiement(t.entreeId)!), _regle(RuleCodes.transferLinked));
      await expectLater(caisse.annulerTransfert(admin, e, e.transfert(t.id)!, motif: ' '), _regle(RuleCodes.reasonRequired));
      await caisse.annulerTransfert(admin, e, e.transfert(t.id)!, motif: 'Mauvaise boutique');
      e = await etat();
      expect(service.soldeEspeces(e, perimetreId: 'b1'), 200000);
      expect(service.soldeEspeces(e, perimetreId: 'b2'), 0);
      expect(e.transfert(t.id)!.annule, isTrue);
    });

    test('transfert refusé avant envoi : espèces insuffisantes, source = destination', () async {
      await caisseOuverte('b1', 1000);
      await expectLater(
        caisse.transferer(admin, await etat(),
            montant: 5000, modeSource: ModePaiement.especes, modeDest: ModePaiement.virement, perimetreSourceId: 'b1'),
        _regle(RuleCodes.cashInsufficient),
      );
      await expectLater(
        caisse.transferer(admin, await etat(),
            montant: 1, modeSource: ModePaiement.virement, modeDest: ModePaiement.virement, perimetreSourceId: 'b1',
            perimetreDestId: 'b1'),
        _regle(RuleCodes.transferSame),
      );
    });

    test('droits : sans cash.transfer ni cash.adjust, ni transfert ni correction de solde', () async {
      await expectLater(
        caisse.transferer(superviseur, await etat(),
            montant: 1, modeSource: ModePaiement.virement, modeDest: ModePaiement.mobileMoney, perimetreSourceId: 'b1',
            perimetreDestId: 'b1'),
        throwsA(isA<Failure>()),
      );
      await expectLater(
        caisse.corriger(superviseur, await etat(),
            nature: NaturePaiement.soldeInitial,
            sens: SensPaiement.entree,
            montant: 275000,
            mode: ModePaiement.mobileMoney,
            motif: 'Solde Orange Money',
            perimetreId: 'b1'),
        throwsA(isA<Failure>()),
      );
      final p = await caisse.corriger(admin, await etat(),
          nature: NaturePaiement.soldeInitial,
          sens: SensPaiement.entree,
          montant: 275000,
          mode: ModePaiement.mobileMoney,
          motif: 'Solde Orange Money',
          perimetreId: 'b1');
      expect(service.soldesParMode(await etat())[ModePaiement.mobileMoney], 275000);
      expect(p.syncStatus, RecordSyncStatus.pendingSync, reason: 'visible tout de suite, envoyé plus tard');
    });
  });
}
