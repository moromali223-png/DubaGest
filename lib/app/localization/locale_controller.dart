import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/di/core_providers.dart';
import 'generated/app_localizations.dart';

/// Langues proposées. Ajouter une langue = un fichier ARB + une entrée ici.
abstract final class AppLocales {
  static const fr = Locale('fr');
  static const ar = Locale('ar');
  static const en = Locale('en');

  static const supported = AppLocalizations.supportedLocales;
  static const fallback = fr;

  static Locale resolve(Locale? device) {
    if (device == null) return fallback;
    return supported.firstWhere(
      (l) => l.languageCode == device.languageCode,
      orElse: () => fallback,
    );
  }
}

/// Langue courante, persistée. Le changement s'applique immédiatement
/// (MaterialApp reconstruit, Directionality RTL pour l'arabe).
class LocaleController extends Notifier<Locale> {
  static const _key = 'app_locale';

  @override
  Locale build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    final locale = saved != null
        ? AppLocales.resolve(Locale(saved))
        : AppLocales.resolve(WidgetsBinding.instance.platformDispatcher.locale);
    Intl.defaultLocale = locale.languageCode;
    return locale;
  }

  Future<void> setLocale(Locale locale) async {
    final resolved = AppLocales.resolve(locale);
    Intl.defaultLocale = resolved.languageCode;
    state = resolved;
    await ref.read(sharedPreferencesProvider).setString(_key, resolved.languageCode);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);
