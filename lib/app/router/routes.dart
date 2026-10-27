import '../../features/agenda/domain/entities/agenda.dart';
import '../../features/commerce/domain/entities/commerce.dart' show StatutStock;
import '../../features/finances/domain/entities/finances.dart';
import '../../features/modules/domain/entities/app_module.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const onboarding = '/onboarding';
  static const createCompany = '/create-company';
  static const joinCompany = '/join-company';
  static const blocked = '/blocked';
  static const home = '/';
  static const administration = '/admin';
  static const declassementAbonnement = '/admin/abonnement/declassement';
  static const finances = '/finances';
  static const settings = '/settings';
  static const changePassword = '/settings/password';
  static const parametresPaiements = '/settings/paiements';
  static const accessDenied = '/access-denied';
  static const contacts = '/contacts';
  static const contactNew = '/contacts/new';
  static String contact(String id) => '/contacts/$id';
  static String contactEdit(String id) => '/contacts/$id/edit';

  static String financesOnglet(String moduleCode) => Uri(path: finances, queryParameters: {'onglet': moduleCode}).toString();
  static String dossierDette(String dossierKey, {SensEngagement sens = SensEngagement.aRecevoir}) => Uri(
        path: '/finances/dossiers/$dossierKey',
        queryParameters: {'sens': sens.code},
      ).toString();
  static String engagement(String id) => '/finances/engagements/$id';
  static String engagementModifier(String id) => '/finances/engagements/$id/edit';
  static String engagementNouveau(SensEngagement sens) => '/finances/engagements/new?sens=${sens.code}';
  static String paiement(String id) => '/finances/paiements/$id';
  static String paiementNouveau({String? engagementId}) => Uri(
        path: '/finances/paiements/new',
        queryParameters: {'engagement': ?engagementId},
      ).toString();
  static const caisseNouvelle = '/finances/caisses/new';
  static String caisse(String id) => '/finances/caisses/$id';
  static const depenseNouvelle = '/finances/depenses/new';
  static String depense(String id) => '/finances/depenses/$id';
  static const financeRevenus = '/finances/revenus';
  static const financeCharges = '/finances/charges';
  static const financeTresorerie = '/finances/tresorerie';
  static const financeCreancesDettes = '/finances/creances-dettes';
  static const financeRapport = '/finances/rapport';
  static const categoriesDepenses = '/finances/categories';
  static const recherche = '/recherche';
  static const rapports = '/rapports';
  static String rapport(String type) => '/rapports/$type';
  static const tableauDeBord = '/tableau-de-bord';
  static const agenda = '/agenda';
  static const notifications = '/notifications';
  static String echeance(String id) => '/agenda/$id';
  static String echeanceModifier(String id) => '/agenda/$id/edit';
  static String echeanceNouvelle({CibleType? cibleType, String? cibleId, String? titre}) => Uri(
        path: '/agenda/new',
        queryParameters: {'cible_type': ?cibleType?.code, 'cible_id': ?cibleId, 'titre': ?titre},
      ).toString();
  static const documents = '/documents';
  static String documentNouveau({String? type, String? contactId}) => Uri(
        path: '/documents/new',
        queryParameters: {'type': ?type, 'contact_id': ?contactId},
      ).toString();
  static String document(String id) => '/documents/$id';

  static String contactNouveau({String? relation}) =>
      Uri(path: contactNew, queryParameters: {'relation': ?relation}).toString();

  // Commerce
  static const stock = '/stock';
  static String stockFiltre(StatutStock statut) => Uri(path: stock, queryParameters: {'statut': statut.name}).toString();
  static const mouvementsStock = '/stock/mouvements';
  static String mouvementsProduit(String produitId) =>
      Uri(path: mouvementsStock, queryParameters: {'produit': produitId}).toString();
  static const produits = '/commerce/produits';
  static String produitNouveau({String? codeBarres, String? categorieId}) => Uri(
        path: '/commerce/produits/new',
        queryParameters: {'code': ?codeBarres, 'categorie': ?categorieId},
      ).toString();
  static String produit(String id) => '/commerce/produits/$id';
  static String produitModifier(String id) => '/commerce/produits/$id/edit';
  static const categoriesProduits = '/commerce/produits/categories';
  static const achats = '/commerce/achats';
  static String achatNouveau({String? fournisseurId, String? produitId, String? bonCommandeId}) => Uri(
        path: '/commerce/achats/new',
        queryParameters: {
          'fournisseur': ?fournisseurId,
          'produit': ?produitId,
          'bon_commande': ?bonCommandeId,
        },
      ).toString();
  static String achat(String id) => '/commerce/achats/$id';
  static String achatModifier(String id) => '/commerce/achats/$id/edit';
  static const ventes = '/commerce/ventes';
  static String venteAvec(String produitId) => Uri(path: ventes, queryParameters: {'produit': produitId}).toString();
  static const historiqueVentes = '/commerce/ventes/historique';
  static String vente(String id) => '/commerce/ventes/$id';
  static const fournisseurs = '/commerce/fournisseurs';
  static String fournisseur(String id) => '/commerce/fournisseurs/$id';
  static const commerceIntelligence = '/commerce/intelligence';

  // Services
  static const servicesAccueil = '/services';
  static const servicesPrestations = '/services/prestations';
  static const prestationNouvelle = '/services/prestations/new';
  static String prestation(String id) => '/services/prestations/$id';
  static String prestationModifier(String id) => '/services/prestations/$id/edit';
  static const servicesPlanning = '/services/planning';
  static const planningNouveau = '/services/planning/new';
  static String planningNouveauAvecDate(DateTime date, {String? contactId}) => Uri(
        path: '/services/planning/new',
        queryParameters: {
          'date': date.toIso8601String(),
          'contactId': ?contactId,
        },
      ).toString();
  static const servicesCatalogue = '/services/catalogue';
  static const serviceNouveau = '/services/catalogue/new';
  static String serviceModifier(String id) => '/services/catalogue/$id/edit';
  static const servicesDevis = '/services/devis';
  static const devisNouveau = '/services/devis/new';
  static String devis(String id) => '/services/devis/$id';
  static const servicesRapports = '/services/rapports';

  // Immobilier
  static const immobilierBiens = '/immobilier/biens';
  static const bienNouveau = '/immobilier/biens/new';
  static String bienDetails(String id) => '/immobilier/biens/$id';
  static String bienModifier(String id) => '/immobilier/biens/$id/edit';
  static const immobilierProprietaires = '/immobilier/proprietaires';
  static String proprietaireDetails(String id) => '/immobilier/proprietaires/$id';
  static const immobilierLocataires = '/immobilier/locataires';
  static String locataireDetails(String id) => '/immobilier/locataires/$id';
  static const immobilierLocations = '/immobilier/locations';
  static const locationNouvelle = '/immobilier/locations/new';
  static String locationDetails(String id) => '/immobilier/locations/$id';
  static const immobilierContrats = '/immobilier/contrats';
  static const contratNouveau = '/immobilier/contrats/new';
  static String contratDetails(String id) => '/immobilier/contrats/$id';
  static String contratModifier(String id) => '/immobilier/contrats/$id/edit';
  static const immobilierLoyers = '/immobilier/loyers';
  static String loyerDetails(String id) => '/immobilier/loyers/$id';
  static const loyerRecevoir = '/immobilier/loyers/recevoir';
  static String loyerRecevoirAvec({String? echeanceId, String? bienId, String? locataireId}) => Uri(
        path: loyerRecevoir,
        queryParameters: {
          'echeanceId': ?echeanceId,
          'bienId': ?bienId,
          'locataireId': ?locataireId,
        },
      ).toString();
  static const immobilierDashboard = '/immobilier/dashboard';

  // Administration Centrale DubaGest (Super Admin)
  static const superAdmin = '/super-admin';
  static const superAdminEntreprises = '/super-admin/entreprises';
  static String superAdminEntreprise(String id) => '/super-admin/entreprises/$id';
  static const superAdminSponsorises = '/super-admin/sponsorises';
  static const superAdminAudit = '/super-admin/audit';

  /// Accessibles sans session.
  static const publicRoutes = {login, register, forgotPassword, joinCompany};

  /// Accessibles à un compte connecté sans entreprise.
  static const sansEntreprise = {onboarding, createCompany, joinCompany};
}

/// Correspondance module → écran. Un module sans écran dédié ouvre la page
/// générique « bientôt disponible », toujours protégée par la garde d'accès.
abstract final class ModuleRoutes {
  static const _dedicated = {
    ModuleCodes.adminEntreprise: '/admin/entreprise',
    ModuleCodes.adminUtilisateurs: '/admin/utilisateurs',
    ModuleCodes.adminPerimetres: '/admin/perimetres',
    ModuleCodes.adminAbonnement: '/admin/abonnement',
    ModuleCodes.adminAudit: '/admin/audit',
    ModuleCodes.commerceStock: Routes.stock,
    ModuleCodes.commerceProduits: Routes.produits,
    ModuleCodes.commerceAchats: Routes.achats,
    ModuleCodes.commerceVentes: Routes.ventes,
    ModuleCodes.commerceFournisseurs: Routes.fournisseurs,
    ModuleCodes.commerceIntelligence: Routes.commerceIntelligence,
    ModuleCodes.communContacts: Routes.contacts,
    ModuleCodes.communDocuments: Routes.documents,
    ModuleCodes.communAgenda: Routes.agenda,
    ModuleCodes.communRapports: Routes.rapports,
    ModuleCodes.servicesPrestations: Routes.servicesPrestations,
    ModuleCodes.servicesServices: Routes.servicesCatalogue,
    ModuleCodes.servicesPlanning: Routes.servicesPlanning,
    ModuleCodes.servicesDevis: Routes.servicesDevis,
    ModuleCodes.servicesRapports: Routes.servicesRapports,
    ModuleCodes.servicesFacturation: Routes.documents,
    ModuleCodes.immobilierBiens: Routes.immobilierBiens,
    ModuleCodes.immobilierProprietaires: Routes.immobilierProprietaires,
    ModuleCodes.immobilierLocataires: Routes.immobilierLocataires,
    ModuleCodes.immobilierLocations: Routes.immobilierLocations,
    ModuleCodes.immobilierContrats: Routes.immobilierContrats,
    ModuleCodes.immobilierLoyers: Routes.immobilierLoyers,
  };

  static String path(String moduleCode) =>
      _dedicated[moduleCode] ??
      (moduleCode.startsWith('finances.') ? Routes.financesOnglet(moduleCode) : '/modules/$moduleCode');
}
