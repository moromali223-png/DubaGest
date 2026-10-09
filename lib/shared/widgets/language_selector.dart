import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../app/localization/locale_controller.dart';

String _nativeName(AppLocalizations l10n, Locale locale) => switch (locale.languageCode) {
      'ar' => l10n.languageArabic,
      'en' => l10n.languageEnglish,
      _ => l10n.languageFrench,
    };

/// Bouton compact (écran de connexion, barre d'application).
class LanguageMenuButton extends ConsumerWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeControllerProvider);
    final l10n = context.l10n;
    return PopupMenuButton<Locale>(
      tooltip: l10n.languageLabel,
      icon: const Icon(Icons.translate),
      initialValue: current,
      onSelected: (l) => ref.read(localeControllerProvider.notifier).setLocale(l),
      itemBuilder: (_) => [
        for (final l in AppLocales.supported)
          PopupMenuItem(value: l, child: Text(_nativeName(l10n, l))),
      ],
    );
  }
}

/// Liste de choix (écran Paramètres).
class LanguageList extends ConsumerWidget {
  const LanguageList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeControllerProvider);
    final l10n = context.l10n;
    return Column(
      children: [
        for (final l in AppLocales.supported)
          ListTile(
            key: ValueKey('language-${l.languageCode}'),
            title: Text(_nativeName(l10n, l)),
            trailing: l == current ? const Icon(Icons.check) : null,
            selected: l == current,
            onTap: () => ref.read(localeControllerProvider.notifier).setLocale(l),
          ),
      ],
    );
  }
}
