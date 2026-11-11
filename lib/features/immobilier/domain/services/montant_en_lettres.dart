/// Convertisseur de montants entiers en lettres en français
/// Spécifique aux devises (FCFA, EUR, USD, etc.) pour les quittances et reçus de loyer.
class MontantEnLettres {
  static const _unites = [
    '', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
    'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize', 'dix-sept', 'dix-huit', 'dix-neuf'
  ];

  static const _dizaines = [
    '', '', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante', 'soixante', 'quatre-vingt', 'quatre-vingt'
  ];

  static String convertir(int nombre, {String devise = 'FCFA'}) {
    if (nombre == 0) {
      return 'zéro ${_libelleDevise(devise, 0)}';
    }

    if (nombre < 0) {
      return 'moins ${convertir(-nombre, devise: devise)}';
    }

    final texte = _convertirBloc(nombre).trim();
    // Majuscule au premier caractère
    final avecMajuscule = texte.isEmpty ? '' : '${texte[0].toUpperCase()}${texte.substring(1)}';
    final libelleDevise = _libelleDevise(devise, nombre);

    return '$avecMajuscule $libelleDevise'.trim();
  }

  static String _libelleDevise(String devise, int nombre) {
    switch (devise.toUpperCase()) {
      case 'XOF':
      case 'FCFA':
        return 'francs CFA';
      case 'EUR':
        return nombre > 1 ? 'euros' : 'euro';
      case 'USD':
        return nombre > 1 ? 'dollars' : 'dollar';
      case 'GNF':
        return 'francs guinéens';
      default:
        return devise;
    }
  }

  static String _convertirBloc(int n) {
    if (n < 20) {
      return _unites[n];
    }

    if (n < 100) {
      final dizaine = n ~/ 10;
      final reste = n % 10;

      if (dizaine == 7) {
        if (reste == 1) return 'soixante et onze';
        return 'soixante-${_unites[10 + reste]}';
      }

      if (dizaine == 9) {
        return 'quatre-vingt-${_unites[10 + reste]}';
      }

      if (reste == 0) {
        if (dizaine == 8) return 'quatre-vingts';
        return _dizaines[dizaine];
      }

      if (reste == 1 && dizaine < 8) {
        return '${_dizaines[dizaine]} et un';
      }

      return '${_dizaines[dizaine]}-${_unites[reste]}';
    }

    if (n < 1000) {
      final centaine = n ~/ 100;
      final reste = n % 100;

      String prefixe;
      if (centaine == 1) {
        prefixe = 'cent';
      } else {
        prefixe = '${_unites[centaine]} cent';
        if (reste == 0) prefixe += 's';
      }

      if (reste == 0) return prefixe;
      return '$prefixe ${_convertirBloc(reste)}';
    }

    if (n < 1000000) {
      final millier = n ~/ 1000;
      final reste = n % 1000;

      String prefixe;
      if (millier == 1) {
        prefixe = 'mille';
      } else {
        prefixe = '${_convertirBloc(millier)} mille';
      }

      if (reste == 0) return prefixe;
      return '$prefixe ${_convertirBloc(reste)}';
    }

    if (n < 1000000000) {
      final million = n ~/ 1000000;
      final reste = n % 1000000;

      final prefixe = million == 1 ? 'un million' : '${_convertirBloc(million)} millions';
      if (reste == 0) return prefixe;
      return '$prefixe ${_convertirBloc(reste)}';
    }

    final milliard = n ~/ 1000000000;
    final reste = n % 1000000000;
    final prefixe = milliard == 1 ? 'un milliard' : '${_convertirBloc(milliard)} milliards';
    if (reste == 0) return prefixe;
    return '$prefixe ${_convertirBloc(reste)}';
  }
}

