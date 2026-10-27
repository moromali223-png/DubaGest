import 'package:dubagest/features/authentication/presentation/pages/onboarding_page.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/pump_app.dart';

class _Contexte extends ContexteSessionNotifier {
  _Contexte(this.valeur);
  final ContexteSession valeur;
  @override
  Future<ContexteSession?> build() async => valeur;
}

void main() {
  testWidgets('compte sans entreprise : seulement « Créer » ou « Rejoindre »', (tester) async {
    await pumpApp(
      tester,
      const OnboardingPage(),
      overrides: [
        contexteSessionProvider.overrideWith(() => _Contexte(contexte(avecEntreprise: false))),
      ],
    );
    expect(find.text('Bienvenue Awa'), findsOneWidget);
    expect(find.text('Que souhaitez-vous faire ?'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-create')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-join')), findsOneWidget);
  });

  testWidgets('en arabe (RTL)', (tester) async {
    await pumpApp(
      tester,
      const OnboardingPage(),
      overrides: [
        contexteSessionProvider.overrideWith(() => _Contexte(contexte(avecEntreprise: false))),
      ],
      locale: const Locale('ar'),
    );
    expect(Directionality.of(tester.element(find.byType(OnboardingPage))), TextDirection.rtl);
    expect(find.text('إنشاء مؤسستي'), findsOneWidget);
  });

  testWidgets('en format mobile (smartphone portrait)', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpApp(
      tester,
      const OnboardingPage(),
      overrides: [
        contexteSessionProvider.overrideWith(() => _Contexte(contexte(avecEntreprise: false))),
      ],
    );
    expect(find.text('Bienvenue Awa'), findsOneWidget);
    expect(find.text('Que souhaitez-vous faire ?'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-create')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-join')), findsOneWidget);
  });
}
