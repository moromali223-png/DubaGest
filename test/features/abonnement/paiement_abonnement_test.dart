import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dubagest/features/abonnement/domain/entities/abonnement.dart';
import 'package:dubagest/features/abonnement/domain/entities/paiement_abonnement.dart';
import 'package:dubagest/features/abonnement/data/adapters/payment_gateway_adapter.dart';
import 'package:dubagest/features/abonnement/presentation/providers/catalogue_plans_provider.dart';
import 'package:dubagest/features/abonnement/presentation/pages/choix_formule_page.dart';
import 'package:dubagest/features/abonnement/presentation/pages/paiement_abonnement_page.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/features/entreprise/domain/entities/entreprise.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/app/localization/generated/app_localizations.dart';

class _FakeContexteNotifier extends AsyncNotifier<ContexteSession?> {
  _FakeContexteNotifier(this._valeur);
  final ContexteSession _valeur;

  @override
  Future<ContexteSession?> build() async => _valeur;
}

void main() {
  final fakePlans = [
    PlanCatalogueItem(
      code: 'NORMAL',
      nom: 'Normal',
      description: '1 activité • 1 boutique • Jusqu\'à 3 utilisateurs',
      ordre: 1,
      prixMensuel: 1000,
      devise: 'XOF',
      maxActivites: 1,
      activites: const [
        {'activite_code': 'COMMERCE', 'activite_libelle': 'Commerce', 'max_utilisateurs': 3, 'max_perimetres': 1}
      ],
      roles: const [],
      modules: const ['commerce.stock', 'commerce.ventes', 'commerce.caisse'],
      tarifsDurees: const [
        TarifDureeItem(dureeMois: 1, montantTotal: 1000, remisePourcentage: 0),
        TarifDureeItem(dureeMois: 3, montantTotal: 3000, remisePourcentage: 0),
        TarifDureeItem(dureeMois: 6, montantTotal: 6000, remisePourcentage: 0),
        TarifDureeItem(dureeMois: 12, montantTotal: 10000, remisePourcentage: 17, badgePromo: '2 mois offerts'),
      ],
    ),
    PlanCatalogueItem(
      code: 'MOYEN',
      nom: 'Moyen',
      description: '2 activités • 2 boutiques • Jusqu\'à 7 utilisateurs',
      ordre: 2,
      prixMensuel: 2000,
      devise: 'XOF',
      maxActivites: 2,
      activites: const [
        {'activite_code': 'COMMERCE', 'activite_libelle': 'Commerce', 'max_utilisateurs': 7, 'max_perimetres': 2},
        {'activite_code': 'SERVICES', 'activite_libelle': 'Services', 'max_utilisateurs': 2, 'max_perimetres': 1},
      ],
      roles: const [],
      modules: const ['commerce.stock', 'commerce.ventes', 'services.prestations', 'commerce.intelligence'],
      tarifsDurees: const [
        TarifDureeItem(dureeMois: 1, montantTotal: 2000, remisePourcentage: 0),
        TarifDureeItem(dureeMois: 3, montantTotal: 6000, remisePourcentage: 0),
        TarifDureeItem(dureeMois: 6, montantTotal: 12000, remisePourcentage: 0),
        TarifDureeItem(dureeMois: 12, montantTotal: 20000, remisePourcentage: 17, badgePromo: '2 mois offerts'),
      ],
    ),
    PlanCatalogueItem(
      code: 'PRO',
      nom: 'Pro',
      description: 'Toutes activités • Boutiques et utilisateurs illimités',
      ordre: 3,
      prixMensuel: 5000,
      devise: 'XOF',
      maxActivites: 3,
      activites: const [
        {'activite_code': 'COMMERCE', 'activite_libelle': 'Commerce'},
        {'activite_code': 'SERVICES', 'activite_libelle': 'Services'},
        {'activite_code': 'IMMOBILIER', 'activite_libelle': 'Immobilier'},
      ],
      roles: const [],
      modules: const ['commerce.stock', 'services.prestations', 'immobilier.biens', 'commerce.intelligence'],
      tarifsDurees: const [
        TarifDureeItem(dureeMois: 1, montantTotal: 5000, remisePourcentage: 0),
        TarifDureeItem(dureeMois: 3, montantTotal: 15000, remisePourcentage: 0),
        TarifDureeItem(dureeMois: 6, montantTotal: 30000, remisePourcentage: 0),
        TarifDureeItem(dureeMois: 12, montantTotal: 50000, remisePourcentage: 17, badgePromo: '2 mois offerts'),
      ],
    ),
  ];

  final fakeContexte = ContexteSession(
    userId: 'usr-1',
    nomComplet: 'Admin Test',
    entreprises: const [
      EntrepriseResume(id: 'ent-1', nom: 'DubaTest SARL', statut: EntrepriseStatut.active),
    ],
    entreprise: const Entreprise(
      id: 'ent-1',
      nom: 'DubaTest SARL',
      statut: EntrepriseStatut.active,
      pays: 'BF',
      devise: 'XOF',
    ),
    membre: const Membre(id: 'mem-1', roleCode: 'ADMINISTRATEUR', estActif: true),
    permissions: const {'entreprise.manage', 'admin.abonnement'},
    abonnement: Abonnement(
      id: 'abo-1',
      planCode: 'NORMAL',
      statut: AbonnementStatut.essai,
      dateDebut: DateTime.now().subtract(const Duration(days: 2)),
      dateFin: DateTime.now().add(const Duration(days: 8)), // Reste 8 jours sur 10
      typeFacturation: 'COMMERCIAL',
    ),
    plan: const Plan(
      code: 'NORMAL',
      nom: 'Normal',
      maxActivites: 1,
      activites: {},
      quotasRoles: {},
      modules: {},
    ),
    activites: const [],
    roles: const {},
    modules: const [],
    perimetres: const [],
    consommation: ConsommationAbonnement.vide,
    chargeLe: DateTime.now(),
    depuisCache: false,
  );

  group('Architecture Abonnements, Tarifs et Prestataires', () {
    test('1. Modèle PrestatairePaiement contient Orange Money et LigdiCash', () {
      expect(PrestatairePaiement.orangeMoney.code, equals('ORANGE_MONEY'));
      expect(PrestatairePaiement.orangeMoney.nom, equals('Orange Money'));
      expect(PrestatairePaiement.ligdiCash.code, equals('LIGDICASH'));
      expect(PrestatairePaiement.ligdiCash.nom, equals('LigdiCash'));

      expect(PrestatairePaiement.fromCode('ORANGE_MONEY'), equals(PrestatairePaiement.orangeMoney));
      expect(PrestatairePaiement.fromCode('LIGDICASH'), equals(PrestatairePaiement.ligdiCash));
    });

    test('2. Modèle StatutTransactionAbonnement couvre les 5 états essentiels', () {
      expect(StatutTransactionAbonnement.enAttente.code, equals('EN_ATTENTE'));
      expect(StatutTransactionAbonnement.enCours.code, equals('EN_COURS'));
      expect(StatutTransactionAbonnement.confirme.code, equals('CONFIRME'));
      expect(StatutTransactionAbonnement.echoue.code, equals('ECHOUE'));
      expect(StatutTransactionAbonnement.annule.code, equals('ANNULE'));
    });

    test('3. Adaptateurs LigdiCash et Orange Money rapportent indisponible avant config API officielle', () async {
      final ligdiAdapter = LigdiCashGatewayAdapter();
      final orangeAdapter = OrangeMoneyGatewayAdapter();

      final dispoLigdi = await ligdiAdapter.verifierDisponibilite();
      expect(dispoLigdi.estConfigure, isFalse);
      expect(dispoLigdi.message, equals('Paiement en ligne bientôt disponible pour ce moyen de paiement.'));

      final dispoOrange = await orangeAdapter.verifierDisponibilite();
      expect(dispoOrange.estConfigure, isFalse);
      expect(dispoOrange.message, equals('Paiement en ligne bientôt disponible pour ce moyen de paiement.'));
    });

    test('4. Modèle TransactionAbonnement désérialise correctement les champs requis', () {
      final json = {
        'id': 'tx-1234',
        'entreprise_id': 'ent-5678',
        'user_id': 'usr-0001',
        'plan_code': 'PRO',
        'duree_mois': 3,
        'montant': 15000,
        'devise': 'XOF',
        'prestataire': 'ORANGE_MONEY',
        'reference_interne': 'DBG-ORANGE_MONEY-20261029-001',
        'statut': 'EN_ATTENTE',
        'est_demo': true,
        'diagnostic': {'source': 'test_unitaire'},
        'created_at': DateTime.now().toIso8601String(),
      };

      final tx = TransactionAbonnement.fromJson(json);
      expect(tx.id, equals('tx-1234'));
      expect(tx.entrepriseId, equals('ent-5678'));
      expect(tx.planCode, equals('PRO'));
      expect(tx.dureeMois, equals(3));
      expect(tx.montant, equals(15000));
      expect(tx.devise, equals('XOF'));
      expect(tx.prestataire, equals(PrestatairePaiement.orangeMoney));
      expect(tx.statut, equals(StatutTransactionAbonnement.enAttente));
      expect(tx.estDemo, isTrue);
    });

    test('5. Modèle HistoriqueRenouvellementItem désérialise correctement les champs', () {
      final json = {
        'id': 'ren-001',
        'type_operation': 'RENOUVELLEMENT',
        'ancien_plan_code': 'NORMAL',
        'nouveau_plan_code': 'MOYEN',
        'duree_mois': 12,
        'montant': 20000,
        'devise': 'XOF',
        'prestataire': 'ORANGE_MONEY',
        'nouvelle_date_fin': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final item = HistoriqueRenouvellementItem.fromJson(json);
      expect(item.id, equals('ren-001'));
      expect(item.typeOperation, equals('RENOUVELLEMENT'));
      expect(item.typeOperationLisible, equals('Renouvellement'));
      expect(item.nouveauPlanCode, equals('MOYEN'));
      expect(item.montant, equals(20000));
    });

    test('6. PlanCatalogueItem calcule correctement les montants des durées avec promotion 12 mois', () {
      final planNormal = fakePlans.first;
      expect(planNormal.tarifPour(1).montantTotal, equals(1000));
      expect(planNormal.tarifPour(3).montantTotal, equals(3000));
      expect(planNormal.tarifPour(6).montantTotal, equals(6000));
      expect(planNormal.tarifPour(12).montantTotal, equals(10000)); // 2 mois offerts !
      expect(planNormal.tarifPour(12).remisePourcentage, equals(17));
    });
  });

  group('Widget Tests : PAGE 1 (ChoixFormulePage)', () {
    testWidgets('7. Affiche les 3 formules, les quotas, les modules et le bouton de validation sans paiement', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contexteSessionProvider.overrideWith(() => _FakeContexteNotifier(fakeContexte)),
            cataloguePlansProvider.overrideWith((ref) async => fakePlans),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChoixFormulePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Titre de la page
      expect(find.text('Formules d\'abonnement DubaGest'), findsOneWidget);

      // Présence des 3 formules
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Moyen'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);

      // Présence des prix de référence
      expect(find.textContaining('1 000'), findsWidgets);
      expect(find.textContaining('2 000'), findsWidgets);
      expect(find.textContaining('5 000'), findsWidgets);

      // Présence des quotas
      expect(find.text('3 utilisateur(s) inclus'), findsOneWidget);
      expect(find.text('7 utilisateur(s) inclus'), findsOneWidget);
      expect(find.text('Utilisateurs illimités'), findsOneWidget);

      // Bouton de validation (ne déclenche aucun paiement)
      expect(find.textContaining('Valider et passer au règlement'), findsOneWidget);
      expect(find.textContaining('Aucun prélèvement ne sera effectué sur cette page'), findsOneWidget);
    });
  });

  group('Widget Tests : PAGE 2 (PaiementAbonnementPage & ReactivezCompteBottomSheet)', () {
    testWidgets('8. Affiche l\'écran de réactivation fidèle aux maquettes avec choix des durées (3, 6, 12 mois)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contexteSessionProvider.overrideWith(() => _FakeContexteNotifier(fakeContexte)),
            cataloguePlansProvider.overrideWith((ref) async => fakePlans),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PaiementAbonnementPage(initialPlanCode: 'NORMAL'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Titre et onglets
      expect(find.text('Règlement de l\'abonnement'), findsOneWidget);
      expect(find.text('Souscrire / Renouveler'), findsOneWidget);
      expect(find.text('Historique des paiements'), findsOneWidget);

      // Titre principal de réactivation fidèle à l'Image 1 & 2
      expect(find.textContaining('Réactivez votre compte'), findsOneWidget);
      expect(find.textContaining('Votre accès a pris fin'), findsOneWidget);

      // Durées disponibles avec le design de cartes et badges de l'Image 2
      expect(find.text('3 mois'), findsOneWidget);
      expect(find.text('6 mois'), findsOneWidget);
      expect(find.text('12 mois'), findsOneWidget);
      expect(find.text('1 mois'), findsOneWidget);

      // Badges de packs
      expect(find.text('Pack Trimestriel'), findsOneWidget);
      expect(find.text('Pack Semestriel'), findsOneWidget);
      expect(find.text('Pack Annuel'), findsOneWidget);

      // Boutons d'action Image 2
      expect(find.text('Continuer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });
  });
}
