/// Normalisation pour la recherche (insensible à la casse, aux accents et aux
/// variantes d'écriture de l'arabe) : « Amadou », « AMADOU » et « Amadoû »
/// se retrouvent ; « أحمد », « احمد » et « أَحْمَد » aussi.
String normaliserRecherche(String? texte) {
  if (texte == null || texte.isEmpty) return '';
  final sortie = StringBuffer();
  for (final rune in texte.toLowerCase().runes) {
    // Diacritiques arabes (tashkil), alef suscrit, tatweel : ignorés.
    if ((rune >= 0x064B && rune <= 0x065F) || rune == 0x0670 || rune == 0x0640) continue;
    final c = String.fromCharCode(rune);
    sortie.write(_equivalents[c] ?? c);
  }
  return sortie.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Chiffres seuls (téléphones) : « +223 70 11-22 » → « 223701122 ».
String chiffresSeuls(String? texte) => (texte ?? '').replaceAll(RegExp(r'\D'), '');

const _equivalents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o',
  'û': 'u', 'ù': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
  // Arabe : formes de l'alef, alef maqsura, ta marbuta.
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
  'ى': 'ي', 'ة': 'ه',
};
