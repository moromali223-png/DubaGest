import 'package:dubagest/app/localization/l10n.dart';
import 'package:dubagest/app/localization/locale_controller.dart';
import 'package:dubagest/core/di/core_providers.dart';
import 'package:dubagest/shared/widgets/language_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reproduit le câblage de DubaGestApp (locale → MaterialApp).
class _LocalizedApp extends ConsumerWidget {
  const _LocalizedApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        locale: ref.watch(localeControllerProvider),
        supportedLocales: AppLocales.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text(context.l10n.navHome)),
            body: const LanguageList(),
          ),
        ),
      );
}

Future<SharedPreferences> _pump(WidgetTester tester, Map<String, Object> prefsValues) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const _LocalizedApp(),
  ));
  await tester.pumpAndSettle();
  return prefs;
}

TextDirection _direction(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(LanguageList)));

void main() {
  testWidgets('FR → AR (RTL) → EN sans redémarrage, langue persistée', (tester) async {
    final prefs = await _pump(tester, {'app_locale': 'fr'});
    expect(find.text('Accueil'), findsOneWidget);
    expect(_direction(tester), TextDirection.ltr);

    await tester.tap(find.byKey(const ValueKey('language-ar')));
    await tester.pumpAndSettle();
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(_direction(tester), TextDirection.rtl);
    expect(prefs.getString('app_locale'), 'ar');

    await tester.tap(find.byKey(const ValueKey('language-en')));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(_direction(tester), TextDirection.ltr);
  });

  testWidgets('la langue enregistrée est restaurée au démarrage', (tester) async {
    await _pump(tester, {'app_locale': 'ar'});
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(_direction(tester), TextDirection.rtl);
  });

  testWidgets('dates formatées selon la langue', (tester) async {
    await _pump(tester, {'app_locale': 'fr'});
    final context = tester.element(find.byType(LanguageList));
    expect(context.l10n.date(DateTime(2026, 10, 3)), '3 octobre 2026');
  });

  test('toutes les langues traduisent les mêmes clés', () async {
    for (final locale in AppLocales.supported) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.appTitle, isNotEmpty);
      expect(l10n.syncPending(3), contains('3'));
      expect(l10n.ruleUsersLimit('MOYEN', 7), contains('7'));
    }
  });
}
