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
        logoPath: logoPath,
        modesPaiement: modesPaiement,
        piedRecu: piedRecu,
      );
}
