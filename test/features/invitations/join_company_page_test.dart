import 'package:dubagest/features/authentication/domain/entities/auth_state.dart';
import 'package:dubagest/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dubagest/features/invitations/presentation/pages/join_company_page.dart';
import 'package:dubagest/features/invitations/presentation/providers/invitations_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _FakeInvitationEnAttente extends InvitationEnAttente {
  String? _token;

  @override
  String? build() => _token;

  @override
  Future<void> memoriser(String token) async {
    _token = token;
    state = token;
  }

  @override
  Future<void> oublier() async {
    _token = null;
    state = null;
  }
}

void main() {
  testWidgets('JoinCompanyPage : saisie du PIN à 6 chiffres sans débordement sur écran très étroit (300px)', (tester) async {
    await pumpApp(
      tester,
      const JoinCompanyPage(),
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(const Unauthenticated())),
        invitationEnAttenteProvider.overrideWith(_FakeInvitationEnAttente.new),
      ],
      size: const Size(300, 700),
    );

    expect(find.text('Code PIN Collaborateur'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(Key('join-pin-$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('join-code-submit')), findsOneWidget);

    // Initialement désactivé
    final submitBtnAvant = tester.widget<FilledButton>(find.byKey(const Key('join-code-submit')));
    expect(submitBtnAvant.onPressed, isNull);

    // Saisie partielle (3 chiffres)
    await tester.enterText(find.byKey(const Key('join-pin-0')), '1');
    await tester.enterText(find.byKey(const Key('join-pin-1')), '2');
    await tester.enterText(find.byKey(const Key('join-pin-2')), '3');
    await tester.pumpAndSettle();

    // Toujours désactivé car 3 chiffres < 6
    final submitBtnPartiel = tester.widget<FilledButton>(find.byKey(const Key('join-code-submit')));
    expect(submitBtnPartiel.onPressed, isNull);

    // Bouton Effacer
    expect(find.text('Effacer'), findsOneWidget);
    await tester.tap(find.text('Effacer'));
    await tester.pumpAndSettle();
    expect(find.text('Coller le code'), findsOneWidget);

    // Saisie complète des 6 chiffres
    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(Key('join-pin-$i')), '${i + 1}');
    }
    await tester.pump();
  });
}
