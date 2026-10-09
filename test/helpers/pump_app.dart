import 'package:dubagest/app/localization/l10n.dart';
import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/core/di/core_providers.dart';
import 'package:dubagest/core/di/sync_providers.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Monte un écran avec thème, traductions et providers surchargés.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Locale locale = const Locale('fr'),
  Size? size,
  bool settle = true,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  SharedPreferences.setMockInitialValues({'app_locale': locale.languageCode});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      syncStateProvider.overrideWith((ref) => Stream.value(const SyncState())),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  ));
  // Un indicateur de progression animé ne « se stabilise » jamais.
  settle ? await tester.pumpAndSettle() : await tester.pump();
}
