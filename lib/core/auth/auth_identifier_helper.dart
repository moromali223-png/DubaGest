/// Type d'identifiant détecté pour l'authentification (E-mail ou Téléphone).
enum AuthIdentifierType {
  email,
  phone,
  invalid,
}

/// Résultat de l'analyse et normalisation d'un identifiant de connexion / inscription.
class AuthIdentifier {
  const AuthIdentifier({
    required this.type,
    required this.raw,
    required this.normalized,
  });

  final AuthIdentifierType type;
  final String raw;
  final String normalized;

  bool get isEmail => type == AuthIdentifierType.email;
  bool get isPhone => type == AuthIdentifierType.phone;
  bool get isValid => type != AuthIdentifierType.invalid;

  /// Analyse une saisie utilisateur, détermine s'il s'agit d'un email ou d'un téléphone,
  /// et normalise au format standard (minuscules pour email, E.164 pour téléphone avec +223 par défaut si national).
  static AuthIdentifier parse(String input, {String defaultCountryCode = '+223'}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return AuthIdentifier(type: AuthIdentifierType.invalid, raw: input, normalized: '');
    }

    // 1. Détection Email : contient un '@' et un point après
    if (trimmed.contains('@')) {
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (emailRegex.hasMatch(trimmed)) {
        return AuthIdentifier(
          type: AuthIdentifierType.email,
          raw: trimmed,
          normalized: trimmed.toLowerCase(),
        );
      } else {
        return AuthIdentifier(
          type: AuthIdentifierType.invalid,
          raw: trimmed,
          normalized: trimmed.toLowerCase(),
        );
      }
    }

    // 2. Détection Téléphone : suppression des espaces, tirets, parenthèses et points
    final cleanDigits = trimmed.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    
    // Vérifie si la chaîne contient principalement des chiffres et optionnellement un '+' au début
    final phoneCharRegex = RegExp(r'^\+?[0-9]{6,15}$');
    if (phoneCharRegex.hasMatch(cleanDigits)) {
      String e164;
      if (cleanDigits.startsWith('+')) {
        e164 = cleanDigits;
      } else if (cleanDigits.startsWith('00')) {
        // Préfixe international 00xx -> +xx
        e164 = '+${cleanDigits.substring(2)}';
      } else if (cleanDigits.length == 8) {
        // Format national malien standard à 8 chiffres (ex: 76123456, 66123456, 20223344)
        e164 = '$defaultCountryCode$cleanDigits';
      } else if (cleanDigits.length == 9 && cleanDigits.startsWith('0')) {
        // Format national avec 0 initial
        e164 = '$defaultCountryCode${cleanDigits.substring(1)}';
      } else {
        // Par défaut si pas d'indicatif fourni
        e164 = cleanDigits.startsWith(defaultCountryCode.replaceAll('+', ''))
            ? '+$cleanDigits'
            : '$defaultCountryCode$cleanDigits';
      }

      return AuthIdentifier(
        type: AuthIdentifierType.phone,
        raw: trimmed,
        normalized: e164,
      );
    }

    return AuthIdentifier(type: AuthIdentifierType.invalid, raw: trimmed, normalized: trimmed);
  }
}
