/// Mode d'utilisation choisi par le commerçant à l'inscription.
enum ModeUtilisation {
  /// MODE A — DUBAGEST GESTION + CATALOGUE
  /// Outils complets de gestion (stock, ventes, achats, caisse, finances)
  /// + catalogue numérique public connecté au stock.
  /// Formules mensuelles (FAIBLE / MOYEN / PRO) avec 10 jours d'essai.
  gestionComplete('GESTION'),

  /// MODE B — DUBAGEST CATALOGUE SEUL
  /// Vitrine numérique commerciale, messages vocaux, vidéos, commandes WhatsApp.
  /// Sans gestion de stock complexe ni modules financiers.
  /// Formule annuelle : 3 000 FCFA / an (sans essai gratuit).
  catalogueSeul('CATALOGUE_SEUL');

  const ModeUtilisation(this.code);
  final String code;

  bool get isCatalogueSeul => this == ModeUtilisation.catalogueSeul;
  bool get isGestionComplete => this == ModeUtilisation.gestionComplete;

  static ModeUtilisation fromCode(String? code) {
    if (code == 'CATALOGUE_SEUL' || code == 'catalogue') {
      return ModeUtilisation.catalogueSeul;
    }
    return ModeUtilisation.gestionComplete;
  }
}
