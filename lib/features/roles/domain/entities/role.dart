import '../../../activites/domain/entities/activite.dart';

/// Codes des rôles V1 (table `public.roles`). Les droits d'un rôle sont
/// définis par ses permissions, jamais par des tests sur ces codes.
abstract final class RoleCodes {
  static const administrateur = 'ADMINISTRATEUR';
  static const superviseur = 'SUPERVISEUR';
  static const gestionnaireStock = 'GESTIONNAIRE_STOCK';
  static const vendeur = 'VENDEUR';
  static const caissier = 'CAISSIER';
  static const gestionnaireImmobilier = 'GESTIONNAIRE_IMMOBILIER';
}

class Role {
  const Role({
    required this.code,
    required this.activite,
    required this.accesTousPerimetres,
  });

  final String code;

  /// `null` : rôle transverse à l'entreprise.
  final ActiviteCode? activite;

  /// Le rôle porte la permission `perimetres.access_all`.
  final bool accesTousPerimetres;
}
