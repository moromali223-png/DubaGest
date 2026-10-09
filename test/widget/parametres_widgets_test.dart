import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/permissions/access_decision.dart';
import 'package:dubagest/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dubagest/features/entreprise/domain/entities/profil_entreprise.dart';
import 'package:dubagest/features/entreprise/domain/usecases/profil_entreprise_usecases.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/finances/presentation/pages/paiement_form_page.dart';
import 'package:dubagest/features/finances/presentation/providers/finances_providers.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/parametres/presentation/pages/parametres_page.dart';
import 'package:dubagest/features/parametres/presentation/pages/parametres_paiements_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/fake_entreprise_repository.dart';
import '../helpers/pump_app.dart';

Matcher _regle(String code) => throwsA(isA<Failure>().having((f) => f.ruleCode, 'règle', code));

void main() {
  const profil = ProfilEntreprise(
    id: entrepriseId, nom: 'Alpha', devise: 'XOF', langueDocuments: 'fr',
    modesPaiement: ['ESPECES', 'MOBILE_MONEY'], piedRecu: 'Merci',
  );

  group('modifier les paramètres', () {
    test('administration seule ; au moins un mode, dans l\'ordre du catalogue ; mention limitée', () async {
      final repo = FakeEntrepriseRepository();
      final modifier = ModifierParametresEntreprise(repo);
      await expectLater(
          modifier(contexte(role: 'VENDEUR'), modesPaiement: {'ESPECES'}), _regle(RuleCodes.permissionDenied));
      await expectLater(modifier(contexte(), modesPaiement: {}), _regle(RuleCodes.paymentModesInvalid));
      await expectLater(modifier(contexte(), modesPaiement: {'BITCOIN'}), _regle(RuleCodes.paymentModesInvalid));
      await expectLater(
        modifier(contexte(), modesPaiement: {'ESPECES'}, piedRecu: 'x' * 301),
        _regle(RuleCodes.textTooLong),
      );
      await modifier(contexte(), modesPaiement: {'CHEQUE', 'ESPECES'}, piedRecu: 'Merci');
      expect(repo.parametresEnregistres?.modes, ['ESPECES', 'CHEQUE']);
      expect(repo.parametresEnregistres?.pied, 'Merci');
    });
  });

  group('écran Paramètres', () {
    List<Object> overrides(String role, {Set<String>? permissions}) => [
          contexteActifProvider.overrideWithValue(contexte(role: role, permissions: permissions)),
          authStateProvider.overrideWith((ref) => const Stream.empty()),
        ];

    testWidgets('administrateur : fiche, paiements et reçus, catégories de dépenses', (tester) async {
      await pumpApp(tester, const ParametresPage(), overrides: overrides('ADMINISTRATEUR').cast(), size: const Size(420, 1600));
      expect(find.byKey(const Key('parametres-fiche')), findsOneWidget);
      expect(find.byKey(const Key('parametres-paiements')), findsOneWidget);
      expect(find.byKey(const Key('parametres-categories')), findsOneWidget);
    });

    testWidgets('vendeur : uniquement ses réglages personnels', (tester) async {
      await pumpApp(tester, const ParametresPage(), overrides: overrides('VENDEUR').cast(), size: const Size(420, 1600));
      expect(find.text('Compte'), findsOneWidget);
      expect(find.byKey(const Key('parametres-fiche')), findsNothing);
      expect(find.byKey(const Key('parametres-paiements')), findsNothing);
      expect(find.byKey(const Key('parametres-categories')), findsNothing);
      expect(find.byKey(const Key('sign-out')), findsOneWidget);
    });
  });

  testWidgets('paiements et reçus : le dernier mode actif ne peut pas être retiré ; enregistrement', (tester) async {
    final repo = FakeEntrepriseRepository()..profilCourant = profil;
    await pumpApp(
      tester,
      const ParametresPaiementsPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(contexte()),
        entrepriseRepositoryProvider.overrideWithValue(repo),
      ],
      size: const Size(420, 1400),
    );
    SwitchListTile interrupteur(String code) => tester.widget(find.byKey(Key('parametre-mode-$code')));
    expect(interrupteur('ESPECES').value, isTrue);
    expect(interrupteur('CARTE').value, isFalse);

    await tester.tap(find.byKey(const Key('parametre-mode-MOBILE_MONEY')));
    await tester.pump();
    expect(interrupteur('ESPECES').onChanged, isNull, reason: 'au moins un mode reste proposé');

    await tester.enterText(find.byKey(const Key('parametre-pied-recu')), 'Merci de votre confiance');
    await tester.tap(find.byKey(const Key('parametres-enregistrer')));
    await tester.pumpAndSettle();
    expect(repo.parametresEnregistres?.modes, ['ESPECES']);
    expect(repo.parametresEnregistres?.pied, 'Merci de votre confiance');
    expect(find.text('Paramètres enregistrés.'), findsOneWidget);
  });

  testWidgets('saisie d\'un paiement : seuls les modes proposés par l\'entreprise', (tester) async {
    await pumpApp(
      tester,
      const PaiementFormPage(),
      overrides: [
        contexteActifProvider.overrideWithValue(contexte()),
        etatFinancesProvider.overrideWith((ref) => Stream.value(EtatFinances())),
        profilEntrepriseProvider.overrideWith((ref) async => profil),
      ],
      size: const Size(420, 1400),
    );
    expect(find.byKey(Key('mode-${ModePaiement.especes.code}')), findsOneWidget);
    expect(find.byKey(Key('mode-${ModePaiement.mobileMoney.code}')), findsOneWidget);
    expect(find.byKey(Key('mode-${ModePaiement.carte.code}')), findsNothing);
    expect(find.byKey(Key('mode-${ModePaiement.cheque.code}')), findsNothing);
  });
}
