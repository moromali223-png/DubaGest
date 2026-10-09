import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou i18n : chaque texte existe en français, anglais et arabe, avec
/// les mêmes paramètres. Un oubli fait échouer les tests.
void main() {
  Map<String, String> charger(String langue) {
    final json = jsonDecode(File('lib/app/localization/arb/app_$langue.arb').readAsStringSync())
        as Map<String, dynamic>;
    return {
      for (final e in json.entries)
        if (!e.key.startsWith('@')) e.key: e.value as String,
    };
  }

  final fr = charger('fr');
  final langues = {'en': charger('en'), 'ar': charger('ar')};

  /// Paramètres {nom} d'un message (hors mots-clés ICU plural/select).
  Set<String> parametres(String message) => RegExp(r'\{(\w+)(?:,|\})')
      .allMatches(message)
      .map((m) => m.group(1)!)
      .where((p) => p != 'plural' && p != 'select')
      .toSet();

  for (final MapEntry(key: code, value: messages) in langues.entries) {
    test('$code : aucune clé manquante ni en trop par rapport au français', () {
      expect(fr.keys.toSet().difference(messages.keys.toSet()), isEmpty, reason: 'manquantes en $code');
      expect(messages.keys.toSet().difference(fr.keys.toSet()), isEmpty, reason: 'en trop en $code');
    });

    test('$code : mêmes paramètres et aucun texte vide', () {
      for (final MapEntry(:key, :value) in fr.entries) {
        final traduction = messages[key];
        if (traduction == null) continue;
        expect(traduction.trim(), isNotEmpty, reason: '$key vide en $code');
        expect(parametres(traduction), parametres(value), reason: 'paramètres de $key en $code');
      }
    });
  }

  test('l\'arabe est réellement traduit (pas de copie du français)', () {
    final identiques = fr.entries
        .where((e) =>
            langues['ar']![e.key] == e.value &&
            RegExp('[a-zA-Zàâçéèêëîïôûùüÿœ]{4,}').hasMatch(e.value.replaceAll(RegExp(r'\{[^}]*\}'), '')))
        .map((e) => e.key)
        // Noms propres et langues affichées dans leur propre écriture.
        .where((k) => !{'appTitle', 'languageFrench', 'languageEnglish'}.contains(k))
        .toList();
    expect(identiques, isEmpty);
  });
}
