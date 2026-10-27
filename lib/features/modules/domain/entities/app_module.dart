import '../../../activites/domain/entities/activite.dart';

/// Codes des modules ayant un comportement spécifique dans l'application.
abstract final class ModuleCodes {
  static const adminEntreprise = 'admin.entreprise';
  static const adminUtilisateurs = 'admin.utilisateurs';
  static const adminPerimetres = 'admin.perimetres';
  static const adminAbonnement = 'admin.abonnement';
  static const adminAudit = 'admin.audit';
  static const commerceVentes = 'commerce.ventes';
  static const commerceProduits = 'commerce.produits';
  static const commerceAchats = 'commerce.achats';
  static const commerceStock = 'commerce.stock';
  static const commerceFournisseurs = 'commerce.fournisseurs';
  static const commerceIntelligence = 'commerce.intelligence';
  static const communContacts = 'commun.contacts';
  static const communDocuments = 'commun.documents';
  static const communAgenda = 'commun.agenda';
  static const communRapports = 'commun.rapports';
  static const financesCreances = 'finances.creances';
  static const financesPaiements = 'finances.paiements';
  static const financesCaisse = 'finances.caisse';
  static const financesDepenses = 'finances.depenses';
  static const servicesPrestations = 'services.prestations';
  static const servicesServices = 'services.services';
  static const servicesPlanning = 'services.planning';
  static const servicesDevis = 'services.devis';
  static const servicesRapports = 'services.rapports';
  static const servicesFacturation = 'services.facturation';
  static const immobilierBiens = 'immobilier.biens';
  static const immobilierProprietaires = 'immobilier.proprietaires';
  static const immobilierLocataires = 'immobilier.locataires';
  static const immobilierLocations = 'immobilier.locations';
  static const immobilierContrats = 'immobilier.contrats';
  static const immobilierLoyers = 'immobilier.loyers';
}

/// Catégorie d'un module (`modules.categorie`).
enum ModuleCategorie {
  /// Paramétrage de l'entreprise (menu ☰ › Administration).
  administration('ADMIN'),

  /// Outil partagé par toutes les activités (contacts, agenda…).
  commun('COMMUN'),

  /// Module propre à une activité.
  metier('METIER'),

  /// Noyau financier, regroupé dans l'onglet Finances.
  finances('FINANCES');

  const ModuleCategorie(this.code);
  final String code;

  static ModuleCategorie? tryParse(String? code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }
}

/// Module fonctionnel (table `public.modules`).
class AppModule {
  const AppModule({
    required this.code,
    required this.activite,
    required this.permissionAcces,
    required this.ordre,
    ModuleCategorie? categorie,
  }) : _categorie = categorie;

  final String code;

  /// `null` : module transverse (administration ou commun).
  final ActiviteCode? activite;
  final String permissionAcces;
  final int ordre;
  final ModuleCategorie? _categorie;

  ModuleCategorie get categorie {
    if (_categorie != null) return _categorie;
    if (code.startsWith('finances.')) return ModuleCategorie.finances;
    if (code.startsWith('commun.')) return ModuleCategorie.commun;
    if (code.startsWith('admin.')) return ModuleCategorie.administration;
    return activite == null ? ModuleCategorie.administration : ModuleCategorie.metier;
  }

  bool get estAdministration => categorie == ModuleCategorie.administration;
  bool get estCommun => categorie == ModuleCategorie.commun;
  bool get estFinances => categorie == ModuleCategorie.finances;

  AppModule copyWith({
    String? code,
    ActiviteCode? activite,
    String? permissionAcces,
    int? ordre,
    ModuleCategorie? categorie,
  }) {
    return AppModule(
      code: code ?? this.code,
      activite: activite ?? this.activite,
      permissionAcces: permissionAcces ?? this.permissionAcces,
      ordre: ordre ?? this.ordre,
      categorie: categorie ?? _categorie,
    );
  }
}

