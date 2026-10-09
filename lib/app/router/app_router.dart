import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/permissions/permission_codes.dart';
import '../../features/abonnement/presentation/pages/abonnement_page.dart';
import '../../features/audit/presentation/pages/audit_page.dart';
import '../../features/authentication/domain/entities/auth_state.dart';
import '../../features/authentication/presentation/pages/change_password_page.dart';
import '../../features/authentication/presentation/pages/forgot_password_page.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/pages/onboarding_page.dart';
import '../../features/authentication/presentation/pages/register_page.dart';
import '../../features/contacts/domain/entities/contact.dart';
import '../../features/contacts/presentation/pages/contact_detail_page.dart';
import '../../features/contacts/presentation/pages/contact_form_page.dart';
import '../../features/contacts/presentation/pages/contacts_page.dart';
import '../../features/contacts/presentation/providers/contacts_providers.dart';
import '../../features/agenda/domain/entities/agenda.dart';
import '../../features/agenda/presentation/pages/agenda_page.dart';
import '../../features/agenda/presentation/pages/echeance_form_page.dart';
import '../../features/agenda/presentation/pages/notifications_page.dart';
import '../../features/agenda/presentation/providers/agenda_providers.dart';
import '../../features/documents/presentation/pages/documents_page.dart';
import '../../features/rapports/domain/rapports.dart';
import '../../features/rapports/presentation/rapports_page.dart';
import '../../features/recherche/presentation/recherche_page.dart';
import '../../features/tableau_de_bord/presentation/tableau_de_bord_page.dart';
import '../../features/entreprise/presentation/pages/create_company_page.dart';
import '../../features/invitations/presentation/pages/join_company_page.dart';
import '../../features/invitations/presentation/providers/invitations_providers.dart';
import '../../features/authentication/presentation/providers/auth_providers.dart';
import '../../features/entreprise/domain/entities/contexte_session.dart';
import '../../features/entreprise/presentation/pages/contexte_bloque_page.dart';
import '../../features/entreprise/presentation/pages/entreprise_page.dart';
import '../../features/entreprise/presentation/pages/splash_page.dart';
import '../../features/entreprise/presentation/providers/contexte_providers.dart';
import '../../features/modules/domain/entities/app_module.dart';
import '../../features/navigation/presentation/pages/access_denied_page.dart';
import '../../features/navigation/domain/entities/navigation_model.dart';
import '../../features/navigation/presentation/pages/administration_page.dart';
import '../../features/finances/domain/entities/finances.dart';
import '../../features/finances/domain/usecases/gerer_finances.dart';
import '../../features/finances/presentation/pages/caisse_page.dart';
import '../../features/finances/presentation/pages/depense_form_page.dart';
import '../../features/finances/presentation/pages/depenses_page.dart';
import '../../features/finances/presentation/pages/dossier_dette_page.dart';
import '../../features/finances/presentation/pages/engagement_form_page.dart';
import '../../features/finances/presentation/pages/engagement_page.dart';
import '../../features/finances/presentation/pages/finances_page.dart';
import '../../features/finances/presentation/pages/paiement_form_page.dart';
import '../../features/finances/presentation/pages/paiement_page.dart';
import '../../features/finances/presentation/pages/finance_revenus_page.dart';
import '../../features/finances/presentation/pages/finance_charges_page.dart';
import '../../features/finances/presentation/pages/finance_tresorerie_page.dart';
import '../../features/finances/presentation/pages/finance_creances_dettes_page.dart';
import '../../features/finances/presentation/pages/finance_rapport_page.dart';
import '../../features/finances/presentation/providers/finances_providers.dart';
import '../../features/navigation/presentation/pages/home_page.dart';
import '../../features/navigation/presentation/pages/module_placeholder_page.dart';
import '../../features/navigation/presentation/providers/navigation_providers.dart';
import '../../features/navigation/presentation/widgets/app_shell.dart';
import '../../features/parametres/presentation/pages/parametres_paiements_page.dart';
import '../../features/parametres/presentation/pages/parametres_page.dart';
import '../../features/perimetres/presentation/pages/perimetres_page.dart';
import '../../features/commerce/domain/entities/commerce.dart' show StatutStock;
import '../../features/commerce/presentation/commerce_providers.dart';
import '../../features/commerce/presentation/pages/achat_form_page.dart';
import '../../features/commerce/presentation/pages/achat_page.dart';
import '../../features/commerce/presentation/pages/achats_page.dart';
import '../../features/commerce/presentation/pages/categories_page.dart';
import '../../features/commerce/presentation/pages/fournisseurs_page.dart';
import '../../features/commerce/presentation/pages/mouvements_page.dart';
import '../../features/commerce/presentation/pages/produit_form_page.dart';
import '../../features/commerce/presentation/pages/produit_page.dart';
import '../../features/commerce/presentation/pages/produits_page.dart';
import '../../features/commerce/presentation/pages/stock_page.dart';
import '../../features/commerce/presentation/pages/vente_page.dart';
import '../../features/commerce/presentation/pages/ventes_page.dart';
import '../../features/utilisateurs/presentation/pages/utilisateurs_page.dart';
import '../../features/services/presentation/pages/services_accueil_page.dart';
import '../../features/services/presentation/pages/prestations_page.dart';
import '../../features/services/presentation/pages/prestation_form_page.dart';
import '../../features/services/presentation/pages/prestation_details_page.dart';
import '../../features/services/presentation/pages/services_planning_page.dart';
import '../../features/services/presentation/pages/services_catalogue_page.dart';
import '../../features/services/presentation/pages/service_form_page.dart';
import '../../features/services/presentation/pages/services_devis_page.dart';
import '../../features/services/presentation/pages/devis_form_page.dart';
import '../../features/services/presentation/pages/devis_details_page.dart';
import '../../features/services/presentation/pages/services_rapport_page.dart';
import '../../features/services/presentation/services_providers.dart';
import 'routes.dart';

/// Décision de redirection globale, pure et testable.
@visibleForTesting
///
/// L'URL ne suffit jamais : chaque destination est recalculée depuis l'état
/// réel (session → contexte → invitation en attente → entreprise / rôle).
String? globalRedirect({
  required String location,
  required AuthState? auth,
  required ContexteSession? contexte,
  String? invitationEnAttente,
}) {
  String? aller(String cible) => location == cible ? null : cible;
  final isPublic = Routes.publicRoutes.contains(location);

  if (auth == null || auth is AuthUnknown) return aller(Routes.splash);
  if (auth is Unauthenticated) return isPublic ? null : Routes.login;
  if (auth is Authenticated && auth.passwordRecovery) return aller(Routes.resetPassword);

  // Connecté : contexte en cours de chargement ou en erreur → écran d'attente.
  if (contexte == null) return aller(Routes.splash);

  // Lien d'invitation ouvert avant la connexion : reprendre le parcours.
  if (invitationEnAttente != null) return aller(Routes.joinCompany);

  switch (contexte.etat) {
    case ContexteEtat.aucuneEntreprise:
      // Aucun rôle, aucune permission : créer ou rejoindre une entreprise.
      return Routes.sansEntreprise.contains(location) ? null : Routes.onboarding;
    case ContexteEtat.membreSuspendu || ContexteEtat.entrepriseSuspendue:
      return location == Routes.joinCompany ? null : aller(Routes.blocked);
    case ContexteEtat.pret:
      final horsApplication = (isPublic && location != Routes.joinCompany) ||
          const {Routes.splash, Routes.blocked, Routes.onboarding, Routes.createCompany, Routes.resetPassword}
              .contains(location);
      return horsApplication ? Routes.home : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  void bump(_, _) => refresh.value++;
  ref.listen(authStateProvider, bump);
  ref.listen(contexteSessionProvider, bump);
  // Permissions / abonnement modifiés : les gardes sont réévaluées.
  ref.listen(navigationModelProvider, bump);
  ref.listen(invitationEnAttenteProvider, bump);

  String? guardModule(String code) => ref.read(moduleAccessProvider(code)).isAllowed
      ? null
      : Uri(path: Routes.accessDenied, queryParameters: {'module': code}).toString();

  String? droitFinance(bool Function(DroitsFinances d) autorise) =>
      autorise(ref.read(droitsFinancesProvider)) ? null : Routes.accessDenied;

  GoRoute moduleRoute(String moduleCode, Widget Function() page) => GoRoute(
        path: ModuleRoutes.path(moduleCode).split('/').last,
        redirect: (_, _) => guardModule(moduleCode),
        builder: (_, _) => page(),
      );

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => globalRedirect(
      location: state.matchedLocation,
      auth: ref.read(authStateProvider).value,
      contexte: ref.read(contexteSessionProvider).value,
      invitationEnAttente: ref.read(invitationEnAttenteProvider),
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterPage()),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordPage()),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, _) => const ChangePasswordPage(recuperation: true),
      ),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingPage()),
      GoRoute(path: Routes.createCompany, builder: (_, _) => const CreateCompanyPage()),
      GoRoute(
        path: Routes.joinCompany,
        builder: (_, state) => JoinCompanyPage(tokenFromLink: state.uri.queryParameters['token']),
      ),
      GoRoute(path: Routes.blocked, builder: (_, _) => const ContexteBloquePage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
          GoRoute(
            path: Routes.administration,
            builder: (_, _) => const AdministrationPage(),
            routes: [
              moduleRoute(ModuleCodes.adminEntreprise, () => const EntreprisePage()),
              moduleRoute(ModuleCodes.adminUtilisateurs, () => const UtilisateursPage()),
              moduleRoute(ModuleCodes.adminPerimetres, () => const PerimetresPage()),
              moduleRoute(ModuleCodes.adminAbonnement, () => const AbonnementPage()),
              moduleRoute(ModuleCodes.adminAudit, () => const AuditPage()),
            ],
          ),
          GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsPage()),
          GoRoute(path: Routes.recherche, builder: (_, _) => const RecherchePage()),
          GoRoute(
            path: Routes.rapports,
            redirect: (_, _) => guardModule(ModuleCodes.communRapports),
            builder: (_, _) => const RapportsPage(),
            routes: [
              GoRoute(
                path: ':type',
                // Le rapport doit aussi être permis par les droits sur ses données.
                redirect: (_, state) => rapportsAutorises(ref.read(droitsFinancesProvider))
                        .any((t) => t.name == state.pathParameters['type'])
                    ? null
                    : Routes.accessDenied,
                builder: (_, state) =>
                    RapportPage(type: TypeRapport.values.byName(state.pathParameters['type']!)),
              ),
            ],
          ),
          GoRoute(
            path: Routes.tableauDeBord,
            // Même règle que l'onglet Finances.
            redirect: (_, _) => (ref.read(navigationModelProvider)?.modulesFinances ?? const []).isEmpty
                ? Routes.accessDenied
                : null,
            builder: (_, _) => const TableauDeBordPage(),
          ),
          GoRoute(
            path: Routes.agenda,
            redirect: (_, _) => guardModule(ModuleCodes.communAgenda),
            builder: (_, _) => const AgendaPage(),
            routes: [
              GoRoute(
                path: 'new',
                redirect: (_, _) => ref.read(droitsAgendaProvider).gerer ? null : Routes.accessDenied,
                builder: (_, state) => EcheanceFormPage(
                  cibleType: CibleType.tryParse(state.uri.queryParameters['cible_type']),
                  cibleId: state.uri.queryParameters['cible_id'],
                  titre: state.uri.queryParameters['titre'],
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => EcheancePage(echeanceId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    redirect: (_, _) => ref.read(droitsAgendaProvider).gerer ? null : Routes.accessDenied,
                    builder: (_, state) => EcheanceFormPage(echeanceId: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: Routes.documents,
            redirect: (_, _) => guardModule(ModuleCodes.communDocuments),
            builder: (_, _) => const DocumentsPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => DocumentPage(documentId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: Routes.stock,
            redirect: (_, _) => guardModule(ModuleCodes.commerceStock),
            builder: (_, state) => StockPage(
              statutInitial: StatutStock.values.where((s) => s.name == state.uri.queryParameters['statut']).firstOrNull,
            ),
            routes: [
              GoRoute(
                path: 'mouvements',
                builder: (_, state) => MouvementsPage(produitId: state.uri.queryParameters['produit']),
              ),
            ],
          ),
          GoRoute(
            path: Routes.produits,
            redirect: (_, _) => guardModule(ModuleCodes.commerceProduits),
            builder: (_, _) => const ProduitsPage(),
            routes: [
              GoRoute(
                path: 'new',
                redirect: (_, _) => ref.read(droitsCommerceProvider).creerProduits ? null : Routes.accessDenied,
                builder: (_, state) => ProduitFormPage(
                  codeBarres: state.uri.queryParameters['code'],
                  categorieId: state.uri.queryParameters['categorie'],
                ),
              ),
              GoRoute(path: 'categories', builder: (_, _) => const CategoriesPage()),
              GoRoute(
                path: ':id',
                builder: (_, state) => ProduitPage(produitId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    redirect: (_, _) => ref.read(droitsCommerceProvider).modifierProduits ? null : Routes.accessDenied,
                    builder: (_, state) => ProduitFormPage(produitId: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: Routes.achats,
            redirect: (_, _) => guardModule(ModuleCodes.commerceAchats),
            builder: (_, _) => const AchatsPage(),
            routes: [
              GoRoute(
                path: 'new',
                redirect: (_, _) => ref.read(droitsCommerceProvider).creerAchats ? null : Routes.accessDenied,
                builder: (_, state) => AchatFormPage(
                  fournisseurId: state.uri.queryParameters['fournisseur'],
                  produitId: state.uri.queryParameters['produit'],
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => AchatPage(achatId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    redirect: (_, _) => ref.read(droitsCommerceProvider).receptionner ? null : Routes.accessDenied,
                    builder: (_, state) => AchatFormPage(achatId: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: Routes.ventes,
            redirect: (_, _) => guardModule(ModuleCodes.commerceVentes),
            builder: (_, state) => VentePage(produitId: state.uri.queryParameters['produit']),
            routes: [
              GoRoute(path: 'historique', builder: (_, _) => const VentesPage()),
              GoRoute(path: ':id', builder: (_, state) => VenteDetailPage(venteId: state.pathParameters['id']!)),
            ],
          ),
          GoRoute(
            path: Routes.fournisseurs,
            redirect: (_, _) => guardModule(ModuleCodes.commerceFournisseurs),
            builder: (_, _) => const FournisseursPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => FournisseurPage(contactId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: Routes.servicesAccueil,
            redirect: (_, _) => guardModule(ModuleCodes.servicesPrestations),
            builder: (_, _) => const ServicesAccueilPage(),
          ),
          GoRoute(
            path: Routes.servicesPrestations,
            redirect: (_, _) => guardModule(ModuleCodes.servicesPrestations),
            builder: (_, state) => PrestationsPage(statutInitial: state.uri.queryParameters['statut']),
            routes: [
              GoRoute(
                path: 'new',
                redirect: (_, _) => ref.read(droitsServicesProvider).peutCreerPrestations ? null : Routes.accessDenied,
                builder: (_, state) => PrestationFormPage(
                  initialContactId: state.uri.queryParameters['contactId'],
                  initialDate: state.uri.queryParameters['date'],
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => PrestationDetailsPage(prestationId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    redirect: (_, _) => ref.read(droitsServicesProvider).peutModifierPrestations ? null : Routes.accessDenied,
                    builder: (_, state) => PrestationFormPage(prestationId: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: Routes.servicesPlanning,
            redirect: (_, _) => guardModule(ModuleCodes.servicesPrestations),
            builder: (_, state) => ServicesPlanningPage(vueInitiale: state.uri.queryParameters['vue']),
          ),
          GoRoute(
            path: Routes.servicesCatalogue,
            redirect: (_, _) => guardModule(ModuleCodes.servicesServices),
            builder: (_, _) => const ServicesCataloguePage(),
            routes: [
              GoRoute(
                path: 'new',
                redirect: (_, _) => ref.read(droitsServicesProvider).peutCreerServices ? null : Routes.accessDenied,
                builder: (_, _) => const ServiceFormPage(),
              ),
              GoRoute(
                path: ':id/edit',
                redirect: (_, _) => ref.read(droitsServicesProvider).peutModifierServices ? null : Routes.accessDenied,
                builder: (_, state) => ServiceFormPage(serviceId: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: Routes.servicesDevis,
            redirect: (_, _) => guardModule(ModuleCodes.servicesPrestations),
            builder: (_, _) => const ServicesDevisPage(),
            routes: [
              GoRoute(
                path: 'new',
                redirect: (_, _) => ref.read(droitsServicesProvider).peutCreerDevis ? null : Routes.accessDenied,
                builder: (_, state) => DevisFormPage(initialContactId: state.uri.queryParameters['contactId']),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => DevisDetailsPage(devisId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: Routes.servicesRapports,
            redirect: (_, _) => guardModule(ModuleCodes.servicesPrestations),
            builder: (_, _) => const ServicesRapportPage(),
          ),
          GoRoute(
            path: Routes.contacts,
            // La garde du module s'applique aussi aux sous-routes.
            redirect: (_, _) => guardModule(ModuleCodes.communContacts),
            builder: (_, _) => const ContactsPage(),
            routes: [
              GoRoute(
                path: 'new',
                redirect: (_, _) => ref.read(droitsContactsProvider).creer ? null : Routes.accessDenied,
                builder: (_, state) => ContactFormPage(
                  relation: switch (state.uri.queryParameters['relation']) {
                    final String r => RelationContact.tryParse(r),
                    _ => null,
                  },
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => ContactDetailPage(contactId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    redirect: (_, _) => ref.read(droitsContactsProvider).modifier ? null : Routes.accessDenied,
                    builder: (_, state) => ContactFormPage(contactId: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: Routes.finances,
            // Même règle que l'onglet : sinon accès refusé.
            redirect: (_, _) => (ref.read(navigationModelProvider)?.destinations ?? const [])
                    .contains(NavDestination.finances)
                ? null
                : Routes.accessDenied,
            builder: (_, state) => FinancesPage(onglet: state.uri.queryParameters['onglet']),
            routes: [
              GoRoute(
                path: 'dossiers/:key',
                redirect: (_, _) => guardModule(ModuleCodes.financesCreances),
                builder: (_, state) => DossierDettePage(
                  dossierKey: state.pathParameters['key']!,
                  sens: SensEngagement.parse(state.uri.queryParameters['sens']),
                ),
              ),
              GoRoute(
                path: 'engagements/new',
                redirect: (_, _) => droitFinance((d) => d.gererCreances),
                builder: (_, state) => EngagementFormPage(sens: SensEngagement.parse(state.uri.queryParameters['sens'])),
              ),
              GoRoute(
                path: 'engagements/:id',
                redirect: (_, _) => guardModule(ModuleCodes.financesCreances),
                builder: (_, state) => EngagementPage(engagementId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    redirect: (_, _) => droitFinance((d) => d.gererCreances),
                    builder: (_, state) => EngagementFormPage(engagementId: state.pathParameters['id']),
                  ),
                ],
              ),
              GoRoute(
                path: 'paiements/new',
                redirect: (_, _) => droitFinance((d) => d.encaisser),
                builder: (_, state) => PaiementFormPage(engagementId: state.uri.queryParameters['engagement']),
              ),
              GoRoute(
                path: 'paiements/:id',
                redirect: (_, _) => guardModule(ModuleCodes.financesPaiements),
                builder: (_, state) => PaiementPage(paiementId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'depenses/new',
                redirect: (_, _) => droitFinance((d) => d.saisirDepenses),
                builder: (_, _) => const DepenseFormPage(),
              ),
              GoRoute(
                path: 'depenses/:id',
                redirect: (_, _) => guardModule(ModuleCodes.financesDepenses),
                builder: (_, state) => DepensePage(depenseId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'categories',
                redirect: (_, _) => droitFinance((d) => d.modifierDepenses),
                builder: (_, _) => const CategoriesDepensesPage(),
              ),
              GoRoute(
                path: 'caisses/new',
                redirect: (_, _) => droitFinance((d) => d.gererCaisses),
                builder: (_, _) => const CaisseFormPage(),
              ),
              GoRoute(
                path: 'caisses/:id',
                redirect: (_, _) => guardModule(ModuleCodes.financesCaisse),
                builder: (_, state) => CaissePage(caisseId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'revenus',
                builder: (_, _) => const FinanceRevenusPage(),
              ),
              GoRoute(
                path: 'charges',
                builder: (_, _) => const FinanceChargesPage(),
              ),
              GoRoute(
                path: 'tresorerie',
                builder: (_, _) => const FinanceTresoreriePage(),
              ),
              GoRoute(
                path: 'creances-dettes',
                builder: (_, _) => const FinanceCreancesDettesPage(),
              ),
              GoRoute(
                path: 'rapport',
                builder: (_, _) => const FinanceRapportPage(),
              ),
            ],
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, _) => const ParametresPage(),
            routes: [
              GoRoute(path: 'password', builder: (_, _) => const ChangePasswordPage()),
              GoRoute(
                path: 'paiements',
                redirect: (_, _) => ref.read(contexteActifProvider)?.permissionEngine.has(PermissionCodes.entrepriseManage) ?? false
                    ? null
                    : Routes.accessDenied,
                builder: (_, _) => const ParametresPaiementsPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/modules/:code',
            redirect: (_, state) => guardModule(state.pathParameters['code']!),
            builder: (_, state) => ModulePlaceholderPage(moduleCode: state.pathParameters['code']!),
          ),
          GoRoute(
            path: Routes.accessDenied,
            builder: (_, state) =>
                AccessDeniedPage(moduleCode: state.uri.queryParameters['module']),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
