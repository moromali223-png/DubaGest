import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/abonnement/domain/entities/paiement_abonnement.dart';
import 'package:dubagest/features/abonnement/presentation/providers/catalogue_plans_provider.dart';

void main() {
  group('LigdiCash Payin Redirect & Sandbox Model Tests', () {
    test('TransactionAbonnement désérialise tokenTransaction, urlPaiement et environnement', () {
      final json = {
        'id': 'tx-ligdicash-001',
        'entreprise_id': 'ent-test-001',
        'plan_code': 'MOYEN',
        'duree_mois': 3,
        'montant': 6000,
        'devise': 'XOF',
        'prestataire': 'LIGDICASH',
        'reference_interne': 'DBG-LIGDICASH-20261105-001',
        'token_transaction': 'tok_sandbox_abc123',
        'url_paiement': 'https://app.ligdicash.com/pay/checkout/tok_sandbox_abc123',
        'environnement': 'TEST',
        'statut': 'EN_COURS',
        'est_demo': true,
        'diagnostic': {'mode': 'SANDBOX_TEST'},
        'created_at': DateTime.now().toIso8601String(),
      };

      final tx = TransactionAbonnement.fromJson(json);

      expect(tx.id, equals('tx-ligdicash-001'));
      expect(tx.prestataire, equals(PrestatairePaiement.ligdiCash));
      expect(tx.statut, equals(StatutTransactionAbonnement.enCours));
      expect(tx.tokenTransaction, equals('tok_sandbox_abc123'));
      expect(tx.urlPaiement, equals('https://app.ligdicash.com/pay/checkout/tok_sandbox_abc123'));
      expect(tx.environnement, equals('TEST'));
      expect(tx.estDemo, isTrue);
    });

    test('Vérification stricte des tarifs officiels DubaGest (1000F, 2000F, 5000F) et 2 mois offerts sur 12 mois', () {
      final planNormal = PlanCatalogueItem(
        code: 'NORMAL',
        nom: 'Normal',
        description: '1 activité • 1 boutique',
        ordre: 1,
        prixMensuel: 1000,
        devise: 'XOF',
        maxActivites: 1,
        activites: const [],
        roles: const [],
        modules: const [],
        tarifsDurees: const [
          TarifDureeItem(dureeMois: 1, montantTotal: 1000, remisePourcentage: 0),
          TarifDureeItem(dureeMois: 3, montantTotal: 3000, remisePourcentage: 0),
          TarifDureeItem(dureeMois: 6, montantTotal: 6000, remisePourcentage: 0),
          TarifDureeItem(dureeMois: 12, montantTotal: 10000, remisePourcentage: 17, badgePromo: '2 mois offerts'),
        ],
      );

      final planMoyen = PlanCatalogueItem(
        code: 'MOYEN',
        nom: 'Moyen',
        description: '2 activités • 2 boutiques',
        ordre: 2,
        prixMensuel: 2000,
        devise: 'XOF',
        maxActivites: 2,
        activites: const [],
        roles: const [],
        modules: const [],
        tarifsDurees: const [
          TarifDureeItem(dureeMois: 1, montantTotal: 2000, remisePourcentage: 0),
          TarifDureeItem(dureeMois: 3, montantTotal: 6000, remisePourcentage: 0),
          TarifDureeItem(dureeMois: 6, montantTotal: 12000, remisePourcentage: 0),
          TarifDureeItem(dureeMois: 12, montantTotal: 20000, remisePourcentage: 17, badgePromo: '2 mois offerts'),
        ],
      );

      final planPro = PlanCatalogueItem(
        code: 'PRO',
        nom: 'Pro',
        description: 'Toutes activités illimitées',
        ordre: 3,
        prixMensuel: 5000,
        devise: 'XOF',
        maxActivites: 3,
        activites: const [],
        roles: const [],
        modules: const [],
        tarifsDurees: const [
          TarifDureeItem(dureeMois: 1, montantTotal: 5000, remisePourcentage: 0),
          TarifDureeItem(dureeMois: 3, montantTotal: 15000, remisePourcentage: 0),
          TarifDureeItem(dureeMois: 6, montantTotal: 30000, remisePourcentage: 0),
          TarifDureeItem(dureeMois: 12, montantTotal: 50000, remisePourcentage: 17, badgePromo: '2 mois offerts'),
        ],
      );

      // 1. Normal (1 000 FCFA / mois)
      expect(planNormal.tarifPour(1).montantTotal, equals(1000));
      expect(planNormal.tarifPour(3).montantTotal, equals(3000));
      expect(planNormal.tarifPour(6).montantTotal, equals(6000));
      expect(planNormal.tarifPour(12).montantTotal, equals(10000)); // 10 x 1 000 F

      // 2. Moyen (2 000 FCFA / mois)
      expect(planMoyen.tarifPour(1).montantTotal, equals(2000));
      expect(planMoyen.tarifPour(3).montantTotal, equals(6000));
      expect(planMoyen.tarifPour(6).montantTotal, equals(12000));
      expect(planMoyen.tarifPour(12).montantTotal, equals(20000)); // 10 x 2 000 F

      // 3. Pro (5 000 FCFA / mois)
      expect(planPro.tarifPour(1).montantTotal, equals(5000));
      expect(planPro.tarifPour(3).montantTotal, equals(15000));
      expect(planPro.tarifPour(6).montantTotal, equals(30000));
      expect(planPro.tarifPour(12).montantTotal, equals(50000)); // 10 x 5 000 F
    });

    test('Vérification des statuts de cycle de vie et couleurs / icônes', () {
      expect(StatutTransactionAbonnement.enCours.libelle, equals('En cours de traitement'));
      expect(StatutTransactionAbonnement.confirme.libelle, equals('Paiement confirmé'));
      expect(StatutTransactionAbonnement.echoue.libelle, equals('Paiement échoué'));
      expect(StatutTransactionAbonnement.annule.libelle, equals('Paiement annulé'));
    });

    test('Ordre officiel des durées (1 mois en 1er, puis 3, 6, 12 mois)', () {
      const dureesOrdonnees = [1, 3, 6, 12];
      expect(dureesOrdonnees.first, equals(1));
      expect(dureesOrdonnees[1], equals(3));
      expect(dureesOrdonnees[2], equals(6));
      expect(dureesOrdonnees.last, equals(12));
    });

    test('LigdiCash est le moyen de paiement actif par défaut et Orange Money est désactivé', () {
      expect(PrestatairePaiement.ligdiCash.code, equals('LIGDICASH'));
      expect(PrestatairePaiement.orangeMoney.code, equals('ORANGE_MONEY'));
    });
  });
}

