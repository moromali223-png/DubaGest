import 'package:dubagest/app/localization/l10n.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/finances/domain/entities/dossier_dette.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/domain/services/calcul_dossiers_dettes.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/presentation/providers/finances_providers.dart';
import 'package:dubagest/features/finances/presentation/widgets/carte_dossier_dette.dart';
import 'package:dubagest/features/finances/presentation/widgets/dettes_vue_principale.dart';
import 'package:dubagest/features/finances/presentation/widgets/finances_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalculDossiersDettes - Consolidation & Règles Métier', () {
    final now = DateTime(2026, 11, 10, 10, 0);

    const contactAmadou = Contact(
      id: 'c_amadou_1',
      entrepriseId: 'ent_1',
      nom: 'Amadou Traoré',
      telephone: '+223 70 00 00 01',
      relations: {RelationContact.client},
      syncStatus: RecordSyncStatus.synced,
    );

    const contactAmadouHomonyme = Contact(
      id: 'c_amadou_2',
      entrepriseId: 'ent_1',
      nom: 'Amadou Traoré',
      telephone: '+223 70 00 00 02',
      relations: {RelationContact.client},
      syncStatus: RecordSyncStatus.synced,
    );

    const contactFournisseur = Contact(
      id: 'c_fournisseur_1',
      entrepriseId: 'ent_1',
      nom: 'Boutique Alpha Fournisseur',
      telephone: '+223 70 00 00 03',
      relations: {RelationContact.fournisseur},
      syncStatus: RecordSyncStatus.synced,
    );

    final Map<String, Contact> contactsMap = {
      'c_amadou_1': contactAmadou,
      'c_amadou_2': contactAmadouHomonyme,
      'c_fournisseur_1': contactFournisseur,
    };

    test('1. Client avec une seule dette -> 1 seul dossier consolidé', () {
      final eng1 = Engagement(
        id: 'eng_1',
        entrepriseId: 'ent_1',
        sens: SensEngagement.aRecevoir,
        libelle: 'Vente Marchandise #001',
        montantTotal: 100000,
        dateEngagement: DateTime(2026, 11, 1),
        echeance: DateTime(2026, 11, 15),
        contactId: 'c_amadou_1',
        syncStatus: RecordSyncStatus.synced,
      );

      final etat = EtatFinances(
        engagements: [eng1],
        paiements: const [],
      );

      final dossiers = CalculDossiersDettes.consolider(
        etat: etat,
        contacts: contactsMap,
        sens: SensEngagement.aRecevoir,
        maintenant: now,
      );

      expect(dossiers.length, 1);
      final d = dossiers.first;
      expect(d.contactId, 'c_amadou_1');
      expect(d.nomAffiche, 'Amadou Traoré');
      expect(d.totalDu, 100000);
      expect(d.totalPaye, 0);
      expect(d.reste, 100000);
      expect(d.nbDettesActives, 1);
      expect(d.statutGlobal, StatutDossierDette.bientot); // 15 nov est à 5 jours de now (10 nov)
    });

    test('2. Client avec 3 dettes -> 1 SEUL dossier consolidé avec la somme totale', () {
      final eng1 = Engagement(
        id: 'eng_1',
        entrepriseId: 'ent_1',
        sens: SensEngagement.aRecevoir,
        libelle: 'Vente #REC-001',
        montantTotal: 30000,
        dateEngagement: DateTime(2026, 11, 1),
        echeance: DateTime(2026, 11, 12),
        contactId: 'c_amadou_1',
        syncStatus: RecordSyncStatus.synced,
      );

      final eng2 = Engagement(
        id: 'eng_2',
        entrepriseId: 'ent_1',
        sens: SensEngagement.aRecevoir,
        libelle: 'Vente #REC-002',
        montantTotal: 50000,
        dateEngagement: DateTime(2026, 11, 2),
        echeance: DateTime(2026, 11, 20),
        contactId: 'c_amadou_1',
        syncStatus: RecordSyncStatus.synced,
      );

      final eng3 = Engagement(
        id: 'eng_3',
        entrepriseId: 'ent_1',
        sens: SensEngagement.aRecevoir,
        libelle: 'Vente #REC-003',
        montantTotal: 20000,
        dateEngagement: DateTime(2026, 11, 3),
        echeance: DateTime(2026, 11, 25),
        contactId: 'c_amadou_1',
        syncStatus: RecordSyncStatus.synced,
      );

      final etat = EtatFinances(
        engagements: [eng1, eng2, eng3],
        paiements: const [],
      );

      final dossiers = CalculDossiersDettes.consolider(
        etat: etat,
        contacts: contactsMap,
        sens: SensEngagement.aRecevoir,
        maintenant: now,
      );

      expect(dossiers.length, 1);
      final d = dossiers.first;
      expect(d.totalDu, 100000);
      expect(d.reste, 100000);
      expect(d.nbDettesActives, 3);
      expect(d.engagements.length, 3);
      expect(d.echeances.length, 3);
      expect(d.prochaineEcheance, DateTime(2026, 11, 12));
    });

    test('3. Ne JAMAIS fusionner deux personnes ayant le même nom mais des IDs différents', () {
      final eng1 = Engagement(
        id: 'eng_1',
        entrepriseId: 'ent_1',
        sens: SensEngagement.aRecevoir,
        libelle: 'Vente 1',
        montantTotal: 50000,
        dateEngagement: DateTime(2026, 11, 1),
        contactId: 'c_amadou_1',
        syncStatus: RecordSyncStatus.synced,
      );

      final eng2 = Engagement(
        id: 'eng_2',
        entrepriseId: 'ent_1',
        sens: SensEngagement.aRecevoir,
        libelle: 'Vente 2',
        montantTotal: 75000,
        dateEngagement: DateTime(2026, 11, 2),
        contactId: 'c_amadou_2',
        syncStatus: RecordSyncStatus.synced,
      );

      final etat = EtatFinances(
        engagements: [eng1, eng2],
        paiements: const [],
      );

      final dossiers = CalculDossiersDettes.consolider(
        etat: etat,
        contacts: contactsMap,
        sens: SensEngagement.aRecevoir,
        maintenant: now,
      );

      expect(dossiers.length, 2);
      expect(dossiers.map((d) => d.contactId).toSet(), {'c_amadou_1', 'c_amadou_2'});
      expect(dossiers.firstWhere((d) => d.contactId == 'c_amadou_1').reste, 50000);
      expect(dossiers.firstWhere((d) => d.contactId == 'c_amadou_2').reste, 75000);
    });

    test('4. Paiement partiel et calcul de solde restant + Timeline', () {
      final eng1 = Engagement(
        id: 'eng_1',
        entrepriseId: 'ent_1',
        sens: SensEngagement.aRecevoir,
        libelle: 'Vente #REC-001',
        montantTotal: 100000,
        montantRegle: 30000,
        dateEngagement: DateTime(2026, 11, 1),
        echeance: DateTime(2026, 11, 20),
        contactId: 'c_amadou_1',
        syncStatus: RecordSyncStatus.synced,
      );

      final pay1 = Paiement(
        id: 'pay_1',
        entrepriseId: 'ent_1',
        sens: SensPaiement.entree,
        mode: ModePaiement.mobileMoney,
        montant: 30000,
        datePaiement: DateTime(2026, 11, 5),
        contactId: 'c_amadou_1',
        affectations: const [Affectation(id: 'aff_1', engagementId: 'eng_1', montant: 30000)],
        syncStatus: RecordSyncStatus.synced,
      );

      final etat = EtatFinances(
        engagements: [eng1],
        paiements: [pay1],
      );

      final dossiers = CalculDossiersDettes.consolider(
        etat: etat,
        contacts: contactsMap,
        sens: SensEngagement.aRecevoir,
        maintenant: now,
      );

      final d = dossiers.first;
      expect(d.totalDu, 100000);
      expect(d.totalPaye, 30000);
      expect(d.reste, 70000);
      expect(d.tauxReglement, 30.0);
      expect(d.timeline.length, 2);
      expect(d.timeline.first.soldeProgressif, 70000); // Most recent event is pay1
      expect(d.timeline.last.soldeProgressif, 100000); // First event is debt creation
    });

    test('5. Dette en retard -> Statut enRetard et calcul des jours de retard', () {
      final eng1 = Engagement(
        id: 'eng_1',
        entrepriseId: 'ent_1',
        sens: SensEngagement.aRecevoir,
        libelle: 'Vente en retard',
        montantTotal: 50000,
        dateEngagement: DateTime(2026, 10, 20),
        echeance: DateTime(2026, 11, 5), // Past date vs 10 nov
        contactId: 'c_amadou_1',
        syncStatus: RecordSyncStatus.synced,
      );

      final etat = EtatFinances(
        engagements: [eng1],
        paiements: const [],
      );

      final dossiers = CalculDossiersDettes.consolider(
        etat: etat,
        contacts: contactsMap,
        sens: SensEngagement.aRecevoir,
        maintenant: now,
      );

      final d = dossiers.first;
      expect(d.estEnRetard, isTrue);
      expect(d.totalEnRetard, 50000);
      expect(d.nbEcheancesEnRetard, 1);
      expect(d.statutGlobal, StatutDossierDette.enRetard);
      expect(d.echeances.first.retardJours, 5); // 10 nov - 5 nov = 5 days
    });

    test('6. Paiement complet -> Dossier réglé', () {
      final eng1 = Engagement(
        id: 'eng_1',
        entrepriseId: 'ent_1',
        sens: SensEngagement.aRecevoir,
        libelle: 'Vente réglée',
        montantTotal: 50000,
        montantRegle: 50000,
        dateEngagement: DateTime(2026, 11, 1),
        contactId: 'c_amadou_1',
        syncStatus: RecordSyncStatus.synced,
      );

      final pay1 = Paiement(
        id: 'pay_1',
        entrepriseId: 'ent_1',
        sens: SensPaiement.entree,
        mode: ModePaiement.especes,
        montant: 50000,
        datePaiement: DateTime(2026, 11, 6),
        contactId: 'c_amadou_1',
        affectations: const [Affectation(id: 'aff_1', engagementId: 'eng_1', montant: 50000)],
        syncStatus: RecordSyncStatus.synced,
      );

      final etat = EtatFinances(
        engagements: [eng1],
        paiements: [pay1],
      );

      final dossiers = CalculDossiersDettes.consolider(
        etat: etat,
        contacts: contactsMap,
        sens: SensEngagement.aRecevoir,
        maintenant: now,
      );

      final d = dossiers.first;
      expect(d.reste, 0);
      expect(d.estSolde, isTrue);
      expect(d.statutGlobal, StatutDossierDette.regle);
      expect(d.tauxReglement, 100.0);
    });

    test('7. Dépense non payée -> apparaît dans les dettes (À payer) du fournisseur', () {
      final engDepense = Engagement(
        id: 'dep_1',
        entrepriseId: 'ent_1',
        sens: SensEngagement.aPayer,
        libelle: 'Achat consommables bureau',
        montantTotal: 45000,
        dateEngagement: DateTime(2026, 11, 2),
        echeance: DateTime(2026, 11, 25),
        contactId: 'c_fournisseur_1',
        origineType: 'DEPENSE',
        syncStatus: RecordSyncStatus.synced,
      );

      final etat = EtatFinances(
        engagements: [engDepense],
        paiements: const [],
      );

      final dossiers = CalculDossiersDettes.consolider(
        etat: etat,
        contacts: contactsMap,
        sens: SensEngagement.aPayer,
        maintenant: now,
      );

      expect(dossiers.length, 1);
      final d = dossiers.first;
      expect(d.contactId, 'c_fournisseur_1');
      expect(d.nomAffiche, 'Boutique Alpha Fournisseur');
      expect(d.totalDu, 45000);
      expect(d.reste, 45000);
      expect(d.sens, SensEngagement.aPayer);
      expect(d.engagements.first.engagement.origineType, 'DEPENSE');
    });

    test('8. Dépense non payée sans contact -> consolidée avec libellé sans erreur', () {
      final engDepenseSansContact = Engagement(
        id: 'dep_2',
        entrepriseId: 'ent_1',
        sens: SensEngagement.aPayer,
        libelle: 'Achat carburant groupe électrogène',
        montantTotal: 25000,
        dateEngagement: DateTime(2026, 11, 3),
        echeance: DateTime(2026, 11, 15),
        contactId: null, // Sans contact
        origineType: 'DEPENSE',
        syncStatus: RecordSyncStatus.synced,
      );

      final etat = EtatFinances(
        engagements: [engDepenseSansContact],
        paiements: const [],
      );

      final dossiers = CalculDossiersDettes.consolider(
        etat: etat,
        contacts: contactsMap,
        sens: SensEngagement.aPayer,
        maintenant: now,
      );

      expect(dossiers.length, 1);
      final d = dossiers.first;
      expect(d.contactId, isNull);
      expect(d.nomAffiche, 'Achat carburant groupe électrogène');
      expect(d.reste, 25000);
      expect(d.sens, SensEngagement.aPayer);
    });
  });

  group('Dettes UI Widgets', () {
    testWidgets('CarteDossierDette affiche les informations consolidées', (tester) async {
      final dossier = DossierDette(
        dossierKey: 'contact_c_1',
        contactId: 'c_1',
        nomAffiche: 'Amadou Traoré',
        telephone: '+223 70 00 00 00',
        sens: SensEngagement.aRecevoir,
        engagements: const [],
        paiements: const [],
        totalDu: 100000,
        totalPaye: 30000,
        reste: 70000,
        totalEnRetard: 20000,
        nbDettesActives: 2,
        nbEcheancesEnRetard: 1,
        prochaineEcheance: DateTime(2026, 11, 15),
        statutGlobal: StatutDossierDette.enRetard,
        echeances: const [],
        timeline: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CarteDossierDette(
                dossier: dossier,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Amadou Traoré'), findsOneWidget);
      expect(find.text('+223 70 00 00 00'), findsOneWidget);
      expect(find.textContaining('70'), findsWidgets);
      expect(find.textContaining('2 dettes'), findsOneWidget);
      expect(find.textContaining('en retard'), findsWidgets);
    });

    testWidgets('DettesVuePrincipale rend correctement le switcher et les filtres', (tester) async {
      final etat = EtatFinances(
        engagements: const [],
        paiements: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            etatFinancesProvider.overrideWith((ref) => Stream.value(etat)),
            contactsParIdProvider.overrideWith((ref) => Stream.value(const {})),
          ],
          child: const MaterialApp(
            locale: Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DettesVuePrincipale(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('À recevoir'), findsWidgets);
      expect(find.text('À payer'), findsWidgets);
      expect(find.text('Tous'), findsOneWidget);
      expect(find.text('En retard'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
