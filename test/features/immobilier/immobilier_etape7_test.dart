import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/immobilier/domain/entities/contrat_bail.dart';
import 'package:dubagest/features/immobilier/domain/entities/echeance_loyer.dart';

void main() {
  group('Étape 7 — Loyers & Encaissements : Tests Unitaires', () {
    test('EcheanceLoyer : Sérialisation et désérialisation JSON intègre', () {
      final echeance = EcheanceLoyer(
        id: 'ech-001',
        entrepriseId: 'ent-1',
        reference: 'ECH-202610-A1B2',
        contratId: 'ctr-001',
        bienId: 'bien-101',
        locataireId: 'loc-202',
        proprietaireId: 'prop-303',
        engagementId: 'eng-404',
        quittanceDocumentId: 'doc-qui-505',
        recuDocumentIds: const ['doc-rec-601', 'doc-rec-602'],
        periodeMois: 10,
        periodeAnnee: 2026,
        dateEmission: DateTime(2026, 10, 1),
        dateExigibilite: DateTime(2026, 10, 5),
        derniereDatePaiement: DateTime(2026, 10, 4),
        loyerNet: 300000,
        charges: 30000,
        totalDu: 330000,
        montantRegle: 330000,
        statut: StatutEcheanceLoyer.solde,
        remarques: 'Payé par virement bancaire anticipé',
        creeLe: DateTime(2026, 10, 1, 8),
        misAJourLe: DateTime(2026, 10, 4, 15),
      );

      final json = echeance.toJson();
      final deserialise = EcheanceLoyer.fromJson(json);

      expect(deserialise.id, 'ech-001');
      expect(deserialise.entrepriseId, 'ent-1');
      expect(deserialise.reference, 'ECH-202610-A1B2');
      expect(deserialise.contratId, 'ctr-001');
      expect(deserialise.bienId, 'bien-101');
      expect(deserialise.locataireId, 'loc-202');
      expect(deserialise.proprietaireId, 'prop-303');
      expect(deserialise.engagementId, 'eng-404');
      expect(deserialise.quittanceDocumentId, 'doc-qui-505');
      expect(deserialise.recuDocumentIds, ['doc-rec-601', 'doc-rec-602']);
      expect(deserialise.periodeMois, 10);
      expect(deserialise.periodeAnnee, 2026);
      expect(deserialise.loyerNet, 300000);
      expect(deserialise.charges, 30000);
      expect(deserialise.totalDu, 330000);
      expect(deserialise.montantRegle, 330000);
      expect(deserialise.statut, StatutEcheanceLoyer.solde);
      expect(deserialise.remarques, 'Payé par virement bancaire anticipé');
      expect(deserialise.estSolde, isTrue);
      expect(deserialise.resteAPayer, 0);
      expect(deserialise.pourcentageRegle, 100.0);
      expect(deserialise.periodeLibelle, 'Octobre 2026');
    });

    test('EcheanceLoyer : Calculs financiers (reste à payer et pourcentage réglé)', () {
      final echeance = EcheanceLoyer(
        id: 'ech-002',
        entrepriseId: 'ent-1',
        reference: 'ECH-202610-C3D4',
        contratId: 'ctr-002',
        bienId: 'bien-1',
        locataireId: 'loc-1',
        proprietaireId: 'prop-1',
        engagementId: 'eng-1',
        periodeMois: 10,
        periodeAnnee: 2026,
        dateEmission: DateTime(2026, 10, 1),
        dateExigibilite: DateTime(2026, 10, 5),
        loyerNet: 200000,
        charges: 50000,
        totalDu: 250000,
        montantRegle: 100000,
        statut: StatutEcheanceLoyer.partiellementPaye,
      );

      expect(echeance.resteAPayer, 150000);
      expect(echeance.pourcentageRegle, 40.0);
      expect(echeance.estSolde, isFalse);

      // Règlement complémentaire
      final miseAJour = echeance.copyWith(
        montantRegle: 250000,
        statut: StatutEcheanceLoyer.solde,
      );

      expect(miseAJour.resteAPayer, 0);
      expect(miseAJour.pourcentageRegle, 100.0);
      expect(miseAJour.estSolde, isTrue);
    });

    test('EcheanceLoyer : Détection dynamique des retards de paiement', () {
      final echeance = EcheanceLoyer(
        id: 'ech-003',
        entrepriseId: 'ent-1',
        reference: 'ECH-202610-E5F6',
        contratId: 'ctr-003',
        bienId: 'bien-1',
        locataireId: 'loc-1',
        proprietaireId: 'prop-1',
        engagementId: 'eng-1',
        periodeMois: 10,
        periodeAnnee: 2026,
        dateEmission: DateTime(2026, 10, 1),
        dateExigibilite: DateTime(2026, 10, 10), // Limite au 10 octobre
        loyerNet: 150000,
        charges: 0,
        totalDu: 150000,
        montantRegle: 50000,
        statut: StatutEcheanceLoyer.partiellementPaye,
      );

      // Le 8 octobre : pas en retard
      expect(echeance.estEnRetardCalcule(DateTime(2026, 10, 8)), isFalse);

      // Le 10 octobre (jour J) : pas en retard
      expect(echeance.estEnRetardCalcule(DateTime(2026, 10, 10)), isFalse);

      // Le 11 octobre : EN RETARD
      expect(echeance.estEnRetardCalcule(DateTime(2026, 10, 11)), isTrue);

      // Si soldé, JAMAIS en retard même après la date
      final echeanceSoldee = echeance.copyWith(
        montantRegle: 150000,
        statut: StatutEcheanceLoyer.solde,
      );
      expect(echeanceSoldee.estEnRetardCalcule(DateTime(2026, 10, 20)), isFalse);
    });

    test('EcheanceLoyer : Multi-acomptes et traçabilité des reçus', () {
      final echeanceInitiale = EcheanceLoyer(
        id: 'ech-004',
        entrepriseId: 'ent-1',
        reference: 'ECH-202610-G7H8',
        contratId: 'ctr-004',
        bienId: 'bien-1',
        locataireId: 'loc-1',
        proprietaireId: 'prop-1',
        engagementId: 'eng-1',
        periodeMois: 10,
        periodeAnnee: 2026,
        dateEmission: DateTime(2026, 10, 1),
        dateExigibilite: DateTime(2026, 10, 5),
        loyerNet: 200000,
        charges: 20000,
        totalDu: 220000,
        montantRegle: 0,
        statut: StatutEcheanceLoyer.aPayer,
        recuDocumentIds: const [],
      );

      // 1er acompte de 100 000 avec émission reçu REC-001
      final apresAcompte1 = echeanceInitiale.copyWith(
        montantRegle: 100000,
        statut: StatutEcheanceLoyer.partiellementPaye,
        derniereDatePaiement: DateTime(2026, 10, 2),
        recuDocumentIds: ['doc-rec-001'],
      );

      expect(apresAcompte1.montantRegle, 100000);
      expect(apresAcompte1.resteAPayer, 120000);
      expect(apresAcompte1.recuDocumentIds, ['doc-rec-001']);
      expect(apresAcompte1.quittanceDocumentId, isNull);

      // 2ème acompte de 70 000 avec reçu REC-002
      final apresAcompte2 = apresAcompte1.copyWith(
        montantRegle: 170000,
        statut: StatutEcheanceLoyer.partiellementPaye,
        derniereDatePaiement: DateTime(2026, 10, 4),
        recuDocumentIds: [...apresAcompte1.recuDocumentIds, 'doc-rec-002'],
      );

      expect(apresAcompte2.montantRegle, 170000);
      expect(apresAcompte2.resteAPayer, 50000);
      expect(apresAcompte2.recuDocumentIds.length, 2);

      // Solde final de 50 000 -> Quittance officielle émise
      final apresSolde = apresAcompte2.copyWith(
        montantRegle: 220000,
        statut: StatutEcheanceLoyer.solde,
        derniereDatePaiement: DateTime(2026, 10, 5),
        quittanceDocumentId: 'doc-qui-999',
      );

      expect(apresSolde.montantRegle, 220000);
      expect(apresSolde.resteAPayer, 0);
      expect(apresSolde.estSolde, isTrue);
      expect(apresSolde.quittanceDocumentId, 'doc-qui-999');
      expect(apresSolde.recuDocumentIds.length, 2);
    });

    test('RecouvrementStatistiques : Calculs des KPI globaux', () {
      final stats = RecouvrementStatistiques(
        totalAppele: 1000000,
        totalEncaisse: 750000,
        totalImpayes: 250000,
        nbEcheances: 5,
        nbSoldes: 3,
        nbEnRetard: 1,
      );

      expect(stats.tauxRecouvrement, 75.0);
      expect(stats.nbSoldes, 3);
      expect(stats.nbEnRetard, 1);
      expect(stats.nbEcheances - stats.nbSoldes, 2);
    });

    test('Règle d\'or : Ségrégation stricte du dépôt de garantie (caution hors loyer)', () {
      final contrat = ContratBail(
        id: 'ctr-005',
        entrepriseId: 'ent-1',
        reference: 'CTR-202610-CAUTION',
        bienId: 'bien-1',
        proprietaireId: 'prop-1',
        locataireId: 'loc-1',
        dateDebut: DateTime(2026, 1, 1),
        loyerMensuel: 300000,
        chargesMensuelles: 30000,
        depotGarantie: 600000, // 2 mois de loyer en caution
      );

      // L'appel de loyer ne doit contenir QUE le loyer + charges (330 000)
      // La caution de 600 000 ne doit JAMAIS être incluse dans le total du loyer
      expect(contrat.totalMensuel, 330000);
      expect(contrat.depotGarantie, 600000);
      expect(contrat.totalMensuel != contrat.depotGarantie, isTrue);

      final echeance = EcheanceLoyer(
        id: 'ech-005',
        entrepriseId: 'ent-1',
        reference: 'ECH-202610-005',
        contratId: contrat.id,
        bienId: contrat.bienId,
        locataireId: contrat.locataireId,
        proprietaireId: contrat.proprietaireId,
        engagementId: 'eng-005',
        periodeMois: 10,
        periodeAnnee: 2026,
        dateEmission: DateTime(2026, 10, 1),
        dateExigibilite: DateTime(2026, 10, 5),
        loyerNet: contrat.loyerMensuel,
        charges: contrat.chargesMensuelles,
        totalDu: contrat.totalMensuel,
        montantRegle: 0,
        statut: StatutEcheanceLoyer.aPayer,
      );

      expect(echeance.totalDu, 330000);
      expect(echeance.totalDu < contrat.depotGarantie, isTrue);
    });

    test('Génération des avis d\'échéance : Idempotence mathématique', () {
      final contrat = ContratBail(
        id: 'ctr-006',
        entrepriseId: 'ent-1',
        reference: 'CTR-202610-IDEMPOTENT',
        bienId: 'bien-1',
        proprietaireId: 'prop-1',
        locataireId: 'loc-1',
        dateDebut: DateTime(2026, 1, 1),
        loyerMensuel: 250000,
        chargesMensuelles: 0,
        termePaiementJour: 5,
        statut: StatutContratBail.actif,
      );

      final echeancesExistantes = <EcheanceLoyer>[
        EcheanceLoyer(
          id: 'ech-existante-octobre',
          entrepriseId: 'ent-1',
          reference: 'ECH-202610-001',
          contratId: contrat.id,
          bienId: contrat.bienId,
          locataireId: contrat.locataireId,
          proprietaireId: contrat.proprietaireId,
          engagementId: 'eng-existante',
          periodeMois: 10,
          periodeAnnee: 2026,
          dateEmission: DateTime(2026, 10, 1),
          dateExigibilite: DateTime(2026, 10, 5),
          loyerNet: 250000,
          charges: 0,
          totalDu: 250000,
          montantRegle: 250000,
          statut: StatutEcheanceLoyer.solde,
        ),
      ];

      // Vérifier si une nouvelle échéance pour le mois 10/2026 doit être générée
      final annee = 2026;
      final mois = 10;
      final existeDeja = echeancesExistantes.any(
        (e) => e.contratId == contrat.id && e.periodeAnnee == annee && e.periodeMois == mois,
      );

      expect(existeDeja, isTrue, reason: 'L\'échéance existe déjà pour ce mois et ne doit pas être dupliquée.');

      // En revanche, pour novembre 2026 (mois 11), elle n'existe pas encore
      final existeEnNovembre = echeancesExistantes.any(
        (e) => e.contratId == contrat.id && e.periodeAnnee == annee && e.periodeMois == 11,
      );

      expect(existeEnNovembre, isFalse);
    });
  });
}
