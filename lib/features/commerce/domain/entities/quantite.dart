/// Quantité exacte : dix-millièmes d'unité (4 décimales, comme `numeric(14,4)`
/// côté serveur). Jamais de flottant dans un calcul de stock :
/// 0,1 + 0,2 vaut exactement 0,3.
extension type const Qte(int brut) implements Object {
  static const zero = Qte(0);
  static const un = Qte(echelle);
  static const echelle = 10000;

  /// Depuis un nombre (JSON du serveur, saisie déjà convertie).
  factory Qte.depuis(num valeur) => Qte((valeur * echelle).round());

  /// Lit une saisie : « 12 », « 2,5 », « 2.5 », « 1/2 », « 2 1/4 ».
  /// `null` si le texte n'est pas un nombre positif.
  static Qte? lire(String texte) {
    // Espaces insécables (séparateurs de milliers) traités comme des espaces.
    final t = texte.trim().replaceAll(RegExp('[  ]'), ' ');
    if (t.isEmpty) return null;
    final fraction = RegExp(r'^(?:(\d+)\s+)?(\d+)\s*/\s*(\d+)$').firstMatch(t);
    if (fraction != null) {
      final entier = int.parse(fraction.group(1) ?? '0');
      final numerateur = int.parse(fraction.group(2)!);
      final denominateur = int.parse(fraction.group(3)!);
      if (denominateur == 0) return null;
      return Qte(entier * echelle + (numerateur * echelle / denominateur).round());
    }
    final normal = t.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    final v = double.tryParse(normal);
    if (v == null || v.isNaN || v.isInfinite || v < 0) return null;
    return Qte.depuis(v);
  }

  double get valeur => brut / echelle;
  bool get estNul => brut == 0;
  bool get estPositif => brut > 0;
  bool get estNegatif => brut < 0;
  bool get estEntier => brut % echelle == 0;

  Qte operator +(Qte autre) => Qte(brut + autre.brut);
  Qte operator -(Qte autre) => Qte(brut - autre.brut);
  Qte operator -() => Qte(-brut);
  bool operator <(Qte autre) => brut < autre.brut;
  bool operator <=(Qte autre) => brut <= autre.brut;
  bool operator >(Qte autre) => brut > autre.brut;
  bool operator >=(Qte autre) => brut >= autre.brut;

  /// Quantité × facteur (ex. 3 cartons × 40 = 120 pièces).
  Qte fois(Qte facteur) => Qte((brut * facteur.brut / echelle).round());

  /// Quantité ÷ facteur (ex. 120 pièces ÷ 40 = 3 cartons).
  Qte divisePar(Qte facteur) => facteur.brut == 0 ? Qte.zero : Qte((brut * echelle / facteur.brut).round());

  /// Nombre entier de lots contenus (ex. 130 pièces → 3 cartons de 40).
  int lotsEntiers(Qte facteur) => facteur.brut <= 0 ? 0 : brut ~/ facteur.brut;

  /// La quantité respecte-t-elle le pas (0,25 → 0,25 / 0,5 / 0,75…) ?
  bool estMultipleDe(Qte pas) => pas.brut <= 0 || brut % pas.brut == 0;

  Qte get absolue => Qte(brut.abs());
  Qte max(Qte autre) => brut >= autre.brut ? this : autre;

  /// Montant (unités entières de la devise) : quantité × prix unitaire.
  int montant(int prixUnitaire) => (brut * prixUnitaire / echelle).round();

  /// Valeur numérique pour le serveur (`numeric`).
  num get json => estEntier ? brut ~/ echelle : valeur;
}

extension SommeQte on Iterable<Qte> {
  Qte get somme => fold(Qte.zero, (a, b) => a + b);
}
