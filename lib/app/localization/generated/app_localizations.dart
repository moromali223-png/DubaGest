import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'DubaGest'**
  String get appTitle;

  /// No description provided for @commonRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get commonSave;

  /// No description provided for @commonCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get commonCreate;

  /// No description provided for @commonDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get commonConfirm;

  /// No description provided for @commonLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get commonLoading;

  /// No description provided for @commonActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get commonActive;

  /// No description provided for @commonInactive.
  ///
  /// In fr, this message translates to:
  /// **'Inactif'**
  String get commonInactive;

  /// No description provided for @commonOptional.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif'**
  String get commonOptional;

  /// No description provided for @languageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get languageLabel;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageArabic.
  ///
  /// In fr, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @authLoginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Accédez à l\'espace de votre entreprise'**
  String get authLoginSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get authPassword;

  /// No description provided for @authSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authSignIn;

  /// No description provided for @authSignOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get authSignOut;

  /// No description provided for @authSignOutPendingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifications non synchronisées'**
  String get authSignOutPendingTitle;

  /// No description provided for @authSignOutPendingMessage.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 modification sera envoyée} other{{count} modifications seront envoyées}} lors de votre prochaine connexion sur cet appareil. Se déconnecter quand même ?'**
  String authSignOutPendingMessage(int count);

  /// No description provided for @authForgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get authForgotPassword;

  /// No description provided for @authForgotPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser le mot de passe'**
  String get authForgotPasswordTitle;

  /// No description provided for @authForgotPasswordHelp.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre adresse e-mail. Vous recevrez un lien pour choisir un nouveau mot de passe.'**
  String get authForgotPasswordHelp;

  /// No description provided for @authSendResetLink.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien'**
  String get authSendResetLink;

  /// No description provided for @authResetLinkSent.
  ///
  /// In fr, this message translates to:
  /// **'Si un compte existe pour cette adresse, un e-mail vient d\'être envoyé.'**
  String get authResetLinkSent;

  /// No description provided for @authBackToLogin.
  ///
  /// In fr, this message translates to:
  /// **'Retour à la connexion'**
  String get authBackToLogin;

  /// No description provided for @authChangePassword.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get authChangePassword;

  /// No description provided for @authNewPassword.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get authNewPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get authConfirmPassword;

  /// No description provided for @authPasswordChanged.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe modifié.'**
  String get authPasswordChanged;

  /// No description provided for @authSessionExpired.
  ///
  /// In fr, this message translates to:
  /// **'Votre session a expiré. Veuillez vous reconnecter.'**
  String get authSessionExpired;

  /// No description provided for @validationRequired.
  ///
  /// In fr, this message translates to:
  /// **'Champ obligatoire'**
  String get validationRequired;

  /// No description provided for @validationEmail.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail invalide'**
  String get validationEmail;

  /// No description provided for @validationPasswordLength.
  ///
  /// In fr, this message translates to:
  /// **'Au moins {min} caractères'**
  String validationPasswordLength(int min);

  /// No description provided for @validationPasswordsMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get validationPasswordsMismatch;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez votre réseau.'**
  String get errorNetwork;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In fr, this message translates to:
  /// **'E-mail ou mot de passe incorrect.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorEmailNotConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail non confirmée.'**
  String get errorEmailNotConfirmed;

  /// No description provided for @errorRateLimited.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessayez dans quelques minutes.'**
  String get errorRateLimited;

  /// No description provided for @errorSessionExpired.
  ///
  /// In fr, this message translates to:
  /// **'Votre session a expiré.'**
  String get errorSessionExpired;

  /// No description provided for @errorForbidden.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas l\'autorisation d\'effectuer cette action.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Élément introuvable.'**
  String get errorNotFound;

  /// No description provided for @errorConflict.
  ///
  /// In fr, this message translates to:
  /// **'Cet élément a été modifié par quelqu\'un d\'autre.'**
  String get errorConflict;

  /// No description provided for @errorDuplicate.
  ///
  /// In fr, this message translates to:
  /// **'Un élément portant ce nom existe déjà.'**
  String get errorDuplicate;

  /// No description provided for @errorServer.
  ///
  /// In fr, this message translates to:
  /// **'Le service est momentanément indisponible.'**
  String get errorServer;

  /// No description provided for @errorLocalStorage.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de stockage sur l\'appareil.'**
  String get errorLocalStorage;

  /// No description provided for @errorUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur inattendue est survenue.'**
  String get errorUnknown;

  /// No description provided for @ruleSubscriptionInactive.
  ///
  /// In fr, this message translates to:
  /// **'L\'abonnement de votre entreprise n\'est pas actif.'**
  String get ruleSubscriptionInactive;

  /// No description provided for @ruleActivityNotAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Votre abonnement {plan} n\'inclut pas cette activité.'**
  String ruleActivityNotAllowed(String plan);

  /// No description provided for @ruleActivityInactive.
  ///
  /// In fr, this message translates to:
  /// **'Cette activité n\'est pas activée pour votre entreprise.'**
  String get ruleActivityInactive;

  /// No description provided for @ruleActivitiesLimit.
  ///
  /// In fr, this message translates to:
  /// **'Votre abonnement {plan} autorise au maximum {max, plural, =1{1 activité} other{{max} activités}}.'**
  String ruleActivitiesLimit(String plan, int max);

  /// No description provided for @ruleUsersLimit.
  ///
  /// In fr, this message translates to:
  /// **'Votre abonnement {plan} autorise au maximum {max, plural, =1{1 utilisateur} other{{max} utilisateurs}}.'**
  String ruleUsersLimit(String plan, int max);

  /// No description provided for @ruleRoleLimit.
  ///
  /// In fr, this message translates to:
  /// **'Votre abonnement {plan} autorise au maximum {max} « {role} ».'**
  String ruleRoleLimit(String plan, int max, String role);

  /// No description provided for @rulePerimetresLimit.
  ///
  /// In fr, this message translates to:
  /// **'Votre abonnement {plan} autorise au maximum {max, plural, =1{1 site} other{{max} sites}} pour l\'activité {activity}.'**
  String rulePerimetresLimit(String plan, int max, String activity);

  /// No description provided for @ruleRoleNotAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Ce rôle n\'est pas disponible avec votre abonnement {plan}.'**
  String ruleRoleNotAllowed(String plan);

  /// No description provided for @ruleRoleActivityInactive.
  ///
  /// In fr, this message translates to:
  /// **'Ce rôle nécessite une activité qui n\'est pas activée.'**
  String get ruleRoleActivityInactive;

  /// No description provided for @ruleModuleNotInPlan.
  ///
  /// In fr, this message translates to:
  /// **'Ce module n\'est pas inclus dans votre abonnement.'**
  String get ruleModuleNotInPlan;

  /// No description provided for @rulePermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Votre rôle ne permet pas cette action.'**
  String get rulePermissionDenied;

  /// No description provided for @rulePerimetreDenied.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'êtes pas affecté à ce site.'**
  String get rulePerimetreDenied;

  /// No description provided for @ruleLastAdmin.
  ///
  /// In fr, this message translates to:
  /// **'L\'entreprise doit conserver au moins un administrateur.'**
  String get ruleLastAdmin;

  /// No description provided for @ruleAssignmentNotNeeded.
  ///
  /// In fr, this message translates to:
  /// **'Ce rôle accède déjà à tous les sites.'**
  String get ruleAssignmentNotNeeded;

  /// No description provided for @ruleAssignmentActivityMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Ce site n\'appartient pas à l\'activité du rôle.'**
  String get ruleAssignmentActivityMismatch;

  /// No description provided for @ruleImmutable.
  ///
  /// In fr, this message translates to:
  /// **'Cette information ne peut plus être modifiée.'**
  String get ruleImmutable;

  /// No description provided for @contextLoading.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de votre espace…'**
  String get contextLoading;

  /// No description provided for @contextLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger votre espace de travail.'**
  String get contextLoadError;

  /// No description provided for @contextOfflineCache.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — données enregistrées sur l\'appareil.'**
  String get contextOfflineCache;

  /// No description provided for @contextNoEntrepriseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune entreprise'**
  String get contextNoEntrepriseTitle;

  /// No description provided for @contextNoEntrepriseMessage.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte n\'est rattaché à aucune entreprise. Contactez votre administrateur.'**
  String get contextNoEntrepriseMessage;

  /// No description provided for @contextMemberSuspendedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accès suspendu'**
  String get contextMemberSuspendedTitle;

  /// No description provided for @contextMemberSuspendedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Votre accès à {entreprise} est suspendu. Contactez votre administrateur.'**
  String contextMemberSuspendedMessage(String entreprise);

  /// No description provided for @contextEntrepriseSuspendedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Entreprise suspendue'**
  String get contextEntrepriseSuspendedTitle;

  /// No description provided for @contextEntrepriseSuspendedMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès à {entreprise} est momentanément suspendu.'**
  String contextEntrepriseSuspendedMessage(String entreprise);

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navAdministration.
  ///
  /// In fr, this message translates to:
  /// **'Administration'**
  String get navAdministration;

  /// No description provided for @navSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get navSettings;

  /// No description provided for @homeGreeting.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeGreetingAnonymous.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get homeGreetingAnonymous;

  /// No description provided for @homeNoModules.
  ///
  /// In fr, this message translates to:
  /// **'Aucun module n\'est disponible pour votre rôle.'**
  String get homeNoModules;

  /// No description provided for @homeSubscriptionInactive.
  ///
  /// In fr, this message translates to:
  /// **'Les modules sont indisponibles tant que l\'abonnement n\'est pas actif.'**
  String get homeSubscriptionInactive;

  /// No description provided for @moduleComingSoonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get moduleComingSoonTitle;

  /// No description provided for @moduleComingSoonMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce module sera disponible dans une prochaine version.'**
  String get moduleComingSoonMessage;

  /// No description provided for @accessDeniedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accès refusé'**
  String get accessDeniedTitle;

  /// No description provided for @accessDeniedBackHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get accessDeniedBackHome;

  /// No description provided for @activityCommerce.
  ///
  /// In fr, this message translates to:
  /// **'Commerce'**
  String get activityCommerce;

  /// No description provided for @activityServices.
  ///
  /// In fr, this message translates to:
  /// **'Services'**
  String get activityServices;

  /// No description provided for @activityImmobilier.
  ///
  /// In fr, this message translates to:
  /// **'Immobilier'**
  String get activityImmobilier;

  /// No description provided for @roleAdministrateur.
  ///
  /// In fr, this message translates to:
  /// **'Administrateur'**
  String get roleAdministrateur;

  /// No description provided for @roleSuperviseur.
  ///
  /// In fr, this message translates to:
  /// **'Superviseur'**
  String get roleSuperviseur;

  /// No description provided for @roleGestionnaireStock.
  ///
  /// In fr, this message translates to:
  /// **'Gestionnaire stock'**
  String get roleGestionnaireStock;

  /// No description provided for @roleVendeur.
  ///
  /// In fr, this message translates to:
  /// **'Vendeur'**
  String get roleVendeur;

  /// No description provided for @planNormal.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get planNormal;

  /// No description provided for @planMoyen.
  ///
  /// In fr, this message translates to:
  /// **'Moyen'**
  String get planMoyen;

  /// No description provided for @planPro.
  ///
  /// In fr, this message translates to:
  /// **'Pro'**
  String get planPro;

  /// No description provided for @moduleAdminEntreprise.
  ///
  /// In fr, this message translates to:
  /// **'Entreprise'**
  String get moduleAdminEntreprise;

  /// No description provided for @moduleAdminUtilisateurs.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get moduleAdminUtilisateurs;

  /// No description provided for @moduleAdminPerimetres.
  ///
  /// In fr, this message translates to:
  /// **'Boutiques et sites'**
  String get moduleAdminPerimetres;

  /// No description provided for @moduleAdminAbonnement.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement'**
  String get moduleAdminAbonnement;

  /// No description provided for @moduleCommerceProduits.
  ///
  /// In fr, this message translates to:
  /// **'Produits'**
  String get moduleCommerceProduits;

  /// No description provided for @moduleCommerceStock.
  ///
  /// In fr, this message translates to:
  /// **'Stock'**
  String get moduleCommerceStock;

  /// No description provided for @moduleCommerceVentes.
  ///
  /// In fr, this message translates to:
  /// **'Ventes'**
  String get moduleCommerceVentes;

  /// No description provided for @moduleCommerceAchats.
  ///
  /// In fr, this message translates to:
  /// **'Achats'**
  String get moduleCommerceAchats;

  /// No description provided for @moduleCommunContacts.
  ///
  /// In fr, this message translates to:
  /// **'Contacts'**
  String get moduleCommunContacts;

  /// No description provided for @moduleCommerceFournisseurs.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseurs'**
  String get moduleCommerceFournisseurs;

  /// No description provided for @moduleFinancesCreances.
  ///
  /// In fr, this message translates to:
  /// **'À recevoir / À payer'**
  String get moduleFinancesCreances;

  /// No description provided for @moduleFinancesCreancesCourt.
  ///
  /// In fr, this message translates to:
  /// **'Dettes'**
  String get moduleFinancesCreancesCourt;

  /// No description provided for @moduleCommunContactsClients.
  ///
  /// In fr, this message translates to:
  /// **'Clients'**
  String get moduleCommunContactsClients;

  /// No description provided for @moduleFinancesPaiements.
  ///
  /// In fr, this message translates to:
  /// **'Paiements'**
  String get moduleFinancesPaiements;

  /// No description provided for @moduleFinancesCaisse.
  ///
  /// In fr, this message translates to:
  /// **'Caisse'**
  String get moduleFinancesCaisse;

  /// No description provided for @moduleFinancesDepenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get moduleFinancesDepenses;

  /// No description provided for @moduleServicesServices.
  ///
  /// In fr, this message translates to:
  /// **'Catalogue'**
  String get moduleServicesServices;

  /// No description provided for @moduleServicesPrestations.
  ///
  /// In fr, this message translates to:
  /// **'Contrats de service'**
  String get moduleServicesPrestations;

  /// No description provided for @moduleServicesPlanning.
  ///
  /// In fr, this message translates to:
  /// **'Interventions'**
  String get moduleServicesPlanning;

  /// No description provided for @moduleServicesDevis.
  ///
  /// In fr, this message translates to:
  /// **'Devis'**
  String get moduleServicesDevis;

  /// No description provided for @moduleServicesFacturation.
  ///
  /// In fr, this message translates to:
  /// **'Factures & Reçus'**
  String get moduleServicesFacturation;

  /// No description provided for @moduleServicesRapports.
  ///
  /// In fr, this message translates to:
  /// **'Rapports'**
  String get moduleServicesRapports;

  /// No description provided for @moduleImmobilierBiens.
  ///
  /// In fr, this message translates to:
  /// **'Biens'**
  String get moduleImmobilierBiens;

  /// No description provided for @moduleImmobilierProprietaires.
  ///
  /// In fr, this message translates to:
  /// **'Propriétaires'**
  String get moduleImmobilierProprietaires;

  /// No description provided for @moduleImmobilierLocataires.
  ///
  /// In fr, this message translates to:
  /// **'Locataires'**
  String get moduleImmobilierLocataires;

  /// No description provided for @moduleImmobilierLocations.
  ///
  /// In fr, this message translates to:
  /// **'Locations'**
  String get moduleImmobilierLocations;

  /// No description provided for @moduleImmobilierContrats.
  ///
  /// In fr, this message translates to:
  /// **'Contrats'**
  String get moduleImmobilierContrats;

  /// No description provided for @moduleImmobilierLoyers.
  ///
  /// In fr, this message translates to:
  /// **'Loyers'**
  String get moduleImmobilierLoyers;

  /// No description provided for @perimetreTypeBoutique.
  ///
  /// In fr, this message translates to:
  /// **'Boutique'**
  String get perimetreTypeBoutique;

  /// No description provided for @perimetreTypeAgence.
  ///
  /// In fr, this message translates to:
  /// **'Agence'**
  String get perimetreTypeAgence;

  /// No description provided for @perimetreTypeSite.
  ///
  /// In fr, this message translates to:
  /// **'Site'**
  String get perimetreTypeSite;

  /// No description provided for @perimetreTypeUnite.
  ///
  /// In fr, this message translates to:
  /// **'Unité'**
  String get perimetreTypeUnite;

  /// No description provided for @perimetresEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun site pour le moment.'**
  String get perimetresEmpty;

  /// No description provided for @perimetreAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get perimetreAdd;

  /// No description provided for @perimetreNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau site'**
  String get perimetreNew;

  /// No description provided for @perimetreEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le site'**
  String get perimetreEdit;

  /// No description provided for @perimetreName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get perimetreName;

  /// No description provided for @perimetreCode.
  ///
  /// In fr, this message translates to:
  /// **'Code'**
  String get perimetreCode;

  /// No description provided for @perimetreActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activité'**
  String get perimetreActivity;

  /// No description provided for @perimetreType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get perimetreType;

  /// No description provided for @perimetreDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce site ?'**
  String get perimetreDeleteTitle;

  /// No description provided for @perimetreDeleteMessage.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » ne sera plus accessible.'**
  String perimetreDeleteMessage(String name);

  /// No description provided for @usersEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur.'**
  String get usersEmpty;

  /// No description provided for @usersInvite.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un utilisateur'**
  String get usersInvite;

  /// No description provided for @usersInviteComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'L\'invitation d\'utilisateurs sera disponible dans une prochaine version.'**
  String get usersInviteComingSoon;

  /// No description provided for @usersYou.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get usersYou;

  /// No description provided for @usersAssignments.
  ///
  /// In fr, this message translates to:
  /// **'Sites affectés'**
  String get usersAssignments;

  /// No description provided for @usersAllPerimetres.
  ///
  /// In fr, this message translates to:
  /// **'Tous les sites'**
  String get usersAllPerimetres;

  /// No description provided for @usersNoPerimetre.
  ///
  /// In fr, this message translates to:
  /// **'Aucun site affecté'**
  String get usersNoPerimetre;

  /// No description provided for @usersOnlineOnly.
  ///
  /// In fr, this message translates to:
  /// **'Cette action nécessite une connexion.'**
  String get usersOnlineOnly;

  /// No description provided for @subscriptionPlan.
  ///
  /// In fr, this message translates to:
  /// **'Formule'**
  String get subscriptionPlan;

  /// No description provided for @subscriptionStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get subscriptionStatus;

  /// No description provided for @subscriptionStatusEssai.
  ///
  /// In fr, this message translates to:
  /// **'Essai'**
  String get subscriptionStatusEssai;

  /// No description provided for @subscriptionStatusActif.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get subscriptionStatusActif;

  /// No description provided for @subscriptionStatusSuspendu.
  ///
  /// In fr, this message translates to:
  /// **'Suspendu'**
  String get subscriptionStatusSuspendu;

  /// No description provided for @subscriptionStatusExpire.
  ///
  /// In fr, this message translates to:
  /// **'Expiré'**
  String get subscriptionStatusExpire;

  /// No description provided for @subscriptionStatusAnnule.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get subscriptionStatusAnnule;

  /// No description provided for @subscriptionSince.
  ///
  /// In fr, this message translates to:
  /// **'Depuis le {date}'**
  String subscriptionSince(String date);

  /// No description provided for @subscriptionUntil.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'au {date}'**
  String subscriptionUntil(String date);

  /// No description provided for @subscriptionNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun abonnement.'**
  String get subscriptionNone;

  /// No description provided for @subscriptionActivities.
  ///
  /// In fr, this message translates to:
  /// **'Activités'**
  String get subscriptionActivities;

  /// No description provided for @subscriptionUsage.
  ///
  /// In fr, this message translates to:
  /// **'Consommation'**
  String get subscriptionUsage;

  /// No description provided for @subscriptionUsers.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get subscriptionUsers;

  /// No description provided for @subscriptionUsageValue.
  ///
  /// In fr, this message translates to:
  /// **'{used} / {max}'**
  String subscriptionUsageValue(int used, int max);

  /// No description provided for @entrepriseInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations'**
  String get entrepriseInfo;

  /// No description provided for @entrepriseName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get entrepriseName;

  /// No description provided for @entrepriseCountry.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get entrepriseCountry;

  /// No description provided for @entrepriseCurrency.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get entrepriseCurrency;

  /// No description provided for @entrepriseRole.
  ///
  /// In fr, this message translates to:
  /// **'Votre rôle'**
  String get entrepriseRole;

  /// No description provided for @syncUpToDate.
  ///
  /// In fr, this message translates to:
  /// **'Données à jour'**
  String get syncUpToDate;

  /// No description provided for @syncPending.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 modification en attente} other{{count} modifications en attente}}'**
  String syncPending(int count);

  /// No description provided for @syncSyncing.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation…'**
  String get syncSyncing;

  /// No description provided for @syncError.
  ///
  /// In fr, this message translates to:
  /// **'Échec de synchronisation'**
  String get syncError;

  /// No description provided for @syncOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get syncOffline;

  /// No description provided for @syncOfflineBanner.
  ///
  /// In fr, this message translates to:
  /// **'Mode hors ligne : vos modifications seront envoyées au retour de la connexion.'**
  String get syncOfflineBanner;

  /// No description provided for @syncLastSynced.
  ///
  /// In fr, this message translates to:
  /// **'Dernière synchronisation : {time}'**
  String syncLastSynced(String time);

  /// No description provided for @syncNow.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser maintenant'**
  String get syncNow;

  /// No description provided for @syncRecordPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'envoi'**
  String get syncRecordPending;

  /// No description provided for @syncRecordError.
  ///
  /// In fr, this message translates to:
  /// **'Non synchronisé'**
  String get syncRecordError;

  /// No description provided for @syncRecordConflict.
  ///
  /// In fr, this message translates to:
  /// **'Modifié ailleurs — version serveur conservée'**
  String get syncRecordConflict;

  /// No description provided for @settingsAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get settingsAccount;

  /// No description provided for @settingsEntreprise.
  ///
  /// In fr, this message translates to:
  /// **'Entreprise'**
  String get settingsEntreprise;

  /// No description provided for @settingsSync.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation'**
  String get settingsSync;

  /// No description provided for @settingsAppearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get settingsAppearance;

  /// No description provided for @authRegisterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer votre compte'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gratuit, en moins d\'une minute.'**
  String get authRegisterSubtitle;

  /// No description provided for @authFirstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get authFirstName;

  /// No description provided for @authLastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get authLastName;

  /// No description provided for @authCreateAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get authCreateAccount;

  /// No description provided for @authNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Déjà un compte ?'**
  String get authHaveAccount;

  /// No description provided for @authSignInLink.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authSignInLink;

  /// No description provided for @authRegisterLink.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get authRegisterLink;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authOr.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get authOr;

  /// No description provided for @authCheckEmailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre e-mail'**
  String get authCheckEmailTitle;

  /// No description provided for @authCheckEmailMessage.
  ///
  /// In fr, this message translates to:
  /// **'Un lien de confirmation a été envoyé à {email}. Ouvrez-le, puis connectez-vous.'**
  String authCheckEmailMessage(String email);

  /// No description provided for @authResetPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get authResetPasswordTitle;

  /// No description provided for @errorAccountExists.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte existe déjà. Connectez-vous.'**
  String get errorAccountExists;

  /// No description provided for @errorWeakPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe trop faible.'**
  String get errorWeakPassword;

  /// No description provided for @errorOauthUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'La connexion avec Google n\'est pas disponible pour le moment.'**
  String get errorOauthUnavailable;

  /// No description provided for @onboardingWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue {name}'**
  String onboardingWelcome(String name);

  /// No description provided for @onboardingWelcomeAnonymous.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue'**
  String get onboardingWelcomeAnonymous;

  /// No description provided for @onboardingQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Que souhaitez-vous faire ?'**
  String get onboardingQuestion;

  /// No description provided for @onboardingCreateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon entreprise'**
  String get onboardingCreateTitle;

  /// No description provided for @onboardingCreateSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous en serez l\'administrateur.'**
  String get onboardingCreateSubtitle;

  /// No description provided for @onboardingJoinTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre une entreprise'**
  String get onboardingJoinTitle;

  /// No description provided for @onboardingJoinSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Avec l\'invitation reçue de votre responsable.'**
  String get onboardingJoinSubtitle;

  /// No description provided for @companyName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'entreprise'**
  String get companyName;

  /// No description provided for @companyPlan.
  ///
  /// In fr, this message translates to:
  /// **'Formule'**
  String get companyPlan;

  /// No description provided for @companyActivities.
  ///
  /// In fr, this message translates to:
  /// **'Activités'**
  String get companyActivities;

  /// No description provided for @companyActivitiesHint.
  ///
  /// In fr, this message translates to:
  /// **'{max, plural, =1{Choisissez 1 activité} other{Jusqu\'à {max} activités}}'**
  String companyActivitiesHint(int max);

  /// No description provided for @companyTrialInfo.
  ///
  /// In fr, this message translates to:
  /// **'Essai gratuit de 14 jours. Vous serez l\'administrateur de l\'entreprise.'**
  String get companyTrialInfo;

  /// No description provided for @companyCreateButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'entreprise'**
  String get companyCreateButton;

  /// No description provided for @joinCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'invitation'**
  String get joinCodeLabel;

  /// No description provided for @joinCodeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Collez le code ou ouvrez le lien reçu.'**
  String get joinCodeHelp;

  /// No description provided for @joinCheck.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get joinCheck;

  /// No description provided for @joinInvitedTo.
  ///
  /// In fr, this message translates to:
  /// **'Invitation à rejoindre {entreprise}'**
  String joinInvitedTo(String entreprise);

  /// No description provided for @joinRole.
  ///
  /// In fr, this message translates to:
  /// **'Rôle : {role}'**
  String joinRole(String role);

  /// No description provided for @joinForEmail.
  ///
  /// In fr, this message translates to:
  /// **'Destinée à {email}'**
  String joinForEmail(String email);

  /// No description provided for @joinExpires.
  ///
  /// In fr, this message translates to:
  /// **'Valable jusqu\'au {date}'**
  String joinExpires(String date);

  /// No description provided for @joinAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter l\'invitation'**
  String get joinAccept;

  /// No description provided for @joinIgnore.
  ///
  /// In fr, this message translates to:
  /// **'Ignorer'**
  String get joinIgnore;

  /// No description provided for @joinSignInToAccept.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous ou créez un compte avec l\'adresse invitée pour accepter.'**
  String get joinSignInToAccept;

  /// No description provided for @ruleInvitationInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Cette invitation est invalide.'**
  String get ruleInvitationInvalid;

  /// No description provided for @ruleInvitationExpired.
  ///
  /// In fr, this message translates to:
  /// **'Cette invitation a expiré.'**
  String get ruleInvitationExpired;

  /// No description provided for @ruleInvitationUsed.
  ///
  /// In fr, this message translates to:
  /// **'Cette invitation a déjà été utilisée.'**
  String get ruleInvitationUsed;

  /// No description provided for @ruleInvitationCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Cette invitation a été annulée.'**
  String get ruleInvitationCancelled;

  /// No description provided for @ruleInvitationOtherEmail.
  ///
  /// In fr, this message translates to:
  /// **'Cette invitation est destinée à une autre adresse e-mail.'**
  String get ruleInvitationOtherEmail;

  /// No description provided for @ruleInvitationNotCancellable.
  ///
  /// In fr, this message translates to:
  /// **'Cette invitation ne peut plus être annulée.'**
  String get ruleInvitationNotCancellable;

  /// No description provided for @ruleEmailNotConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez d\'abord votre adresse e-mail.'**
  String get ruleEmailNotConfirmed;

  /// No description provided for @ruleAlreadyMember.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne fait déjà partie de l\'entreprise.'**
  String get ruleAlreadyMember;

  /// No description provided for @ruleCompanyAlreadyCreated.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà créé une entreprise.'**
  String get ruleCompanyAlreadyCreated;

  /// No description provided for @rulePlanInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Cette formule n\'est pas disponible.'**
  String get rulePlanInvalid;

  /// No description provided for @ruleActivityRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez au moins une activité.'**
  String get ruleActivityRequired;

  /// No description provided for @ruleNameInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est trop court.'**
  String get ruleNameInvalid;

  /// No description provided for @rulePerimetreRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez au moins un site pour ce rôle.'**
  String get rulePerimetreRequired;

  /// No description provided for @inviteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Inviter un utilisateur'**
  String get inviteTitle;

  /// No description provided for @inviteRole.
  ///
  /// In fr, this message translates to:
  /// **'Rôle'**
  String get inviteRole;

  /// No description provided for @invitePerimetres.
  ///
  /// In fr, this message translates to:
  /// **'Sites autorisés'**
  String get invitePerimetres;

  /// No description provided for @inviteSend.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'invitation'**
  String get inviteSend;

  /// No description provided for @inviteNoRole.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rôle disponible avec votre abonnement.'**
  String get inviteNoRole;

  /// No description provided for @inviteCreatedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Invitation créée'**
  String get inviteCreatedTitle;

  /// No description provided for @inviteCreatedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Partagez ce lien avec {email}. Il est valable jusqu\'au {date} et ne sert qu\'une fois.'**
  String inviteCreatedMessage(String email, String date);

  /// No description provided for @inviteCopyLink.
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien'**
  String get inviteCopyLink;

  /// No description provided for @inviteCopyCode.
  ///
  /// In fr, this message translates to:
  /// **'Copier le code'**
  String get inviteCopyCode;

  /// No description provided for @inviteCopied.
  ///
  /// In fr, this message translates to:
  /// **'Copié'**
  String get inviteCopied;

  /// No description provided for @inviteCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler l\'invitation'**
  String get inviteCancel;

  /// No description provided for @invitationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Invitations'**
  String get invitationsTitle;

  /// No description provided for @invitationStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get invitationStatusPending;

  /// No description provided for @invitationStatusAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Acceptée'**
  String get invitationStatusAccepted;

  /// No description provided for @invitationStatusExpired.
  ///
  /// In fr, this message translates to:
  /// **'Expirée'**
  String get invitationStatusExpired;

  /// No description provided for @invitationStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get invitationStatusCancelled;

  /// No description provided for @navSell.
  ///
  /// In fr, this message translates to:
  /// **'Vendre'**
  String get navSell;

  /// No description provided for @navStock.
  ///
  /// In fr, this message translates to:
  /// **'Stock'**
  String get navStock;

  /// No description provided for @navFinances.
  ///
  /// In fr, this message translates to:
  /// **'Finances'**
  String get navFinances;

  /// No description provided for @navAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get navAccount;

  /// No description provided for @financesComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Le tableau de bord financier (chiffre d\'affaires, encaissements, dépenses, impayés) arrive avec les modules Ventes et Caisse.'**
  String get financesComingSoon;

  /// No description provided for @menuActivities.
  ///
  /// In fr, this message translates to:
  /// **'Mes activités'**
  String get menuActivities;

  /// No description provided for @menuPreferences.
  ///
  /// In fr, this message translates to:
  /// **'Préférences'**
  String get menuPreferences;

  /// No description provided for @menuSeeSubscription.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'abonnement'**
  String get menuSeeSubscription;

  /// No description provided for @activityStatusActive.
  ///
  /// In fr, this message translates to:
  /// **'Active'**
  String get activityStatusActive;

  /// No description provided for @activityActivate.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get activityActivate;

  /// No description provided for @activityActivateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activer {activity} ?'**
  String activityActivateTitle(String activity);

  /// No description provided for @activityActivateMessage.
  ///
  /// In fr, this message translates to:
  /// **'Les modules de cette activité seront ajoutés à votre entreprise. Créez ensuite son premier site.'**
  String get activityActivateMessage;

  /// No description provided for @activityActivated.
  ///
  /// In fr, this message translates to:
  /// **'Activité activée.'**
  String get activityActivated;

  /// No description provided for @homeToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get homeToday;

  /// No description provided for @homeWatch.
  ///
  /// In fr, this message translates to:
  /// **'À surveiller'**
  String get homeWatch;

  /// No description provided for @homeKpiPending.
  ///
  /// In fr, this message translates to:
  /// **'Les chiffres s\'afficheront dès les premières ventes enregistrées.'**
  String get homeKpiPending;

  /// No description provided for @kpiRevenue.
  ///
  /// In fr, this message translates to:
  /// **'Chiffre d\'affaires'**
  String get kpiRevenue;

  /// No description provided for @kpiCollected.
  ///
  /// In fr, this message translates to:
  /// **'Encaissé'**
  String get kpiCollected;

  /// No description provided for @kpiExpenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get kpiExpenses;

  /// No description provided for @kpiUnpaid.
  ///
  /// In fr, this message translates to:
  /// **'Impayés clients'**
  String get kpiUnpaid;

  /// No description provided for @homeTrialDaysLeft.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =0{Votre essai se termine aujourd\'hui} =1{Essai : 1 jour restant} other{Essai : {days} jours restants}}'**
  String homeTrialDaysLeft(int days);

  /// No description provided for @homeTrialHint.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez votre formule pour continuer sans interruption.'**
  String get homeTrialHint;

  /// No description provided for @roleCaissier.
  ///
  /// In fr, this message translates to:
  /// **'Caissier'**
  String get roleCaissier;

  /// No description provided for @roleGestionnaireImmobilier.
  ///
  /// In fr, this message translates to:
  /// **'Gestionnaire immobilier'**
  String get roleGestionnaireImmobilier;

  /// No description provided for @subscriptionUsageUnlimited.
  ///
  /// In fr, this message translates to:
  /// **'{used} · illimité'**
  String subscriptionUsageUnlimited(int used);

  /// No description provided for @companyPlanPrice.
  ///
  /// In fr, this message translates to:
  /// **'{price} / mois'**
  String companyPlanPrice(String price);

  /// No description provided for @entrepriseIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get entrepriseIdentity;

  /// No description provided for @entrepriseContact.
  ///
  /// In fr, this message translates to:
  /// **'Coordonnées'**
  String get entrepriseContact;

  /// No description provided for @entrepriseLegal.
  ///
  /// In fr, this message translates to:
  /// **'Informations légales'**
  String get entrepriseLegal;

  /// No description provided for @entreprisePreferences.
  ///
  /// In fr, this message translates to:
  /// **'Préférences'**
  String get entreprisePreferences;

  /// No description provided for @entreprisePhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get entreprisePhone;

  /// No description provided for @entrepriseAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get entrepriseAddress;

  /// No description provided for @entrepriseCity.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get entrepriseCity;

  /// No description provided for @entrepriseTaxId.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant fiscal (NIF)'**
  String get entrepriseTaxId;

  /// No description provided for @entrepriseTradeRegister.
  ///
  /// In fr, this message translates to:
  /// **'Registre du commerce (RCCM)'**
  String get entrepriseTradeRegister;

  /// No description provided for @entrepriseDocLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue des documents'**
  String get entrepriseDocLanguage;

  /// No description provided for @entrepriseSaved.
  ///
  /// In fr, this message translates to:
  /// **'Informations enregistrées.'**
  String get entrepriseSaved;

  /// No description provided for @entrepriseLogoLater.
  ///
  /// In fr, this message translates to:
  /// **'Le logo pourra être ajouté avec les pièces jointes (prochaine étape).'**
  String get entrepriseLogoLater;

  /// No description provided for @moduleAdminAudit.
  ///
  /// In fr, this message translates to:
  /// **'Journal d\'activité'**
  String get moduleAdminAudit;

  /// No description provided for @auditEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune activité enregistrée pour le moment.'**
  String get auditEmpty;

  /// No description provided for @auditSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get auditSystem;

  /// No description provided for @auditActionCreation.
  ///
  /// In fr, this message translates to:
  /// **'Création'**
  String get auditActionCreation;

  /// No description provided for @auditActionModification.
  ///
  /// In fr, this message translates to:
  /// **'Modification'**
  String get auditActionModification;

  /// No description provided for @auditActionArchivage.
  ///
  /// In fr, this message translates to:
  /// **'Archivage'**
  String get auditActionArchivage;

  /// No description provided for @auditActionRestauration.
  ///
  /// In fr, this message translates to:
  /// **'Restauration'**
  String get auditActionRestauration;

  /// No description provided for @auditActionSuppression.
  ///
  /// In fr, this message translates to:
  /// **'Suppression'**
  String get auditActionSuppression;

  /// No description provided for @auditEntityEntreprise.
  ///
  /// In fr, this message translates to:
  /// **'Entreprise'**
  String get auditEntityEntreprise;

  /// No description provided for @auditEntityActivite.
  ///
  /// In fr, this message translates to:
  /// **'Activité'**
  String get auditEntityActivite;

  /// No description provided for @auditEntityAbonnement.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement'**
  String get auditEntityAbonnement;

  /// No description provided for @auditEntityMembre.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get auditEntityMembre;

  /// No description provided for @auditEntityAffectation.
  ///
  /// In fr, this message translates to:
  /// **'Affectation à un site'**
  String get auditEntityAffectation;

  /// No description provided for @auditEntitySite.
  ///
  /// In fr, this message translates to:
  /// **'Site'**
  String get auditEntitySite;

  /// No description provided for @auditEntityInvitation.
  ///
  /// In fr, this message translates to:
  /// **'Invitation'**
  String get auditEntityInvitation;

  /// No description provided for @auditOtherFields.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 autre information} other{{count} autres informations}}'**
  String auditOtherFields(int count);

  /// No description provided for @espaceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Espace de travail'**
  String get espaceTitle;

  /// No description provided for @espaceGlobal.
  ///
  /// In fr, this message translates to:
  /// **'Vue globale'**
  String get espaceGlobal;

  /// No description provided for @espaceActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activité'**
  String get espaceActivity;

  /// No description provided for @espaceSite.
  ///
  /// In fr, this message translates to:
  /// **'Boutique / site'**
  String get espaceSite;

  /// No description provided for @commonClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get commonClear;

  /// No description provided for @ruleTextTooLong.
  ///
  /// In fr, this message translates to:
  /// **'Texte trop long ({max} caractères au maximum).'**
  String ruleTextTooLong(int max);

  /// No description provided for @homeCommonTools.
  ///
  /// In fr, this message translates to:
  /// **'Outils communs'**
  String get homeCommonTools;

  /// No description provided for @contactRelationClient.
  ///
  /// In fr, this message translates to:
  /// **'Client'**
  String get contactRelationClient;

  /// No description provided for @contactRelationFournisseur.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur'**
  String get contactRelationFournisseur;

  /// No description provided for @contactRelationLocataire.
  ///
  /// In fr, this message translates to:
  /// **'Locataire'**
  String get contactRelationLocataire;

  /// No description provided for @contactRelationProprietaire.
  ///
  /// In fr, this message translates to:
  /// **'Propriétaire'**
  String get contactRelationProprietaire;

  /// No description provided for @contactRelationPrestataire.
  ///
  /// In fr, this message translates to:
  /// **'Prestataire'**
  String get contactRelationPrestataire;

  /// No description provided for @contactTypePersonne.
  ///
  /// In fr, this message translates to:
  /// **'Personne'**
  String get contactTypePersonne;

  /// No description provided for @contactTypeOrganisation.
  ///
  /// In fr, this message translates to:
  /// **'Organisation'**
  String get contactTypeOrganisation;

  /// No description provided for @contactsSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom, téléphone, e-mail, ville…'**
  String get contactsSearchHint;

  /// No description provided for @contactsFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get contactsFilterAll;

  /// No description provided for @contactsShowArchived.
  ///
  /// In fr, this message translates to:
  /// **'Archivés'**
  String get contactsShowArchived;

  /// No description provided for @contactsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact pour le moment. Ajoutez vos clients, fournisseurs, locataires…'**
  String get contactsEmpty;

  /// No description provided for @contactsNoResult.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact ne correspond à la recherche.'**
  String get contactsNoResult;

  /// No description provided for @contactAdd.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contact'**
  String get contactAdd;

  /// No description provided for @contactNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contact'**
  String get contactNew;

  /// No description provided for @contactEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le contact'**
  String get contactEdit;

  /// No description provided for @contactDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Fiche contact'**
  String get contactDetailTitle;

  /// No description provided for @contactNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Ce contact n\'existe pas ou n\'est plus accessible.'**
  String get contactNotFound;

  /// No description provided for @contactSaved.
  ///
  /// In fr, this message translates to:
  /// **'Contact enregistré.'**
  String get contactSaved;

  /// No description provided for @contactArchived.
  ///
  /// In fr, this message translates to:
  /// **'Archivé'**
  String get contactArchived;

  /// No description provided for @contactArchive.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get contactArchive;

  /// No description provided for @contactRestore.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver'**
  String get contactRestore;

  /// No description provided for @contactArchiveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Archiver ce contact ?'**
  String get contactArchiveTitle;

  /// No description provided for @contactArchiveMessage.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » n\'apparaîtra plus dans les listes. Son historique est conservé et vous pourrez le réactiver.'**
  String contactArchiveMessage(String name);

  /// No description provided for @contactRelationsNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune relation indiquée'**
  String get contactRelationsNone;

  /// No description provided for @contactFieldNom.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get contactFieldNom;

  /// No description provided for @contactFieldRaisonSociale.
  ///
  /// In fr, this message translates to:
  /// **'Raison sociale'**
  String get contactFieldRaisonSociale;

  /// No description provided for @contactFieldPrenom.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get contactFieldPrenom;

  /// No description provided for @contactFieldTelephone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get contactFieldTelephone;

  /// No description provided for @contactFieldWhatsapp.
  ///
  /// In fr, this message translates to:
  /// **'WhatsApp'**
  String get contactFieldWhatsapp;

  /// No description provided for @contactWhatsappHint.
  ///
  /// In fr, this message translates to:
  /// **'À remplir seulement si différent du téléphone'**
  String get contactWhatsappHint;

  /// No description provided for @contactFieldEmail.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get contactFieldEmail;

  /// No description provided for @contactFieldAdresse.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get contactFieldAdresse;

  /// No description provided for @contactFieldVille.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get contactFieldVille;

  /// No description provided for @contactFieldRemarque.
  ///
  /// In fr, this message translates to:
  /// **'Remarque'**
  String get contactFieldRemarque;

  /// No description provided for @contactFieldRelations.
  ///
  /// In fr, this message translates to:
  /// **'Relation avec l\'entreprise'**
  String get contactFieldRelations;

  /// No description provided for @contactCall.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get contactCall;

  /// No description provided for @contactWhatsapp.
  ///
  /// In fr, this message translates to:
  /// **'WhatsApp'**
  String get contactWhatsapp;

  /// No description provided for @contactEmailAction.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get contactEmailAction;

  /// No description provided for @contactActionUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible sur cet appareil.'**
  String get contactActionUnavailable;

  /// No description provided for @contactHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get contactHistoryTitle;

  /// No description provided for @contactHistoryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Les ventes, paiements et loyers de ce contact apparaîtront ici dès que ces modules seront disponibles.'**
  String get contactHistoryEmpty;

  /// No description provided for @contactDuplicateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce contact existe peut-être déjà'**
  String get contactDuplicateTitle;

  /// No description provided for @contactDuplicateMessage.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une fiche a le même nom ou le même téléphone.} other{{count} fiches ont le même nom ou le même téléphone.}} Utilisez la fiche existante pour garder un historique unique.'**
  String contactDuplicateMessage(int count);

  /// No description provided for @contactDuplicateOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la fiche'**
  String get contactDuplicateOpen;

  /// No description provided for @contactDuplicateAddRelation.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter la relation'**
  String get contactDuplicateAddRelation;

  /// No description provided for @contactDuplicateCreateAnyway.
  ///
  /// In fr, this message translates to:
  /// **'Créer quand même'**
  String get contactDuplicateCreateAnyway;

  /// No description provided for @contactHistoryNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune somme due ni aucun paiement pour ce contact.'**
  String get contactHistoryNone;

  /// No description provided for @contactOwesUs.
  ///
  /// In fr, this message translates to:
  /// **'Nous doit'**
  String get contactOwesUs;

  /// No description provided for @contactWeOwe.
  ///
  /// In fr, this message translates to:
  /// **'Nous lui devons'**
  String get contactWeOwe;

  /// No description provided for @commonEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get commonEdit;

  /// No description provided for @homeSeeFinances.
  ///
  /// In fr, this message translates to:
  /// **'Voir les finances'**
  String get homeSeeFinances;

  /// No description provided for @validationAmount.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant supérieur à zéro'**
  String get validationAmount;

  /// No description provided for @validationAmountMax.
  ///
  /// In fr, this message translates to:
  /// **'Au maximum {max}'**
  String validationAmountMax(String max);

  /// No description provided for @paymentModeCash.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get paymentModeCash;

  /// No description provided for @paymentModeMobileMoney.
  ///
  /// In fr, this message translates to:
  /// **'Mobile money'**
  String get paymentModeMobileMoney;

  /// No description provided for @paymentModeCard.
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get paymentModeCard;

  /// No description provided for @paymentModeTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Virement'**
  String get paymentModeTransfer;

  /// No description provided for @paymentModeCheque.
  ///
  /// In fr, this message translates to:
  /// **'Chèque'**
  String get paymentModeCheque;

  /// No description provided for @paymentModeOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get paymentModeOther;

  /// No description provided for @debtStateUnpaid.
  ///
  /// In fr, this message translates to:
  /// **'À encaisser'**
  String get debtStateUnpaid;

  /// No description provided for @debtStateToPay.
  ///
  /// In fr, this message translates to:
  /// **'À payer'**
  String get debtStateToPay;

  /// No description provided for @debtStatePartial.
  ///
  /// In fr, this message translates to:
  /// **'Partiel'**
  String get debtStatePartial;

  /// No description provided for @debtStateOverdue.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get debtStateOverdue;

  /// No description provided for @debtStatePaid.
  ///
  /// In fr, this message translates to:
  /// **'Soldé'**
  String get debtStatePaid;

  /// No description provided for @debtStateCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get debtStateCancelled;

  /// No description provided for @cashMoveCollection.
  ///
  /// In fr, this message translates to:
  /// **'Encaissement'**
  String get cashMoveCollection;

  /// No description provided for @cashMoveDisbursement.
  ///
  /// In fr, this message translates to:
  /// **'Décaissement'**
  String get cashMoveDisbursement;

  /// No description provided for @cashMoveDeposit.
  ///
  /// In fr, this message translates to:
  /// **'Dépôt'**
  String get cashMoveDeposit;

  /// No description provided for @cashMoveWithdrawal.
  ///
  /// In fr, this message translates to:
  /// **'Retrait'**
  String get cashMoveWithdrawal;

  /// No description provided for @financeRejectedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Refusé par le serveur'**
  String get financeRejectedTitle;

  /// No description provided for @financeRejectedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette opération n\'a pas été enregistrée (droits, caisse fermée ou montant dépassé). Elle n\'est comptée dans aucun total.'**
  String get financeRejectedMessage;

  /// No description provided for @financeRejectedRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get financeRejectedRemove;

  /// No description provided for @financeRejectedShort.
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get financeRejectedShort;

  /// No description provided for @financeNoContact.
  ///
  /// In fr, this message translates to:
  /// **'Sans contact'**
  String get financeNoContact;

  /// No description provided for @financeContact.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get financeContact;

  /// No description provided for @financeInCash.
  ///
  /// In fr, this message translates to:
  /// **'En caisse'**
  String get financeInCash;

  /// No description provided for @financeToReceive.
  ///
  /// In fr, this message translates to:
  /// **'À recevoir'**
  String get financeToReceive;

  /// No description provided for @financeToPay.
  ///
  /// In fr, this message translates to:
  /// **'À payer'**
  String get financeToPay;

  /// No description provided for @financeOverdueAmount.
  ///
  /// In fr, this message translates to:
  /// **'{amount} en retard'**
  String financeOverdueAmount(String amount);

  /// No description provided for @financeNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Élément introuvable ou inaccessible.'**
  String get financeNotFound;

  /// No description provided for @financeSite.
  ///
  /// In fr, this message translates to:
  /// **'Boutique / agence'**
  String get financeSite;

  /// No description provided for @financeAllSites.
  ///
  /// In fr, this message translates to:
  /// **'Toute l\'entreprise'**
  String get financeAllSites;

  /// No description provided for @financePendingSync.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré sur l\'appareil, en attente d\'envoi'**
  String get financePendingSync;

  /// No description provided for @debtNewReceivable.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle somme à recevoir'**
  String get debtNewReceivable;

  /// No description provided for @debtNewPayable.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle somme à payer'**
  String get debtNewPayable;

  /// No description provided for @debtShowSettled.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les soldés'**
  String get debtShowSettled;

  /// No description provided for @debtEmptyReceivable.
  ///
  /// In fr, this message translates to:
  /// **'Personne ne vous doit d\'argent.'**
  String get debtEmptyReceivable;

  /// No description provided for @debtEmptyPayable.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne devez rien pour le moment.'**
  String get debtEmptyPayable;

  /// No description provided for @debtDueOn.
  ///
  /// In fr, this message translates to:
  /// **'Échéance {date}'**
  String debtDueOn(String date);

  /// No description provided for @debtDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Somme due'**
  String get debtDetailTitle;

  /// No description provided for @debtRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Reste dû'**
  String get debtRemaining;

  /// No description provided for @debtPaid.
  ///
  /// In fr, this message translates to:
  /// **'Déjà réglé'**
  String get debtPaid;

  /// No description provided for @debtTotal.
  ///
  /// In fr, this message translates to:
  /// **'Montant total'**
  String get debtTotal;

  /// No description provided for @debtDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get debtDate;

  /// No description provided for @debtDueDate.
  ///
  /// In fr, this message translates to:
  /// **'Échéance'**
  String get debtDueDate;

  /// No description provided for @debtNoDueDate.
  ///
  /// In fr, this message translates to:
  /// **'Sans échéance'**
  String get debtNoDueDate;

  /// No description provided for @debtCancelReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif d\'annulation'**
  String get debtCancelReason;

  /// No description provided for @debtCollect.
  ///
  /// In fr, this message translates to:
  /// **'Encaisser'**
  String get debtCollect;

  /// No description provided for @debtPay.
  ///
  /// In fr, this message translates to:
  /// **'Payer'**
  String get debtPay;

  /// No description provided for @debtCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get debtCancel;

  /// No description provided for @debtPayments.
  ///
  /// In fr, this message translates to:
  /// **'Paiements'**
  String get debtPayments;

  /// No description provided for @debtNoPayment.
  ///
  /// In fr, this message translates to:
  /// **'Aucun paiement pour le moment.'**
  String get debtNoPayment;

  /// No description provided for @debtCancelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler cette somme due ?'**
  String get debtCancelTitle;

  /// No description provided for @debtCancelMessage.
  ///
  /// In fr, this message translates to:
  /// **'Elle ne sera plus comptée. Elle reste visible dans l\'historique.'**
  String get debtCancelMessage;

  /// No description provided for @debtEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la somme due'**
  String get debtEdit;

  /// No description provided for @debtWhoOwes.
  ///
  /// In fr, this message translates to:
  /// **'Qui doit payer ?'**
  String get debtWhoOwes;

  /// No description provided for @debtOwedTo.
  ///
  /// In fr, this message translates to:
  /// **'À qui devez-vous ?'**
  String get debtOwedTo;

  /// No description provided for @debtLabel.
  ///
  /// In fr, this message translates to:
  /// **'Objet'**
  String get debtLabel;

  /// No description provided for @debtLabelHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : marchandises livrées à crédit'**
  String get debtLabelHint;

  /// No description provided for @debtAlreadyPaid.
  ///
  /// In fr, this message translates to:
  /// **'Déjà réglé : {amount}. Le total ne peut pas être inférieur.'**
  String debtAlreadyPaid(String amount);

  /// No description provided for @paymentNew.
  ///
  /// In fr, this message translates to:
  /// **'Encaisser'**
  String get paymentNew;

  /// No description provided for @paymentsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun paiement enregistré.'**
  String get paymentsEmpty;

  /// No description provided for @paymentCancellation.
  ///
  /// In fr, this message translates to:
  /// **'Annulation de paiement'**
  String get paymentCancellation;

  /// No description provided for @paymentIn.
  ///
  /// In fr, this message translates to:
  /// **'Encaissement'**
  String get paymentIn;

  /// No description provided for @paymentOut.
  ///
  /// In fr, this message translates to:
  /// **'Paiement versé'**
  String get paymentOut;

  /// No description provided for @paymentCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get paymentCancelled;

  /// No description provided for @paymentSaved.
  ///
  /// In fr, this message translates to:
  /// **'Paiement enregistré.'**
  String get paymentSaved;

  /// No description provided for @paymentNewIn.
  ///
  /// In fr, this message translates to:
  /// **'Encaisser'**
  String get paymentNewIn;

  /// No description provided for @paymentNewOut.
  ///
  /// In fr, this message translates to:
  /// **'Payer'**
  String get paymentNewOut;

  /// No description provided for @paymentFrom.
  ///
  /// In fr, this message translates to:
  /// **'Payé par'**
  String get paymentFrom;

  /// No description provided for @paymentTo.
  ///
  /// In fr, this message translates to:
  /// **'Payé à'**
  String get paymentTo;

  /// No description provided for @paymentAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get paymentAmount;

  /// No description provided for @paymentMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode de paiement'**
  String get paymentMode;

  /// No description provided for @paymentCashRegister.
  ///
  /// In fr, this message translates to:
  /// **'Caisse'**
  String get paymentCashRegister;

  /// No description provided for @paymentNoCashRegister.
  ///
  /// In fr, this message translates to:
  /// **'Hors caisse'**
  String get paymentNoCashRegister;

  /// No description provided for @paymentNoOpenRegister.
  ///
  /// In fr, this message translates to:
  /// **'Aucune caisse ouverte : le paiement sera enregistré hors caisse.'**
  String get paymentNoOpenRegister;

  /// No description provided for @paymentSettlesReceivables.
  ///
  /// In fr, this message translates to:
  /// **'Règle les sommes dues'**
  String get paymentSettlesReceivables;

  /// No description provided for @paymentSettlesPayables.
  ///
  /// In fr, this message translates to:
  /// **'Règle les dettes'**
  String get paymentSettlesPayables;

  /// No description provided for @paymentRemainingOf.
  ///
  /// In fr, this message translates to:
  /// **'Reste {amount}'**
  String paymentRemainingOf(String amount);

  /// No description provided for @paymentUnallocated.
  ///
  /// In fr, this message translates to:
  /// **'{amount} non affecté (avance)'**
  String paymentUnallocated(String amount);

  /// No description provided for @paymentReference.
  ///
  /// In fr, this message translates to:
  /// **'Référence'**
  String get paymentReference;

  /// No description provided for @paymentReferenceHint.
  ///
  /// In fr, this message translates to:
  /// **'N° de transaction, de chèque…'**
  String get paymentReferenceHint;

  /// No description provided for @paymentNote.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get paymentNote;

  /// No description provided for @paymentConfirmIn.
  ///
  /// In fr, this message translates to:
  /// **'Encaisser {amount}'**
  String paymentConfirmIn(String amount);

  /// No description provided for @paymentConfirmOut.
  ///
  /// In fr, this message translates to:
  /// **'Payer {amount}'**
  String paymentConfirmOut(String amount);

  /// No description provided for @paymentDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get paymentDetailTitle;

  /// No description provided for @paymentDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get paymentDate;

  /// No description provided for @paymentCancelsPayment.
  ///
  /// In fr, this message translates to:
  /// **'Annule le paiement'**
  String get paymentCancelsPayment;

  /// No description provided for @paymentOpenOriginal.
  ///
  /// In fr, this message translates to:
  /// **'Voir le paiement d\'origine'**
  String get paymentOpenOriginal;

  /// No description provided for @paymentCancelledBy.
  ///
  /// In fr, this message translates to:
  /// **'Annulé le'**
  String get paymentCancelledBy;

  /// No description provided for @paymentCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ce paiement'**
  String get paymentCancel;

  /// No description provided for @paymentCancelHint.
  ///
  /// In fr, this message translates to:
  /// **'Un paiement n\'est jamais effacé : son annulation est enregistrée et les sommes dues redeviennent dues.'**
  String get paymentCancelHint;

  /// No description provided for @paymentCancelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ce paiement ?'**
  String get paymentCancelTitle;

  /// No description provided for @paymentCancelMessage.
  ///
  /// In fr, this message translates to:
  /// **'Un paiement inverse de {amount} sera enregistré, et la caisse sera ajustée s\'il s\'agissait d\'espèces.'**
  String paymentCancelMessage(String amount);

  /// No description provided for @cashNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle caisse'**
  String get cashNew;

  /// No description provided for @cashEmptyAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Aucune caisse. Créez une caisse pour chaque boutique ou agence qui manipule des espèces.'**
  String get cashEmptyAdmin;

  /// No description provided for @cashEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune caisse accessible.'**
  String get cashEmpty;

  /// No description provided for @cashOpenState.
  ///
  /// In fr, this message translates to:
  /// **'Ouverte'**
  String get cashOpenState;

  /// No description provided for @cashClosedState.
  ///
  /// In fr, this message translates to:
  /// **'Fermée'**
  String get cashClosedState;

  /// No description provided for @cashOpenSince.
  ///
  /// In fr, this message translates to:
  /// **'Ouverte depuis {date}'**
  String cashOpenSince(String date);

  /// No description provided for @cashBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde en caisse'**
  String get cashBalance;

  /// No description provided for @cashOpeningBalance.
  ///
  /// In fr, this message translates to:
  /// **'Fond de caisse : {amount}'**
  String cashOpeningBalance(String amount);

  /// No description provided for @cashOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la caisse'**
  String get cashOpen;

  /// No description provided for @cashClose.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer la caisse'**
  String get cashClose;

  /// No description provided for @cashMovements.
  ///
  /// In fr, this message translates to:
  /// **'Mouvements'**
  String get cashMovements;

  /// No description provided for @cashNoMovement.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mouvement depuis l\'ouverture.'**
  String get cashNoMovement;

  /// No description provided for @cashHistory.
  ///
  /// In fr, this message translates to:
  /// **'Clôtures précédentes'**
  String get cashHistory;

  /// No description provided for @cashClosingPending.
  ///
  /// In fr, this message translates to:
  /// **'Clôture en attente d\'envoi'**
  String get cashClosingPending;

  /// No description provided for @cashClosingSummary.
  ///
  /// In fr, this message translates to:
  /// **'Attendu {expected} · compté {counted}'**
  String cashClosingSummary(String expected, String counted);

  /// No description provided for @cashNoGap.
  ///
  /// In fr, this message translates to:
  /// **'Aucun écart'**
  String get cashNoGap;

  /// No description provided for @cashOpeningAmount.
  ///
  /// In fr, this message translates to:
  /// **'Fond de caisse'**
  String get cashOpeningAmount;

  /// No description provided for @cashMoveReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get cashMoveReason;

  /// No description provided for @cashExpected.
  ///
  /// In fr, this message translates to:
  /// **'Montant attendu : {amount}'**
  String cashExpected(String amount);

  /// No description provided for @cashCounted.
  ///
  /// In fr, this message translates to:
  /// **'Montant compté'**
  String get cashCounted;

  /// No description provided for @cashGap.
  ///
  /// In fr, this message translates to:
  /// **'Écart : {amount}'**
  String cashGap(String amount);

  /// No description provided for @cashClosingNote.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire (facultatif)'**
  String get cashClosingNote;

  /// No description provided for @cashName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la caisse'**
  String get cashName;

  /// No description provided for @cashDefaultName.
  ///
  /// In fr, this message translates to:
  /// **'Caisse {site}'**
  String cashDefaultName(String site);

  /// No description provided for @ruleLabelInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez l\'objet (200 caractères au maximum).'**
  String get ruleLabelInvalid;

  /// No description provided for @ruleCommitmentCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Cette somme due a été annulée.'**
  String get ruleCommitmentCancelled;

  /// No description provided for @ruleCommitmentPaid.
  ///
  /// In fr, this message translates to:
  /// **'Des paiements ont déjà été enregistrés : annulez-les d\'abord.'**
  String get ruleCommitmentPaid;

  /// No description provided for @ruleTotalBelowPaid.
  ///
  /// In fr, this message translates to:
  /// **'Le total ne peut pas être inférieur à ce qui est déjà réglé ({amount}).'**
  String ruleTotalBelowPaid(String amount);

  /// No description provided for @ruleAmountAboveRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Montant supérieur au reste dû ({amount}).'**
  String ruleAmountAboveRemaining(String amount);

  /// No description provided for @ruleAllocationAbovePayment.
  ///
  /// In fr, this message translates to:
  /// **'La répartition dépasse le montant du paiement.'**
  String get ruleAllocationAbovePayment;

  /// No description provided for @ruleAllocationWrongDirection.
  ///
  /// In fr, this message translates to:
  /// **'Un encaissement ne peut régler qu\'une somme à recevoir, un paiement versé qu\'une somme à payer.'**
  String get ruleAllocationWrongDirection;

  /// No description provided for @ruleAllocationOtherContact.
  ///
  /// In fr, this message translates to:
  /// **'Cette somme due concerne un autre contact.'**
  String get ruleAllocationOtherContact;

  /// No description provided for @rulePaymentAlreadyCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Ce paiement est déjà annulé.'**
  String get rulePaymentAlreadyCancelled;

  /// No description provided for @ruleModeWithoutCash.
  ///
  /// In fr, this message translates to:
  /// **'Seules les espèces passent par la caisse.'**
  String get ruleModeWithoutCash;

  /// No description provided for @ruleDateInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Date de paiement invalide.'**
  String get ruleDateInvalid;

  /// No description provided for @ruleCashClosed.
  ///
  /// In fr, this message translates to:
  /// **'La caisse est fermée : ouvrez-la d\'abord.'**
  String get ruleCashClosed;

  /// No description provided for @ruleCashOpenSession.
  ///
  /// In fr, this message translates to:
  /// **'Clôturez d\'abord la caisse.'**
  String get ruleCashOpenSession;

  /// No description provided for @ruleCashAlreadyOpen.
  ///
  /// In fr, this message translates to:
  /// **'Cette caisse est déjà ouverte.'**
  String get ruleCashAlreadyOpen;

  /// No description provided for @ruleCashInactive.
  ///
  /// In fr, this message translates to:
  /// **'Cette caisse est désactivée.'**
  String get ruleCashInactive;

  /// No description provided for @ruleCashInsufficient.
  ///
  /// In fr, this message translates to:
  /// **'Espèces insuffisantes en caisse (solde : {amount}).'**
  String ruleCashInsufficient(String amount);

  /// No description provided for @ruleFinanceInconsistent.
  ///
  /// In fr, this message translates to:
  /// **'Opération impossible : données incohérentes. Actualisez puis réessayez.'**
  String get ruleFinanceInconsistent;

  /// No description provided for @financeExpensesMonth.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses du mois'**
  String get financeExpensesMonth;

  /// No description provided for @debtOpenExpense.
  ///
  /// In fr, this message translates to:
  /// **'Voir la dépense'**
  String get debtOpenExpense;

  /// No description provided for @expenseCatRent.
  ///
  /// In fr, this message translates to:
  /// **'Loyer'**
  String get expenseCatRent;

  /// No description provided for @expenseCatEnergy.
  ///
  /// In fr, this message translates to:
  /// **'Électricité'**
  String get expenseCatEnergy;

  /// No description provided for @expenseCatTransport.
  ///
  /// In fr, this message translates to:
  /// **'Transport'**
  String get expenseCatTransport;

  /// No description provided for @expenseCatSalaries.
  ///
  /// In fr, this message translates to:
  /// **'Salaires'**
  String get expenseCatSalaries;

  /// No description provided for @expenseCatSupplies.
  ///
  /// In fr, this message translates to:
  /// **'Fournitures'**
  String get expenseCatSupplies;

  /// No description provided for @expenseCatCommunication.
  ///
  /// In fr, this message translates to:
  /// **'Communication et publicité'**
  String get expenseCatCommunication;

  /// No description provided for @expenseCatMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Entretien'**
  String get expenseCatMaintenance;

  /// No description provided for @expenseCatTaxes.
  ///
  /// In fr, this message translates to:
  /// **'Impôts et taxes'**
  String get expenseCatTaxes;

  /// No description provided for @expenseCatOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get expenseCatOther;

  /// No description provided for @expenseNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle dépense'**
  String get expenseNew;

  /// No description provided for @expenseSaved.
  ///
  /// In fr, this message translates to:
  /// **'Dépense enregistrée.'**
  String get expenseSaved;

  /// No description provided for @expenseCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get expenseCategories;

  /// No description provided for @expensesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune dépense enregistrée.'**
  String get expensesEmpty;

  /// No description provided for @expenseCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get expenseCancelled;

  /// No description provided for @expenseToPay.
  ///
  /// In fr, this message translates to:
  /// **'À payer'**
  String get expenseToPay;

  /// No description provided for @expenseDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Dépense'**
  String get expenseDetailTitle;

  /// No description provided for @expenseDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de la dépense'**
  String get expenseDate;

  /// No description provided for @expenseSettlement.
  ///
  /// In fr, this message translates to:
  /// **'Règlement'**
  String get expenseSettlement;

  /// No description provided for @expensePaidWith.
  ///
  /// In fr, this message translates to:
  /// **'Payée · {mode}'**
  String expensePaidWith(String mode);

  /// No description provided for @expenseToPayRemaining.
  ///
  /// In fr, this message translates to:
  /// **'À payer : {amount}'**
  String expenseToPayRemaining(String amount);

  /// No description provided for @expenseSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur (facultatif)'**
  String get expenseSupplier;

  /// No description provided for @expenseCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la dépense'**
  String get expenseCancel;

  /// No description provided for @expenseEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la dépense'**
  String get expenseEdit;

  /// No description provided for @expenseLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get expenseLabel;

  /// No description provided for @expenseLabelHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : taxi pour la livraison'**
  String get expenseLabelHint;

  /// No description provided for @expenseCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get expenseCategory;

  /// No description provided for @expenseAmountLocked.
  ///
  /// In fr, this message translates to:
  /// **'Le montant ne se modifie pas : annulez la dépense puis ressaisissez-la.'**
  String get expenseAmountLocked;

  /// No description provided for @expenseCancelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler cette dépense ?'**
  String get expenseCancelTitle;

  /// No description provided for @expenseCancelMessagePaid.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement sera annulé (et la caisse réajustée pour des espèces), puis la dépense. Rien n\'est effacé de l\'historique.'**
  String get expenseCancelMessagePaid;

  /// No description provided for @expenseCancelMessage.
  ///
  /// In fr, this message translates to:
  /// **'La somme à payer liée sera annulée. Rien n\'est effacé de l\'historique.'**
  String get expenseCancelMessage;

  /// No description provided for @expenseCategoryNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle catégorie'**
  String get expenseCategoryNew;

  /// No description provided for @expenseCategoryName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la catégorie'**
  String get expenseCategoryName;

  /// No description provided for @expenseCategoriesHint.
  ///
  /// In fr, this message translates to:
  /// **'Une catégorie désactivée n\'est plus proposée ; les dépenses déjà saisies la conservent.'**
  String get expenseCategoriesHint;

  /// No description provided for @expensePaidNow.
  ///
  /// In fr, this message translates to:
  /// **'Payée maintenant'**
  String get expensePaidNow;

  /// No description provided for @expensePayLater.
  ///
  /// In fr, this message translates to:
  /// **'À payer plus tard'**
  String get expensePayLater;

  /// No description provided for @expenseReferenceHint.
  ///
  /// In fr, this message translates to:
  /// **'N° de facture, de reçu…'**
  String get expenseReferenceHint;

  /// No description provided for @ruleCommitmentLinked.
  ///
  /// In fr, this message translates to:
  /// **'Cette somme est liée à une dépense : modifiez ou annulez la dépense.'**
  String get ruleCommitmentLinked;

  /// No description provided for @ruleCategoryInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une catégorie active.'**
  String get ruleCategoryInvalid;

  /// No description provided for @ruleExpensePaid.
  ///
  /// In fr, this message translates to:
  /// **'Cette dépense est payée : annulez d\'abord son paiement.'**
  String get ruleExpensePaid;

  /// No description provided for @ruleExpenseCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Cette dépense est annulée.'**
  String get ruleExpenseCancelled;

  /// No description provided for @moduleCommunDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get moduleCommunDocuments;

  /// No description provided for @docTypeReceipt.
  ///
  /// In fr, this message translates to:
  /// **'Reçu'**
  String get docTypeReceipt;

  /// No description provided for @docTypeInvoice.
  ///
  /// In fr, this message translates to:
  /// **'Facture'**
  String get docTypeInvoice;

  /// No description provided for @docTypeQuote.
  ///
  /// In fr, this message translates to:
  /// **'Devis'**
  String get docTypeQuote;

  /// No description provided for @docTypeCreditNote.
  ///
  /// In fr, this message translates to:
  /// **'Avoir'**
  String get docTypeCreditNote;

  /// No description provided for @docSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'N° de document ou nom…'**
  String get docSearchHint;

  /// No description provided for @docEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun document émis. Les reçus s\'émettent depuis la fiche d\'un paiement.'**
  String get docEmpty;

  /// No description provided for @docIssueReceipt.
  ///
  /// In fr, this message translates to:
  /// **'Émettre le reçu'**
  String get docIssueReceipt;

  /// No description provided for @docOpenReceipt.
  ///
  /// In fr, this message translates to:
  /// **'Voir le reçu {numero}'**
  String docOpenReceipt(String numero);

  /// No description provided for @docReceiptTitle.
  ///
  /// In fr, this message translates to:
  /// **'REÇU'**
  String get docReceiptTitle;

  /// No description provided for @docDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get docDate;

  /// No description provided for @docReceivedFrom.
  ///
  /// In fr, this message translates to:
  /// **'Reçu de'**
  String get docReceivedFrom;

  /// No description provided for @docPaymentMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode de paiement'**
  String get docPaymentMode;

  /// No description provided for @docReference.
  ///
  /// In fr, this message translates to:
  /// **'Référence'**
  String get docReference;

  /// No description provided for @docAmountReceived.
  ///
  /// In fr, this message translates to:
  /// **'Montant reçu'**
  String get docAmountReceived;

  /// No description provided for @docSettles.
  ///
  /// In fr, this message translates to:
  /// **'Règlement de'**
  String get docSettles;

  /// No description provided for @docColumnLabel.
  ///
  /// In fr, this message translates to:
  /// **'Objet'**
  String get docColumnLabel;

  /// No description provided for @docColumnAmount.
  ///
  /// In fr, this message translates to:
  /// **'Payé'**
  String get docColumnAmount;

  /// No description provided for @docColumnRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Reste dû'**
  String get docColumnRemaining;

  /// No description provided for @docIssuedBy.
  ///
  /// In fr, this message translates to:
  /// **'Émis par {name}'**
  String docIssuedBy(String name);

  /// No description provided for @docGeneratedBy.
  ///
  /// In fr, this message translates to:
  /// **'Document généré par DubaGest'**
  String get docGeneratedBy;

  /// No description provided for @docCancelledStamp.
  ///
  /// In fr, this message translates to:
  /// **'ANNULÉ'**
  String get docCancelledStamp;

  /// No description provided for @docPhone.
  ///
  /// In fr, this message translates to:
  /// **'Tél. : {value}'**
  String docPhone(String value);

  /// No description provided for @docTaxId.
  ///
  /// In fr, this message translates to:
  /// **'N° fiscal : {value}'**
  String docTaxId(String value);

  /// No description provided for @docTradeRegister.
  ///
  /// In fr, this message translates to:
  /// **'RCCM : {value}'**
  String docTradeRegister(String value);

  /// No description provided for @ruleDocumentExists.
  ///
  /// In fr, this message translates to:
  /// **'Un reçu a déjà été émis pour ce paiement.'**
  String get ruleDocumentExists;

  /// No description provided for @ruleDocumentOriginInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Un reçu ne s\'émet que pour un encaissement valide.'**
  String get ruleDocumentOriginInvalid;

  /// No description provided for @ruleDocumentNumbersExhausted.
  ///
  /// In fr, this message translates to:
  /// **'Plus de numéro de reçu disponible sur cet appareil. Connectez-vous à internet un instant pour en réserver.'**
  String get ruleDocumentNumbersExhausted;

  /// No description provided for @ruleDocumentNumberInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de document invalide. Actualisez puis réessayez.'**
  String get ruleDocumentNumberInvalid;

  /// No description provided for @moduleCommunAgenda.
  ///
  /// In fr, this message translates to:
  /// **'Agenda'**
  String get moduleCommunAgenda;

  /// No description provided for @agendaTypeReminder.
  ///
  /// In fr, this message translates to:
  /// **'Rappel'**
  String get agendaTypeReminder;

  /// No description provided for @agendaTypeMeeting.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous'**
  String get agendaTypeMeeting;

  /// No description provided for @agendaTypeTask.
  ///
  /// In fr, this message translates to:
  /// **'Tâche'**
  String get agendaTypeTask;

  /// No description provided for @agendaTypeFollowUp.
  ///
  /// In fr, this message translates to:
  /// **'Relance'**
  String get agendaTypeFollowUp;

  /// No description provided for @agendaNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle échéance'**
  String get agendaNew;

  /// No description provided for @agendaEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'échéance'**
  String get agendaEdit;

  /// No description provided for @agendaMine.
  ///
  /// In fr, this message translates to:
  /// **'Mes tâches'**
  String get agendaMine;

  /// No description provided for @agendaEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Rien de prévu. Ajoutez un rappel, une tâche ou une relance.'**
  String get agendaEmpty;

  /// No description provided for @agendaOverdue.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get agendaOverdue;

  /// No description provided for @agendaToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get agendaToday;

  /// No description provided for @agendaNextDays.
  ///
  /// In fr, this message translates to:
  /// **'7 prochains jours'**
  String get agendaNextDays;

  /// No description provided for @agendaLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get agendaLater;

  /// No description provided for @agendaAssignedTo.
  ///
  /// In fr, this message translates to:
  /// **'Confié à {name}'**
  String agendaAssignedTo(String name);

  /// No description provided for @agendaMarkDone.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme fait'**
  String get agendaMarkDone;

  /// No description provided for @agendaReopen.
  ///
  /// In fr, this message translates to:
  /// **'Remettre à faire'**
  String get agendaReopen;

  /// No description provided for @agendaCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler l\'échéance'**
  String get agendaCancel;

  /// No description provided for @agendaDueToReceive.
  ///
  /// In fr, this message translates to:
  /// **'Échéance d\'encaissement'**
  String get agendaDueToReceive;

  /// No description provided for @agendaDueToPay.
  ///
  /// In fr, this message translates to:
  /// **'Échéance de paiement'**
  String get agendaDueToPay;

  /// No description provided for @agendaReminderBefore.
  ///
  /// In fr, this message translates to:
  /// **'Rappel {delay} avant'**
  String agendaReminderBefore(String delay);

  /// No description provided for @agendaOpenDebt.
  ///
  /// In fr, this message translates to:
  /// **'Voir la somme due'**
  String get agendaOpenDebt;

  /// No description provided for @agendaStatusTodo.
  ///
  /// In fr, this message translates to:
  /// **'À faire'**
  String get agendaStatusTodo;

  /// No description provided for @agendaStatusDone.
  ///
  /// In fr, this message translates to:
  /// **'Fait'**
  String get agendaStatusDone;

  /// No description provided for @agendaStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get agendaStatusCancelled;

  /// No description provided for @agendaTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get agendaTitle;

  /// No description provided for @agendaTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : appeler Amadou pour le solde'**
  String get agendaTitleHint;

  /// No description provided for @agendaWhen.
  ///
  /// In fr, this message translates to:
  /// **'Date et heure'**
  String get agendaWhen;

  /// No description provided for @agendaReminder.
  ///
  /// In fr, this message translates to:
  /// **'Rappel'**
  String get agendaReminder;

  /// No description provided for @agendaNoReminder.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rappel'**
  String get agendaNoReminder;

  /// No description provided for @agendaAssignee.
  ///
  /// In fr, this message translates to:
  /// **'Confier à'**
  String get agendaAssignee;

  /// No description provided for @agendaNobody.
  ///
  /// In fr, this message translates to:
  /// **'Personne en particulier'**
  String get agendaNobody;

  /// No description provided for @agendaMe.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get agendaMe;

  /// No description provided for @agendaPlanFollowUp.
  ///
  /// In fr, this message translates to:
  /// **'Planifier une relance'**
  String get agendaPlanFollowUp;

  /// No description provided for @agendaFollowUpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Relancer {name}'**
  String agendaFollowUpTitle(String name);

  /// No description provided for @agendaDelayMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{n} min'**
  String agendaDelayMinutes(int n);

  /// No description provided for @agendaDelayHours.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 heure} other{{n} heures}}'**
  String agendaDelayHours(int n);

  /// No description provided for @agendaDelayDays.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 jour} other{{n} jours}}'**
  String agendaDelayDays(int n);

  /// No description provided for @notificationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer lu'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Rien à signaler.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsToHandle.
  ///
  /// In fr, this message translates to:
  /// **'À traiter'**
  String get notificationsToHandle;

  /// No description provided for @notificationsReceived.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get notificationsReceived;

  /// No description provided for @notifOverdue.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get notifOverdue;

  /// No description provided for @notifDueSoon.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt'**
  String get notifDueSoon;

  /// No description provided for @notifDebtsOverdue.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 somme à recevoir en retard} other{{n} sommes à recevoir en retard}}'**
  String notifDebtsOverdue(int n);

  /// No description provided for @notifCashOpenLong.
  ///
  /// In fr, this message translates to:
  /// **'{name} ouverte depuis plus de 24 h'**
  String notifCashOpenLong(String name);

  /// No description provided for @notifRejected.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 opération refusée par le serveur} other{{n} opérations refusées par le serveur}}'**
  String notifRejected(int n);

  /// No description provided for @notifRejectedHint.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez-la pour lire le motif et la retirer.'**
  String get notifRejectedHint;

  /// No description provided for @notifAssigned.
  ///
  /// In fr, this message translates to:
  /// **'{name} vous a confié une tâche'**
  String notifAssigned(String name);

  /// No description provided for @notifDone.
  ///
  /// In fr, this message translates to:
  /// **'{name} a terminé une tâche'**
  String notifDone(String name);

  /// No description provided for @ruleAssigneeInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne n\'est pas un membre actif de l\'entreprise.'**
  String get ruleAssigneeInvalid;

  /// No description provided for @ruleTargetInvalid.
  ///
  /// In fr, this message translates to:
  /// **'La fiche liée n\'existe plus.'**
  String get ruleTargetInvalid;

  /// No description provided for @dashboardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get dashboardTitle;

  /// No description provided for @dashboard7Days.
  ///
  /// In fr, this message translates to:
  /// **'7 jours'**
  String get dashboard7Days;

  /// No description provided for @dashboard30Days.
  ///
  /// In fr, this message translates to:
  /// **'30 jours'**
  String get dashboard30Days;

  /// No description provided for @dashboardMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois'**
  String get dashboardMonth;

  /// No description provided for @dashboardEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération sur cette période pour cet espace.'**
  String get dashboardEmpty;

  /// No description provided for @dashboardFlows.
  ///
  /// In fr, this message translates to:
  /// **'Encaissé et versé par jour'**
  String get dashboardFlows;

  /// No description provided for @dashboardExpensesByCategory.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses par catégorie'**
  String get dashboardExpensesByCategory;

  /// No description provided for @dashboardTopDebtors.
  ///
  /// In fr, this message translates to:
  /// **'Qui vous doit le plus'**
  String get dashboardTopDebtors;

  /// No description provided for @dashboardCollected.
  ///
  /// In fr, this message translates to:
  /// **'Encaissé'**
  String get dashboardCollected;

  /// No description provided for @dashboardPaidOut.
  ///
  /// In fr, this message translates to:
  /// **'Versé'**
  String get dashboardPaidOut;

  /// No description provided for @dashboardNet.
  ///
  /// In fr, this message translates to:
  /// **'Solde de la période'**
  String get dashboardNet;

  /// No description provided for @dashboardExpenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get dashboardExpenses;

  /// No description provided for @dashboardOtherCategories.
  ///
  /// In fr, this message translates to:
  /// **'Autres catégories'**
  String get dashboardOtherCategories;

  /// No description provided for @dashboardSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get dashboardSeeAll;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un contact, un reçu, un paiement…'**
  String get searchHint;

  /// No description provided for @searchIntro.
  ///
  /// In fr, this message translates to:
  /// **'Nom, téléphone, montant, n° de reçu… La recherche fonctionne aussi hors-ligne.'**
  String get searchIntro;

  /// No description provided for @searchNoResult.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat.'**
  String get searchNoResult;

  /// No description provided for @searchDebts.
  ///
  /// In fr, this message translates to:
  /// **'Sommes dues'**
  String get searchDebts;

  /// No description provided for @moduleCommunRapports.
  ///
  /// In fr, this message translates to:
  /// **'Rapports'**
  String get moduleCommunRapports;

  /// No description provided for @reportCashJournal.
  ///
  /// In fr, this message translates to:
  /// **'Journal de trésorerie'**
  String get reportCashJournal;

  /// No description provided for @reportCashJournalHint.
  ///
  /// In fr, this message translates to:
  /// **'Tous les encaissements et paiements versés de la période.'**
  String get reportCashJournalHint;

  /// No description provided for @reportExpenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses par catégorie'**
  String get reportExpenses;

  /// No description provided for @reportExpensesHint.
  ///
  /// In fr, this message translates to:
  /// **'Nombre et total des dépenses de la période, par catégorie.'**
  String get reportExpensesHint;

  /// No description provided for @reportAgedReceivables.
  ///
  /// In fr, this message translates to:
  /// **'Balance âgée des créances'**
  String get reportAgedReceivables;

  /// No description provided for @reportAgedReceivablesHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce que chaque client doit encore, selon l\'ancienneté du retard.'**
  String get reportAgedReceivablesHint;

  /// No description provided for @reportCashClosings.
  ///
  /// In fr, this message translates to:
  /// **'Clôtures de caisse'**
  String get reportCashClosings;

  /// No description provided for @reportCashClosingsHint.
  ///
  /// In fr, this message translates to:
  /// **'Solde attendu, montant compté et écart de chaque clôture.'**
  String get reportCashClosingsHint;

  /// No description provided for @reportPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Du {start} au {end}'**
  String reportPeriod(String start, String end);

  /// No description provided for @reportAtDate.
  ///
  /// In fr, this message translates to:
  /// **'Situation au {date}'**
  String reportAtDate(String date);

  /// No description provided for @reportTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get reportTotal;

  /// No description provided for @reportNet.
  ///
  /// In fr, this message translates to:
  /// **'Solde : {amount}'**
  String reportNet(String amount);

  /// No description provided for @reportCount.
  ///
  /// In fr, this message translates to:
  /// **'Nombre'**
  String get reportCount;

  /// No description provided for @reportNotDue.
  ///
  /// In fr, this message translates to:
  /// **'Non échu'**
  String get reportNotDue;

  /// No description provided for @reportDaysRange.
  ///
  /// In fr, this message translates to:
  /// **'{a} à {b} j'**
  String reportDaysRange(int a, int b);

  /// No description provided for @reportDaysOver.
  ///
  /// In fr, this message translates to:
  /// **'Plus de {n} j'**
  String reportDaysOver(int n);

  /// No description provided for @reportClosedOn.
  ///
  /// In fr, this message translates to:
  /// **'Clôturée le'**
  String get reportClosedOn;

  /// No description provided for @reportExpected.
  ///
  /// In fr, this message translates to:
  /// **'Attendu'**
  String get reportExpected;

  /// No description provided for @reportGap.
  ///
  /// In fr, this message translates to:
  /// **'Écart'**
  String get reportGap;

  /// No description provided for @reportNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rapport disponible avec vos droits.'**
  String get reportNone;

  /// No description provided for @reportEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée pour cette période.'**
  String get reportEmpty;

  /// No description provided for @reportExportPdf.
  ///
  /// In fr, this message translates to:
  /// **'Exporter en PDF'**
  String get reportExportPdf;

  /// No description provided for @reportGeneratedOn.
  ///
  /// In fr, this message translates to:
  /// **'Édité le {date} — DubaGest'**
  String reportGeneratedOn(String date);

  /// No description provided for @notesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notes et pièces jointes'**
  String get notesTitle;

  /// No description provided for @notesAddHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une note…'**
  String get notesAddHint;

  /// No description provided for @notesAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter la note'**
  String get notesAdd;

  /// No description provided for @attachmentsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pièces jointes'**
  String get attachmentsTitle;

  /// No description provided for @attachTakePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get attachTakePhoto;

  /// No description provided for @attachChooseFile.
  ///
  /// In fr, this message translates to:
  /// **'Joindre un fichier'**
  String get attachChooseFile;

  /// No description provided for @attachOnlineHint.
  ///
  /// In fr, this message translates to:
  /// **'Photo ou PDF, 10 Mo au plus. L\'envoi d\'un fichier demande une connexion.'**
  String get attachOnlineHint;

  /// No description provided for @attachFileTypes.
  ///
  /// In fr, this message translates to:
  /// **'Images et PDF'**
  String get attachFileTypes;

  /// No description provided for @attachSizeKb.
  ///
  /// In fr, this message translates to:
  /// **'{n} Ko'**
  String attachSizeKb(int n);

  /// No description provided for @attachSizeMb.
  ///
  /// In fr, this message translates to:
  /// **'{value} Mo'**
  String attachSizeMb(String value);

  /// No description provided for @entrepriseLogoHint.
  ///
  /// In fr, this message translates to:
  /// **'Le logo apparaît en tête des reçus (PNG, JPEG ou WEBP, 2 Mo au plus).'**
  String get entrepriseLogoHint;

  /// No description provided for @entrepriseLogoChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer le logo'**
  String get entrepriseLogoChange;

  /// No description provided for @entrepriseLogoSaved.
  ///
  /// In fr, this message translates to:
  /// **'Logo enregistré.'**
  String get entrepriseLogoSaved;

  /// No description provided for @entrepriseLogoTypes.
  ///
  /// In fr, this message translates to:
  /// **'Images'**
  String get entrepriseLogoTypes;

  /// No description provided for @ruleFileTypeInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Format non accepté : photo (JPEG, PNG, WEBP) ou PDF uniquement.'**
  String get ruleFileTypeInvalid;

  /// No description provided for @ruleFileTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Fichier trop volumineux ({max} Mo au plus).'**
  String ruleFileTooLarge(int max);

  /// No description provided for @settingsCompanyProfile.
  ///
  /// In fr, this message translates to:
  /// **'Fiche de l\'entreprise'**
  String get settingsCompanyProfile;

  /// No description provided for @settingsPayments.
  ///
  /// In fr, this message translates to:
  /// **'Paiements et reçus'**
  String get settingsPayments;

  /// No description provided for @settingsPaymentsHint.
  ///
  /// In fr, this message translates to:
  /// **'Modes de paiement proposés, mention des reçus'**
  String get settingsPaymentsHint;

  /// No description provided for @settingsExpenseCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories de dépenses'**
  String get settingsExpenseCategories;

  /// No description provided for @settingsPaymentModes.
  ///
  /// In fr, this message translates to:
  /// **'Modes de paiement proposés'**
  String get settingsPaymentModes;

  /// No description provided for @settingsPaymentModesHint.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les modes activés sont proposés à la saisie. Les paiements déjà enregistrés ne changent pas.'**
  String get settingsPaymentModesHint;

  /// No description provided for @settingsPaymentModeCash.
  ///
  /// In fr, this message translates to:
  /// **'Passe par la caisse'**
  String get settingsPaymentModeCash;

  /// No description provided for @settingsReceiptFooter.
  ///
  /// In fr, this message translates to:
  /// **'Mention en bas des reçus'**
  String get settingsReceiptFooter;

  /// No description provided for @settingsReceiptFooterHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Merci de votre confiance.'**
  String get settingsReceiptFooterHint;

  /// No description provided for @settingsReceiptFooterNote.
  ///
  /// In fr, this message translates to:
  /// **'Imprimée sur les prochains reçus ; les reçus déjà émis ne changent pas.'**
  String get settingsReceiptFooterNote;

  /// No description provided for @settingsSaved.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres enregistrés.'**
  String get settingsSaved;

  /// No description provided for @rulePaymentModesInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez au moins un mode de paiement de la liste.'**
  String get rulePaymentModesInvalid;

  /// No description provided for @rulePaymentModeDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Ce mode de paiement n\'est plus proposé par l\'entreprise. Choisissez-en un autre.'**
  String get rulePaymentModeDisabled;

  /// No description provided for @comStatusInStock.
  ///
  /// In fr, this message translates to:
  /// **'En stock'**
  String get comStatusInStock;

  /// No description provided for @comStatusLow.
  ///
  /// In fr, this message translates to:
  /// **'Stock faible'**
  String get comStatusLow;

  /// No description provided for @comStatusOut.
  ///
  /// In fr, this message translates to:
  /// **'Rupture'**
  String get comStatusOut;

  /// No description provided for @comAllShops.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les boutiques'**
  String get comAllShops;

  /// No description provided for @comChooseShop.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la boutique'**
  String get comChooseShop;

  /// No description provided for @comShop.
  ///
  /// In fr, this message translates to:
  /// **'Boutique'**
  String get comShop;

  /// No description provided for @comShopRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une boutique'**
  String get comShopRequired;

  /// No description provided for @comBefore.
  ///
  /// In fr, this message translates to:
  /// **'Avant'**
  String get comBefore;

  /// No description provided for @comAfter.
  ///
  /// In fr, this message translates to:
  /// **'Après'**
  String get comAfter;

  /// No description provided for @comQuantity.
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get comQuantity;

  /// No description provided for @comQuantityInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Entrez une quantité valable'**
  String get comQuantityInvalid;

  /// No description provided for @comFractionNotAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Ce produit se compte en {unite} entiers'**
  String comFractionNotAllowed(String unite);

  /// No description provided for @comFractionStep.
  ///
  /// In fr, this message translates to:
  /// **'Par pas de {pas} {unite}'**
  String comFractionStep(String pas, String unite);

  /// No description provided for @comScan.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un code-barres'**
  String get comScan;

  /// No description provided for @comScanTitle.
  ///
  /// In fr, this message translates to:
  /// **'Scanner'**
  String get comScanTitle;

  /// No description provided for @comTorch.
  ///
  /// In fr, this message translates to:
  /// **'Lampe'**
  String get comTorch;

  /// No description provided for @comScanUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'La caméra n\'est pas disponible. Saisissez le code à la main.'**
  String get comScanUnavailable;

  /// No description provided for @comScanHint.
  ///
  /// In fr, this message translates to:
  /// **'Placez le code-barres dans le cadre'**
  String get comScanHint;

  /// No description provided for @comBarcodeUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Ce code n\'est lié à aucun produit'**
  String get comBarcodeUnknown;

  /// No description provided for @comChooseProduct.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un produit'**
  String get comChooseProduct;

  /// No description provided for @comSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom, référence ou code-barres…'**
  String get comSearchHint;

  /// No description provided for @comAllCategories.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get comAllCategories;

  /// No description provided for @comNoProductFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit trouvé'**
  String get comNoProductFound;

  /// No description provided for @comNoProductFoundHint.
  ///
  /// In fr, this message translates to:
  /// **'Essayez un autre mot, ou ajoutez ce produit.'**
  String get comNoProductFoundHint;

  /// No description provided for @comAddProduct.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un produit'**
  String get comAddProduct;

  /// No description provided for @comUsualProducts.
  ///
  /// In fr, this message translates to:
  /// **'Produits habituels'**
  String get comUsualProducts;

  /// No description provided for @comAllProducts.
  ///
  /// In fr, this message translates to:
  /// **'Tous les produits'**
  String get comAllProducts;

  /// No description provided for @comProduct.
  ///
  /// In fr, this message translates to:
  /// **'Produit'**
  String get comProduct;

  /// No description provided for @comFrom.
  ///
  /// In fr, this message translates to:
  /// **'De'**
  String get comFrom;

  /// No description provided for @comTo.
  ///
  /// In fr, this message translates to:
  /// **'Vers'**
  String get comTo;

  /// No description provided for @comNewEntry.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle entrée'**
  String get comNewEntry;

  /// No description provided for @comSaveEntry.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer l\'entrée'**
  String get comSaveEntry;

  /// No description provided for @comNewExit.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle sortie'**
  String get comNewExit;

  /// No description provided for @comConfirmExit.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la sortie'**
  String get comConfirmExit;

  /// No description provided for @comTransferStock.
  ///
  /// In fr, this message translates to:
  /// **'Transférer du stock'**
  String get comTransferStock;

  /// No description provided for @comConfirmTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le transfert'**
  String get comConfirmTransfer;

  /// No description provided for @comInventory.
  ///
  /// In fr, this message translates to:
  /// **'Inventaire'**
  String get comInventory;

  /// No description provided for @comValidateInventory.
  ///
  /// In fr, this message translates to:
  /// **'Valider l\'inventaire'**
  String get comValidateInventory;

  /// No description provided for @comConfirmExitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la sortie ?'**
  String get comConfirmExitTitle;

  /// No description provided for @comConfirmTransferTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le transfert ?'**
  String get comConfirmTransferTitle;

  /// No description provided for @comConfirmInventoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Valider l\'inventaire ?'**
  String get comConfirmInventoryTitle;

  /// No description provided for @comCurrentStock.
  ///
  /// In fr, this message translates to:
  /// **'Stock actuel : {quantite}'**
  String comCurrentStock(String quantite);

  /// No description provided for @comHowMany.
  ///
  /// In fr, this message translates to:
  /// **'Combien ?'**
  String get comHowMany;

  /// No description provided for @comCountedQuantity.
  ///
  /// In fr, this message translates to:
  /// **'Combien en avez-vous compté ?'**
  String get comCountedQuantity;

  /// No description provided for @comWhy.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi cet écart ?'**
  String get comWhy;

  /// No description provided for @comReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get comReason;

  /// No description provided for @comNoteOptional.
  ///
  /// In fr, this message translates to:
  /// **'Note (facultatif)'**
  String get comNoteOptional;

  /// No description provided for @comAddNote.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une note'**
  String get comAddNote;

  /// No description provided for @comStockPreview.
  ///
  /// In fr, this message translates to:
  /// **'Votre stock'**
  String get comStockPreview;

  /// No description provided for @comStockInsufficientInline.
  ///
  /// In fr, this message translates to:
  /// **'Stock insuffisant · Disponible : {disponible}'**
  String comStockInsufficientInline(String disponible);

  /// No description provided for @comInventoryNoGap.
  ///
  /// In fr, this message translates to:
  /// **'Aucun écart : le stock est juste'**
  String get comInventoryNoGap;

  /// No description provided for @comInventoryGap.
  ///
  /// In fr, this message translates to:
  /// **'Écart : {ecart}'**
  String comInventoryGap(String ecart);

  /// No description provided for @comStockUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Stock mis à jour'**
  String get comStockUpdated;

  /// No description provided for @comTransferDone.
  ///
  /// In fr, this message translates to:
  /// **'{quantite} transférés vers {boutique}'**
  String comTransferDone(String quantite, String boutique);

  /// No description provided for @comReasonPurchase.
  ///
  /// In fr, this message translates to:
  /// **'Achat'**
  String get comReasonPurchase;

  /// No description provided for @comReasonReturn.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get comReasonReturn;

  /// No description provided for @comReasonAdjustment.
  ///
  /// In fr, this message translates to:
  /// **'Ajustement'**
  String get comReasonAdjustment;

  /// No description provided for @comReasonSale.
  ///
  /// In fr, this message translates to:
  /// **'Vente'**
  String get comReasonSale;

  /// No description provided for @comReasonLoss.
  ///
  /// In fr, this message translates to:
  /// **'Perte'**
  String get comReasonLoss;

  /// No description provided for @comReasonBreakage.
  ///
  /// In fr, this message translates to:
  /// **'Casse'**
  String get comReasonBreakage;

  /// No description provided for @comReasonTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get comReasonTransfer;

  /// No description provided for @comReasonCountError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de comptage'**
  String get comReasonCountError;

  /// No description provided for @comReasonMissing.
  ///
  /// In fr, this message translates to:
  /// **'Produit manquant'**
  String get comReasonMissing;

  /// No description provided for @comReasonOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get comReasonOther;

  /// No description provided for @ruleStockInsufficient.
  ///
  /// In fr, this message translates to:
  /// **'Stock insuffisant : il reste {disponible}.'**
  String ruleStockInsufficient(String disponible);

  /// No description provided for @ruleQuantityInvalid.
  ///
  /// In fr, this message translates to:
  /// **'La quantité doit être supérieure à zéro.'**
  String get ruleQuantityInvalid;

  /// No description provided for @ruleFractionInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Quantité non valable : ce produit se vend par {pas} {unite}.'**
  String ruleFractionInvalid(String pas, String unite);

  /// No description provided for @ruleUnitInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez les unités : chaque unité a un nom différent et contient au moins une unité de base.'**
  String get ruleUnitInvalid;

  /// No description provided for @ruleBarcodeExists.
  ///
  /// In fr, this message translates to:
  /// **'Ce code-barres est déjà utilisé par un autre produit.'**
  String get ruleBarcodeExists;

  /// No description provided for @ruleTransferSameShop.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez deux boutiques différentes.'**
  String get ruleTransferSameShop;

  /// No description provided for @ruleShopRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la boutique.'**
  String get ruleShopRequired;

  /// No description provided for @ruleLinesInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins un produit avec une quantité.'**
  String get ruleLinesInvalid;

  /// No description provided for @ruleReceptionAbove.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de recevoir plus que commandé (reste : {reste}).'**
  String ruleReceptionAbove(String reste);

  /// No description provided for @rulePurchaseReceived.
  ///
  /// In fr, this message translates to:
  /// **'Cet achat a déjà été reçu : il ne peut plus être modifié ni annulé.'**
  String get rulePurchaseReceived;

  /// No description provided for @rulePurchasePaid.
  ///
  /// In fr, this message translates to:
  /// **'Cet achat est déjà payé : annulez d\'abord le paiement.'**
  String get rulePurchasePaid;

  /// No description provided for @rulePurchaseCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Cet achat est annulé.'**
  String get rulePurchaseCancelled;

  /// No description provided for @ruleSaleCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Cette vente est déjà annulée.'**
  String get ruleSaleCancelled;

  /// No description provided for @ruleSalePaid.
  ///
  /// In fr, this message translates to:
  /// **'Cette vente est encaissée : annulez d\'abord le paiement dans Finances.'**
  String get ruleSalePaid;

  /// No description provided for @ruleCustomerRequired.
  ///
  /// In fr, this message translates to:
  /// **'Pour une vente à crédit, choisissez le client.'**
  String get ruleCustomerRequired;

  /// No description provided for @comProductsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Produits'**
  String get comProductsTitle;

  /// No description provided for @comCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get comCategories;

  /// No description provided for @comManageCategories.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les catégories'**
  String get comManageCategories;

  /// No description provided for @comGridView.
  ///
  /// In fr, this message translates to:
  /// **'Affichage en grille'**
  String get comGridView;

  /// No description provided for @comListView.
  ///
  /// In fr, this message translates to:
  /// **'Affichage en liste'**
  String get comListView;

  /// No description provided for @comEmptyProductsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit'**
  String get comEmptyProductsTitle;

  /// No description provided for @comEmptyProductsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez vos produits pour commencer à gérer votre stock et vos ventes.'**
  String get comEmptyProductsMessage;

  /// No description provided for @comProductsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun produit} =1{1 produit} other{{count} produits}}'**
  String comProductsCount(int count);

  /// No description provided for @comNoProductInCategory.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit dans {categorie}'**
  String comNoProductInCategory(String categorie);

  /// No description provided for @comAddProductHere.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un produit ici'**
  String get comAddProductHere;

  /// No description provided for @comSeeProduct.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get comSeeProduct;

  /// No description provided for @comAddToStock.
  ///
  /// In fr, this message translates to:
  /// **'+ Stock'**
  String get comAddToStock;

  /// No description provided for @comSell.
  ///
  /// In fr, this message translates to:
  /// **'Vendre'**
  String get comSell;

  /// No description provided for @comCreateProduct.
  ///
  /// In fr, this message translates to:
  /// **'Créer le produit'**
  String get comCreateProduct;

  /// No description provided for @comBarcodeUnknownHint.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous créer un produit avec ce code ?'**
  String get comBarcodeUnknownHint;

  /// No description provided for @comArchived.
  ///
  /// In fr, this message translates to:
  /// **'Archivé'**
  String get comArchived;

  /// No description provided for @comShowArchived.
  ///
  /// In fr, this message translates to:
  /// **'Produits archivés'**
  String get comShowArchived;

  /// No description provided for @comSortBy.
  ///
  /// In fr, this message translates to:
  /// **'Trier'**
  String get comSortBy;

  /// No description provided for @comSortName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get comSortName;

  /// No description provided for @comSortStock.
  ///
  /// In fr, this message translates to:
  /// **'Stock le plus bas'**
  String get comSortStock;

  /// No description provided for @comSortPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get comSortPrice;

  /// No description provided for @comSortBestSellers.
  ///
  /// In fr, this message translates to:
  /// **'Plus vendus'**
  String get comSortBestSellers;

  /// No description provided for @comNewProduct.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau produit'**
  String get comNewProduct;

  /// No description provided for @comEditProduct.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le produit'**
  String get comEditProduct;

  /// No description provided for @comStepIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Le produit'**
  String get comStepIdentity;

  /// No description provided for @comStepUnits.
  ///
  /// In fr, this message translates to:
  /// **'Unités et prix'**
  String get comStepUnits;

  /// No description provided for @comStepStock.
  ///
  /// In fr, this message translates to:
  /// **'Stock'**
  String get comStepStock;

  /// No description provided for @comStepOptions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d\'options'**
  String get comStepOptions;

  /// No description provided for @comStepOf.
  ///
  /// In fr, this message translates to:
  /// **'Étape {etape} sur {total}'**
  String comStepOf(int etape, int total);

  /// No description provided for @comNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get comNext;

  /// No description provided for @comPrevious.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get comPrevious;

  /// No description provided for @comSaveProduct.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le produit'**
  String get comSaveProduct;

  /// No description provided for @comProductSaved.
  ///
  /// In fr, this message translates to:
  /// **'Produit enregistré'**
  String get comProductSaved;

  /// No description provided for @comAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get comAddPhoto;

  /// No description provided for @comTakePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get comTakePhoto;

  /// No description provided for @comChooseFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get comChooseFromGallery;

  /// No description provided for @comPhotoHint.
  ///
  /// In fr, this message translates to:
  /// **'Une photo aide vos vendeurs à reconnaître le produit.'**
  String get comPhotoHint;

  /// No description provided for @comMainPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo principale'**
  String get comMainPhoto;

  /// No description provided for @comSetMainPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en premier'**
  String get comSetMainPhoto;

  /// No description provided for @comRemovePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la photo'**
  String get comRemovePhoto;

  /// No description provided for @comProductName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du produit'**
  String get comProductName;

  /// No description provided for @comProductNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Carreau 40×40'**
  String get comProductNameHint;

  /// No description provided for @comNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un nom au produit'**
  String get comNameRequired;

  /// No description provided for @comCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get comCategory;

  /// No description provided for @comSubCategory.
  ///
  /// In fr, this message translates to:
  /// **'Sous-catégorie'**
  String get comSubCategory;

  /// No description provided for @comNoCategory.
  ///
  /// In fr, this message translates to:
  /// **'Sans catégorie'**
  String get comNoCategory;

  /// No description provided for @comNewCategory.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle catégorie'**
  String get comNewCategory;

  /// No description provided for @comNewSubCategory.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle sous-catégorie'**
  String get comNewSubCategory;

  /// No description provided for @comCategoryName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la catégorie'**
  String get comCategoryName;

  /// No description provided for @comReference.
  ///
  /// In fr, this message translates to:
  /// **'Référence (facultatif)'**
  String get comReference;

  /// No description provided for @comBarcode.
  ///
  /// In fr, this message translates to:
  /// **'Code-barres (facultatif)'**
  String get comBarcode;

  /// No description provided for @comCountedIn.
  ///
  /// In fr, this message translates to:
  /// **'Je compte ce produit en…'**
  String get comCountedIn;

  /// No description provided for @comOtherUnit.
  ///
  /// In fr, this message translates to:
  /// **'Autre…'**
  String get comOtherUnit;

  /// No description provided for @comUnitName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'unité'**
  String get comUnitName;

  /// No description provided for @comUnitNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : botte, seau, fût'**
  String get comUnitNameHint;

  /// No description provided for @comSalePrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix de vente'**
  String get comSalePrice;

  /// No description provided for @comSalePricePer.
  ///
  /// In fr, this message translates to:
  /// **'Prix de vente par {unite}'**
  String comSalePricePer(String unite);

  /// No description provided for @comWholesalePricePer.
  ///
  /// In fr, this message translates to:
  /// **'Prix de gros par {unite}'**
  String comWholesalePricePer(String unite);

  /// No description provided for @comPurchasePricePer.
  ///
  /// In fr, this message translates to:
  /// **'Prix d\'achat par {unite} (facultatif)'**
  String comPurchasePricePer(String unite);

  /// No description provided for @comSellWholesale.
  ///
  /// In fr, this message translates to:
  /// **'Je vends aussi en gros'**
  String get comSellWholesale;

  /// No description provided for @comRetail.
  ///
  /// In fr, this message translates to:
  /// **'Détail'**
  String get comRetail;

  /// No description provided for @comWholesale.
  ///
  /// In fr, this message translates to:
  /// **'Gros'**
  String get comWholesale;

  /// No description provided for @comPurchase.
  ///
  /// In fr, this message translates to:
  /// **'Achat'**
  String get comPurchase;

  /// No description provided for @comPackagings.
  ///
  /// In fr, this message translates to:
  /// **'Emballages'**
  String get comPackagings;

  /// No description provided for @comPackagingsHint.
  ///
  /// In fr, this message translates to:
  /// **'Vous achetez ou vendez par carton, paquet, sac… ? Ajoutez-les : l\'application fera les calculs.'**
  String get comPackagingsHint;

  /// No description provided for @comAddPackaging.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un emballage'**
  String get comAddPackaging;

  /// No description provided for @comCopyUnits.
  ///
  /// In fr, this message translates to:
  /// **'Copier d\'un autre produit'**
  String get comCopyUnits;

  /// No description provided for @comOneUnitContains.
  ///
  /// In fr, this message translates to:
  /// **'1 {unite} contient'**
  String comOneUnitContains(String unite);

  /// No description provided for @comContains.
  ///
  /// In fr, this message translates to:
  /// **'contient'**
  String get comContains;

  /// No description provided for @comFactorRequired.
  ///
  /// In fr, this message translates to:
  /// **'Combien de {unite} ?'**
  String comFactorRequired(String unite);

  /// No description provided for @comCalculated.
  ///
  /// In fr, this message translates to:
  /// **'calculé'**
  String get comCalculated;

  /// No description provided for @comPriceSetByYou.
  ///
  /// In fr, this message translates to:
  /// **'prix fixé par vous'**
  String get comPriceSetByYou;

  /// No description provided for @comDiscountOf.
  ///
  /// In fr, this message translates to:
  /// **'remise de {pourcent} %'**
  String comDiscountOf(String pourcent);

  /// No description provided for @comMarkupOf.
  ///
  /// In fr, this message translates to:
  /// **'{pourcent} % plus cher que le détail'**
  String comMarkupOf(String pourcent);

  /// No description provided for @comPriceHigherWarning.
  ///
  /// In fr, this message translates to:
  /// **'Attention : ce lot coûte plus cher que les unités vendues séparément.'**
  String get comPriceHigherWarning;

  /// No description provided for @comBackToCalculated.
  ///
  /// In fr, this message translates to:
  /// **'Revenir au prix calculé'**
  String get comBackToCalculated;

  /// No description provided for @comProfitPer.
  ///
  /// In fr, this message translates to:
  /// **'Bénéfice : {montant} par {unite}'**
  String comProfitPer(String montant, String unite);

  /// No description provided for @comUnitsSummary.
  ///
  /// In fr, this message translates to:
  /// **'Résumé'**
  String get comUnitsSummary;

  /// No description provided for @comInitialStock.
  ///
  /// In fr, this message translates to:
  /// **'Stock de départ'**
  String get comInitialStock;

  /// No description provided for @comInitialStockHint.
  ///
  /// In fr, this message translates to:
  /// **'Combien en avez-vous aujourd\'hui ? (facultatif)'**
  String get comInitialStockHint;

  /// No description provided for @comInitialStockNote.
  ///
  /// In fr, this message translates to:
  /// **'Stock de départ'**
  String get comInitialStockNote;

  /// No description provided for @comAlertThreshold.
  ///
  /// In fr, this message translates to:
  /// **'Prévenez-moi quand il reste moins de…'**
  String get comAlertThreshold;

  /// No description provided for @comAlertThresholdHint.
  ///
  /// In fr, this message translates to:
  /// **'Le produit passera en « Stock faible ».'**
  String get comAlertThresholdHint;

  /// No description provided for @comSellFractions.
  ///
  /// In fr, this message translates to:
  /// **'Vente au détail en morceaux'**
  String get comSellFractions;

  /// No description provided for @comSellFractionsHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : ½ bidon, 2,5 mètres, 0,25 kg'**
  String get comSellFractionsHint;

  /// No description provided for @comMinimumStep.
  ///
  /// In fr, this message translates to:
  /// **'Plus petite quantité vendue'**
  String get comMinimumStep;

  /// No description provided for @comCharacteristics.
  ///
  /// In fr, this message translates to:
  /// **'Caractéristiques'**
  String get comCharacteristics;

  /// No description provided for @comAddCharacteristic.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une caractéristique'**
  String get comAddCharacteristic;

  /// No description provided for @comCharacteristicName.
  ///
  /// In fr, this message translates to:
  /// **'Nom (ex. : garantie)'**
  String get comCharacteristicName;

  /// No description provided for @comMainSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur principal'**
  String get comMainSupplier;

  /// No description provided for @comChooseSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un fournisseur'**
  String get comChooseSupplier;

  /// No description provided for @comDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description (facultatif)'**
  String get comDescription;

  /// No description provided for @comNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get comNone;

  /// No description provided for @comAttrMarque.
  ///
  /// In fr, this message translates to:
  /// **'Marque'**
  String get comAttrMarque;

  /// No description provided for @comAttrModele.
  ///
  /// In fr, this message translates to:
  /// **'Modèle'**
  String get comAttrModele;

  /// No description provided for @comAttrCouleur.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get comAttrCouleur;

  /// No description provided for @comAttrDimensions.
  ///
  /// In fr, this message translates to:
  /// **'Dimensions'**
  String get comAttrDimensions;

  /// No description provided for @comAttrFinition.
  ///
  /// In fr, this message translates to:
  /// **'Finition'**
  String get comAttrFinition;

  /// No description provided for @comAttrVolume.
  ///
  /// In fr, this message translates to:
  /// **'Volume'**
  String get comAttrVolume;

  /// No description provided for @comAttrType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get comAttrType;

  /// No description provided for @comAttrSection.
  ///
  /// In fr, this message translates to:
  /// **'Section'**
  String get comAttrSection;

  /// No description provided for @comAttrLongueur.
  ///
  /// In fr, this message translates to:
  /// **'Longueur'**
  String get comAttrLongueur;

  /// No description provided for @comAttrTaille.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get comAttrTaille;

  /// No description provided for @comAttrPoids.
  ///
  /// In fr, this message translates to:
  /// **'Poids'**
  String get comAttrPoids;

  /// No description provided for @comAttrEmplacement.
  ///
  /// In fr, this message translates to:
  /// **'Emplacement'**
  String get comAttrEmplacement;

  /// No description provided for @comUnitPiece.
  ///
  /// In fr, this message translates to:
  /// **'Pièce'**
  String get comUnitPiece;

  /// No description provided for @comUnitCarton.
  ///
  /// In fr, this message translates to:
  /// **'Carton'**
  String get comUnitCarton;

  /// No description provided for @comUnitPaquet.
  ///
  /// In fr, this message translates to:
  /// **'Paquet'**
  String get comUnitPaquet;

  /// No description provided for @comUnitSac.
  ///
  /// In fr, this message translates to:
  /// **'Sac'**
  String get comUnitSac;

  /// No description provided for @comUnitBidon.
  ///
  /// In fr, this message translates to:
  /// **'Bidon'**
  String get comUnitBidon;

  /// No description provided for @comUnitBouteille.
  ///
  /// In fr, this message translates to:
  /// **'Bouteille'**
  String get comUnitBouteille;

  /// No description provided for @comUnitSachet.
  ///
  /// In fr, this message translates to:
  /// **'Sachet'**
  String get comUnitSachet;

  /// No description provided for @comUnitBoite.
  ///
  /// In fr, this message translates to:
  /// **'Boîte'**
  String get comUnitBoite;

  /// No description provided for @comUnitRouleau.
  ///
  /// In fr, this message translates to:
  /// **'Rouleau'**
  String get comUnitRouleau;

  /// No description provided for @comUnitMetre.
  ///
  /// In fr, this message translates to:
  /// **'Mètre'**
  String get comUnitMetre;

  /// No description provided for @comUnitKg.
  ///
  /// In fr, this message translates to:
  /// **'Kg'**
  String get comUnitKg;

  /// No description provided for @comUnitLitre.
  ///
  /// In fr, this message translates to:
  /// **'Litre'**
  String get comUnitLitre;

  /// No description provided for @comUnitDouzaine.
  ///
  /// In fr, this message translates to:
  /// **'Douzaine'**
  String get comUnitDouzaine;

  /// No description provided for @comUnitLot.
  ///
  /// In fr, this message translates to:
  /// **'Lot'**
  String get comUnitLot;

  /// No description provided for @comUnitPalette.
  ///
  /// In fr, this message translates to:
  /// **'Palette'**
  String get comUnitPalette;

  /// No description provided for @comUnitTonne.
  ///
  /// In fr, this message translates to:
  /// **'Tonne'**
  String get comUnitTonne;

  /// No description provided for @comProductNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Ce produit n\'existe plus.'**
  String get comProductNotFound;

  /// No description provided for @comChooseCustomer.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un client'**
  String get comChooseCustomer;

  /// No description provided for @comNewSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau fournisseur'**
  String get comNewSupplier;

  /// No description provided for @comNewCustomer.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau client'**
  String get comNewCustomer;

  /// No description provided for @comSearchContact.
  ///
  /// In fr, this message translates to:
  /// **'Nom ou téléphone…'**
  String get comSearchContact;

  /// No description provided for @comNoContact.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact trouvé'**
  String get comNoContact;

  /// No description provided for @comStockCard.
  ///
  /// In fr, this message translates to:
  /// **'Stock'**
  String get comStockCard;

  /// No description provided for @comDistribution.
  ///
  /// In fr, this message translates to:
  /// **'Répartition'**
  String get comDistribution;

  /// No description provided for @comEntry.
  ///
  /// In fr, this message translates to:
  /// **'Entrée'**
  String get comEntry;

  /// No description provided for @comExit.
  ///
  /// In fr, this message translates to:
  /// **'Sortie'**
  String get comExit;

  /// No description provided for @comTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get comTransfer;

  /// No description provided for @comBuy.
  ///
  /// In fr, this message translates to:
  /// **'Acheter'**
  String get comBuy;

  /// No description provided for @comPricesAndUnits.
  ///
  /// In fr, this message translates to:
  /// **'Prix et unités'**
  String get comPricesAndUnits;

  /// No description provided for @comUnit.
  ///
  /// In fr, this message translates to:
  /// **'Unité'**
  String get comUnit;

  /// No description provided for @comProfit.
  ///
  /// In fr, this message translates to:
  /// **'Bénéfice'**
  String get comProfit;

  /// No description provided for @comLastMovements.
  ///
  /// In fr, this message translates to:
  /// **'Derniers mouvements'**
  String get comLastMovements;

  /// No description provided for @comSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get comSeeAll;

  /// No description provided for @comNoMovement.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mouvement pour le moment'**
  String get comNoMovement;

  /// No description provided for @comSuppliers.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseurs'**
  String get comSuppliers;

  /// No description provided for @comArchive.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get comArchive;

  /// No description provided for @comRestore.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver'**
  String get comRestore;

  /// No description provided for @comArchiveConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Archiver ce produit ? Il ne sera plus proposé à la vente ni à l\'achat. Son historique est conservé.'**
  String get comArchiveConfirm;

  /// No description provided for @comBarcodeShort.
  ///
  /// In fr, this message translates to:
  /// **'Code-barres'**
  String get comBarcodeShort;

  /// No description provided for @comReferenceShort.
  ///
  /// In fr, this message translates to:
  /// **'Référence'**
  String get comReferenceShort;

  /// No description provided for @comMinimumAlert.
  ///
  /// In fr, this message translates to:
  /// **'Alerte sous {quantite}'**
  String comMinimumAlert(String quantite);

  /// No description provided for @comToCheck.
  ///
  /// In fr, this message translates to:
  /// **'Stock à vérifier'**
  String get comToCheck;

  /// No description provided for @comPendingSend.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'envoi'**
  String get comPendingSend;

  /// No description provided for @comCategoriesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get comCategoriesTitle;

  /// No description provided for @comCategoriesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Organisez vos produits'**
  String get comCategoriesEmptyTitle;

  /// No description provided for @comCategoriesEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un modèle adapté à votre commerce, ou créez vos propres catégories.'**
  String get comCategoriesEmptyMessage;

  /// No description provided for @comUseTemplate.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser un modèle'**
  String get comUseTemplate;

  /// No description provided for @comChooseSector.
  ///
  /// In fr, this message translates to:
  /// **'Quel est votre commerce ?'**
  String get comChooseSector;

  /// No description provided for @comTemplateApplied.
  ///
  /// In fr, this message translates to:
  /// **'Catégories créées'**
  String get comTemplateApplied;

  /// No description provided for @comAddSubCategory.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une sous-catégorie'**
  String get comAddSubCategory;

  /// No description provided for @comDisable.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get comDisable;

  /// No description provided for @comEnable.
  ///
  /// In fr, this message translates to:
  /// **'Afficher'**
  String get comEnable;

  /// No description provided for @comSectorHardware.
  ///
  /// In fr, this message translates to:
  /// **'Quincaillerie'**
  String get comSectorHardware;

  /// No description provided for @comSectorGrocery.
  ///
  /// In fr, this message translates to:
  /// **'Boutique / alimentation'**
  String get comSectorGrocery;

  /// No description provided for @comSectorSupermarket.
  ///
  /// In fr, this message translates to:
  /// **'Supermarché'**
  String get comSectorSupermarket;

  /// No description provided for @comSectorTextile.
  ///
  /// In fr, this message translates to:
  /// **'Vêtements et chaussures'**
  String get comSectorTextile;

  /// No description provided for @comSectorCosmetics.
  ///
  /// In fr, this message translates to:
  /// **'Cosmétique'**
  String get comSectorCosmetics;

  /// No description provided for @comSectorElectronics.
  ///
  /// In fr, this message translates to:
  /// **'Téléphonie et électronique'**
  String get comSectorElectronics;

  /// No description provided for @comCatOutils.
  ///
  /// In fr, this message translates to:
  /// **'Outils'**
  String get comCatOutils;

  /// No description provided for @comCatMateriaux.
  ///
  /// In fr, this message translates to:
  /// **'Matériaux'**
  String get comCatMateriaux;

  /// No description provided for @comCatPeinture.
  ///
  /// In fr, this message translates to:
  /// **'Peinture'**
  String get comCatPeinture;

  /// No description provided for @comCatPeintureInterieur.
  ///
  /// In fr, this message translates to:
  /// **'Intérieur'**
  String get comCatPeintureInterieur;

  /// No description provided for @comCatPeintureExterieur.
  ///
  /// In fr, this message translates to:
  /// **'Extérieur'**
  String get comCatPeintureExterieur;

  /// No description provided for @comCatPeinturePrimaire.
  ///
  /// In fr, this message translates to:
  /// **'Primaire'**
  String get comCatPeinturePrimaire;

  /// No description provided for @comCatPeintureVernis.
  ///
  /// In fr, this message translates to:
  /// **'Vernis'**
  String get comCatPeintureVernis;

  /// No description provided for @comCatPlomberie.
  ///
  /// In fr, this message translates to:
  /// **'Plomberie'**
  String get comCatPlomberie;

  /// No description provided for @comCatElectricite.
  ///
  /// In fr, this message translates to:
  /// **'Électricité'**
  String get comCatElectricite;

  /// No description provided for @comCatVisserie.
  ///
  /// In fr, this message translates to:
  /// **'Visserie'**
  String get comCatVisserie;

  /// No description provided for @comCatMenuiserie.
  ///
  /// In fr, this message translates to:
  /// **'Menuiserie'**
  String get comCatMenuiserie;

  /// No description provided for @comCatAccessoires.
  ///
  /// In fr, this message translates to:
  /// **'Accessoires'**
  String get comCatAccessoires;

  /// No description provided for @comCatCarrelage.
  ///
  /// In fr, this message translates to:
  /// **'Carrelage'**
  String get comCatCarrelage;

  /// No description provided for @comCatBoissons.
  ///
  /// In fr, this message translates to:
  /// **'Boissons'**
  String get comCatBoissons;

  /// No description provided for @comCatEpicerie.
  ///
  /// In fr, this message translates to:
  /// **'Épicerie'**
  String get comCatEpicerie;

  /// No description provided for @comCatFrais.
  ///
  /// In fr, this message translates to:
  /// **'Produits frais'**
  String get comCatFrais;

  /// No description provided for @comCatBoulangerie.
  ///
  /// In fr, this message translates to:
  /// **'Boulangerie'**
  String get comCatBoulangerie;

  /// No description provided for @comCatHygiene.
  ///
  /// In fr, this message translates to:
  /// **'Hygiène'**
  String get comCatHygiene;

  /// No description provided for @comCatMenage.
  ///
  /// In fr, this message translates to:
  /// **'Entretien de la maison'**
  String get comCatMenage;

  /// No description provided for @comCatCosmetique.
  ///
  /// In fr, this message translates to:
  /// **'Beauté'**
  String get comCatCosmetique;

  /// No description provided for @comCatVetements.
  ///
  /// In fr, this message translates to:
  /// **'Vêtements'**
  String get comCatVetements;

  /// No description provided for @comCatChaussures.
  ///
  /// In fr, this message translates to:
  /// **'Chaussures'**
  String get comCatChaussures;

  /// No description provided for @comCatTelephonie.
  ///
  /// In fr, this message translates to:
  /// **'Téléphones'**
  String get comCatTelephonie;

  /// No description provided for @comCatElectronique.
  ///
  /// In fr, this message translates to:
  /// **'Électronique'**
  String get comCatElectronique;

  /// No description provided for @comCatPapeterie.
  ///
  /// In fr, this message translates to:
  /// **'Papeterie'**
  String get comCatPapeterie;

  /// No description provided for @comMovementsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mouvements'**
  String get comMovementsTitle;

  /// No description provided for @comFamilyAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get comFamilyAll;

  /// No description provided for @comFamilyEntries.
  ///
  /// In fr, this message translates to:
  /// **'Entrées'**
  String get comFamilyEntries;

  /// No description provided for @comFamilyExits.
  ///
  /// In fr, this message translates to:
  /// **'Sorties'**
  String get comFamilyExits;

  /// No description provided for @comFamilyTransfers.
  ///
  /// In fr, this message translates to:
  /// **'Transferts'**
  String get comFamilyTransfers;

  /// No description provided for @comFamilyAdjustments.
  ///
  /// In fr, this message translates to:
  /// **'Ajustements'**
  String get comFamilyAdjustments;

  /// No description provided for @comFamilyLosses.
  ///
  /// In fr, this message translates to:
  /// **'Pertes'**
  String get comFamilyLosses;

  /// No description provided for @comToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get comToday;

  /// No description provided for @comYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get comYesterday;

  /// No description provided for @comBy.
  ///
  /// In fr, this message translates to:
  /// **'par {nom}'**
  String comBy(String nom);

  /// No description provided for @comTypeEntry.
  ///
  /// In fr, this message translates to:
  /// **'Entrée'**
  String get comTypeEntry;

  /// No description provided for @comTypeExit.
  ///
  /// In fr, this message translates to:
  /// **'Sortie'**
  String get comTypeExit;

  /// No description provided for @comTypeTransferOut.
  ///
  /// In fr, this message translates to:
  /// **'Transfert envoyé'**
  String get comTypeTransferOut;

  /// No description provided for @comTypeTransferIn.
  ///
  /// In fr, this message translates to:
  /// **'Transfert reçu'**
  String get comTypeTransferIn;

  /// No description provided for @comTypeInventory.
  ///
  /// In fr, this message translates to:
  /// **'Inventaire'**
  String get comTypeInventory;

  /// No description provided for @comMovementRejected.
  ///
  /// In fr, this message translates to:
  /// **'Refusé par le serveur'**
  String get comMovementRejected;

  /// No description provided for @comEmptyMovementsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mouvement'**
  String get comEmptyMovementsTitle;

  /// No description provided for @comEmptyMovementsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Les entrées, sorties et transferts apparaîtront ici.'**
  String get comEmptyMovementsMessage;

  /// No description provided for @comRemoveRejected.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get comRemoveRejected;

  /// No description provided for @comPeriodAll.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les dates'**
  String get comPeriodAll;

  /// No description provided for @comPeriodToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get comPeriodToday;

  /// No description provided for @comPeriodWeek.
  ///
  /// In fr, this message translates to:
  /// **'7 derniers jours'**
  String get comPeriodWeek;

  /// No description provided for @comPeriodMonth.
  ///
  /// In fr, this message translates to:
  /// **'30 derniers jours'**
  String get comPeriodMonth;

  /// No description provided for @comStockTitle.
  ///
  /// In fr, this message translates to:
  /// **'Stock'**
  String get comStockTitle;

  /// No description provided for @comStockSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivez vos produits, vos quantités et vos mouvements.'**
  String get comStockSubtitle;

  /// No description provided for @comKpiProducts.
  ///
  /// In fr, this message translates to:
  /// **'Produits'**
  String get comKpiProducts;

  /// No description provided for @comKpiLow.
  ///
  /// In fr, this message translates to:
  /// **'Stock faible'**
  String get comKpiLow;

  /// No description provided for @comKpiOut.
  ///
  /// In fr, this message translates to:
  /// **'Ruptures'**
  String get comKpiOut;

  /// No description provided for @comKpiMovesToday.
  ///
  /// In fr, this message translates to:
  /// **'Mouvements du jour'**
  String get comKpiMovesToday;

  /// No description provided for @comOrder.
  ///
  /// In fr, this message translates to:
  /// **'Commander'**
  String get comOrder;

  /// No description provided for @comStockEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre stock est encore vide'**
  String get comStockEmptyTitle;

  /// No description provided for @comStockEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Commencez par ajouter votre premier produit.'**
  String get comStockEmptyMessage;

  /// No description provided for @comNothingToReport.
  ///
  /// In fr, this message translates to:
  /// **'Rien à signaler : tout est en stock.'**
  String get comNothingToReport;

  /// No description provided for @comToWatch.
  ///
  /// In fr, this message translates to:
  /// **'À surveiller'**
  String get comToWatch;

  /// No description provided for @comSeeMovements.
  ///
  /// In fr, this message translates to:
  /// **'Voir les mouvements'**
  String get comSeeMovements;

  /// No description provided for @comStockActions.
  ///
  /// In fr, this message translates to:
  /// **'Que voulez-vous faire ?'**
  String get comStockActions;

  /// No description provided for @comWatchLow.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 produit en stock faible} other{{count} produits en stock faible}}'**
  String comWatchLow(int count);

  /// No description provided for @comWatchOut.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 produit en rupture} other{{count} produits en rupture}}'**
  String comWatchOut(int count);

  /// No description provided for @comPurchasesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Achats'**
  String get comPurchasesTitle;

  /// No description provided for @comNewPurchase.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel achat'**
  String get comNewPurchase;

  /// No description provided for @comEditPurchase.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'achat'**
  String get comEditPurchase;

  /// No description provided for @comPurchaseEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun achat'**
  String get comPurchaseEmptyTitle;

  /// No description provided for @comPurchaseEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez vos achats chez vos fournisseurs : le stock augmente à la réception.'**
  String get comPurchaseEmptyMessage;

  /// No description provided for @comFilterToReceive.
  ///
  /// In fr, this message translates to:
  /// **'À recevoir'**
  String get comFilterToReceive;

  /// No description provided for @comFilterReceived.
  ///
  /// In fr, this message translates to:
  /// **'Reçus'**
  String get comFilterReceived;

  /// No description provided for @comFilterCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulés'**
  String get comFilterCancelled;

  /// No description provided for @comStatusOrdered.
  ///
  /// In fr, this message translates to:
  /// **'Commandé'**
  String get comStatusOrdered;

  /// No description provided for @comStatusPartlyReceived.
  ///
  /// In fr, this message translates to:
  /// **'Reçu en partie'**
  String get comStatusPartlyReceived;

  /// No description provided for @comStatusReceived.
  ///
  /// In fr, this message translates to:
  /// **'Reçu'**
  String get comStatusReceived;

  /// No description provided for @comStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get comStatusCancelled;

  /// No description provided for @comSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur'**
  String get comSupplier;

  /// No description provided for @comNoSupplierChosen.
  ///
  /// In fr, this message translates to:
  /// **'Choisir le fournisseur (facultatif)'**
  String get comNoSupplierChosen;

  /// No description provided for @comPurchaseDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get comPurchaseDate;

  /// No description provided for @comSupplierReference.
  ///
  /// In fr, this message translates to:
  /// **'N° de facture / bon (facultatif)'**
  String get comSupplierReference;

  /// No description provided for @comProducts.
  ///
  /// In fr, this message translates to:
  /// **'Produits'**
  String get comProducts;

  /// No description provided for @comAddLine.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un produit'**
  String get comAddLine;

  /// No description provided for @comUnitPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix par {unite}'**
  String comUnitPrice(String unite);

  /// No description provided for @comLastPrice.
  ///
  /// In fr, this message translates to:
  /// **'Dernier prix : {montant}'**
  String comLastPrice(String montant);

  /// No description provided for @comTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get comTotal;

  /// No description provided for @comSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get comSave;

  /// No description provided for @comSaveAndReceive.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer et réceptionner'**
  String get comSaveAndReceive;

  /// No description provided for @comPurchaseSaved.
  ///
  /// In fr, this message translates to:
  /// **'Achat enregistré'**
  String get comPurchaseSaved;

  /// No description provided for @comReceive.
  ///
  /// In fr, this message translates to:
  /// **'Réceptionner'**
  String get comReceive;

  /// No description provided for @comReceiveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réception de la marchandise'**
  String get comReceiveTitle;

  /// No description provided for @comReceivedToday.
  ///
  /// In fr, this message translates to:
  /// **'Reçu aujourd\'hui'**
  String get comReceivedToday;

  /// No description provided for @comOrdered.
  ///
  /// In fr, this message translates to:
  /// **'Commandé'**
  String get comOrdered;

  /// No description provided for @comAlreadyReceived.
  ///
  /// In fr, this message translates to:
  /// **'Déjà reçu'**
  String get comAlreadyReceived;

  /// No description provided for @comRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Reste'**
  String get comRemaining;

  /// No description provided for @comReceiveAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout reçu'**
  String get comReceiveAll;

  /// No description provided for @comNothingReceived.
  ///
  /// In fr, this message translates to:
  /// **'Rien'**
  String get comNothingReceived;

  /// No description provided for @comConfirmReception.
  ///
  /// In fr, this message translates to:
  /// **'Valider la réception'**
  String get comConfirmReception;

  /// No description provided for @comReceptionDone.
  ///
  /// In fr, this message translates to:
  /// **'Marchandise reçue : stock mis à jour'**
  String get comReceptionDone;

  /// No description provided for @comStockImpact.
  ///
  /// In fr, this message translates to:
  /// **'Effet sur le stock'**
  String get comStockImpact;

  /// No description provided for @comReceptions.
  ///
  /// In fr, this message translates to:
  /// **'Réceptions'**
  String get comReceptions;

  /// No description provided for @comCancelPurchase.
  ///
  /// In fr, this message translates to:
  /// **'Annuler l\'achat'**
  String get comCancelPurchase;

  /// No description provided for @comCancelPurchaseConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Annuler cet achat ? La dette fournisseur sera annulée.'**
  String get comCancelPurchaseConfirm;

  /// No description provided for @comDebt.
  ///
  /// In fr, this message translates to:
  /// **'Reste à payer'**
  String get comDebt;

  /// No description provided for @comPaid.
  ///
  /// In fr, this message translates to:
  /// **'Payé'**
  String get comPaid;

  /// No description provided for @comPaySupplier.
  ///
  /// In fr, this message translates to:
  /// **'Payer le fournisseur'**
  String get comPaySupplier;

  /// No description provided for @comFullyPaid.
  ///
  /// In fr, this message translates to:
  /// **'Entièrement payé'**
  String get comFullyPaid;

  /// No description provided for @comLinesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 produit} other{{count} produits}}'**
  String comLinesCount(int count);

  /// No description provided for @comPurchaseOf.
  ///
  /// In fr, this message translates to:
  /// **'Achat du {date}'**
  String comPurchaseOf(String date);

  /// No description provided for @comNoSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Sans fournisseur'**
  String get comNoSupplier;

  /// No description provided for @comEditLine.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la ligne'**
  String get comEditLine;

  /// No description provided for @comRemoveLine.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get comRemoveLine;

  /// No description provided for @comApply.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get comApply;

  /// No description provided for @comSuppliersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseurs'**
  String get comSuppliersTitle;

  /// No description provided for @comSuppliersEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fournisseur'**
  String get comSuppliersEmptyTitle;

  /// No description provided for @comSuppliersEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez les personnes ou sociétés auprès de qui vous achetez.'**
  String get comSuppliersEmptyMessage;

  /// No description provided for @comAddSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un fournisseur'**
  String get comAddSupplier;

  /// No description provided for @comTotalBought.
  ///
  /// In fr, this message translates to:
  /// **'Total acheté'**
  String get comTotalBought;

  /// No description provided for @comLastPurchase.
  ///
  /// In fr, this message translates to:
  /// **'Dernier achat'**
  String get comLastPurchase;

  /// No description provided for @comSuppliedProducts.
  ///
  /// In fr, this message translates to:
  /// **'Produits fournis'**
  String get comSuppliedProducts;

  /// No description provided for @comPurchaseHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique des achats'**
  String get comPurchaseHistory;

  /// No description provided for @comCall.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get comCall;

  /// No description provided for @comOpenContact.
  ///
  /// In fr, this message translates to:
  /// **'Fiche contact'**
  String get comOpenContact;

  /// No description provided for @comNeverBought.
  ///
  /// In fr, this message translates to:
  /// **'Aucun achat pour le moment'**
  String get comNeverBought;

  /// No description provided for @comPurchasesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun achat} =1{1 achat} other{{count} achats}}'**
  String comPurchasesCount(int count);

  /// No description provided for @comSalesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vendre'**
  String get comSalesTitle;

  /// No description provided for @comSalesHistory.
  ///
  /// In fr, this message translates to:
  /// **'Ventes'**
  String get comSalesHistory;

  /// No description provided for @comCart.
  ///
  /// In fr, this message translates to:
  /// **'Panier'**
  String get comCart;

  /// No description provided for @comCartEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Touchez un produit pour l\'ajouter au panier.'**
  String get comCartEmpty;

  /// No description provided for @comCartCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 article} other{{count} articles}}'**
  String comCartCount(int count);

  /// No description provided for @comCheckout.
  ///
  /// In fr, this message translates to:
  /// **'Encaisser'**
  String get comCheckout;

  /// No description provided for @comBestSellers.
  ///
  /// In fr, this message translates to:
  /// **'Plus vendus'**
  String get comBestSellers;

  /// No description provided for @comPayment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get comPayment;

  /// No description provided for @comPayNow.
  ///
  /// In fr, this message translates to:
  /// **'Payé maintenant'**
  String get comPayNow;

  /// No description provided for @comOnCredit.
  ///
  /// In fr, this message translates to:
  /// **'À crédit'**
  String get comOnCredit;

  /// No description provided for @comCustomer.
  ///
  /// In fr, this message translates to:
  /// **'Client'**
  String get comCustomer;

  /// No description provided for @comCustomerOptional.
  ///
  /// In fr, this message translates to:
  /// **'Client (facultatif)'**
  String get comCustomerOptional;

  /// No description provided for @comDiscount.
  ///
  /// In fr, this message translates to:
  /// **'Remise'**
  String get comDiscount;

  /// No description provided for @comToPay.
  ///
  /// In fr, this message translates to:
  /// **'À payer'**
  String get comToPay;

  /// No description provided for @comSaleDone.
  ///
  /// In fr, this message translates to:
  /// **'Vente enregistrée : {montant}'**
  String comSaleDone(String montant);

  /// No description provided for @comConfirmSale.
  ///
  /// In fr, this message translates to:
  /// **'Valider la vente'**
  String get comConfirmSale;

  /// No description provided for @comCashOpen.
  ///
  /// In fr, this message translates to:
  /// **'L\'argent entre dans la caisse ouverte.'**
  String get comCashOpen;

  /// No description provided for @comNoCashOpen.
  ///
  /// In fr, this message translates to:
  /// **'Aucune caisse ouverte : le paiement est enregistré sans caisse.'**
  String get comNoCashOpen;

  /// No description provided for @comAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Disponible : {quantite}'**
  String comAvailable(String quantite);

  /// No description provided for @comSalesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vente'**
  String get comSalesEmptyTitle;

  /// No description provided for @comSalesEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vos ventes apparaîtront ici.'**
  String get comSalesEmptyMessage;

  /// No description provided for @comSaleOf.
  ///
  /// In fr, this message translates to:
  /// **'Vente du {date}'**
  String comSaleOf(String date);

  /// No description provided for @comCancelSale.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la vente'**
  String get comCancelSale;

  /// No description provided for @comCancelSaleConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Annuler cette vente ? Les produits reviennent en stock.'**
  String get comCancelSaleConfirm;

  /// No description provided for @comCancelReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif (facultatif)'**
  String get comCancelReason;

  /// No description provided for @comSaleCancelledDone.
  ///
  /// In fr, this message translates to:
  /// **'Vente annulée'**
  String get comSaleCancelledDone;

  /// No description provided for @comCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get comCancelled;

  /// No description provided for @comSalesToday.
  ///
  /// In fr, this message translates to:
  /// **'Ventes du jour'**
  String get comSalesToday;

  /// No description provided for @comNoShopAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas de boutique pour vendre.'**
  String get comNoShopAllowed;

  /// No description provided for @comClearCart.
  ///
  /// In fr, this message translates to:
  /// **'Vider le panier'**
  String get comClearCart;

  /// No description provided for @comChangeUnit.
  ///
  /// In fr, this message translates to:
  /// **'Quantité et unité'**
  String get comChangeUnit;

  /// No description provided for @comPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get comPrice;

  /// No description provided for @comSeller.
  ///
  /// In fr, this message translates to:
  /// **'Vendeur'**
  String get comSeller;

  /// No description provided for @comNewSale.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle vente'**
  String get comNewSale;

  /// No description provided for @comStepProductUnits.
  ///
  /// In fr, this message translates to:
  /// **'Produit et unités'**
  String get comStepProductUnits;

  /// No description provided for @comStepPricesStock.
  ///
  /// In fr, this message translates to:
  /// **'Prix et stock'**
  String get comStepPricesStock;

  /// No description provided for @comProductInfo.
  ///
  /// In fr, this message translates to:
  /// **'Le produit'**
  String get comProductInfo;

  /// No description provided for @comProductInfoHint.
  ///
  /// In fr, this message translates to:
  /// **'Une photo et un nom clair aident vos vendeurs à le reconnaître.'**
  String get comProductInfoHint;

  /// No description provided for @comPhotoShort.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get comPhotoShort;

  /// No description provided for @comHowCounted.
  ///
  /// In fr, this message translates to:
  /// **'Comment comptez-vous ce produit ?'**
  String get comHowCounted;

  /// No description provided for @comHowCountedHint.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la plus petite quantité que vous vendez : une pièce, un sac, un litre…'**
  String get comHowCountedHint;

  /// No description provided for @comPackagingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vendez-vous aussi par carton, paquet, sac… ?'**
  String get comPackagingTitle;

  /// No description provided for @comPackagingHint2.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez l\'emballage et ce qu\'il contient : les prix et le stock seront calculés pour vous.'**
  String get comPackagingHint2;

  /// No description provided for @comPackagingName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'emballage'**
  String get comPackagingName;

  /// No description provided for @comPackagingContains.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de {unite} dans 1 emballage'**
  String comPackagingContains(String unite);

  /// No description provided for @comRetailPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix de vente au détail'**
  String get comRetailPrice;

  /// No description provided for @comRetailPriceHint.
  ///
  /// In fr, this message translates to:
  /// **'Le prix habituel pour un client. Choisissez l\'unité de ce prix.'**
  String get comRetailPriceHint;

  /// No description provided for @comWholesalePrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix de vente en gros'**
  String get comWholesalePrice;

  /// No description provided for @comWholesalePriceHint.
  ///
  /// In fr, this message translates to:
  /// **'Le prix pour les gros acheteurs, souvent par carton.'**
  String get comWholesalePriceHint;

  /// No description provided for @comPurchasePrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix d\'achat (facultatif)'**
  String get comPurchasePrice;

  /// No description provided for @comPurchasePriceHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous payez au fournisseur : pour voir votre bénéfice.'**
  String get comPurchasePriceHint;

  /// No description provided for @comPricePer.
  ///
  /// In fr, this message translates to:
  /// **'Prix pour 1 :'**
  String get comPricePer;

  /// No description provided for @comEquivalentPrice.
  ///
  /// In fr, this message translates to:
  /// **'Soit {montant} par {unite}'**
  String comEquivalentPrice(String montant, String unite);

  /// No description provided for @comPriceSummary.
  ///
  /// In fr, this message translates to:
  /// **'Vos prix, calculés pour chaque unité'**
  String get comPriceSummary;

  /// No description provided for @comAmountHint.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get comAmountHint;

  /// No description provided for @comSaveChanges.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get comSaveChanges;

  /// No description provided for @comStockAndAlert.
  ///
  /// In fr, this message translates to:
  /// **'Stock et alerte'**
  String get comStockAndAlert;

  /// No description provided for @comSupplierNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fournisseur choisi'**
  String get comSupplierNone;

  /// No description provided for @comReferenceHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : CAR-0012'**
  String get comReferenceHint;

  /// No description provided for @comGenerateReference.
  ///
  /// In fr, this message translates to:
  /// **'Proposer une référence'**
  String get comGenerateReference;

  /// No description provided for @comChooseCategory.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une catégorie'**
  String get comChooseCategory;

  /// No description provided for @comBarcodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code-barres'**
  String get comBarcodeLabel;

  /// No description provided for @comBarcodeHint.
  ///
  /// In fr, this message translates to:
  /// **'Scannez ou tapez le code (facultatif)'**
  String get comBarcodeHint;

  /// No description provided for @comUnitPieceHelp.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : carreau, ampoule'**
  String get comUnitPieceHelp;

  /// No description provided for @rcpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Reçus'**
  String get rcpTitle;

  /// No description provided for @rcpSaleReceipt.
  ///
  /// In fr, this message translates to:
  /// **'REÇU DE VENTE'**
  String get rcpSaleReceipt;

  /// No description provided for @rcpNumberPending.
  ///
  /// In fr, this message translates to:
  /// **'Numéro attribué à la synchronisation'**
  String get rcpNumberPending;

  /// No description provided for @rcpSaleSaved.
  ///
  /// In fr, this message translates to:
  /// **'Vente enregistrée'**
  String get rcpSaleSaved;

  /// No description provided for @rcpView.
  ///
  /// In fr, this message translates to:
  /// **'Voir le reçu'**
  String get rcpView;

  /// No description provided for @rcpShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get rcpShare;

  /// No description provided for @rcpPrint.
  ///
  /// In fr, this message translates to:
  /// **'Imprimer'**
  String get rcpPrint;

  /// No description provided for @rcpPdf.
  ///
  /// In fr, this message translates to:
  /// **'PDF'**
  String get rcpPdf;

  /// No description provided for @rcpNewSale.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle vente'**
  String get rcpNewSale;

  /// No description provided for @rcpCounterCustomer.
  ///
  /// In fr, this message translates to:
  /// **'Client comptoir'**
  String get rcpCounterCustomer;

  /// No description provided for @rcpSelectCustomer.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner'**
  String get rcpSelectCustomer;

  /// No description provided for @rcpAddName.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un nom'**
  String get rcpAddName;

  /// No description provided for @rcpCustomerName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du client'**
  String get rcpCustomerName;

  /// No description provided for @rcpPhoneOptional.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone (facultatif)'**
  String get rcpPhoneOptional;

  /// No description provided for @rcpCreditNeedsCustomer.
  ///
  /// In fr, this message translates to:
  /// **'Vente à crédit : choisissez ou ajoutez le client.'**
  String get rcpCreditNeedsCustomer;

  /// No description provided for @rcpDeposit.
  ///
  /// In fr, this message translates to:
  /// **'Payé maintenant (facultatif)'**
  String get rcpDeposit;

  /// No description provided for @rcpDepositHint.
  ///
  /// In fr, this message translates to:
  /// **'Laissez vide si le client ne paie rien aujourd\'hui.'**
  String get rcpDepositHint;

  /// No description provided for @rcpSubtotal.
  ///
  /// In fr, this message translates to:
  /// **'Sous-total'**
  String get rcpSubtotal;

  /// No description provided for @rcpPaid.
  ///
  /// In fr, this message translates to:
  /// **'Montant payé'**
  String get rcpPaid;

  /// No description provided for @rcpRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Reste'**
  String get rcpRemaining;

  /// No description provided for @rcpRemainingToPay.
  ///
  /// In fr, this message translates to:
  /// **'RESTE À PAYER'**
  String get rcpRemainingToPay;

  /// No description provided for @rcpShop.
  ///
  /// In fr, this message translates to:
  /// **'Boutique'**
  String get rcpShop;

  /// No description provided for @rcpDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get rcpDate;

  /// No description provided for @rcpTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure'**
  String get rcpTime;

  /// No description provided for @rcpThanks.
  ///
  /// In fr, this message translates to:
  /// **'Merci pour votre confiance.'**
  String get rcpThanks;

  /// No description provided for @rcpTagline.
  ///
  /// In fr, this message translates to:
  /// **'La gestion simple de votre activité'**
  String get rcpTagline;

  /// No description provided for @rcpProduct.
  ///
  /// In fr, this message translates to:
  /// **'Produit'**
  String get rcpProduct;

  /// No description provided for @rcpQty.
  ///
  /// In fr, this message translates to:
  /// **'Qté'**
  String get rcpQty;

  /// No description provided for @rcpPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get rcpPrice;

  /// No description provided for @rcpLineTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get rcpLineTotal;

  /// No description provided for @rcpStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get rcpStatus;

  /// No description provided for @rcpStatusValid.
  ///
  /// In fr, this message translates to:
  /// **'Validé'**
  String get rcpStatusValid;

  /// No description provided for @rcpStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get rcpStatusCancelled;

  /// No description provided for @rcpStatusCredit.
  ///
  /// In fr, this message translates to:
  /// **'À crédit'**
  String get rcpStatusCredit;

  /// No description provided for @rcpStatusPartial.
  ///
  /// In fr, this message translates to:
  /// **'Partiellement payé'**
  String get rcpStatusPartial;

  /// No description provided for @rcpCancelledStamp.
  ///
  /// In fr, this message translates to:
  /// **'ANNULÉ'**
  String get rcpCancelledStamp;

  /// No description provided for @rcpCancelledInfo.
  ///
  /// In fr, this message translates to:
  /// **'Annulé le {date} par {nom}'**
  String rcpCancelledInfo(String date, String nom);

  /// No description provided for @rcpEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun reçu pour le moment'**
  String get rcpEmptyTitle;

  /// No description provided for @rcpEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vos reçus apparaîtront ici après vos premières ventes.'**
  String get rcpEmptyMessage;

  /// No description provided for @rcpCreateSale.
  ///
  /// In fr, this message translates to:
  /// **'Créer une vente'**
  String get rcpCreateSale;

  /// No description provided for @rcpNoResultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun reçu trouvé'**
  String get rcpNoResultTitle;

  /// No description provided for @rcpNoResultMessage.
  ///
  /// In fr, this message translates to:
  /// **'Essayez un autre numéro, client ou date.'**
  String get rcpNoResultMessage;

  /// No description provided for @rcpSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'N° de reçu, client, téléphone, produit…'**
  String get rcpSearchHint;

  /// No description provided for @rcpPeriodToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get rcpPeriodToday;

  /// No description provided for @rcpPeriodYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get rcpPeriodYesterday;

  /// No description provided for @rcpPeriodWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get rcpPeriodWeek;

  /// No description provided for @rcpPeriodMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois'**
  String get rcpPeriodMonth;

  /// No description provided for @rcpPeriodCustom.
  ///
  /// In fr, this message translates to:
  /// **'Période…'**
  String get rcpPeriodCustom;

  /// No description provided for @rcpPeriodAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get rcpPeriodAll;

  /// No description provided for @rcpAllSellers.
  ///
  /// In fr, this message translates to:
  /// **'Tous les vendeurs'**
  String get rcpAllSellers;

  /// No description provided for @rcpAllPayments.
  ///
  /// In fr, this message translates to:
  /// **'Tous les paiements'**
  String get rcpAllPayments;

  /// No description provided for @rcpAllStatuses.
  ///
  /// In fr, this message translates to:
  /// **'Tous les statuts'**
  String get rcpAllStatuses;

  /// No description provided for @rcpCredit.
  ///
  /// In fr, this message translates to:
  /// **'Crédit'**
  String get rcpCredit;

  /// No description provided for @rcpSales.
  ///
  /// In fr, this message translates to:
  /// **'Ventes'**
  String get rcpSales;

  /// No description provided for @rcpShops.
  ///
  /// In fr, this message translates to:
  /// **'Boutiques'**
  String get rcpShops;

  /// No description provided for @rcpLatest.
  ///
  /// In fr, this message translates to:
  /// **'Dernières ventes'**
  String get rcpLatest;

  /// No description provided for @rcpSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tous les reçus'**
  String get rcpSeeAll;

  /// No description provided for @rcpFilters.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get rcpFilters;

  /// No description provided for @rcpReset.
  ///
  /// In fr, this message translates to:
  /// **'Effacer les filtres'**
  String get rcpReset;

  /// No description provided for @rcpTraceability.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get rcpTraceability;

  /// No description provided for @rcpCreatedBy.
  ///
  /// In fr, this message translates to:
  /// **'Vente enregistrée par {nom}'**
  String rcpCreatedBy(String nom);

  /// No description provided for @rcpOnDevice.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrée sur l\'appareil, en attente d\'envoi'**
  String get rcpOnDevice;

  /// No description provided for @rcpCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun reçu} =1{1 reçu} other{{count} reçus}}'**
  String rcpCount(int count);

  /// No description provided for @expenseCatFuel.
  ///
  /// In fr, this message translates to:
  /// **'Carburant'**
  String get expenseCatFuel;

  /// No description provided for @expenseCatWater.
  ///
  /// In fr, this message translates to:
  /// **'Eau'**
  String get expenseCatWater;

  /// No description provided for @expenseCatInternet.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone et internet'**
  String get expenseCatInternet;

  /// No description provided for @expenseCatRepair.
  ///
  /// In fr, this message translates to:
  /// **'Réparation'**
  String get expenseCatRepair;

  /// No description provided for @expenseCatCleaning.
  ///
  /// In fr, this message translates to:
  /// **'Nettoyage'**
  String get expenseCatCleaning;

  /// No description provided for @expenseCatSecurity.
  ///
  /// In fr, this message translates to:
  /// **'Gardiennage'**
  String get expenseCatSecurity;

  /// No description provided for @expenseCatDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Livraison'**
  String get expenseCatDelivery;

  /// No description provided for @expenseCatBankFees.
  ///
  /// In fr, this message translates to:
  /// **'Frais bancaires'**
  String get expenseCatBankFees;

  /// No description provided for @expenseCatInsurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance'**
  String get expenseCatInsurance;

  /// No description provided for @cashNatureContribution.
  ///
  /// In fr, this message translates to:
  /// **'Apport'**
  String get cashNatureContribution;

  /// No description provided for @cashNatureWithdrawal.
  ///
  /// In fr, this message translates to:
  /// **'Retrait'**
  String get cashNatureWithdrawal;

  /// No description provided for @cashNatureTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get cashNatureTransfer;

  /// No description provided for @cashNatureRefund.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement'**
  String get cashNatureRefund;

  /// No description provided for @cashNatureAdjustment.
  ///
  /// In fr, this message translates to:
  /// **'Ajustement'**
  String get cashNatureAdjustment;

  /// No description provided for @cashNatureOpeningBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde initial'**
  String get cashNatureOpeningBalance;

  /// No description provided for @cashNatureOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get cashNatureOther;

  /// No description provided for @cashGapReasonChange.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de rendu monnaie'**
  String get cashGapReasonChange;

  /// No description provided for @cashGapReasonUnrecorded.
  ///
  /// In fr, this message translates to:
  /// **'Dépense non enregistrée'**
  String get cashGapReasonUnrecorded;

  /// No description provided for @cashGapReasonCounting.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de comptage'**
  String get cashGapReasonCounting;

  /// No description provided for @cashGapReasonOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get cashGapReasonOther;

  /// No description provided for @cashGapJustify.
  ///
  /// In fr, this message translates to:
  /// **'Un écart de {amount} a été constaté. Indiquez sa cause.'**
  String cashGapJustify(String amount);

  /// No description provided for @cashGapNoteRequired.
  ///
  /// In fr, this message translates to:
  /// **'Justification (obligatoire)'**
  String get cashGapNoteRequired;

  /// No description provided for @cashOperationReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get cashOperationReason;

  /// No description provided for @cashTransferTitle.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get cashTransferTitle;

  /// No description provided for @cashTransferFrom.
  ///
  /// In fr, this message translates to:
  /// **'Depuis'**
  String get cashTransferFrom;

  /// No description provided for @cashTransferTo.
  ///
  /// In fr, this message translates to:
  /// **'Vers'**
  String get cashTransferTo;

  /// No description provided for @cashTransferSame.
  ///
  /// In fr, this message translates to:
  /// **'La source et la destination doivent être différentes.'**
  String get cashTransferSame;

  /// No description provided for @cashTransferDone.
  ///
  /// In fr, this message translates to:
  /// **'Transfert enregistré'**
  String get cashTransferDone;

  /// No description provided for @cashTransferCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler le transfert'**
  String get cashTransferCancel;

  /// No description provided for @cashCompanyLevel.
  ///
  /// In fr, this message translates to:
  /// **'Entreprise (sans boutique)'**
  String get cashCompanyLevel;

  /// No description provided for @cashIn.
  ///
  /// In fr, this message translates to:
  /// **'Entrée d\'argent'**
  String get cashIn;

  /// No description provided for @cashOut.
  ///
  /// In fr, this message translates to:
  /// **'Sortie d\'argent'**
  String get cashOut;

  /// No description provided for @cashSite.
  ///
  /// In fr, this message translates to:
  /// **'Boutique / site'**
  String get cashSite;

  /// No description provided for @cashScreenSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivez vos entrées, vos sorties et votre solde.'**
  String get cashScreenSubtitle;

  /// No description provided for @cashAllShops.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les boutiques'**
  String get cashAllShops;

  /// No description provided for @cashAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Solde disponible'**
  String get cashAvailable;

  /// No description provided for @cashShowAmounts.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les montants'**
  String get cashShowAmounts;

  /// No description provided for @cashHideAmounts.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les montants'**
  String get cashHideAmounts;

  /// No description provided for @cashCashOnHand.
  ///
  /// In fr, this message translates to:
  /// **'Espèces en caisse'**
  String get cashCashOnHand;

  /// No description provided for @cashIncoming.
  ///
  /// In fr, this message translates to:
  /// **'Entrées'**
  String get cashIncoming;

  /// No description provided for @cashOutgoing.
  ///
  /// In fr, this message translates to:
  /// **'Sorties'**
  String get cashOutgoing;

  /// No description provided for @cashNet.
  ///
  /// In fr, this message translates to:
  /// **'Variation'**
  String get cashNet;

  /// No description provided for @cashOperationsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune opération} =1{1 opération} other{{count} opérations}}'**
  String cashOperationsCount(int count);

  /// No description provided for @cashAddOperation.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une opération'**
  String get cashAddOperation;

  /// No description provided for @cashBalanceTrend.
  ///
  /// In fr, this message translates to:
  /// **'Évolution du solde'**
  String get cashBalanceTrend;

  /// No description provided for @cashInBreakdown.
  ///
  /// In fr, this message translates to:
  /// **'D\'où vient l\'argent'**
  String get cashInBreakdown;

  /// No description provided for @cashOutBreakdown.
  ///
  /// In fr, this message translates to:
  /// **'Où part l\'argent'**
  String get cashOutBreakdown;

  /// No description provided for @cashByMode.
  ///
  /// In fr, this message translates to:
  /// **'Moyens d\'argent'**
  String get cashByMode;

  /// No description provided for @cashComparison.
  ///
  /// In fr, this message translates to:
  /// **'Comparaison'**
  String get cashComparison;

  /// No description provided for @cashPreviousPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Période précédente'**
  String get cashPreviousPeriod;

  /// No description provided for @cashByShop.
  ///
  /// In fr, this message translates to:
  /// **'Par boutique'**
  String get cashByShop;

  /// No description provided for @cashOperationsHistory.
  ///
  /// In fr, this message translates to:
  /// **'Opérations'**
  String get cashOperationsHistory;

  /// No description provided for @cashSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une opération…'**
  String get cashSearchHint;

  /// No description provided for @cashFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get cashFilterAll;

  /// No description provided for @cashReadyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre caisse est prête'**
  String get cashReadyTitle;

  /// No description provided for @cashReadyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Les ventes, paiements et dépenses apparaîtront automatiquement ici.'**
  String get cashReadyMessage;

  /// No description provided for @cashNoDataPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée pour cette période.'**
  String get cashNoDataPeriod;

  /// No description provided for @cashBalanced.
  ///
  /// In fr, this message translates to:
  /// **'Équilibrée'**
  String get cashBalanced;

  /// No description provided for @cashGapLarge.
  ///
  /// In fr, this message translates to:
  /// **'Écart important'**
  String get cashGapLarge;

  /// No description provided for @periodToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get periodToday;

  /// No description provided for @periodYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get periodYesterday;

  /// No description provided for @periodThisWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get periodThisWeek;

  /// No description provided for @periodThisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois'**
  String get periodThisMonth;

  /// No description provided for @periodThisYear.
  ///
  /// In fr, this message translates to:
  /// **'Cette année'**
  String get periodThisYear;

  /// No description provided for @periodAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get periodAll;

  /// No description provided for @periodCustom.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get periodCustom;

  /// No description provided for @period7Days.
  ///
  /// In fr, this message translates to:
  /// **'7 j'**
  String get period7Days;

  /// No description provided for @period30Days.
  ///
  /// In fr, this message translates to:
  /// **'30 j'**
  String get period30Days;

  /// No description provided for @period3Months.
  ///
  /// In fr, this message translates to:
  /// **'3 mois'**
  String get period3Months;

  /// No description provided for @cashSrcSale.
  ///
  /// In fr, this message translates to:
  /// **'Vente'**
  String get cashSrcSale;

  /// No description provided for @cashSrcCustomerPayment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement client'**
  String get cashSrcCustomerPayment;

  /// No description provided for @cashSrcService.
  ///
  /// In fr, this message translates to:
  /// **'Prestation'**
  String get cashSrcService;

  /// No description provided for @cashSrcRent.
  ///
  /// In fr, this message translates to:
  /// **'Loyer'**
  String get cashSrcRent;

  /// No description provided for @cashSrcPurchase.
  ///
  /// In fr, this message translates to:
  /// **'Achat'**
  String get cashSrcPurchase;

  /// No description provided for @cashSrcSupplierPayment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement fournisseur'**
  String get cashSrcSupplierPayment;

  /// No description provided for @cashSrcExpense.
  ///
  /// In fr, this message translates to:
  /// **'Dépense'**
  String get cashSrcExpense;

  /// No description provided for @cashAlertGap.
  ///
  /// In fr, this message translates to:
  /// **'Écart de {amount} à la dernière clôture de {register}.'**
  String cashAlertGap(String amount, String register);

  /// No description provided for @cashAlertOutflowsUp.
  ///
  /// In fr, this message translates to:
  /// **'Sorties en hausse de {percent} % par rapport à la semaine précédente.'**
  String cashAlertOutflowsUp(int percent);

  /// No description provided for @cashDetailDate.
  ///
  /// In fr, this message translates to:
  /// **'Date et heure'**
  String get cashDetailDate;

  /// No description provided for @cashDetailSource.
  ///
  /// In fr, this message translates to:
  /// **'Source'**
  String get cashDetailSource;

  /// No description provided for @cashDetailReference.
  ///
  /// In fr, this message translates to:
  /// **'Référence'**
  String get cashDetailReference;

  /// No description provided for @cashDetailContact.
  ///
  /// In fr, this message translates to:
  /// **'Client / fournisseur'**
  String get cashDetailContact;

  /// No description provided for @cashDetailOpen.
  ///
  /// In fr, this message translates to:
  /// **'Voir le détail'**
  String get cashDetailOpen;

  /// No description provided for @cashCancelOperation.
  ///
  /// In fr, this message translates to:
  /// **'Annuler l\'opération'**
  String get cashCancelOperation;

  /// No description provided for @cashCancelReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif de l\'annulation'**
  String get cashCancelReason;

  /// No description provided for @cashPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'envoi'**
  String get cashPending;

  /// No description provided for @financeManage.
  ///
  /// In fr, this message translates to:
  /// **'Gérer vos finances'**
  String get financeManage;

  /// No description provided for @periodDay.
  ///
  /// In fr, this message translates to:
  /// **'Jour'**
  String get periodDay;

  /// No description provided for @periodMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get periodYear;

  /// No description provided for @periodDates.
  ///
  /// In fr, this message translates to:
  /// **'Dates'**
  String get periodDates;

  /// No description provided for @periodPrevious.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get periodPrevious;

  /// No description provided for @periodNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get periodNext;

  /// No description provided for @periodChooseDates.
  ///
  /// In fr, this message translates to:
  /// **'Choisir les dates'**
  String get periodChooseDates;

  /// No description provided for @expenseTotalPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Total de la période'**
  String get expenseTotalPeriod;

  /// No description provided for @expensesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune dépense} =1{1 dépense} other{{count} dépenses}}'**
  String expensesCount(int count);

  /// No description provided for @servicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Services & Prestations'**
  String get servicesTitle;

  /// No description provided for @servicesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'La gestion simple de vos interventions et devis'**
  String get servicesSubtitle;

  /// No description provided for @prestationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Prestations'**
  String get prestationsTitle;

  /// No description provided for @planningServicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Planning des interventions'**
  String get planningServicesTitle;

  /// No description provided for @catalogueServicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Catalogue des prestations'**
  String get catalogueServicesTitle;

  /// No description provided for @devisServicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Devis de services'**
  String get devisServicesTitle;

  /// No description provided for @statutAFaire.
  ///
  /// In fr, this message translates to:
  /// **'À faire'**
  String get statutAFaire;

  /// No description provided for @statutPlanifiee.
  ///
  /// In fr, this message translates to:
  /// **'Planifiée'**
  String get statutPlanifiee;

  /// No description provided for @statutEnCours.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get statutEnCours;

  /// No description provided for @statutTerminee.
  ///
  /// In fr, this message translates to:
  /// **'Terminée'**
  String get statutTerminee;

  /// No description provided for @statutLivree.
  ///
  /// In fr, this message translates to:
  /// **'Livrée'**
  String get statutLivree;

  /// No description provided for @statutAnnulee.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get statutAnnulee;

  /// No description provided for @prioriteFaible.
  ///
  /// In fr, this message translates to:
  /// **'Faible / À venir'**
  String get prioriteFaible;

  /// No description provided for @prioriteAttentionJ2.
  ///
  /// In fr, this message translates to:
  /// **'Attention (J-2)'**
  String get prioriteAttentionJ2;

  /// No description provided for @prioriteUrgentJ1.
  ///
  /// In fr, this message translates to:
  /// **'Urgent (J-1)'**
  String get prioriteUrgentJ1;

  /// No description provided for @prioriteAujourdhui.
  ///
  /// In fr, this message translates to:
  /// **'À faire aujourd\'hui'**
  String get prioriteAujourdhui;

  /// No description provided for @prioriteEnRetard.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get prioriteEnRetard;

  /// No description provided for @nouvellePrestation.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle prestation'**
  String get nouvellePrestation;

  /// No description provided for @nouveauDevisService.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau devis'**
  String get nouveauDevisService;

  /// No description provided for @nouveauServiceCatalogue.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau service'**
  String get nouveauServiceCatalogue;

  /// No description provided for @convertirDevisEnPrestation.
  ///
  /// In fr, this message translates to:
  /// **'Convertir en prestation'**
  String get convertirDevisEnPrestation;

  /// No description provided for @demarrerTravail.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer'**
  String get demarrerTravail;

  /// No description provided for @terminerTravail.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get terminerTravail;

  /// No description provided for @livrerPrestation.
  ///
  /// In fr, this message translates to:
  /// **'Livrer au client'**
  String get livrerPrestation;

  /// No description provided for @reporterEcheance.
  ///
  /// In fr, this message translates to:
  /// **'Reporter l\'échéance'**
  String get reporterEcheance;

  /// No description provided for @motifReport.
  ///
  /// In fr, this message translates to:
  /// **'Motif du report'**
  String get motifReport;

  /// No description provided for @uniteForfait.
  ///
  /// In fr, this message translates to:
  /// **'Forfait'**
  String get uniteForfait;

  /// No description provided for @uniteHeure.
  ///
  /// In fr, this message translates to:
  /// **'Par heure'**
  String get uniteHeure;

  /// No description provided for @uniteJour.
  ///
  /// In fr, this message translates to:
  /// **'Par jour'**
  String get uniteJour;

  /// No description provided for @uniteM2.
  ///
  /// In fr, this message translates to:
  /// **'Par m²'**
  String get uniteM2;

  /// No description provided for @uniteKm.
  ///
  /// In fr, this message translates to:
  /// **'Par km'**
  String get uniteKm;

  /// No description provided for @unitePiece.
  ///
  /// In fr, this message translates to:
  /// **'Par pièce'**
  String get unitePiece;

  /// No description provided for @statutDevisBrouillon.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon'**
  String get statutDevisBrouillon;

  /// No description provided for @statutDevisEmis.
  ///
  /// In fr, this message translates to:
  /// **'Émis'**
  String get statutDevisEmis;

  /// No description provided for @statutDevisAccepte.
  ///
  /// In fr, this message translates to:
  /// **'Accepté'**
  String get statutDevisAccepte;

  /// No description provided for @statutDevisRefuse.
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get statutDevisRefuse;

  /// No description provided for @statutDevisConverti.
  ///
  /// In fr, this message translates to:
  /// **'Converti en prestation'**
  String get statutDevisConverti;

  /// No description provided for @rapportsServicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rapports & Rentabilité Services'**
  String get rapportsServicesTitle;

  /// No description provided for @performanceFinanciere.
  ///
  /// In fr, this message translates to:
  /// **'Performance Financière'**
  String get performanceFinanciere;

  /// No description provided for @totalFacture.
  ///
  /// In fr, this message translates to:
  /// **'Total Facturé'**
  String get totalFacture;

  /// No description provided for @totalEncaisse.
  ///
  /// In fr, this message translates to:
  /// **'Total Encaissé'**
  String get totalEncaisse;

  /// No description provided for @aRecouvrer.
  ///
  /// In fr, this message translates to:
  /// **'À Recouvrer'**
  String get aRecouvrer;

  /// No description provided for @tauxRecouvrement.
  ///
  /// In fr, this message translates to:
  /// **'Taux de recouvrement'**
  String get tauxRecouvrement;

  /// No description provided for @ventilationMainOeuvrePieces.
  ///
  /// In fr, this message translates to:
  /// **'Ventilation de la Valeur Facturée'**
  String get ventilationMainOeuvrePieces;

  /// No description provided for @mainOeuvre.
  ///
  /// In fr, this message translates to:
  /// **'Main d\'œuvre / Prestations'**
  String get mainOeuvre;

  /// No description provided for @piecesStock.
  ///
  /// In fr, this message translates to:
  /// **'Pièces stock'**
  String get piecesStock;

  /// No description provided for @transformationDevis.
  ///
  /// In fr, this message translates to:
  /// **'Transformation Devis'**
  String get transformationDevis;

  /// No description provided for @bonPriseEnCharge.
  ///
  /// In fr, this message translates to:
  /// **'Bon de prise en charge'**
  String get bonPriseEnCharge;

  /// No description provided for @rappelClient.
  ///
  /// In fr, this message translates to:
  /// **'Rappeler le client'**
  String get rappelClient;

  /// No description provided for @envoyerWhatsApp.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer WhatsApp'**
  String get envoyerWhatsApp;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
