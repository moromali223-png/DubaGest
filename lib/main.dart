

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'app/config/config_providers.dart';
import 'app/di/app_composition.dart';
import 'core/database/app_database.dart';
import 'core/database/connection.dart';
import 'core/di/core_providers.dart';
import 'core/utils/app_logger.dart';

Future<void> main() async {
  // Web : URL réelles (/join-company?token=…) au lieu de « #/… » ; sans effet ailleurs.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error('Erreur Flutter', error: details.exception, stackTrace: details.stack);
  };

  final config = AppConfig.fromEnvironment();
  final prefs = await SharedPreferences.getInstance();
  // Restaure la session persistée (fonctionne hors-ligne).
  await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabaseKey);
  final database = AppDatabase(openAppDatabaseConnection());

  runApp(ProviderScope(
    // Comportement explicite : pas de nouvelle tentative automatique des
    // providers ; les réessais sont gérés par la sync et par l'utilisateur.
    retry: (_, _) => null,
    overrides: [
      appConfigProvider.overrideWithValue(config),
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseClientProvider.overrideWithValue(Supabase.instance.client),
      appDatabaseProvider.overrideWithValue(database),
      ...appOverrides,
    ],
    child: const DubaGestApp(),
  ));
}
