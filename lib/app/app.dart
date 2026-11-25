import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/presentation/providers/auth_providers.dart';
import 'di/app_composition.dart';
import 'localization/l10n.dart';
import 'localization/locale_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class DubaGestApp extends ConsumerStatefulWidget {
  const DubaGestApp({super.key});

  @override
  ConsumerState<DubaGestApp> createState() => _DubaGestAppState();
}

class _DubaGestAppState extends ConsumerState<DubaGestApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        ref.read(authRepositoryProvider).handleAppResume();
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionSyncCoordinatorProvider);
    ref.watch(reserveNumerosProvider);
    ref.watch(photosEnAttenteProvider);
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // La direction (RTL pour l'arabe) découle de la locale.
      locale: locale,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
