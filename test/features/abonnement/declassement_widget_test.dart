import 'package:dubagest/features/abonnement/domain/entities/declassement_models.dart';
import 'package:dubagest/features/abonnement/domain/repositories/declassement_repository.dart';
import 'package:dubagest/features/abonnement/presentation/pages/declassement_page.dart';
import 'package:dubagest/features/abonnement/presentation/providers/declassement_providers.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contexte_fixtures.dart';
import '../../helpers/pump_app.dart';

class _FakeDeclassementRepo implements DeclassementRepository {
  @override
  Future<AnalyseDeclassement> analyserLimites({
    required String entrepriseId,
    required String planCibleCode,
  }) async {
    return const AnalyseDeclassement(
      conforme: true,
      entrepriseId: 'e-1',
      planActuel: PlanTarifInfo(code: 'MOYEN', nom: 'Moyen', prixMensuel: 2000, maxActivites: 2),
      planCible: PlanTarifInfo(code: 'NORMAL', nom: 'Normal', prixMensuel: 1000, maxActivites: 1),
      typeFacturation: 'COMMERCIAL',
      valeurCommercialeReference: 1000,
      montantDu: 1000,
      utilisateursActifs: 2,
      nbActivitesActives: 1,
      activitesActives: ['COMMERCE'],
      perimetresActifsParActivite: {'COMMERCE': 1},
      anomalies: [],
    );
  }

  @override
  Future<DemandeDeclassement> demanderDeclassement({
    required String entrepriseId,
    required String planCibleCode,
  }) async {
    final analyse = await analyserLimites(entrepriseId: entrepriseId, planCibleCode: planCibleCode);
    return DemandeDeclassement(
      id: 'd-1',
      entrepriseId: entrepriseId,
      planActuelCode: 'MOYEN',
      planCibleCode: planCibleCode,
      statut: 'pending_preparation',
      conforme: true,
      analyse: analyse,
      anomalies: const [],
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<DemandeDeclassement?> getDemandeEnCours(String entrepriseId) async => null;

  @override
  Future<void> ajusterRessource({
    required String entrepriseId,
    required String typeRessource,
    required String ressourceId,
    required String action,
  }) async {}

  @override
  Future<Map<String, dynamic>> validerEtAppliquerDeclassement(String demandeId) async => {};

  @override
  Future<void> annulerDemande(String demandeId) async {}
}

class _Contexte extends ContexteSessionNotifier {
  _Contexte(this.valeur);
  final ContexteSession valeur;
  @override
  Future<ContexteSession?> build() async => valeur;
}

void main() {
  testWidgets('DeclassementPage monte sans erreur', (tester) async {
    final ctx = contexte(role: 'ADMINISTRATEUR', plan: 'MOYEN');

    await pumpApp(
      tester,
      const DeclassementPage(),
      overrides: [
        contexteSessionProvider.overrideWith(() => _Contexte(ctx)),
        declassementRepositoryProvider.overrideWithValue(_FakeDeclassementRepo()),
      ],
      settle: false,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DeclassementPage), findsOneWidget);
  });
}
