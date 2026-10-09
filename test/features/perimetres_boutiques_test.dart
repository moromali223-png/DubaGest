import 'package:dubagest/app/localization/l10n.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/activites/domain/entities/activite.dart';
import 'package:dubagest/features/entreprise/domain/entities/espace_courant.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/entreprise/presentation/providers/espace_providers.dart';
import 'package:dubagest/features/entreprise/presentation/widgets/espace_selector.dart';
import 'package:dubagest/features/perimetres/domain/entities/perimetre.dart';
import 'package:dubagest/features/perimetres/domain/services/boutiques_naming_service.dart';
import 'package:dubagest/features/perimetres/presentation/pages/perimetres_page.dart';
import 'package:dubagest/features/perimetres/presentation/providers/perimetres_providers.dart';
import 'package:dubagest/features/utilisateurs/presentation/providers/membres_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';

void main() {
  group('Boutiques Naming & Conception Rules', () {
    test('1. Nommage séquentiel automatique : Boutique A, Boutique B, Boutique C...', () {
      expect(BoutiquesNamingService.nomParDefaut(0), 'Boutique A');
      expect(BoutiquesNamingService.nomParDefaut(1), 'Boutique B');
      expect(BoutiquesNamingService.nomParDefaut(2), 'Boutique C');
      expect(BoutiquesNamingService.nomParDefaut(3), 'Boutique D');

      expect(BoutiquesNamingService.codeParDefaut(0), 'SHOP-001');
      expect(BoutiquesNamingService.codeParDefaut(1), 'SHOP-002');
    });

    test('2. Suggérer automatiquement le nom suivant en fonction des boutiques existantes', () {
      const p1 = Perimetre(
        id: 'p1',
        entrepriseId: 'ent1',
        activite: ActiviteCode.commerce,
        type: PerimetreType.boutique,
        nom: 'Boutique A',
        code: 'SHOP-001',
      );

      final sug1 = BoutiquesNamingService.suggestionSuivante([p1]);
      expect(sug1.nom, 'Boutique B');
      expect(sug1.code, 'SHOP-002');

      const p2 = Perimetre(
        id: 'p2',
        entrepriseId: 'ent1',
        activite: ActiviteCode.commerce,
        type: PerimetreType.boutique,
        nom: 'Boutique Centrale', // Renommée
        code: 'SHOP-002',
      );

      final sug2 = BoutiquesNamingService.suggestionSuivante([p1, p2]);
      expect(sug2.nom, 'Boutique C');
      expect(sug2.code, 'SHOP-003');
    });

    test('3. Distinction stricte : Toutes les boutiques est une VUE CONSOLIDÉE, pas une boutique', () {
      const vueConsolidee = EspaceCourant(activite: ActiviteCode.commerce, perimetreId: null);
      const boutiqueReelle = EspaceCourant(activite: ActiviteCode.commerce, perimetreId: 'p1');

      expect(BoutiquesNamingService.estVueConsolidee(vueConsolidee), isTrue);
      expect(BoutiquesNamingService.estVueConsolidee(boutiqueReelle), isFalse);
    });
  });

  group('Boutique UI Widgets', () {
    const p1 = Perimetre(
      id: 'p1',
      entrepriseId: 'ent1',
      activite: ActiviteCode.commerce,
      type: PerimetreType.boutique,
      nom: 'Boutique A',
      code: 'SHOP-001',
      estActif: true,
      syncStatus: RecordSyncStatus.synced,
    );

    const p2 = Perimetre(
      id: 'p2',
      entrepriseId: 'ent1',
      activite: ActiviteCode.commerce,
      type: PerimetreType.boutique,
      nom: 'Boutique B',
      code: 'SHOP-002',
      estActif: true,
      syncStatus: RecordSyncStatus.synced,
    );

    testWidgets('EspaceSelector - 1 seule boutique : affichage discret sans dropdown interactif', (tester) async {
      final mockContext = contexte(
        perimetres: [
          perimetreJson('p1', nom: 'Boutique A'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contexteActifProvider.overrideWithValue(mockContext),
            espaceCourantProvider.overrideWith(() => _MockEspaceController(const EspaceCourant(activite: ActiviteCode.commerce, perimetreId: 'p1'))),
          ],
          child: const MaterialApp(
            locale: Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EspaceSelector(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Boutique A'), findsOneWidget);
      // Pas de dropdown d'ouverture
      expect(find.byKey(const Key('espace-selector')), findsNothing);
    });

    testWidgets('EspaceSelector - Multi-boutiques : sélecteur interactif avec Vue Consolidée', (tester) async {
      final mockContext = contexte(
        perimetres: [
          perimetreJson('p1', nom: 'Boutique A'),
          perimetreJson('p2', nom: 'Boutique B'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contexteActifProvider.overrideWithValue(mockContext),
            espaceCourantProvider.overrideWith(() => _MockEspaceController(const EspaceCourant(activite: ActiviteCode.commerce, perimetreId: null))),
          ],
          child: const MaterialApp(
            locale: Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EspaceSelector(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Toutes les boutiques'), findsOneWidget);
      expect(find.byKey(const Key('espace-selector')), findsOneWidget);

      // Ouvrir la feuille de sélection
      await tester.tap(find.byKey(const Key('espace-selector')));
      await tester.pumpAndSettle();

      expect(find.text('Sélectionner une boutique'), findsOneWidget);
      expect(find.text('Vue consolidée · Cumul des 2 boutiques actives'), findsOneWidget);
      expect(find.text('Boutique A'), findsOneWidget);
      expect(find.text('Boutique B'), findsOneWidget);
    });

    testWidgets('PerimetresPage rend la liste des boutiques avec quotas et actions', (tester) async {
      final mockContext = contexte(
        perimetres: [
          perimetreJson('p1', nom: 'Boutique A'),
          perimetreJson('p2', nom: 'Boutique B'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contexteActifProvider.overrideWithValue(mockContext),
            perimetresProvider.overrideWith((ref) => Stream.value([p1, p2])),
            membresProvider.overrideWith((ref) => Future.value(const [])),
          ],
          child: const MaterialApp(
            locale: Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PerimetresPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mes boutiques & sites'), findsOneWidget);
      expect(find.text('Boutique A'), findsOneWidget);
      expect(find.text('Boutique B'), findsOneWidget);
      expect(find.text('Boutiques enregistrées (2)'), findsOneWidget);
    });
  });
}

class _MockEspaceController extends Notifier<EspaceCourant> implements EspaceCourantController {
  _MockEspaceController(this._initial);
  final EspaceCourant _initial;

  @override
  EspaceCourant build() => _initial;

  @override
  Future<void> choisirActivite(ActiviteCode? activite) async {
    state = EspaceCourant(activite: activite, perimetreId: state.perimetreId);
  }

  @override
  Future<void> choisirSite(String? perimetreId) async {
    state = EspaceCourant(activite: state.activite, perimetreId: perimetreId);
  }
}
