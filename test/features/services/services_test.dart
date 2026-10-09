import 'package:dubagest/features/services/domain/entities/prestation.dart';
import 'package:dubagest/features/services/domain/entities/service_catalogue.dart';
import 'package:dubagest/features/services/domain/entities/metier_template.dart';
import 'package:dubagest/features/services/domain/services/moteur_echeances.dart';
import 'package:dubagest/features/services/domain/usecases/gerer_services.dart';
import 'package:dubagest/features/services/presentation/pdf/devis_services_pdf.dart';
import 'package:dubagest/features/services/presentation/pages/prestation_details_page.dart';
import 'package:dubagest/features/services/presentation/pages/prestations_page.dart';
import 'package:dubagest/features/services/presentation/pages/services_accueil_page.dart';
import 'package:dubagest/features/services/presentation/pages/services_catalogue_page.dart';
import 'package:dubagest/features/services/presentation/pages/services_planning_page.dart';
import 'package:dubagest/features/services/presentation/pages/services_devis_page.dart';
import 'package:dubagest/features/services/presentation/pages/devis_details_page.dart';
import 'package:dubagest/features/services/presentation/pages/services_rapport_page.dart';
import 'package:dubagest/features/services/presentation/widgets/bon_prise_en_charge_dialog.dart';
import 'package:dubagest/features/services/presentation/widgets/historique_services_contact.dart';
import 'package:dubagest/features/services/presentation/widgets/prestation_rappel_dialog.dart';
import 'package:dubagest/features/services/presentation/services_providers.dart';
import 'package:dubagest/features/services/domain/repositories/services_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dubagest/app/localization/l10n.dart';
import 'package:dubagest/features/services/presentation/widgets/services_widgets.dart';
import 'package:dubagest/features/services/data/models/services_mappers.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import '../../helpers/contexte_fixtures.dart';
import '../../helpers/fake_entreprise_repository.dart';
import '../../helpers/pump_app.dart';

class InMemoryServicesRepository implements ServicesRepository {
  final List<Prestation> prestations = [];
  final List<ServiceCatalogue> catalogue = [];
  final List<DevisPrestation> devis = [];

  @override
  Stream<List<ServiceCatalogue>> observerCatalogue(String entrepriseId) =>
      Stream.value(catalogue.where((s) => s.entrepriseId == entrepriseId).toList());

  @override
  Future<ServiceCatalogue> sauvegarderService(ServiceCatalogue service) async {
    final idx = catalogue.indexWhere((s) => s.id == service.id);
    if (idx >= 0) {
      catalogue[idx] = service;
    } else {
      catalogue.add(service);
    }
    return service;
  }

  @override
  Future<void> archiverService(String serviceId) async {
    catalogue.removeWhere((s) => s.id == serviceId);
  }

  @override
  Stream<List<Prestation>> observerPrestations(String entrepriseId, {String? perimetreId}) =>
      Stream.value(prestations.where((p) => p.entrepriseId == entrepriseId).toList());

  @override
  Future<Prestation?> getPrestation(String prestationId) async =>
      prestations.where((p) => p.id == prestationId).firstOrNull;

  @override
  Future<Prestation> creerPrestation(Prestation prestation) async {
    prestations.insert(0, prestation);
    return prestation;
  }

  @override
  Future<Prestation> modifierPrestation(Prestation prestation) async {
    final idx = prestations.indexWhere((p) => p.id == prestation.id);
    if (idx >= 0) prestations[idx] = prestation;
    return prestation;
  }

  @override
  Future<void> changerStatutPrestation(String prestationId, StatutPrestation nouveauStatut, {String? motif}) async {
    final idx = prestations.indexWhere((p) => p.id == prestationId);
    if (idx >= 0) {
      prestations[idx] = prestations[idx].copyWith(statut: nouveauStatut, motifAnnulation: motif);
    }
  }

  @override
  Future<void> reporterPrestation(
    String prestationId,
    DateTime nouvelleEcheanceJour,
    String? nouvelleEcheanceHeure,
    String motif,
  ) async {
    final idx = prestations.indexWhere((p) => p.id == prestationId);
    if (idx >= 0) {
      prestations[idx] = prestations[idx].copyWith(
        echeanceJour: nouvelleEcheanceJour,
        echeanceHeure: nouvelleEcheanceHeure,
        motifReport: motif,
      );
    }
  }

  @override
  Future<void> annulerPrestation(String prestationId, String motif) =>
      changerStatutPrestation(prestationId, StatutPrestation.annulee, motif: motif);

  @override
  Stream<List<PrestationHistorique>> observerHistorique(String prestationId) => Stream.value(const []);

  @override
  Stream<List<DevisPrestation>> observerDevis(String entrepriseId, {String? perimetreId}) =>
      Stream.value(devis.where((d) => d.entrepriseId == entrepriseId).toList());

  @override
  Future<DevisPrestation> creerDevis(DevisPrestation d) async {
    devis.insert(0, d);
    return d;
  }

  @override
  Future<DevisPrestation> modifierDevis(DevisPrestation d) async {
    final idx = devis.indexWhere((x) => x.id == d.id);
    if (idx >= 0) devis[idx] = d;
    return d;
  }

  @override
  Future<void> changerStatutDevis(String devisId, StatutDevis nouveauStatut) async {
    final idx = devis.indexWhere((x) => x.id == devisId);
    if (idx >= 0) {
      final old = devis[idx];
      devis[idx] = DevisPrestation(
        id: old.id,
        entrepriseId: old.entrepriseId,
        numero: old.numero,
        titre: old.titre,
        lignes: old.lignes,
        total: old.total,
        statut: nouveauStatut,
        dateEmission: old.dateEmission,
      );
    }
  }

  @override
  Future<Prestation> convertirDevisEnPrestation(String devisId) async {
    final d = devis.firstWhere((x) => x.id == devisId);
    final p = Prestation(
      id: 'prest-from-${d.id}',
      entrepriseId: d.entrepriseId,
      titre: d.titre,
      lignes: d.lignes,
      total: d.total,
    );
    prestations.insert(0, p);
    await changerStatutDevis(devisId, StatutDevis.converti);
    return p;
  }
}

void main() {
  group('Moteur d\'Échéances & Priorités Intelligentes (J-2, J-1, Retard)', () {
    const moteur = MoteurEcheances();
    final fixedNow = DateTime(2026, 10, 15, 10, 0, 0);

    test('Échéance dans plus de 2 jours -> Faible / À venir', () {
      final p = Prestation(
        id: 'p1',
        entrepriseId: entrepriseId,
        titre: 'Installation réseau',
        lignes: const [],
        total: 50000,
        echeanceJour: DateTime(2026, 10, 20), // J+5
      );

      final priorite = moteur.calculerPriorite(p, fixedNow);
      expect(priorite, PrioriteEcheance.faible);
    });

    test('Échéance dans 48h -> Attention (J-2)', () {
      final p = Prestation(
        id: 'p2',
        entrepriseId: entrepriseId,
        titre: 'Vidange complète',
        lignes: const [],
        total: 35000,
        echeanceJour: DateTime(2026, 10, 17),
        echeanceHeure: '08:00', // 46 heures restantes
      );

      final priorite = moteur.calculerPriorite(p, fixedNow);
      expect(priorite, PrioriteEcheance.attention);
    });

    test('Échéance dans 24h -> Urgent (J-1)', () {
      final p = Prestation(
        id: 'p3',
        entrepriseId: entrepriseId,
        titre: 'Changement écran iPhone',
        lignes: const [],
        total: 45000,
        echeanceJour: DateTime(2026, 10, 16),
        echeanceHeure: '09:00', // 23 heures restantes
      );

      final priorite = moteur.calculerPriorite(p, fixedNow);
      expect(priorite, PrioriteEcheance.urgent);
    });

    test('Échéance aujourd\'hui -> À faire aujourd\'hui', () {
      final p = Prestation(
        id: 'p4',
        entrepriseId: entrepriseId,
        titre: 'Coupe et brushing',
        lignes: const [],
        total: 15000,
        echeanceJour: DateTime(2026, 10, 15),
        echeanceHeure: '15:00',
      );

      final priorite = moteur.calculerPriorite(p, fixedNow);
      expect(priorite, PrioriteEcheance.aujourdhui);
    });

    test('Échéance dépassée et travail non terminé -> En retard', () {
      final p = Prestation(
        id: 'p5',
        entrepriseId: entrepriseId,
        titre: 'Robe de mariée',
        lignes: const [],
        total: 120000,
        statut: StatutPrestation.enCours,
        echeanceJour: DateTime(2026, 10, 12),
        echeanceHeure: '10:00', // 3 jours exacts avant fixedNow (15 oct 10h)
      );

      final priorite = moteur.calculerPriorite(p, fixedNow);
      expect(priorite, PrioriteEcheance.enRetard);
      expect(moteur.texteRetard(p, fixedNow), contains('3 jours de retard'));
    });

    test('Prestation terminée -> Pas d\'alerte de retard même si date passée', () {
      final p = Prestation(
        id: 'p6',
        entrepriseId: entrepriseId,
        titre: 'Réparation PC portable',
        lignes: const [],
        total: 25000,
        statut: StatutPrestation.terminee,
        echeanceJour: DateTime(2026, 10, 10),
      );

      final priorite = moteur.calculerPriorite(p, fixedNow);
      expect(priorite, PrioriteEcheance.faible);
    });
  });

  group('Indépendance Statut Travail vs Statut Financier', () {
    test('Calcul correct des acomptes, soldes et états de règlement', () {
      const p = Prestation(
        id: 'p1',
        entrepriseId: entrepriseId,
        titre: 'Rénovation carrelage',
        lignes: [],
        total: 100000,
        montantRegle: 40000, // Acompte versé
      );

      expect(p.soldeRestant, 60000);
      expect(p.aAcomptePartiel, isTrue);
      expect(p.estPayeIntegralement, isFalse);
      expect(p.estNonPaye, isFalse);
    });

    test('Prestation totalement réglée', () {
      const p = Prestation(
        id: 'p2',
        entrepriseId: entrepriseId,
        titre: 'Nettoyage bureaux',
        lignes: [],
        total: 50000,
        montantRegle: 50000,
      );

      expect(p.soldeRestant, 0);
      expect(p.estPayeIntegralement, isTrue);
      expect(p.aAcomptePartiel, isFalse);
    });
  });

  group('Use cases GererServices & Conversion Devis', () {
    late InMemoryServicesRepository repo;
    late GererServices gerer;

    setUp(() {
      repo = InMemoryServicesRepository();
      gerer = GererServices(repo);
    });

    test('Création de prestation et calcul automatique du total', () async {
      final p = await gerer.creerPrestation(
        entrepriseId: entrepriseId,
        titre: 'Réparation Climatisation',
        lignes: const [
          LignePrestation(id: 'l1', libelle: 'Diagnostic', quantite: 1, prixUnitaire: 15000),
          LignePrestation(id: 'l2', libelle: 'Recharge gaz', quantite: 2, prixUnitaire: 20000),
        ],
        remise: 5000,
      );

      expect(p.total, 50000); // (15k + 40k) - 5k = 50k
      expect(p.statut, StatutPrestation.aFaire);
    });

    test('Transition de statut : Démarrer puis Terminer', () async {
      final p = await gerer.creerPrestation(
        entrepriseId: entrepriseId,
        titre: 'Peinture salon',
        lignes: const [LignePrestation(id: 'l1', libelle: 'Forfait peinture', quantite: 1, prixUnitaire: 80000)],
      );

      await gerer.demarrerPrestation(p.id);
      expect((await repo.getPrestation(p.id))?.statut, StatutPrestation.enCours);

      await gerer.terminerPrestation(p.id);
      expect((await repo.getPrestation(p.id))?.statut, StatutPrestation.terminee);
    });

    test('Conversion 1-clic d\'un devis accepté en prestation', () async {
      final devis = await gerer.creerDevis(
        entrepriseId: entrepriseId,
        numero: 'DEV-202610-001',
        titre: 'Projet pose carrelage',
        dateEmission: DateTime.now(),
        lignes: const [LignePrestation(id: 'l1', libelle: 'Pose m2', quantite: 40, prixUnitaire: 3000)],
      );

      final prestation = await gerer.convertirDevisEnPrestation(devis.id);
      expect(prestation.titre, 'Projet pose carrelage');
      expect(prestation.total, 120000);
      expect((await repo.observerDevis(entrepriseId).first).first.statut, StatutDevis.converti);
    });
  });

  group('Interface Widgets & Navigation Services', () {
    testWidgets('ServicesAccueilPage affiche les KPIs, actions rapides et alertes', (tester) async {
      final repo = InMemoryServicesRepository();
      repo.prestations.add(
        Prestation(
          id: 'p1',
          entrepriseId: entrepriseId,
          titre: 'Réparation téléphone',
          lignes: const [LignePrestation(id: 'l1', libelle: 'Écran', quantite: 1, prixUnitaire: 25000)],
          total: 25000,
          echeanceJour: DateTime.now(),
          echeanceHeure: '16:00',
        ),
      );

      final ctx = contexte(
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'services.view', 'services.create', 'prestations.view', 'prestations.create', 'quotes.view'},
      );

      await pumpApp(
        tester,
        const ServicesAccueilPage(),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Bonjour Awa 👋'), findsOneWidget);
      expect(find.text('Aujourd\'hui'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('+ Prestation'), findsOneWidget);
      expect(find.text('📅 Planning'), findsOneWidget);
      expect(find.text('📝 Devis'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Réparation téléphone'), 200);
      expect(find.text('Réparation téléphone'), findsWidgets);
    });

    testWidgets('PrestationsPage permet de filtrer les interventions', (tester) async {
      final repo = InMemoryServicesRepository();
      repo.prestations.addAll([
        const Prestation(
          id: 'p1',
          entrepriseId: entrepriseId,
          titre: 'Nettoyage canapé',
          lignes: [],
          total: 20000,
          statut: StatutPrestation.aFaire,
        ),
        const Prestation(
          id: 'p2',
          entrepriseId: entrepriseId,
          titre: 'Vidange Toyota',
          lignes: [],
          total: 30000,
          statut: StatutPrestation.enCours,
        ),
      ]);

      final ctx = contexte(
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'prestations.view', 'prestations.create'},
      );

      await pumpApp(
        tester,
        const PrestationsPage(),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Nettoyage canapé'), findsOneWidget);
      expect(find.text('Vidange Toyota'), findsOneWidget);

      // Clic sur le filtre 'En cours'
      await tester.tap(find.text('En cours').first);
      await tester.pumpAndSettle();

      expect(find.text('Nettoyage canapé'), findsNothing);
      expect(find.text('Vidange Toyota'), findsOneWidget);
    });
  });

  group('Socle Offline First & Mappers Services', () {
    test('ServicesMappers sérialise et désérialise un ServiceCatalogue fidèlement', () {
      const s = ServiceCatalogue(
        id: 'sc-1',
        entrepriseId: entrepriseId,
        nom: 'Coupe Homme',
        categorie: 'Coiffure',
        prix: 3000,
        unite: UniteFacturation.forfait,
        dureeMinutes: 30,
      );

      final json = ServicesMappers.serviceToJson(s);
      final restored = ServicesMappers.serviceFromJson(json);

      expect(restored.id, s.id);
      expect(restored.nom, s.nom);
      expect(restored.prix, s.prix);
      expect(restored.unite, s.unite);
      expect(restored.dureeMinutes, s.dureeMinutes);
    });

    test('ServicesMappers sérialise et désérialise une Prestation avec ses lignes', () {
      final p = Prestation(
        id: 'p-offline-1',
        entrepriseId: entrepriseId,
        titre: 'Réparation Climatiseur',
        lignes: const [
          LignePrestation(id: 'l1', libelle: 'Recharge gaz R410A', quantite: 1, prixUnitaire: 25000),
          LignePrestation(id: 'l2', libelle: 'Main d\'œuvre', quantite: 2, prixUnitaire: 10000),
        ],
        remise: 5000,
        total: 40000,
        statut: StatutPrestation.enCours,
        priorite: PrioritePrestation.haute,
        echeanceJour: DateTime(2026, 10, 15),
        echeanceHeure: '14:30',
      );

      final json = ServicesMappers.prestationToJson(p);
      final restored = ServicesMappers.prestationFromJson(json);

      expect(restored.id, p.id);
      expect(restored.titre, p.titre);
      expect(restored.lignes.length, 2);
      expect(restored.total, 40000);
      expect(restored.statut, StatutPrestation.enCours);
      expect(restored.priorite, PrioritePrestation.haute);
      expect(restored.echeanceJour, DateTime(2026, 10, 15));
      expect(restored.echeanceHeure, '14:30');
    });

    test('ServicesMappers sérialise et désérialise un DevisPrestation', () {
      final d = DevisPrestation(
        id: 'dev-offline-1',
        entrepriseId: entrepriseId,
        numero: 'DEV-202610-001',
        titre: 'Peinture Façade',
        lignes: const [
          LignePrestation(id: 'l1', libelle: 'Peinture acrylique', quantite: 50, prixUnitaire: 2000),
        ],
        total: 100000,
        dateEmission: DateTime(2026, 10, 9),
        statut: StatutDevis.brouillon,
      );

      final json = ServicesMappers.devisToJson(d);
      final restored = ServicesMappers.devisFromJson(json);

      expect(restored.id, d.id);
      expect(restored.numero, 'DEV-202610-001');
      expect(restored.total, 100000);
      expect(restored.statut, StatutDevis.brouillon);
    });
  });

  group('Étape 3 : Catalogue des Prestations & Unités de Facturation', () {
    test('Formatage intelligent de la durée des prestations du catalogue', () {
      const s1 = ServiceCatalogue(
        id: 's1',
        entrepriseId: entrepriseId,
        nom: 'Brushing Express',
        dureeMinutes: 30,
      );
      expect(s1.dureeFormatee, '30 min');

      const s2 = ServiceCatalogue(
        id: 's2',
        entrepriseId: entrepriseId,
        nom: 'Vidange & Contrôle',
        dureeMinutes: 60,
      );
      expect(s2.dureeFormatee, '1 h');

      const s3 = ServiceCatalogue(
        id: 's3',
        entrepriseId: entrepriseId,
        nom: 'Pose Tresses & Soin',
        dureeMinutes: 150,
      );
      expect(s3.dureeFormatee, '2 h 30 min');

      const s4 = ServiceCatalogue(
        id: 's4',
        entrepriseId: entrepriseId,
        nom: 'Diagnostic sans durée fixée',
        dureeMinutes: null,
      );
      expect(s4.dureeFormatee, isNull);
    });

    testWidgets('ServicesCataloguePage liste les prestations, filtre par catégorie et recherche', (tester) async {
      final repo = InMemoryServicesRepository();
      repo.catalogue.addAll([
        const ServiceCatalogue(
          id: 'c1',
          entrepriseId: entrepriseId,
          nom: 'Coupe Homme',
          categorie: 'Coiffure',
          prix: 3000,
          unite: UniteFacturation.forfait,
          dureeMinutes: 30,
        ),
        const ServiceCatalogue(
          id: 'c2',
          entrepriseId: entrepriseId,
          nom: 'Coloration Cheveux',
          categorie: 'Coiffure',
          prix: 15000,
          unite: UniteFacturation.forfait,
          dureeMinutes: 90,
        ),
        const ServiceCatalogue(
          id: 'c3',
          entrepriseId: entrepriseId,
          nom: 'Réparation Connecteur de Charge',
          categorie: 'Électronique',
          prix: 10000,
          unite: UniteFacturation.piece,
          dureeMinutes: 45,
        ),
      ]);

      final ctx = contexte(
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'services.view', 'services.create', 'services.update'},
      );

      await pumpApp(
        tester,
        const ServicesCataloguePage(),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pumpAndSettle();

      // Vérifier que tous les services sont affichés
      expect(find.text('Coupe Homme'), findsOneWidget);
      expect(find.text('Coloration Cheveux'), findsOneWidget);
      expect(find.text('Réparation Connecteur de Charge'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('1 h 30 min'), findsOneWidget);

      // Clic sur le filtre catégorie 'Électronique' (ChoiceChip)
      await tester.tap(find.widgetWithText(ChoiceChip, 'Électronique'));
      await tester.pumpAndSettle();

      expect(find.text('Coupe Homme'), findsNothing);
      expect(find.text('Coloration Cheveux'), findsNothing);
      expect(find.text('Réparation Connecteur de Charge'), findsOneWidget);

      // Réinitialiser avec le chip 'Toutes'
      await tester.tap(find.widgetWithText(ChoiceChip, 'Toutes'));
      await tester.pumpAndSettle();

      expect(find.text('Coupe Homme'), findsOneWidget);
      expect(find.text('Coloration Cheveux'), findsOneWidget);
      expect(find.text('Réparation Connecteur de Charge'), findsOneWidget);
    });
  });

  group('Étape 4 : Fiche Client, Liaison & Historique des Interventions', () {
    testWidgets('HistoriqueServicesContact affiche les KPIs, prestations et devis d\'un client', (tester) async {
      final repo = InMemoryServicesRepository();
      repo.prestations.addAll([
        const Prestation(
          id: 'p-client-1',
          entrepriseId: entrepriseId,
          contactId: 'client-123',
          titre: 'Réparation Ordinateur',
          lignes: [],
          total: 50000,
          montantRegle: 20000,
          statut: StatutPrestation.enCours,
        ),
        const Prestation(
          id: 'p-client-2',
          entrepriseId: entrepriseId,
          contactId: 'client-123',
          titre: 'Installation Antivirus',
          lignes: [],
          total: 15000,
          montantRegle: 15000,
          statut: StatutPrestation.terminee,
        ),
        const Prestation(
          id: 'p-other',
          entrepriseId: entrepriseId,
          contactId: 'client-999',
          titre: 'Autre prestation',
          lignes: [],
          total: 100000,
          statut: StatutPrestation.aFaire,
        ),
      ]);

      repo.devis.add(
        DevisPrestation(
          id: 'dev-123',
          entrepriseId: entrepriseId,
          contactId: 'client-123',
          numero: 'DEV-001',
          titre: 'Mise à niveau Serveur',
          lignes: const [],
          total: 80000,
          dateEmission: DateTime.now(),
        ),
      );

      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'services.view', 'prestations.view', 'prestations.create', 'quotes.view'},
      );

      await pumpApp(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: HistoriqueServicesContact(contactId: 'client-123'),
          ),
        ),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pumpAndSettle();

      // Vérifier le titre et les KPIs
      expect(find.text('Prestations & Services'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 prestations pour ce client
      expect(find.text('1 en cours'), findsOneWidget);
      expect(find.text('Réparation Ordinateur'), findsOneWidget);
      expect(find.text('Installation Antivirus'), findsOneWidget);
      expect(find.text('Autre prestation'), findsNothing); // filtré !
      expect(find.text('Mise à niveau Serveur'), findsOneWidget); // devis associé
    });
  });

  group('Étape 5 : Prise en charge, Ordres de Travail & Suivi des Interventions', () {
    testWidgets('PrestationDetailsPage affiche le détail et ouvre le bon de prise en charge', (tester) async {
      final repo = InMemoryServicesRepository();
      const p = Prestation(
        id: 'p-details-1',
        entrepriseId: entrepriseId,
        titre: 'Réparation MacBook Pro M1',
        description: 'Écran noir suite à une chute',
        lignes: [
          LignePrestation(id: 'l1', libelle: 'Remplacement dalle LCD', quantite: 1, prixUnitaire: 120000),
          LignePrestation(id: 'l2', libelle: 'Main d\'œuvre spécialisée', quantite: 1, prixUnitaire: 25000),
        ],
        total: 145000,
        montantRegle: 50000,
        statut: StatutPrestation.enCours,
      );
      repo.prestations.add(p);

      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'services.view', 'prestations.view', 'prestations.update'},
      );

      await pumpApp(
        tester,
        const PrestationDetailsPage(prestationId: 'p-details-1'),
        settle: false,
        size: const Size(1200, 1600),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Vérifier affichage du titre, montant total et lignes
      expect(find.text('Réparation MacBook Pro M1'), findsOneWidget);
      expect(find.text('Écran noir suite à une chute'), findsOneWidget);
      expect(find.text('Remplacement dalle LCD'), findsOneWidget);
      expect(find.text('Main d\'œuvre spécialisée'), findsOneWidget);
      expect(find.text('Bon de prise en charge'), findsOneWidget);
    });

    testWidgets('BonPriseEnChargeDialog affiche le bon de prise en charge et bouton WhatsApp', (tester) async {
      final repo = InMemoryServicesRepository();
      const p = Prestation(
        id: 'p-details-2',
        entrepriseId: entrepriseId,
        titre: 'Diagnostic Climatisation',
        description: 'Bruit anormal au démarrage',
        lignes: [
          LignePrestation(id: 'l1', libelle: 'Forfait diagnostic', quantite: 1, prixUnitaire: 20000),
        ],
        total: 20000,
        montantRegle: 10000,
        statut: StatutPrestation.aFaire,
      );

      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'services.view', 'prestations.view'},
      );

      await pumpApp(
        tester,
        const Scaffold(
          body: BonPriseEnChargeDialog(prestation: p),
        ),
        settle: false,
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ORDRE DE TRAVAIL & BON DE PRISE EN CHARGE'), findsOneWidget);
      expect(find.text('Diagnostic Climatisation'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
    });
  });

  group('Étape 6 : Planning Intelligent, Agenda & Rappels d\'Intervention', () {
    testWidgets('ServicesPlanningPage affiche les différentes vues, filtres et compteurs', (tester) async {
      final repo = InMemoryServicesRepository();
      final now = DateTime.now();

      repo.prestations.addAll([
        Prestation(
          id: 'p-today',
          entrepriseId: entrepriseId,
          titre: 'Installation Climatiseur',
          lignes: const [],
          total: 50000,
          echeanceJour: DateTime(now.year, now.month, now.day),
          echeanceHeure: '14:00',
          statut: StatutPrestation.planifiee,
        ),
        Prestation(
          id: 'p-late',
          entrepriseId: entrepriseId,
          titre: 'Réparation Groupe Électrogène',
          lignes: const [],
          total: 80000,
          echeanceJour: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2)),
          statut: StatutPrestation.enCours,
        ),
      ]);

      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'services.view', 'prestations.view'},
      );

      await pumpApp(
        tester,
        const ServicesPlanningPage(vueInitiale: 'aujourdhui'),
        settle: false,
        size: const Size(1200, 800),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Vérifie l'en-tête et l'élément d'aujourd'hui
      expect(find.text('Planning & Agenda'), findsOneWidget);
      expect(find.text('Installation Climatiseur'), findsOneWidget);

      // Clic sur l'onglet 'En retard'
      final chipFinder = find.textContaining('En retard').first;
      await tester.ensureVisible(chipFinder);
      await tester.pump();
      await tester.tap(chipFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Réparation Groupe Électrogène'), findsOneWidget);
    });

    testWidgets('PrestationRappelDialog affiche les modèles et options WhatsApp/SMS', (tester) async {
      const p = Prestation(
        id: 'p-rappel-1',
        entrepriseId: entrepriseId,
        titre: 'Révision Complète Véhicule',
        lignes: [],
        total: 75000,
        montantRegle: 25000,
        statut: StatutPrestation.terminee,
      );

      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'services.view', 'prestations.view'},
      );

      await pumpApp(
        tester,
        const Scaffold(
          body: PrestationRappelDialog(prestation: p),
        ),
        settle: false,
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Envoyer un rappel / relance'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Copier'), findsOneWidget);
      expect(find.textContaining('terminée'), findsWidgets);
    });
  });

  group('Étape 7 : Gestion des Devis, Facturation & Acomptes Services', () {
    testWidgets('ServicesDevisPage liste les devis et filtre par recherche', (tester) async {
      final repo = InMemoryServicesRepository();
      repo.devis.addAll([
        DevisPrestation(
          id: 'dev-1',
          entrepriseId: entrepriseId,
          numero: 'DEV-2026-001',
          titre: 'Rénovation Salon VIP',
          lignes: [],
          total: 150000,
          statut: StatutDevis.envoye,
          dateEmission: DateTime(2026, 10, 1),
        ),
        DevisPrestation(
          id: 'dev-2',
          entrepriseId: entrepriseId,
          numero: 'DEV-2026-002',
          titre: 'Maintenance Informatique',
          lignes: [],
          total: 80000,
          statut: StatutDevis.brouillon,
          dateEmission: DateTime(2026, 10, 2),
        ),
      ]);

      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'services.view', 'prestations.view'},
      );

      await pumpApp(
        tester,
        const ServicesDevisPage(),
        settle: false,
        size: const Size(1200, 800),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rénovation Salon VIP'), findsOneWidget);
      expect(find.text('Maintenance Informatique'), findsOneWidget);
      expect(find.text('DEV-2026-001'), findsOneWidget);
      expect(find.text('Envoyé'), findsOneWidget);
    });

    testWidgets('DevisDetailsPage affiche le chiffrage détaillé et permet la conversion en prestation', (tester) async {
      final repo = InMemoryServicesRepository();
      final d = DevisPrestation(
        id: 'dev-details-1',
        entrepriseId: entrepriseId,
        numero: 'DEV-2026-005',
        titre: 'Installation Caméras Surveillance',
        description: 'Pack 4 caméras IP + Enregistreur NVR',
        lignes: const [
          LignePrestation(id: 'l1', libelle: 'Caméra IP 4K Extérieure', quantite: 4, prixUnitaire: 35000),
          LignePrestation(id: 'l2', libelle: 'Enregistreur NVR 8 Voies', quantite: 1, prixUnitaire: 60000),
        ],
        total: 200000,
        statut: StatutDevis.accepte,
        dateEmission: DateTime(2026, 10, 3),
      );
      repo.devis.add(d);

      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'services.view', 'prestations.view', 'prestations.create'},
      );

      await pumpApp(
        tester,
        const DevisDetailsPage(devisId: 'dev-details-1'),
        settle: false,
        size: const Size(1200, 800),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('DEV-2026-005'), findsOneWidget);
      expect(find.text('Installation Caméras Surveillance'), findsOneWidget);
      expect(find.text('Caméra IP 4K Extérieure'), findsOneWidget);
      expect(find.text('Enregistreur NVR 8 Voies'), findsOneWidget);
      expect(find.text('Accepté'), findsOneWidget);
      expect(find.text('Convertir en prestation'), findsOneWidget);
      expect(find.text('Partager WhatsApp'), findsOneWidget);

      // Clic sur "Convertir en prestation"
      await tester.tap(find.text('Convertir en prestation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // La prestation doit avoir été créée dans le repo avec les mêmes lignes et total
      expect(repo.prestations.length, 1);
      expect(repo.prestations.first.titre, 'Installation Caméras Surveillance');
      expect(repo.prestations.first.total, 200000);
      expect(repo.prestations.first.lignes.length, 2);
    });
  });

  group('Étape 8 : Liaison Stock & Consommables Utilisés lors des Interventions', () {
    test('LignePrestation avec produitId est identifiée comme consommable et se sérialise correctement', () {
      const lignePiece = LignePrestation(
        id: 'lp-stock-1',
        produitId: 'prod-batterie-123',
        libelle: 'Batterie iPhone 13 Pro Originale',
        quantite: 1,
        prixUnitaire: 28000,
      );

      const ligneMainOeuvre = LignePrestation(
        id: 'lp-service-1',
        serviceId: 'serv-reparation-1',
        libelle: 'Main d\'œuvre remplacement batterie',
        quantite: 1,
        prixUnitaire: 10000,
      );

      expect(lignePiece.estConsommable, isTrue);
      expect(ligneMainOeuvre.estConsommable, isFalse);

      final json = lignePiece.toJson();
      expect(json['produit_id'], 'prod-batterie-123');

      final deserialise = LignePrestation.fromJson(json);
      expect(deserialise.produitId, 'prod-batterie-123');
      expect(deserialise.estConsommable, isTrue);
      expect(deserialise.totalLigne, 28000);
    });

    testWidgets('PrestationDetailsPage affiche le badge Pièce stock pour les consommables', (tester) async {
      final repo = InMemoryServicesRepository();
      const p = Prestation(
        id: 'p-stock-details-1',
        entrepriseId: entrepriseId,
        titre: 'Changement Écran Samsung S21',
        description: 'Écran OLED + Main d\'œuvre',
        lignes: [
          LignePrestation(
            id: 'l-stock-1',
            produitId: 'prod-ecran-oled',
            libelle: 'Dalle OLED Samsung S21',
            quantite: 1,
            prixUnitaire: 65000,
          ),
          LignePrestation(
            id: 'l-serv-1',
            serviceId: 'serv-pose',
            libelle: 'Pose & Test tactile',
            quantite: 1,
            prixUnitaire: 15000,
          ),
        ],
        total: 80000,
        statut: StatutPrestation.enCours,
      );
      repo.prestations.add(p);

      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'services.view', 'prestations.view'},
      );

      await pumpApp(
        tester,
        const PrestationDetailsPage(prestationId: 'p-stock-details-1'),
        settle: false,
        size: const Size(1200, 1600),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Changement Écran Samsung S21'), findsOneWidget);
      expect(find.text('Dalle OLED Samsung S21'), findsOneWidget);
      expect(find.text('Pose & Test tactile'), findsOneWidget);
      // Le badge "📦 Pièce stock" doit être présent pour la pièce détachée
      expect(find.text('📦 Pièce stock'), findsOneWidget);
    });
  });

  group('Étape 9 : Rapports, Rentabilité & Tableau de Bord Services', () {
    testWidgets('ServicesRapportPage affiche les KPIs financiers, ventilation et devis', (tester) async {
      final repo = InMemoryServicesRepository();
      final now = DateTime.now();

      repo.prestations.addAll([
        Prestation(
          id: 'p-rep-1',
          entrepriseId: entrepriseId,
          titre: 'Réparation MacBook Pro',
          lignes: const [
            LignePrestation(id: 'l1', produitId: 'lcd-screen', libelle: 'Écran LCD', quantite: 1, prixUnitaire: 100000),
            LignePrestation(id: 'l2', libelle: 'Main d\'œuvre', quantite: 1, prixUnitaire: 30000),
          ],
          total: 130000,
          montantRegle: 80000,
          statut: StatutPrestation.terminee,
          echeanceJour: now,
        ),
        Prestation(
          id: 'p-rep-2',
          entrepriseId: entrepriseId,
          titre: 'Installation Climatiseur',
          lignes: const [
            LignePrestation(id: 'l3', libelle: 'Pose & Raccordement', quantite: 1, prixUnitaire: 40000),
          ],
          total: 40000,
          montantRegle: 40000,
          statut: StatutPrestation.livree,
          echeanceJour: now,
        ),
      ]);

      repo.devis.addAll([
        DevisPrestation(
          id: 'dev-rep-1',
          entrepriseId: entrepriseId,
          numero: 'DEV-REP-1',
          titre: 'Pack Entretien',
          lignes: const [],
          total: 50000,
          statut: StatutDevis.converti,
          dateEmission: now,
        ),
      ]);

      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'GESTIONNAIRE_SERVICES',
        permissions: {'services.view', 'prestations.view'},
      );

      await pumpApp(
        tester,
        const ServicesRapportPage(),
        settle: false,
        size: const Size(1200, 800),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rapports & Rentabilité Services'), findsOneWidget);
      expect(find.text('Performance Financière'), findsOneWidget);
      expect(find.text('Total Facturé'), findsOneWidget);
      expect(find.text('Encaissé'), findsOneWidget);
      expect(find.text('À Recouvrer'), findsOneWidget);
      expect(find.text('Ventilation de la Valeur Facturée'), findsOneWidget);
      expect(find.text('Interventions'), findsOneWidget);
      expect(find.text('Transformation Devis'), findsOneWidget);
    });
  });

  group('Étape 10 : Rôles, Permissions & Sécurité RBAC du module Services', () {
    test('DroitsServices évalue correctement les permissions selon la politique RBAC', () {
      final container = ProviderContainer(
        overrides: [
          contexteActifProvider.overrideWithValue(
            contexte(
              activites: const ['SERVICES'],
              role: 'TECHNICIEN_SERVICES',
              permissions: {
                'services.view',
                'prestations.view',
                'prestations.update',
              },
            ),
          ),
        ],
      );

      final droits = container.read(droitsServicesProvider);
      expect(droits.peutVoirServices, isTrue);
      expect(droits.peutCreerServices, isFalse);
      expect(droits.peutModifierServices, isFalse);
      expect(droits.peutVoirPrestations, isTrue);
      expect(droits.peutCreerPrestations, isFalse);
      expect(droits.peutModifierPrestations, isTrue);
      expect(droits.peutAnnulerPrestations, isFalse);
      expect(droits.peutVoirDevis, isFalse);
      expect(droits.peutCreerDevis, isFalse);
      expect(droits.peutModifierDevis, isFalse);
    });

    testWidgets('PrestationDetailsPage masque Démarrer/Terminer sans prestation.update et Annuler sans prestation.cancel', (tester) async {
      final repo = InMemoryServicesRepository();
      const p = Prestation(
        id: 'p-rbac',
        entrepriseId: entrepriseId,
        titre: 'Installation caméra',
        lignes: [],
        total: 45000,
        statut: StatutPrestation.aFaire,
      );
      repo.prestations.add(p);

      // Utilisateur en lecture seule
      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'OBSERVATEUR',
        permissions: {'prestations.view'},
      );

      await pumpApp(
        tester,
        const PrestationDetailsPage(prestationId: 'p-rbac'),
        settle: false,
        size: const Size(1200, 800),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Installation caméra'), findsOneWidget);
      // Démarrer et Annuler ne doivent PAS être présents
      expect(find.text('Démarrer'), findsNothing);
      expect(find.text('Annuler'), findsNothing);
      // Bon de prise en charge et Rappel restent accessibles
      expect(find.text('Bon de prise en charge'), findsOneWidget);
    });

    testWidgets('DevisDetailsPage masque Convertir sans prestation.create et Marquer accepté sans quotes.update', (tester) async {
      final repo = InMemoryServicesRepository();
      final devis = DevisPrestation(
        id: 'dev-rbac',
        entrepriseId: entrepriseId,
        numero: 'DEV-RBAC-01',
        titre: 'Diagnostic réseau',
        lignes: const [],
        total: 30000,
        statut: StatutDevis.brouillon,
        dateEmission: DateTime.now(),
      );
      repo.devis.add(devis);

      // Utilisateur avec seulement quotes.view
      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'COMMERCIAL_JUNIOR',
        permissions: {'quotes.view'},
      );

      await pumpApp(
        tester,
        const DevisDetailsPage(devisId: 'dev-rbac'),
        settle: false,
        size: const Size(1200, 800),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('DEV-RBAC-01'), findsOneWidget);
      expect(find.text('Convertir en prestation'), findsNothing);
      expect(find.text('Marquer accepté'), findsNothing);
      expect(find.text('Marquer refusé'), findsNothing);
      expect(find.text('Partager WhatsApp'), findsOneWidget);
    });

    testWidgets('ServicesCataloguePage masque le bouton FAB sans services.create', (tester) async {
      final repo = InMemoryServicesRepository();
      repo.catalogue.add(
        const ServiceCatalogue(
          id: 's-rbac',
          entrepriseId: entrepriseId,
          nom: 'Révision moteur',
          prix: 25000,
          unite: UniteFacturation.forfait,
        ),
      );

      final ctx = contexte(
        activites: const ['SERVICES'],
        role: 'LECTEUR',
        permissions: {'services.view'},
      );

      await pumpApp(
        tester,
        const ServicesCataloguePage(),
        settle: false,
        size: const Size(1200, 800),
        overrides: [
          contexteActifProvider.overrideWithValue(ctx),
          servicesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Révision moteur'), findsOneWidget);
      expect(find.text('Nouveau service'), findsNothing);
    });
  });

  group('Étape 11 : Internationalisation & Accessibilité (FR, EN, AR & RTL)', () {
    test('Traductions complètes des statuts, devis, unités et priorités (FR, EN, AR)', () {
      final l10nFr = lookupAppLocalizations(const Locale('fr'));
      final l10nEn = lookupAppLocalizations(const Locale('en'));
      final l10nAr = lookupAppLocalizations(const Locale('ar'));

      // Statuts Prestations
      expect(l10nFr.statutPrestation(StatutPrestation.aFaire), 'À faire');
      expect(l10nEn.statutPrestation(StatutPrestation.aFaire), 'To do');
      expect(l10nAr.statutPrestation(StatutPrestation.aFaire), 'قيد الانتظار');

      expect(l10nFr.statutPrestation(StatutPrestation.terminee), 'Terminée');
      expect(l10nEn.statutPrestation(StatutPrestation.terminee), 'Completed');
      expect(l10nAr.statutPrestation(StatutPrestation.terminee), 'مكتملة');

      // Statuts Devis
      expect(l10nFr.statutDevis(StatutDevis.brouillon), 'Brouillon');
      expect(l10nEn.statutDevis(StatutDevis.brouillon), 'Draft');
      expect(l10nAr.statutDevis(StatutDevis.brouillon), 'مسودة');

      expect(l10nFr.statutDevis(StatutDevis.accepte), 'Accepté');
      expect(l10nEn.statutDevis(StatutDevis.accepte), 'Accepted');
      expect(l10nAr.statutDevis(StatutDevis.accepte), 'مقبول');

      // Unités
      expect(l10nFr.uniteFacturation(UniteFacturation.forfait), 'Forfait');
      expect(l10nEn.uniteFacturation(UniteFacturation.forfait), 'Flat rate');
      expect(l10nAr.uniteFacturation(UniteFacturation.forfait), 'جزافي');

      expect(l10nFr.uniteFacturation(UniteFacturation.heure), 'Par heure');
      expect(l10nEn.uniteFacturation(UniteFacturation.heure), 'Per hour');
      expect(l10nAr.uniteFacturation(UniteFacturation.heure), 'بالساعة');
    });

    testWidgets('StatutPrestationBadge affiche la traduction en arabe avec support RTL', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Center(
            child: StatutPrestationBadge(statut: StatutPrestation.terminee),
          ),
        ),
        locale: const Locale('ar'),
      );

      expect(find.text('مكتملة'), findsOneWidget);
    });

    testWidgets('StatutPrestationBadge affiche la traduction en anglais', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Center(
            child: StatutPrestationBadge(statut: StatutPrestation.enCours),
          ),
        ),
        locale: const Locale('en'),
      );

      expect(find.text('In progress'), findsOneWidget);
    });
  });

  group('Étape 12 : Modèles Métiers, Photographies de Dossier & Devis PDF', () {
    test('Calculs multi-unités des échéances prévues (heures, jours, semaines, mois)', () {
      final baseDate = DateTime(2026, 4, 1, 10, 0);
      const moteur = MoteurEcheances();

      final echeanceHeures = moteur.calculerEcheancePrevue(
        baseDate,
        24,
        UniteDuree.heures,
      );
      expect(echeanceHeures.difference(baseDate).inHours, 24);

      final echeanceJours = moteur.calculerEcheancePrevue(
        baseDate,
        21,
        UniteDuree.jours,
      );
      expect(echeanceJours.difference(baseDate).inDays, 21);

      final echeanceSemaines = moteur.calculerEcheancePrevue(
        baseDate,
        2,
        UniteDuree.semaines,
      );
      expect(echeanceSemaines.difference(baseDate).inDays, 14);

      final echeanceMois = moteur.calculerEcheancePrevue(
        baseDate,
        1,
        UniteDuree.mois,
      );
      expect(echeanceMois.month, 5);
    });

    test('MetierTemplate fournit les presets requis (incubation, pressing, couture, etc.)', () {
      final incubation = MetierTemplate.templatePour(MetierCode.incubation);
      expect(incubation.titreParDefaut, 'Lot incubation d\'œufs');
      expect(incubation.dureeParDefaut, 21);
      expect(incubation.uniteParDefaut, UniteDuree.jours);

      final pressing = MetierTemplate.templatePour(MetierCode.pressing);
      expect(pressing.champs.any((c) => c.cle == 'type_vetement'), isTrue);

      final reparation = MetierTemplate.templatePour(MetierCode.reparation);
      expect(reparation.champs.any((c) => c.cle == 'panne_declaree'), isTrue);
    });

    test('PhotoPrestation sérialisation et catégories de traçabilité', () {
      final photo = PhotoPrestation(
        id: 'photo-1',
        prestationId: 'p-1',
        cheminLocal: '/data/user/0/dubagest/cache/p1.jpg',
        categorie: CategoriePhoto.reception,
        legende: 'Écran fêlé à l\'arrivée',
        createdAt: DateTime(2026, 4, 1, 10, 0),
        auteurNom: 'Technicien A',
      );

      final json = photo.toJson();
      final deserialized = PhotoPrestation.fromJson(json);

      expect(deserialized.id, 'photo-1');
      expect(deserialized.categorie, CategoriePhoto.reception);
      expect(deserialized.legende, 'Écran fêlé à l\'arrivée');
      expect(deserialized.auteurNom, 'Technicien A');
    });

    test('Génération Devis PDF sans erreur', () async {
      final devis = DevisPrestation(
        id: 'dev-pdf-1',
        entrepriseId: 'ent-1',
        numero: 'DEV-2026-0042',
        titre: 'Incubation 500 œufs de pintade',
        description: 'Mire au 7e et 14e jour inclus',
        lignes: const [
          LignePrestation(id: 'l-1', libelle: 'Incubation forfait 500 œufs', prixUnitaire: 50000, quantite: 1),
          LignePrestation(id: 'l-2', libelle: 'Vaccination 1er jour', prixUnitaire: 15000, quantite: 1),
        ],
        total: 65000,
        acompteDemande: 30000,
        dateEmission: DateTime(2026, 4, 1),
        dateValidite: DateTime(2026, 4, 15),
        conditions: 'Acompte de 50% obligatoire au dépôt.',
      );

      final bytes = await genererDevisPdf(devis);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });
  });
}






