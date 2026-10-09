import '../../../activites/domain/entities/activite.dart';
import '../../../modules/domain/entities/app_module.dart';

/// Onglets de la barre du bas (5 positions : Accueil, Module principal, Action +, Finances, Compte).
enum NavDestination {
  accueil,
  stock,
  prestations,
  loyers,
  ventes,
  finances,
  compte,
}

/// Type de l'action principale du bouton central (Position 3).
enum QuickActionType {
  /// Commerce seul : Vendre
  vendre,

  /// Services seul : Prester
  prester,

  /// Immobilier seul : Encaisser
  encaisser,

  /// Multi-activités : Menu d'actions rapides contextuelles
  multi,
}

class ModuleSection {
  const ModuleSection({required this.activite, required this.modules});
  final ActiviteCode activite;
  final List<AppModule> modules;
}

/// Navigation autorisée pour l'utilisateur courant, calculée — jamais figée.
class NavigationModel {
  const NavigationModel({
    required this.destinations,
    required this.sections,
    this.modulesCommuns = const [],
    this.modulesFinances = const [],
    required this.modulesAdministration,
    required this.abonnementActif,
    this.venteDisponible = false,
    this.actionCentrale,
    this.activiteActive,
    this.isWorkspaceVendeur = false,
    this.isWorkspaceGestionnaireStock = false,
  });

  final List<NavDestination> destinations;

  /// Modules métier groupés par activité active.
  final List<ModuleSection> sections;

  /// Outils partagés par toutes les activités (contacts…), quelle que soit
  /// l'activité de travail choisie.
  final List<AppModule> modulesCommuns;

  /// Onglets de la page Finances (à recevoir / paiements / caisse).
  final List<AppModule> modulesFinances;
  final List<AppModule> modulesAdministration;
  final bool abonnementActif;

  /// Action principale disponible : Vendre, Prester, Encaisser ou menu multi.
  final bool venteDisponible;
  final QuickActionType? actionCentrale;
  final ActiviteCode? activiteActive;
  final bool isWorkspaceVendeur;
  final bool isWorkspaceGestionnaireStock;
}
