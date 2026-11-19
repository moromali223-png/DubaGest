/// Fiche de l'entreprise (identité, coordonnées, informations légales).
class ProfilEntreprise {
  const ProfilEntreprise({
    required this.id,
    required this.nom,
    required this.devise,
    required this.langueDocuments,
    this.pays,
    this.telephone,
    this.adresse,
    this.ville,
    this.identifiantFiscal,
    this.registreCommerce,
    this.logoPath,
    this.modesPaiement = tousLesModes,
    this.piedRecu,
    this.slug,
    this.whatsappCommercial,
    this.descriptionCommerciale,
    this.estCatalogueActif = true,
  });

  /// Devises proposées (code ISO 4217). XOF (FCFA) par défaut.
  static const devises = ['XOF', 'XAF', 'GNF', 'MAD', 'DZD', 'TND', 'MRU', 'NGN', 'GHS', 'EUR', 'USD'];

  /// Catalogue commun des modes de paiement (codes serveur), dans l'ordre.
  static const tousLesModes = ['ESPECES', 'MOBILE_MONEY', 'CARTE', 'VIREMENT', 'CHEQUE', 'AUTRE'];

  /// Longueur maximale de la mention en bas des reçus.
  static const piedRecuMax = 300;

  final String id;
  final String nom;
  final String devise;
  final String langueDocuments;
  final String? pays;
  final String? telephone;
  final String? adresse;
  final String? ville;
  final String? identifiantFiscal;
  final String? registreCommerce;

  /// Chemin du logo dans le stockage (bucket « fichiers »).
  final String? logoPath;

  /// Modes proposés par l'entreprise (codes serveur, ordre du catalogue).
  final List<String> modesPaiement;

  /// Mention imprimée en bas des reçus (figée à l'émission).
  final String? piedRecu;

  /// Identifiant d'URL publique (slug boutique e.g. dubagest.com/boutique/mon-magasin)
  final String? slug;

  /// Numéro WhatsApp dédié aux commandes du catalogue
  final String? whatsappCommercial;

  /// Présentation commerciale de la boutique
  final String? descriptionCommerciale;

  /// Indique si la vitrine/catalogue public est actif
  final bool estCatalogueActif;

  ProfilEntreprise copyWith({
    String? nom,
    String? devise,
    String? langueDocuments,
    String? pays,
    String? telephone,
    String? adresse,
    String? ville,
    String? identifiantFiscal,
    String? registreCommerce,
    String? logoPath,
    List<String>? modesPaiement,
    String? piedRecu,
    String? slug,
    String? whatsappCommercial,
    String? descriptionCommerciale,
    bool? estCatalogueActif,
  }) =>
      ProfilEntreprise(
        id: id,
        nom: nom ?? this.nom,
        devise: devise ?? this.devise,
        langueDocuments: langueDocuments ?? this.langueDocuments,
        pays: pays ?? this.pays,
        telephone: telephone ?? this.telephone,
        adresse: adresse ?? this.adresse,
        ville: ville ?? this.ville,
        identifiantFiscal: identifiantFiscal ?? this.identifiantFiscal,
        registreCommerce: registreCommerce ?? this.registreCommerce,
        logoPath: logoPath ?? this.logoPath,
        modesPaiement: modesPaiement ?? this.modesPaiement,
        piedRecu: piedRecu ?? this.piedRecu,
        slug: slug ?? this.slug,
        whatsappCommercial: whatsappCommercial ?? this.whatsappCommercial,
        descriptionCommerciale: descriptionCommerciale ?? this.descriptionCommerciale,
        estCatalogueActif: estCatalogueActif ?? this.estCatalogueActif,
      );
}
