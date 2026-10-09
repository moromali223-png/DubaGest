// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'DubaGest';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonCreate => 'Créer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonLoading => 'Chargement…';

  @override
  String get commonActive => 'Actif';

  @override
  String get commonInactive => 'Inactif';

  @override
  String get commonOptional => 'Facultatif';

  @override
  String get languageLabel => 'Langue';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get authLoginTitle => 'Connexion';

  @override
  String get authLoginSubtitle => 'Accédez à l\'espace de votre entreprise';

  @override
  String get authEmail => 'Adresse e-mail';

  @override
  String get authPassword => 'Mot de passe';

  @override
  String get authSignIn => 'Se connecter';

  @override
  String get authSignOut => 'Se déconnecter';

  @override
  String get authSignOutPendingTitle => 'Modifications non synchronisées';

  @override
  String authSignOutPendingMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications seront envoyées',
      one: '1 modification sera envoyée',
    );
    return '$_temp0 lors de votre prochaine connexion sur cet appareil. Se déconnecter quand même ?';
  }

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authForgotPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get authForgotPasswordHelp =>
      'Saisissez votre adresse e-mail. Vous recevrez un lien pour choisir un nouveau mot de passe.';

  @override
  String get authSendResetLink => 'Envoyer le lien';

  @override
  String get authResetLinkSent =>
      'Si un compte existe pour cette adresse, un e-mail vient d\'être envoyé.';

  @override
  String get authBackToLogin => 'Retour à la connexion';

  @override
  String get authChangePassword => 'Changer le mot de passe';

  @override
  String get authNewPassword => 'Nouveau mot de passe';

  @override
  String get authConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get authPasswordChanged => 'Mot de passe modifié.';

  @override
  String get authSessionExpired =>
      'Votre session a expiré. Veuillez vous reconnecter.';

  @override
  String get validationRequired => 'Champ obligatoire';

  @override
  String get validationEmail => 'Adresse e-mail invalide';

  @override
  String validationPasswordLength(int min) {
    return 'Au moins $min caractères';
  }

  @override
  String get validationPasswordsMismatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get errorNetwork => 'Connexion impossible. Vérifiez votre réseau.';

  @override
  String get errorInvalidCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get errorEmailNotConfirmed => 'Adresse e-mail non confirmée.';

  @override
  String get errorRateLimited =>
      'Trop de tentatives. Réessayez dans quelques minutes.';

  @override
  String get errorSessionExpired => 'Votre session a expiré.';

  @override
  String get errorForbidden =>
      'Vous n\'avez pas l\'autorisation d\'effectuer cette action.';

  @override
  String get errorNotFound => 'Élément introuvable.';

  @override
  String get errorConflict =>
      'Cet élément a été modifié par quelqu\'un d\'autre.';

  @override
  String get errorDuplicate => 'Un élément portant ce nom existe déjà.';

  @override
  String get errorServer => 'Le service est momentanément indisponible.';

  @override
  String get errorLocalStorage => 'Erreur de stockage sur l\'appareil.';

  @override
  String get errorUnknown => 'Une erreur inattendue est survenue.';

  @override
  String get ruleSubscriptionInactive =>
      'L\'abonnement de votre entreprise n\'est pas actif.';

  @override
  String ruleActivityNotAllowed(String plan) {
    return 'Votre abonnement $plan n\'inclut pas cette activité.';
  }

  @override
  String get ruleActivityInactive =>
      'Cette activité n\'est pas activée pour votre entreprise.';

  @override
  String ruleActivitiesLimit(String plan, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max activités',
      one: '1 activité',
    );
    return 'Votre abonnement $plan autorise au maximum $_temp0.';
  }

  @override
  String ruleUsersLimit(String plan, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max utilisateurs',
      one: '1 utilisateur',
    );
    return 'Votre abonnement $plan autorise au maximum $_temp0.';
  }

  @override
  String ruleRoleLimit(String plan, int max, String role) {
    return 'Votre abonnement $plan autorise au maximum $max « $role ».';
  }

  @override
  String rulePerimetresLimit(String plan, int max, String activity) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max sites',
      one: '1 site',
    );
    return 'Votre abonnement $plan autorise au maximum $_temp0 pour l\'activité $activity.';
  }

  @override
  String ruleRoleNotAllowed(String plan) {
    return 'Ce rôle n\'est pas disponible avec votre abonnement $plan.';
  }

  @override
  String get ruleRoleActivityInactive =>
      'Ce rôle nécessite une activité qui n\'est pas activée.';

  @override
  String get ruleModuleNotInPlan =>
      'Ce module n\'est pas inclus dans votre abonnement.';

  @override
  String get rulePermissionDenied => 'Votre rôle ne permet pas cette action.';

  @override
  String get rulePerimetreDenied => 'Vous n\'êtes pas affecté à ce site.';

  @override
  String get ruleLastAdmin =>
      'L\'entreprise doit conserver au moins un administrateur.';

  @override
  String get ruleAssignmentNotNeeded => 'Ce rôle accède déjà à tous les sites.';

  @override
  String get ruleAssignmentActivityMismatch =>
      'Ce site n\'appartient pas à l\'activité du rôle.';

  @override
  String get ruleImmutable => 'Cette information ne peut plus être modifiée.';

  @override
  String get contextLoading => 'Préparation de votre espace…';

  @override
  String get contextLoadError =>
      'Impossible de charger votre espace de travail.';

  @override
  String get contextOfflineCache =>
      'Hors ligne — données enregistrées sur l\'appareil.';

  @override
  String get contextNoEntrepriseTitle => 'Aucune entreprise';

  @override
  String get contextNoEntrepriseMessage =>
      'Votre compte n\'est rattaché à aucune entreprise. Contactez votre administrateur.';

  @override
  String get contextMemberSuspendedTitle => 'Accès suspendu';

  @override
  String contextMemberSuspendedMessage(String entreprise) {
    return 'Votre accès à $entreprise est suspendu. Contactez votre administrateur.';
  }

  @override
  String get contextEntrepriseSuspendedTitle => 'Entreprise suspendue';

  @override
  String contextEntrepriseSuspendedMessage(String entreprise) {
    return 'L\'accès à $entreprise est momentanément suspendu.';
  }

  @override
  String get navHome => 'Accueil';

  @override
  String get navAdministration => 'Administration';

  @override
  String get navSettings => 'Paramètres';

  @override
  String homeGreeting(String name) {
    return 'Bonjour $name';
  }

  @override
  String get homeGreetingAnonymous => 'Bonjour';

  @override
  String get homeNoModules => 'Aucun module n\'est disponible pour votre rôle.';

  @override
  String get homeSubscriptionInactive =>
      'Les modules sont indisponibles tant que l\'abonnement n\'est pas actif.';

  @override
  String get moduleComingSoonTitle => 'Bientôt disponible';

  @override
  String get moduleComingSoonMessage =>
      'Ce module sera disponible dans une prochaine version.';

  @override
  String get accessDeniedTitle => 'Accès refusé';

  @override
  String get accessDeniedBackHome => 'Retour à l\'accueil';

  @override
  String get activityCommerce => 'Commerce';

  @override
  String get activityServices => 'Services';

  @override
  String get activityImmobilier => 'Immobilier';

  @override
  String get roleAdministrateur => 'Administrateur';

  @override
  String get roleSuperviseur => 'Superviseur';

  @override
  String get roleGestionnaireStock => 'Gestionnaire stock';

  @override
  String get roleVendeur => 'Vendeur';

  @override
  String get planNormal => 'Normal';

  @override
  String get planMoyen => 'Moyen';

  @override
  String get planPro => 'Pro';

  @override
  String get moduleAdminEntreprise => 'Entreprise';

  @override
  String get moduleAdminUtilisateurs => 'Utilisateurs';

  @override
  String get moduleAdminPerimetres => 'Boutiques et sites';

  @override
  String get moduleAdminAbonnement => 'Abonnement';

  @override
  String get moduleCommerceProduits => 'Produits';

  @override
  String get moduleCommerceStock => 'Stock';

  @override
  String get moduleCommerceVentes => 'Ventes';

  @override
  String get moduleCommerceAchats => 'Achats';

  @override
  String get moduleCommunContacts => 'Contacts';

  @override
  String get moduleCommerceFournisseurs => 'Fournisseurs';

  @override
  String get moduleFinancesCreances => 'À recevoir / À payer';

  @override
  String get moduleFinancesCreancesCourt => 'Dettes';

  @override
  String get moduleCommunContactsClients => 'Clients';

  @override
  String get moduleFinancesPaiements => 'Paiements';

  @override
  String get moduleFinancesCaisse => 'Caisse';

  @override
  String get moduleFinancesDepenses => 'Dépenses';

  @override
  String get moduleServicesServices => 'Catalogue';

  @override
  String get moduleServicesPrestations => 'Prestations';

  @override
  String get moduleServicesPlanning => 'Planning';

  @override
  String get moduleServicesDevis => 'Devis';

  @override
  String get moduleServicesFacturation => 'Factures & Reçus';

  @override
  String get moduleServicesRapports => 'Rapports';

  @override
  String get moduleImmobilierBiens => 'Biens';

  @override
  String get moduleImmobilierProprietaires => 'Propriétaires';

  @override
  String get moduleImmobilierLocataires => 'Locataires';

  @override
  String get moduleImmobilierLocations => 'Locations';

  @override
  String get moduleImmobilierContrats => 'Contrats';

  @override
  String get moduleImmobilierLoyers => 'Loyers';

  @override
  String get perimetreTypeBoutique => 'Boutique';

  @override
  String get perimetreTypeAgence => 'Agence';

  @override
  String get perimetreTypeSite => 'Site';

  @override
  String get perimetreTypeUnite => 'Unité';

  @override
  String get perimetresEmpty => 'Aucun site pour le moment.';

  @override
  String get perimetreAdd => 'Ajouter';

  @override
  String get perimetreNew => 'Nouveau site';

  @override
  String get perimetreEdit => 'Modifier le site';

  @override
  String get perimetreName => 'Nom';

  @override
  String get perimetreCode => 'Code';

  @override
  String get perimetreActivity => 'Activité';

  @override
  String get perimetreType => 'Type';

  @override
  String get perimetreDeleteTitle => 'Supprimer ce site ?';

  @override
  String perimetreDeleteMessage(String name) {
    return '« $name » ne sera plus accessible.';
  }

  @override
  String get usersEmpty => 'Aucun utilisateur.';

  @override
  String get usersInvite => 'Ajouter un utilisateur';

  @override
  String get usersInviteComingSoon =>
      'L\'invitation d\'utilisateurs sera disponible dans une prochaine version.';

  @override
  String get usersYou => 'Vous';

  @override
  String get usersAssignments => 'Sites affectés';

  @override
  String get usersAllPerimetres => 'Tous les sites';

  @override
  String get usersNoPerimetre => 'Aucun site affecté';

  @override
  String get usersOnlineOnly => 'Cette action nécessite une connexion.';

  @override
  String get subscriptionPlan => 'Formule';

  @override
  String get subscriptionStatus => 'Statut';

  @override
  String get subscriptionStatusEssai => 'Essai';

  @override
  String get subscriptionStatusActif => 'Actif';

  @override
  String get subscriptionStatusSuspendu => 'Suspendu';

  @override
  String get subscriptionStatusExpire => 'Expiré';

  @override
  String get subscriptionStatusAnnule => 'Annulé';

  @override
  String subscriptionSince(String date) {
    return 'Depuis le $date';
  }

  @override
  String subscriptionUntil(String date) {
    return 'Jusqu\'au $date';
  }

  @override
  String get subscriptionNone => 'Aucun abonnement.';

  @override
  String get subscriptionActivities => 'Activités';

  @override
  String get subscriptionUsage => 'Consommation';

  @override
  String get subscriptionUsers => 'Utilisateurs';

  @override
  String subscriptionUsageValue(int used, int max) {
    return '$used / $max';
  }

  @override
  String get entrepriseInfo => 'Informations';

  @override
  String get entrepriseName => 'Nom';

  @override
  String get entrepriseCountry => 'Pays';

  @override
  String get entrepriseCurrency => 'Devise';

  @override
  String get entrepriseRole => 'Votre rôle';

  @override
  String get syncUpToDate => 'Données à jour';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications en attente',
      one: '1 modification en attente',
    );
    return '$_temp0';
  }

  @override
  String get syncSyncing => 'Synchronisation…';

  @override
  String get syncError => 'Échec de synchronisation';

  @override
  String get syncOffline => 'Hors ligne';

  @override
  String get syncOfflineBanner =>
      'Mode hors ligne : vos modifications seront envoyées au retour de la connexion.';

  @override
  String syncLastSynced(String time) {
    return 'Dernière synchronisation : $time';
  }

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get syncRecordPending => 'En attente d\'envoi';

  @override
  String get syncRecordError => 'Non synchronisé';

  @override
  String get syncRecordConflict =>
      'Modifié ailleurs — version serveur conservée';

  @override
  String get settingsAccount => 'Compte';

  @override
  String get settingsEntreprise => 'Entreprise';

  @override
  String get settingsSync => 'Synchronisation';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get authRegisterTitle => 'Créer votre compte';

  @override
  String get authRegisterSubtitle => 'Gratuit, en moins d\'une minute.';

  @override
  String get authFirstName => 'Prénom';

  @override
  String get authLastName => 'Nom';

  @override
  String get authCreateAccount => 'Créer mon compte';

  @override
  String get authNoAccount => 'Pas encore de compte ?';

  @override
  String get authHaveAccount => 'Déjà un compte ?';

  @override
  String get authSignInLink => 'Se connecter';

  @override
  String get authRegisterLink => 'Créer un compte';

  @override
  String get authContinueWithGoogle => 'Continuer avec Google';

  @override
  String get authOr => 'ou';

  @override
  String get authCheckEmailTitle => 'Vérifiez votre e-mail';

  @override
  String authCheckEmailMessage(String email) {
    return 'Un lien de confirmation a été envoyé à $email. Ouvrez-le, puis connectez-vous.';
  }

  @override
  String get authResetPasswordTitle => 'Nouveau mot de passe';

  @override
  String get errorAccountExists => 'Ce compte existe déjà. Connectez-vous.';

  @override
  String get errorWeakPassword => 'Mot de passe trop faible.';

  @override
  String get errorOauthUnavailable =>
      'La connexion avec Google n\'est pas disponible pour le moment.';

  @override
  String onboardingWelcome(String name) {
    return 'Bienvenue $name';
  }

  @override
  String get onboardingWelcomeAnonymous => 'Bienvenue';

  @override
  String get onboardingQuestion => 'Que souhaitez-vous faire ?';

  @override
  String get onboardingCreateTitle => 'Créer mon entreprise';

  @override
  String get onboardingCreateSubtitle => 'Vous en serez l\'administrateur.';

  @override
  String get onboardingJoinTitle => 'Rejoindre une entreprise';

  @override
  String get onboardingJoinSubtitle =>
      'Avec l\'invitation reçue de votre responsable.';

  @override
  String get companyName => 'Nom de l\'entreprise';

  @override
  String get companyPlan => 'Formule';

  @override
  String get companyActivities => 'Activités';

  @override
  String companyActivitiesHint(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Jusqu\'à $max activités',
      one: 'Choisissez 1 activité',
    );
    return '$_temp0';
  }

  @override
  String get companyTrialInfo =>
      'Essai gratuit de 14 jours. Vous serez l\'administrateur de l\'entreprise.';

  @override
  String get companyCreateButton => 'Créer l\'entreprise';

  @override
  String get joinCodeLabel => 'Code d\'invitation';

  @override
  String get joinCodeHelp => 'Collez le code ou ouvrez le lien reçu.';

  @override
  String get joinCheck => 'Vérifier';

  @override
  String joinInvitedTo(String entreprise) {
    return 'Invitation à rejoindre $entreprise';
  }

  @override
  String joinRole(String role) {
    return 'Rôle : $role';
  }

  @override
  String joinForEmail(String email) {
    return 'Destinée à $email';
  }

  @override
  String joinExpires(String date) {
    return 'Valable jusqu\'au $date';
  }

  @override
  String get joinAccept => 'Accepter l\'invitation';

  @override
  String get joinIgnore => 'Ignorer';

  @override
  String get joinSignInToAccept =>
      'Connectez-vous ou créez un compte avec l\'adresse invitée pour accepter.';

  @override
  String get ruleInvitationInvalid => 'Cette invitation est invalide.';

  @override
  String get ruleInvitationExpired => 'Cette invitation a expiré.';

  @override
  String get ruleInvitationUsed => 'Cette invitation a déjà été utilisée.';

  @override
  String get ruleInvitationCancelled => 'Cette invitation a été annulée.';

  @override
  String get ruleInvitationOtherEmail =>
      'Cette invitation est destinée à une autre adresse e-mail.';

  @override
  String get ruleInvitationNotCancellable =>
      'Cette invitation ne peut plus être annulée.';

  @override
  String get ruleEmailNotConfirmed =>
      'Confirmez d\'abord votre adresse e-mail.';

  @override
  String get ruleAlreadyMember =>
      'Cette personne fait déjà partie de l\'entreprise.';

  @override
  String get ruleCompanyAlreadyCreated => 'Vous avez déjà créé une entreprise.';

  @override
  String get rulePlanInvalid => 'Cette formule n\'est pas disponible.';

  @override
  String get ruleActivityRequired => 'Choisissez au moins une activité.';

  @override
  String get ruleNameInvalid => 'Le nom est trop court.';

  @override
  String get rulePerimetreRequired =>
      'Choisissez au moins un site pour ce rôle.';

  @override
  String get inviteTitle => 'Inviter un utilisateur';

  @override
  String get inviteRole => 'Rôle';

  @override
  String get invitePerimetres => 'Sites autorisés';

  @override
  String get inviteSend => 'Créer l\'invitation';

  @override
  String get inviteNoRole => 'Aucun rôle disponible avec votre abonnement.';

  @override
  String get inviteCreatedTitle => 'Invitation créée';

  @override
  String inviteCreatedMessage(String email, String date) {
    return 'Partagez ce lien avec $email. Il est valable jusqu\'au $date et ne sert qu\'une fois.';
  }

  @override
  String get inviteCopyLink => 'Copier le lien';

  @override
  String get inviteCopyCode => 'Copier le code';

  @override
  String get inviteCopied => 'Copié';

  @override
  String get inviteCancel => 'Annuler l\'invitation';

  @override
  String get invitationsTitle => 'Invitations';

  @override
  String get invitationStatusPending => 'En attente';

  @override
  String get invitationStatusAccepted => 'Acceptée';

  @override
  String get invitationStatusExpired => 'Expirée';

  @override
  String get invitationStatusCancelled => 'Annulée';

  @override
  String get navSell => 'Vendre';

  @override
  String get navStock => 'Stock';

  @override
  String get navFinances => 'Finances';

  @override
  String get navAccount => 'Compte';

  @override
  String get financesComingSoon =>
      'Le tableau de bord financier (chiffre d\'affaires, encaissements, dépenses, impayés) arrive avec les modules Ventes et Caisse.';

  @override
  String get menuActivities => 'Mes activités';

  @override
  String get menuPreferences => 'Préférences';

  @override
  String get menuSeeSubscription => 'Voir l\'abonnement';

  @override
  String get activityStatusActive => 'Active';

  @override
  String get activityActivate => 'Activer';

  @override
  String activityActivateTitle(String activity) {
    return 'Activer $activity ?';
  }

  @override
  String get activityActivateMessage =>
      'Les modules de cette activité seront ajoutés à votre entreprise. Créez ensuite son premier site.';

  @override
  String get activityActivated => 'Activité activée.';

  @override
  String get homeToday => 'Aujourd\'hui';

  @override
  String get homeWatch => 'À surveiller';

  @override
  String get homeKpiPending =>
      'Les chiffres s\'afficheront dès les premières ventes enregistrées.';

  @override
  String get kpiRevenue => 'Chiffre d\'affaires';

  @override
  String get kpiCollected => 'Encaissé';

  @override
  String get kpiExpenses => 'Dépenses';

  @override
  String get kpiUnpaid => 'Impayés clients';

  @override
  String homeTrialDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Essai : $days jours restants',
      one: 'Essai : 1 jour restant',
      zero: 'Votre essai se termine aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String get homeTrialHint =>
      'Choisissez votre formule pour continuer sans interruption.';

  @override
  String get roleCaissier => 'Caissier';

  @override
  String get roleGestionnaireImmobilier => 'Gestionnaire immobilier';

  @override
  String subscriptionUsageUnlimited(int used) {
    return '$used · illimité';
  }

  @override
  String companyPlanPrice(String price) {
    return '$price / mois';
  }

  @override
  String get entrepriseIdentity => 'Identité';

  @override
  String get entrepriseContact => 'Coordonnées';

  @override
  String get entrepriseLegal => 'Informations légales';

  @override
  String get entreprisePreferences => 'Préférences';

  @override
  String get entreprisePhone => 'Téléphone';

  @override
  String get entrepriseAddress => 'Adresse';

  @override
  String get entrepriseCity => 'Ville';

  @override
  String get entrepriseTaxId => 'Identifiant fiscal (NIF)';

  @override
  String get entrepriseTradeRegister => 'Registre du commerce (RCCM)';

  @override
  String get entrepriseDocLanguage => 'Langue des documents';

  @override
  String get entrepriseSaved => 'Informations enregistrées.';

  @override
  String get entrepriseLogoLater =>
      'Le logo pourra être ajouté avec les pièces jointes (prochaine étape).';

  @override
  String get moduleAdminAudit => 'Journal d\'activité';

  @override
  String get auditEmpty => 'Aucune activité enregistrée pour le moment.';

  @override
  String get auditSystem => 'Système';

  @override
  String get auditActionCreation => 'Création';

  @override
  String get auditActionModification => 'Modification';

  @override
  String get auditActionArchivage => 'Archivage';

  @override
  String get auditActionRestauration => 'Restauration';

  @override
  String get auditActionSuppression => 'Suppression';

  @override
  String get auditEntityEntreprise => 'Entreprise';

  @override
  String get auditEntityActivite => 'Activité';

  @override
  String get auditEntityAbonnement => 'Abonnement';

  @override
  String get auditEntityMembre => 'Membre';

  @override
  String get auditEntityAffectation => 'Affectation à un site';

  @override
  String get auditEntitySite => 'Site';

  @override
  String get auditEntityInvitation => 'Invitation';

  @override
  String auditOtherFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres informations',
      one: '1 autre information',
    );
    return '$_temp0';
  }

  @override
  String get espaceTitle => 'Espace de travail';

  @override
  String get espaceGlobal => 'Vue globale';

  @override
  String get espaceActivity => 'Activité';

  @override
  String get espaceSite => 'Boutique / site';

  @override
  String get commonClear => 'Effacer';

  @override
  String ruleTextTooLong(int max) {
    return 'Texte trop long ($max caractères au maximum).';
  }

  @override
  String get homeCommonTools => 'Outils communs';

  @override
  String get contactRelationClient => 'Client';

  @override
  String get contactRelationFournisseur => 'Fournisseur';

  @override
  String get contactRelationLocataire => 'Locataire';

  @override
  String get contactRelationProprietaire => 'Propriétaire';

  @override
  String get contactRelationPrestataire => 'Prestataire';

  @override
  String get contactTypePersonne => 'Personne';

  @override
  String get contactTypeOrganisation => 'Organisation';

  @override
  String get contactsSearchHint => 'Nom, téléphone, e-mail, ville…';

  @override
  String get contactsFilterAll => 'Tous';

  @override
  String get contactsShowArchived => 'Archivés';

  @override
  String get contactsEmpty =>
      'Aucun contact pour le moment. Ajoutez vos clients, fournisseurs, locataires…';

  @override
  String get contactsNoResult => 'Aucun contact ne correspond à la recherche.';

  @override
  String get contactAdd => 'Nouveau contact';

  @override
  String get contactNew => 'Nouveau contact';

  @override
  String get contactEdit => 'Modifier le contact';

  @override
  String get contactDetailTitle => 'Fiche contact';

  @override
  String get contactNotFound =>
      'Ce contact n\'existe pas ou n\'est plus accessible.';

  @override
  String get contactSaved => 'Contact enregistré.';

  @override
  String get contactArchived => 'Archivé';

  @override
  String get contactArchive => 'Archiver';

  @override
  String get contactRestore => 'Réactiver';

  @override
  String get contactArchiveTitle => 'Archiver ce contact ?';

  @override
  String contactArchiveMessage(String name) {
    return '« $name » n\'apparaîtra plus dans les listes. Son historique est conservé et vous pourrez le réactiver.';
  }

  @override
  String get contactRelationsNone => 'Aucune relation indiquée';

  @override
  String get contactFieldNom => 'Nom';

  @override
  String get contactFieldRaisonSociale => 'Raison sociale';

  @override
  String get contactFieldPrenom => 'Prénom';

  @override
  String get contactFieldTelephone => 'Téléphone';

  @override
  String get contactFieldWhatsapp => 'WhatsApp';

  @override
  String get contactWhatsappHint =>
      'À remplir seulement si différent du téléphone';

  @override
  String get contactFieldEmail => 'E-mail';

  @override
  String get contactFieldAdresse => 'Adresse';

  @override
  String get contactFieldVille => 'Ville';

  @override
  String get contactFieldRemarque => 'Remarque';

  @override
  String get contactFieldRelations => 'Relation avec l\'entreprise';

  @override
  String get contactCall => 'Appeler';

  @override
  String get contactWhatsapp => 'WhatsApp';

  @override
  String get contactEmailAction => 'E-mail';

  @override
  String get contactActionUnavailable => 'Action impossible sur cet appareil.';

  @override
  String get contactHistoryTitle => 'Historique';

  @override
  String get contactHistoryEmpty =>
      'Les ventes, paiements et loyers de ce contact apparaîtront ici dès que ces modules seront disponibles.';

  @override
  String get contactDuplicateTitle => 'Ce contact existe peut-être déjà';

  @override
  String contactDuplicateMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fiches ont le même nom ou le même téléphone.',
      one: 'Une fiche a le même nom ou le même téléphone.',
    );
    return '$_temp0 Utilisez la fiche existante pour garder un historique unique.';
  }

  @override
  String get contactDuplicateOpen => 'Ouvrir la fiche';

  @override
  String get contactDuplicateAddRelation => 'Ajouter la relation';

  @override
  String get contactDuplicateCreateAnyway => 'Créer quand même';

  @override
  String get contactHistoryNone =>
      'Aucune somme due ni aucun paiement pour ce contact.';

  @override
  String get contactOwesUs => 'Nous doit';

  @override
  String get contactWeOwe => 'Nous lui devons';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get homeSeeFinances => 'Voir les finances';

  @override
  String get validationAmount => 'Saisissez un montant supérieur à zéro';

  @override
  String validationAmountMax(String max) {
    return 'Au maximum $max';
  }

  @override
  String get paymentModeCash => 'Espèces';

  @override
  String get paymentModeMobileMoney => 'Mobile money';

  @override
  String get paymentModeCard => 'Carte';

  @override
  String get paymentModeTransfer => 'Virement';

  @override
  String get paymentModeCheque => 'Chèque';

  @override
  String get paymentModeOther => 'Autre';

  @override
  String get debtStateUnpaid => 'À encaisser';

  @override
  String get debtStateToPay => 'À payer';

  @override
  String get debtStatePartial => 'Partiel';

  @override
  String get debtStateOverdue => 'En retard';

  @override
  String get debtStatePaid => 'Soldé';

  @override
  String get debtStateCancelled => 'Annulé';

  @override
  String get cashMoveCollection => 'Encaissement';

  @override
  String get cashMoveDisbursement => 'Décaissement';

  @override
  String get cashMoveDeposit => 'Dépôt';

  @override
  String get cashMoveWithdrawal => 'Retrait';

  @override
  String get financeRejectedTitle => 'Refusé par le serveur';

  @override
  String get financeRejectedMessage =>
      'Cette opération n\'a pas été enregistrée (droits, caisse fermée ou montant dépassé). Elle n\'est comptée dans aucun total.';

  @override
  String get financeRejectedRemove => 'Retirer';

  @override
  String get financeRejectedShort => 'Refusé';

  @override
  String get financeNoContact => 'Sans contact';

  @override
  String get financeContact => 'Contact';

  @override
  String get financeInCash => 'En caisse';

  @override
  String get financeToReceive => 'À recevoir';

  @override
  String get financeToPay => 'À payer';

  @override
  String financeOverdueAmount(String amount) {
    return '$amount en retard';
  }

  @override
  String get financeNotFound => 'Élément introuvable ou inaccessible.';

  @override
  String get financeSite => 'Boutique / agence';

  @override
  String get financeAllSites => 'Toute l\'entreprise';

  @override
  String get financePendingSync =>
      'Enregistré sur l\'appareil, en attente d\'envoi';

  @override
  String get debtNewReceivable => 'Nouvelle somme à recevoir';

  @override
  String get debtNewPayable => 'Nouvelle somme à payer';

  @override
  String get debtShowSettled => 'Afficher les soldés';

  @override
  String get debtEmptyReceivable => 'Personne ne vous doit d\'argent.';

  @override
  String get debtEmptyPayable => 'Vous ne devez rien pour le moment.';

  @override
  String debtDueOn(String date) {
    return 'Échéance $date';
  }

  @override
  String get debtDetailTitle => 'Somme due';

  @override
  String get debtRemaining => 'Reste dû';

  @override
  String get debtPaid => 'Déjà réglé';

  @override
  String get debtTotal => 'Montant total';

  @override
  String get debtDate => 'Date';

  @override
  String get debtDueDate => 'Échéance';

  @override
  String get debtNoDueDate => 'Sans échéance';

  @override
  String get debtCancelReason => 'Motif d\'annulation';

  @override
  String get debtCollect => 'Encaisser';

  @override
  String get debtPay => 'Payer';

  @override
  String get debtCancel => 'Annuler';

  @override
  String get debtPayments => 'Paiements';

  @override
  String get debtNoPayment => 'Aucun paiement pour le moment.';

  @override
  String get debtCancelTitle => 'Annuler cette somme due ?';

  @override
  String get debtCancelMessage =>
      'Elle ne sera plus comptée. Elle reste visible dans l\'historique.';

  @override
  String get debtEdit => 'Modifier la somme due';

  @override
  String get debtWhoOwes => 'Qui doit payer ?';

  @override
  String get debtOwedTo => 'À qui devez-vous ?';

  @override
  String get debtLabel => 'Objet';

  @override
  String get debtLabelHint => 'Ex. : marchandises livrées à crédit';

  @override
  String debtAlreadyPaid(String amount) {
    return 'Déjà réglé : $amount. Le total ne peut pas être inférieur.';
  }

  @override
  String get paymentNew => 'Encaisser';

  @override
  String get paymentsEmpty => 'Aucun paiement enregistré.';

  @override
  String get paymentCancellation => 'Annulation de paiement';

  @override
  String get paymentIn => 'Encaissement';

  @override
  String get paymentOut => 'Paiement versé';

  @override
  String get paymentCancelled => 'Annulé';

  @override
  String get paymentSaved => 'Paiement enregistré.';

  @override
  String get paymentNewIn => 'Encaisser';

  @override
  String get paymentNewOut => 'Payer';

  @override
  String get paymentFrom => 'Payé par';

  @override
  String get paymentTo => 'Payé à';

  @override
  String get paymentAmount => 'Montant';

  @override
  String get paymentMode => 'Mode de paiement';

  @override
  String get paymentCashRegister => 'Caisse';

  @override
  String get paymentNoCashRegister => 'Hors caisse';

  @override
  String get paymentNoOpenRegister =>
      'Aucune caisse ouverte : le paiement sera enregistré hors caisse.';

  @override
  String get paymentSettlesReceivables => 'Règle les sommes dues';

  @override
  String get paymentSettlesPayables => 'Règle les dettes';

  @override
  String paymentRemainingOf(String amount) {
    return 'Reste $amount';
  }

  @override
  String paymentUnallocated(String amount) {
    return '$amount non affecté (avance)';
  }

  @override
  String get paymentReference => 'Référence';

  @override
  String get paymentReferenceHint => 'N° de transaction, de chèque…';

  @override
  String get paymentNote => 'Note';

  @override
  String paymentConfirmIn(String amount) {
    return 'Encaisser $amount';
  }

  @override
  String paymentConfirmOut(String amount) {
    return 'Payer $amount';
  }

  @override
  String get paymentDetailTitle => 'Paiement';

  @override
  String get paymentDate => 'Date';

  @override
  String get paymentCancelsPayment => 'Annule le paiement';

  @override
  String get paymentOpenOriginal => 'Voir le paiement d\'origine';

  @override
  String get paymentCancelledBy => 'Annulé le';

  @override
  String get paymentCancel => 'Annuler ce paiement';

  @override
  String get paymentCancelHint =>
      'Un paiement n\'est jamais effacé : son annulation est enregistrée et les sommes dues redeviennent dues.';

  @override
  String get paymentCancelTitle => 'Annuler ce paiement ?';

  @override
  String paymentCancelMessage(String amount) {
    return 'Un paiement inverse de $amount sera enregistré, et la caisse sera ajustée s\'il s\'agissait d\'espèces.';
  }

  @override
  String get cashNew => 'Nouvelle caisse';

  @override
  String get cashEmptyAdmin =>
      'Aucune caisse. Créez une caisse pour chaque boutique ou agence qui manipule des espèces.';

  @override
  String get cashEmpty => 'Aucune caisse accessible.';

  @override
  String get cashOpenState => 'Ouverte';

  @override
  String get cashClosedState => 'Fermée';

  @override
  String cashOpenSince(String date) {
    return 'Ouverte depuis $date';
  }

  @override
  String get cashBalance => 'Solde en caisse';

  @override
  String cashOpeningBalance(String amount) {
    return 'Fond de caisse : $amount';
  }

  @override
  String get cashOpen => 'Ouvrir la caisse';

  @override
  String get cashClose => 'Clôturer la caisse';

  @override
  String get cashMovements => 'Mouvements';

  @override
  String get cashNoMovement => 'Aucun mouvement depuis l\'ouverture.';

  @override
  String get cashHistory => 'Clôtures précédentes';

  @override
  String get cashClosingPending => 'Clôture en attente d\'envoi';

  @override
  String cashClosingSummary(String expected, String counted) {
    return 'Attendu $expected · compté $counted';
  }

  @override
  String get cashNoGap => 'Aucun écart';

  @override
  String get cashOpeningAmount => 'Fond de caisse';

  @override
  String get cashMoveReason => 'Motif';

  @override
  String cashExpected(String amount) {
    return 'Montant attendu : $amount';
  }

  @override
  String get cashCounted => 'Montant compté';

  @override
  String cashGap(String amount) {
    return 'Écart : $amount';
  }

  @override
  String get cashClosingNote => 'Commentaire (facultatif)';

  @override
  String get cashName => 'Nom de la caisse';

  @override
  String cashDefaultName(String site) {
    return 'Caisse $site';
  }

  @override
  String get ruleLabelInvalid =>
      'Indiquez l\'objet (200 caractères au maximum).';

  @override
  String get ruleCommitmentCancelled => 'Cette somme due a été annulée.';

  @override
  String get ruleCommitmentPaid =>
      'Des paiements ont déjà été enregistrés : annulez-les d\'abord.';

  @override
  String ruleTotalBelowPaid(String amount) {
    return 'Le total ne peut pas être inférieur à ce qui est déjà réglé ($amount).';
  }

  @override
  String ruleAmountAboveRemaining(String amount) {
    return 'Montant supérieur au reste dû ($amount).';
  }

  @override
  String get ruleAllocationAbovePayment =>
      'La répartition dépasse le montant du paiement.';

  @override
  String get ruleAllocationWrongDirection =>
      'Un encaissement ne peut régler qu\'une somme à recevoir, un paiement versé qu\'une somme à payer.';

  @override
  String get ruleAllocationOtherContact =>
      'Cette somme due concerne un autre contact.';

  @override
  String get rulePaymentAlreadyCancelled => 'Ce paiement est déjà annulé.';

  @override
  String get ruleModeWithoutCash => 'Seules les espèces passent par la caisse.';

  @override
  String get ruleDateInvalid => 'Date de paiement invalide.';

  @override
  String get ruleCashClosed => 'La caisse est fermée : ouvrez-la d\'abord.';

  @override
  String get ruleCashOpenSession => 'Clôturez d\'abord la caisse.';

  @override
  String get ruleCashAlreadyOpen => 'Cette caisse est déjà ouverte.';

  @override
  String get ruleCashInactive => 'Cette caisse est désactivée.';

  @override
  String ruleCashInsufficient(String amount) {
    return 'Espèces insuffisantes en caisse (solde : $amount).';
  }

  @override
  String get ruleFinanceInconsistent =>
      'Opération impossible : données incohérentes. Actualisez puis réessayez.';

  @override
  String get financeExpensesMonth => 'Dépenses du mois';

  @override
  String get debtOpenExpense => 'Voir la dépense';

  @override
  String get expenseCatRent => 'Loyer';

  @override
  String get expenseCatEnergy => 'Électricité';

  @override
  String get expenseCatTransport => 'Transport';

  @override
  String get expenseCatSalaries => 'Salaires';

  @override
  String get expenseCatSupplies => 'Fournitures';

  @override
  String get expenseCatCommunication => 'Communication et publicité';

  @override
  String get expenseCatMaintenance => 'Entretien';

  @override
  String get expenseCatTaxes => 'Impôts et taxes';

  @override
  String get expenseCatOther => 'Autre';

  @override
  String get expenseNew => 'Nouvelle dépense';

  @override
  String get expenseSaved => 'Dépense enregistrée.';

  @override
  String get expenseCategories => 'Catégories';

  @override
  String get expensesEmpty => 'Aucune dépense enregistrée.';

  @override
  String get expenseCancelled => 'Annulée';

  @override
  String get expenseToPay => 'À payer';

  @override
  String get expenseDetailTitle => 'Dépense';

  @override
  String get expenseDate => 'Date de la dépense';

  @override
  String get expenseSettlement => 'Règlement';

  @override
  String expensePaidWith(String mode) {
    return 'Payée · $mode';
  }

  @override
  String expenseToPayRemaining(String amount) {
    return 'À payer : $amount';
  }

  @override
  String get expenseSupplier => 'Fournisseur (facultatif)';

  @override
  String get expenseCancel => 'Annuler la dépense';

  @override
  String get expenseEdit => 'Modifier la dépense';

  @override
  String get expenseLabel => 'Description';

  @override
  String get expenseLabelHint => 'Ex. : taxi pour la livraison';

  @override
  String get expenseCategory => 'Catégorie';

  @override
  String get expenseAmountLocked =>
      'Le montant ne se modifie pas : annulez la dépense puis ressaisissez-la.';

  @override
  String get expenseCancelTitle => 'Annuler cette dépense ?';

  @override
  String get expenseCancelMessagePaid =>
      'Le paiement sera annulé (et la caisse réajustée pour des espèces), puis la dépense. Rien n\'est effacé de l\'historique.';

  @override
  String get expenseCancelMessage =>
      'La somme à payer liée sera annulée. Rien n\'est effacé de l\'historique.';

  @override
  String get expenseCategoryNew => 'Nouvelle catégorie';

  @override
  String get expenseCategoryName => 'Nom de la catégorie';

  @override
  String get expenseCategoriesHint =>
      'Une catégorie désactivée n\'est plus proposée ; les dépenses déjà saisies la conservent.';

  @override
  String get expensePaidNow => 'Payée maintenant';

  @override
  String get expensePayLater => 'À payer plus tard';

  @override
  String get expenseReferenceHint => 'N° de facture, de reçu…';

  @override
  String get ruleCommitmentLinked =>
      'Cette somme est liée à une dépense : modifiez ou annulez la dépense.';

  @override
  String get ruleCategoryInvalid => 'Choisissez une catégorie active.';

  @override
  String get ruleExpensePaid =>
      'Cette dépense est payée : annulez d\'abord son paiement.';

  @override
  String get ruleExpenseCancelled => 'Cette dépense est annulée.';

  @override
  String get moduleCommunDocuments => 'Documents';

  @override
  String get docTypeReceipt => 'Reçu';

  @override
  String get docTypeInvoice => 'Facture';

  @override
  String get docTypeQuote => 'Devis';

  @override
  String get docTypeCreditNote => 'Avoir';

  @override
  String get docSearchHint => 'N° de document ou nom…';

  @override
  String get docEmpty =>
      'Aucun document émis. Les reçus s\'émettent depuis la fiche d\'un paiement.';

  @override
  String get docIssueReceipt => 'Émettre le reçu';

  @override
  String docOpenReceipt(String numero) {
    return 'Voir le reçu $numero';
  }

  @override
  String get docReceiptTitle => 'REÇU';

  @override
  String get docDate => 'Date';

  @override
  String get docReceivedFrom => 'Reçu de';

  @override
  String get docPaymentMode => 'Mode de paiement';

  @override
  String get docReference => 'Référence';

  @override
  String get docAmountReceived => 'Montant reçu';

  @override
  String get docSettles => 'Règlement de';

  @override
  String get docColumnLabel => 'Objet';

  @override
  String get docColumnAmount => 'Payé';

  @override
  String get docColumnRemaining => 'Reste dû';

  @override
  String docIssuedBy(String name) {
    return 'Émis par $name';
  }

  @override
  String get docGeneratedBy => 'Document généré par DubaGest';

  @override
  String get docCancelledStamp => 'ANNULÉ';

  @override
  String docPhone(String value) {
    return 'Tél. : $value';
  }

  @override
  String docTaxId(String value) {
    return 'N° fiscal : $value';
  }

  @override
  String docTradeRegister(String value) {
    return 'RCCM : $value';
  }

  @override
  String get ruleDocumentExists => 'Un reçu a déjà été émis pour ce paiement.';

  @override
  String get ruleDocumentOriginInvalid =>
      'Un reçu ne s\'émet que pour un encaissement valide.';

  @override
  String get ruleDocumentNumbersExhausted =>
      'Plus de numéro de reçu disponible sur cet appareil. Connectez-vous à internet un instant pour en réserver.';

  @override
  String get ruleDocumentNumberInvalid =>
      'Numéro de document invalide. Actualisez puis réessayez.';

  @override
  String get moduleCommunAgenda => 'Agenda';

  @override
  String get agendaTypeReminder => 'Rappel';

  @override
  String get agendaTypeMeeting => 'Rendez-vous';

  @override
  String get agendaTypeTask => 'Tâche';

  @override
  String get agendaTypeFollowUp => 'Relance';

  @override
  String get agendaNew => 'Nouvelle échéance';

  @override
  String get agendaEdit => 'Modifier l\'échéance';

  @override
  String get agendaMine => 'Mes tâches';

  @override
  String get agendaEmpty =>
      'Rien de prévu. Ajoutez un rappel, une tâche ou une relance.';

  @override
  String get agendaOverdue => 'En retard';

  @override
  String get agendaToday => 'Aujourd\'hui';

  @override
  String get agendaNextDays => '7 prochains jours';

  @override
  String get agendaLater => 'Plus tard';

  @override
  String agendaAssignedTo(String name) {
    return 'Confié à $name';
  }

  @override
  String get agendaMarkDone => 'Marquer comme fait';

  @override
  String get agendaReopen => 'Remettre à faire';

  @override
  String get agendaCancel => 'Annuler l\'échéance';

  @override
  String get agendaDueToReceive => 'Échéance d\'encaissement';

  @override
  String get agendaDueToPay => 'Échéance de paiement';

  @override
  String agendaReminderBefore(String delay) {
    return 'Rappel $delay avant';
  }

  @override
  String get agendaOpenDebt => 'Voir la somme due';

  @override
  String get agendaStatusTodo => 'À faire';

  @override
  String get agendaStatusDone => 'Fait';

  @override
  String get agendaStatusCancelled => 'Annulé';

  @override
  String get agendaTitle => 'Titre';

  @override
  String get agendaTitleHint => 'Ex. : appeler Amadou pour le solde';

  @override
  String get agendaWhen => 'Date et heure';

  @override
  String get agendaReminder => 'Rappel';

  @override
  String get agendaNoReminder => 'Aucun rappel';

  @override
  String get agendaAssignee => 'Confier à';

  @override
  String get agendaNobody => 'Personne en particulier';

  @override
  String get agendaMe => 'Moi';

  @override
  String get agendaPlanFollowUp => 'Planifier une relance';

  @override
  String agendaFollowUpTitle(String name) {
    return 'Relancer $name';
  }

  @override
  String agendaDelayMinutes(int n) {
    return '$n min';
  }

  @override
  String agendaDelayHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n heures',
      one: '1 heure',
    );
    return '$_temp0';
  }

  @override
  String agendaDelayDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Tout marquer lu';

  @override
  String get notificationsEmpty => 'Rien à signaler.';

  @override
  String get notificationsToHandle => 'À traiter';

  @override
  String get notificationsReceived => 'Messages';

  @override
  String get notifOverdue => 'En retard';

  @override
  String get notifDueSoon => 'Bientôt';

  @override
  String notifDebtsOverdue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sommes à recevoir en retard',
      one: '1 somme à recevoir en retard',
    );
    return '$_temp0';
  }

  @override
  String notifCashOpenLong(String name) {
    return '$name ouverte depuis plus de 24 h';
  }

  @override
  String notifRejected(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n opérations refusées par le serveur',
      one: '1 opération refusée par le serveur',
    );
    return '$_temp0';
  }

  @override
  String get notifRejectedHint => 'Ouvrez-la pour lire le motif et la retirer.';

  @override
  String notifAssigned(String name) {
    return '$name vous a confié une tâche';
  }

  @override
  String notifDone(String name) {
    return '$name a terminé une tâche';
  }

  @override
  String get ruleAssigneeInvalid =>
      'Cette personne n\'est pas un membre actif de l\'entreprise.';

  @override
  String get ruleTargetInvalid => 'La fiche liée n\'existe plus.';

  @override
  String get dashboardTitle => 'Tableau de bord';

  @override
  String get dashboard7Days => '7 jours';

  @override
  String get dashboard30Days => '30 jours';

  @override
  String get dashboardMonth => 'Ce mois';

  @override
  String get dashboardEmpty =>
      'Aucune opération sur cette période pour cet espace.';

  @override
  String get dashboardFlows => 'Encaissé et versé par jour';

  @override
  String get dashboardExpensesByCategory => 'Dépenses par catégorie';

  @override
  String get dashboardTopDebtors => 'Qui vous doit le plus';

  @override
  String get dashboardCollected => 'Encaissé';

  @override
  String get dashboardPaidOut => 'Versé';

  @override
  String get dashboardNet => 'Solde de la période';

  @override
  String get dashboardExpenses => 'Dépenses';

  @override
  String get dashboardOtherCategories => 'Autres catégories';

  @override
  String get dashboardSeeAll => 'Tout voir';

  @override
  String get searchHint => 'Rechercher un contact, un reçu, un paiement…';

  @override
  String get searchIntro =>
      'Nom, téléphone, montant, n° de reçu… La recherche fonctionne aussi hors-ligne.';

  @override
  String get searchNoResult => 'Aucun résultat.';

  @override
  String get searchDebts => 'Sommes dues';

  @override
  String get moduleCommunRapports => 'Rapports';

  @override
  String get reportCashJournal => 'Journal de trésorerie';

  @override
  String get reportCashJournalHint =>
      'Tous les encaissements et paiements versés de la période.';

  @override
  String get reportExpenses => 'Dépenses par catégorie';

  @override
  String get reportExpensesHint =>
      'Nombre et total des dépenses de la période, par catégorie.';

  @override
  String get reportAgedReceivables => 'Balance âgée des créances';

  @override
  String get reportAgedReceivablesHint =>
      'Ce que chaque client doit encore, selon l\'ancienneté du retard.';

  @override
  String get reportCashClosings => 'Clôtures de caisse';

  @override
  String get reportCashClosingsHint =>
      'Solde attendu, montant compté et écart de chaque clôture.';

  @override
  String reportPeriod(String start, String end) {
    return 'Du $start au $end';
  }

  @override
  String reportAtDate(String date) {
    return 'Situation au $date';
  }

  @override
  String get reportTotal => 'Total';

  @override
  String reportNet(String amount) {
    return 'Solde : $amount';
  }

  @override
  String get reportCount => 'Nombre';

  @override
  String get reportNotDue => 'Non échu';

  @override
  String reportDaysRange(int a, int b) {
    return '$a à $b j';
  }

  @override
  String reportDaysOver(int n) {
    return 'Plus de $n j';
  }

  @override
  String get reportClosedOn => 'Clôturée le';

  @override
  String get reportExpected => 'Attendu';

  @override
  String get reportGap => 'Écart';

  @override
  String get reportNone => 'Aucun rapport disponible avec vos droits.';

  @override
  String get reportEmpty => 'Aucune donnée pour cette période.';

  @override
  String get reportExportPdf => 'Exporter en PDF';

  @override
  String reportGeneratedOn(String date) {
    return 'Édité le $date — DubaGest';
  }

  @override
  String get notesTitle => 'Notes et pièces jointes';

  @override
  String get notesAddHint => 'Ajouter une note…';

  @override
  String get notesAdd => 'Ajouter la note';

  @override
  String get attachmentsTitle => 'Pièces jointes';

  @override
  String get attachTakePhoto => 'Prendre une photo';

  @override
  String get attachChooseFile => 'Joindre un fichier';

  @override
  String get attachOnlineHint =>
      'Photo ou PDF, 10 Mo au plus. L\'envoi d\'un fichier demande une connexion.';

  @override
  String get attachFileTypes => 'Images et PDF';

  @override
  String attachSizeKb(int n) {
    return '$n Ko';
  }

  @override
  String attachSizeMb(String value) {
    return '$value Mo';
  }

  @override
  String get entrepriseLogoHint =>
      'Le logo apparaît en tête des reçus (PNG, JPEG ou WEBP, 2 Mo au plus).';

  @override
  String get entrepriseLogoChange => 'Changer le logo';

  @override
  String get entrepriseLogoSaved => 'Logo enregistré.';

  @override
  String get entrepriseLogoTypes => 'Images';

  @override
  String get ruleFileTypeInvalid =>
      'Format non accepté : photo (JPEG, PNG, WEBP) ou PDF uniquement.';

  @override
  String ruleFileTooLarge(int max) {
    return 'Fichier trop volumineux ($max Mo au plus).';
  }

  @override
  String get settingsCompanyProfile => 'Fiche de l\'entreprise';

  @override
  String get settingsPayments => 'Paiements et reçus';

  @override
  String get settingsPaymentsHint =>
      'Modes de paiement proposés, mention des reçus';

  @override
  String get settingsExpenseCategories => 'Catégories de dépenses';

  @override
  String get settingsPaymentModes => 'Modes de paiement proposés';

  @override
  String get settingsPaymentModesHint =>
      'Seuls les modes activés sont proposés à la saisie. Les paiements déjà enregistrés ne changent pas.';

  @override
  String get settingsPaymentModeCash => 'Passe par la caisse';

  @override
  String get settingsReceiptFooter => 'Mention en bas des reçus';

  @override
  String get settingsReceiptFooterHint => 'Ex. : Merci de votre confiance.';

  @override
  String get settingsReceiptFooterNote =>
      'Imprimée sur les prochains reçus ; les reçus déjà émis ne changent pas.';

  @override
  String get settingsSaved => 'Paramètres enregistrés.';

  @override
  String get rulePaymentModesInvalid =>
      'Choisissez au moins un mode de paiement de la liste.';

  @override
  String get rulePaymentModeDisabled =>
      'Ce mode de paiement n\'est plus proposé par l\'entreprise. Choisissez-en un autre.';

  @override
  String get comStatusInStock => 'En stock';

  @override
  String get comStatusLow => 'Stock faible';

  @override
  String get comStatusOut => 'Rupture';

  @override
  String get comAllShops => 'Toutes les boutiques';

  @override
  String get comChooseShop => 'Choisir la boutique';

  @override
  String get comShop => 'Boutique';

  @override
  String get comShopRequired => 'Choisissez une boutique';

  @override
  String get comBefore => 'Avant';

  @override
  String get comAfter => 'Après';

  @override
  String get comQuantity => 'Quantité';

  @override
  String get comQuantityInvalid => 'Entrez une quantité valable';

  @override
  String comFractionNotAllowed(String unite) {
    return 'Ce produit se compte en $unite entiers';
  }

  @override
  String comFractionStep(String pas, String unite) {
    return 'Par pas de $pas $unite';
  }

  @override
  String get comScan => 'Scanner un code-barres';

  @override
  String get comScanTitle => 'Scanner';

  @override
  String get comTorch => 'Lampe';

  @override
  String get comScanUnavailable =>
      'La caméra n\'est pas disponible. Saisissez le code à la main.';

  @override
  String get comScanHint => 'Placez le code-barres dans le cadre';

  @override
  String get comBarcodeUnknown => 'Ce code n\'est lié à aucun produit';

  @override
  String get comChooseProduct => 'Choisir un produit';

  @override
  String get comSearchHint => 'Nom, référence ou code-barres…';

  @override
  String get comAllCategories => 'Toutes';

  @override
  String get comNoProductFound => 'Aucun produit trouvé';

  @override
  String get comNoProductFoundHint =>
      'Essayez un autre mot, ou ajoutez ce produit.';

  @override
  String get comAddProduct => 'Ajouter un produit';

  @override
  String get comUsualProducts => 'Produits habituels';

  @override
  String get comAllProducts => 'Tous les produits';

  @override
  String get comProduct => 'Produit';

  @override
  String get comFrom => 'De';

  @override
  String get comTo => 'Vers';

  @override
  String get comNewEntry => 'Nouvelle entrée';

  @override
  String get comSaveEntry => 'Enregistrer l\'entrée';

  @override
  String get comNewExit => 'Nouvelle sortie';

  @override
  String get comConfirmExit => 'Confirmer la sortie';

  @override
  String get comTransferStock => 'Transférer du stock';

  @override
  String get comConfirmTransfer => 'Confirmer le transfert';

  @override
  String get comInventory => 'Inventaire';

  @override
  String get comValidateInventory => 'Valider l\'inventaire';

  @override
  String get comConfirmExitTitle => 'Confirmer la sortie ?';

  @override
  String get comConfirmTransferTitle => 'Confirmer le transfert ?';

  @override
  String get comConfirmInventoryTitle => 'Valider l\'inventaire ?';

  @override
  String comCurrentStock(String quantite) {
    return 'Stock actuel : $quantite';
  }

  @override
  String get comHowMany => 'Combien ?';

  @override
  String get comCountedQuantity => 'Combien en avez-vous compté ?';

  @override
  String get comWhy => 'Pourquoi cet écart ?';

  @override
  String get comReason => 'Motif';

  @override
  String get comNoteOptional => 'Note (facultatif)';

  @override
  String get comAddNote => 'Ajouter une note';

  @override
  String get comStockPreview => 'Votre stock';

  @override
  String comStockInsufficientInline(String disponible) {
    return 'Stock insuffisant · Disponible : $disponible';
  }

  @override
  String get comInventoryNoGap => 'Aucun écart : le stock est juste';

  @override
  String comInventoryGap(String ecart) {
    return 'Écart : $ecart';
  }

  @override
  String get comStockUpdated => 'Stock mis à jour';

  @override
  String comTransferDone(String quantite, String boutique) {
    return '$quantite transférés vers $boutique';
  }

  @override
  String get comReasonPurchase => 'Achat';

  @override
  String get comReasonReturn => 'Retour';

  @override
  String get comReasonAdjustment => 'Ajustement';

  @override
  String get comReasonSale => 'Vente';

  @override
  String get comReasonLoss => 'Perte';

  @override
  String get comReasonBreakage => 'Casse';

  @override
  String get comReasonTransfer => 'Transfert';

  @override
  String get comReasonCountError => 'Erreur de comptage';

  @override
  String get comReasonMissing => 'Produit manquant';

  @override
  String get comReasonOther => 'Autre';

  @override
  String ruleStockInsufficient(String disponible) {
    return 'Stock insuffisant : il reste $disponible.';
  }

  @override
  String get ruleQuantityInvalid => 'La quantité doit être supérieure à zéro.';

  @override
  String ruleFractionInvalid(String pas, String unite) {
    return 'Quantité non valable : ce produit se vend par $pas $unite.';
  }

  @override
  String get ruleUnitInvalid =>
      'Vérifiez les unités : chaque unité a un nom différent et contient au moins une unité de base.';

  @override
  String get ruleBarcodeExists =>
      'Ce code-barres est déjà utilisé par un autre produit.';

  @override
  String get ruleTransferSameShop => 'Choisissez deux boutiques différentes.';

  @override
  String get ruleShopRequired => 'Choisissez la boutique.';

  @override
  String get ruleLinesInvalid =>
      'Ajoutez au moins un produit avec une quantité.';

  @override
  String ruleReceptionAbove(String reste) {
    return 'Impossible de recevoir plus que commandé (reste : $reste).';
  }

  @override
  String get rulePurchaseReceived =>
      'Cet achat a déjà été reçu : il ne peut plus être modifié ni annulé.';

  @override
  String get rulePurchasePaid =>
      'Cet achat est déjà payé : annulez d\'abord le paiement.';

  @override
  String get rulePurchaseCancelled => 'Cet achat est annulé.';

  @override
  String get ruleSaleCancelled => 'Cette vente est déjà annulée.';

  @override
  String get ruleSalePaid =>
      'Cette vente est encaissée : annulez d\'abord le paiement dans Finances.';

  @override
  String get ruleCustomerRequired =>
      'Pour une vente à crédit, choisissez le client.';

  @override
  String get comProductsTitle => 'Produits';

  @override
  String get comCategories => 'Catégories';

  @override
  String get comManageCategories => 'Gérer les catégories';

  @override
  String get comGridView => 'Affichage en grille';

  @override
  String get comListView => 'Affichage en liste';

  @override
  String get comEmptyProductsTitle => 'Aucun produit';

  @override
  String get comEmptyProductsMessage =>
      'Ajoutez vos produits pour commencer à gérer votre stock et vos ventes.';

  @override
  String comProductsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits',
      one: '1 produit',
      zero: 'Aucun produit',
    );
    return '$_temp0';
  }

  @override
  String comNoProductInCategory(String categorie) {
    return 'Aucun produit dans $categorie';
  }

  @override
  String get comAddProductHere => 'Ajouter un produit ici';

  @override
  String get comSeeProduct => 'Voir';

  @override
  String get comAddToStock => '+ Stock';

  @override
  String get comSell => 'Vendre';

  @override
  String get comCreateProduct => 'Créer le produit';

  @override
  String get comBarcodeUnknownHint =>
      'Voulez-vous créer un produit avec ce code ?';

  @override
  String get comArchived => 'Archivé';

  @override
  String get comShowArchived => 'Produits archivés';

  @override
  String get comSortBy => 'Trier';

  @override
  String get comSortName => 'Nom';

  @override
  String get comSortStock => 'Stock le plus bas';

  @override
  String get comSortPrice => 'Prix';

  @override
  String get comSortBestSellers => 'Plus vendus';

  @override
  String get comNewProduct => 'Nouveau produit';

  @override
  String get comEditProduct => 'Modifier le produit';

  @override
  String get comStepIdentity => 'Le produit';

  @override
  String get comStepUnits => 'Unités et prix';

  @override
  String get comStepStock => 'Stock';

  @override
  String get comStepOptions => 'Plus d\'options';

  @override
  String comStepOf(int etape, int total) {
    return 'Étape $etape sur $total';
  }

  @override
  String get comNext => 'Suivant';

  @override
  String get comPrevious => 'Précédent';

  @override
  String get comSaveProduct => 'Enregistrer le produit';

  @override
  String get comProductSaved => 'Produit enregistré';

  @override
  String get comAddPhoto => 'Ajouter une photo';

  @override
  String get comTakePhoto => 'Prendre une photo';

  @override
  String get comChooseFromGallery => 'Choisir dans la galerie';

  @override
  String get comPhotoHint =>
      'Une photo aide vos vendeurs à reconnaître le produit.';

  @override
  String get comMainPhoto => 'Photo principale';

  @override
  String get comSetMainPhoto => 'Mettre en premier';

  @override
  String get comRemovePhoto => 'Retirer la photo';

  @override
  String get comProductName => 'Nom du produit';

  @override
  String get comProductNameHint => 'Ex. : Carreau 40×40';

  @override
  String get comNameRequired => 'Donnez un nom au produit';

  @override
  String get comCategory => 'Catégorie';

  @override
  String get comSubCategory => 'Sous-catégorie';

  @override
  String get comNoCategory => 'Sans catégorie';

  @override
  String get comNewCategory => 'Nouvelle catégorie';

  @override
  String get comNewSubCategory => 'Nouvelle sous-catégorie';

  @override
  String get comCategoryName => 'Nom de la catégorie';

  @override
  String get comReference => 'Référence (facultatif)';

  @override
  String get comBarcode => 'Code-barres (facultatif)';

  @override
  String get comCountedIn => 'Je compte ce produit en…';

  @override
  String get comOtherUnit => 'Autre…';

  @override
  String get comUnitName => 'Nom de l\'unité';

  @override
  String get comUnitNameHint => 'Ex. : botte, seau, fût';

  @override
  String get comSalePrice => 'Prix de vente';

  @override
  String comSalePricePer(String unite) {
    return 'Prix de vente par $unite';
  }

  @override
  String comWholesalePricePer(String unite) {
    return 'Prix de gros par $unite';
  }

  @override
  String comPurchasePricePer(String unite) {
    return 'Prix d\'achat par $unite (facultatif)';
  }

  @override
  String get comSellWholesale => 'Je vends aussi en gros';

  @override
  String get comRetail => 'Détail';

  @override
  String get comWholesale => 'Gros';

  @override
  String get comPurchase => 'Achat';

  @override
  String get comPackagings => 'Emballages';

  @override
  String get comPackagingsHint =>
      'Vous achetez ou vendez par carton, paquet, sac… ? Ajoutez-les : l\'application fera les calculs.';

  @override
  String get comAddPackaging => 'Ajouter un emballage';

  @override
  String get comCopyUnits => 'Copier d\'un autre produit';

  @override
  String comOneUnitContains(String unite) {
    return '1 $unite contient';
  }

  @override
  String get comContains => 'contient';

  @override
  String comFactorRequired(String unite) {
    return 'Combien de $unite ?';
  }

  @override
  String get comCalculated => 'calculé';

  @override
  String get comPriceSetByYou => 'prix fixé par vous';

  @override
  String comDiscountOf(String pourcent) {
    return 'remise de $pourcent %';
  }

  @override
  String comMarkupOf(String pourcent) {
    return '$pourcent % plus cher que le détail';
  }

  @override
  String get comPriceHigherWarning =>
      'Attention : ce lot coûte plus cher que les unités vendues séparément.';

  @override
  String get comBackToCalculated => 'Revenir au prix calculé';

  @override
  String comProfitPer(String montant, String unite) {
    return 'Bénéfice : $montant par $unite';
  }

  @override
  String get comUnitsSummary => 'Résumé';

  @override
  String get comInitialStock => 'Stock de départ';

  @override
  String get comInitialStockHint =>
      'Combien en avez-vous aujourd\'hui ? (facultatif)';

  @override
  String get comInitialStockNote => 'Stock de départ';

  @override
  String get comAlertThreshold => 'Prévenez-moi quand il reste moins de…';

  @override
  String get comAlertThresholdHint => 'Le produit passera en « Stock faible ».';

  @override
  String get comSellFractions => 'Vente au détail en morceaux';

  @override
  String get comSellFractionsHint => 'Ex. : ½ bidon, 2,5 mètres, 0,25 kg';

  @override
  String get comMinimumStep => 'Plus petite quantité vendue';

  @override
  String get comCharacteristics => 'Caractéristiques';

  @override
  String get comAddCharacteristic => 'Ajouter une caractéristique';

  @override
  String get comCharacteristicName => 'Nom (ex. : garantie)';

  @override
  String get comMainSupplier => 'Fournisseur principal';

  @override
  String get comChooseSupplier => 'Choisir un fournisseur';

  @override
  String get comDescription => 'Description (facultatif)';

  @override
  String get comNone => 'Aucun';

  @override
  String get comAttrMarque => 'Marque';

  @override
  String get comAttrModele => 'Modèle';

  @override
  String get comAttrCouleur => 'Couleur';

  @override
  String get comAttrDimensions => 'Dimensions';

  @override
  String get comAttrFinition => 'Finition';

  @override
  String get comAttrVolume => 'Volume';

  @override
  String get comAttrType => 'Type';

  @override
  String get comAttrSection => 'Section';

  @override
  String get comAttrLongueur => 'Longueur';

  @override
  String get comAttrTaille => 'Taille';

  @override
  String get comAttrPoids => 'Poids';

  @override
  String get comAttrEmplacement => 'Emplacement';

  @override
  String get comUnitPiece => 'Pièce';

  @override
  String get comUnitCarton => 'Carton';

  @override
  String get comUnitPaquet => 'Paquet';

  @override
  String get comUnitSac => 'Sac';

  @override
  String get comUnitBidon => 'Bidon';

  @override
  String get comUnitBouteille => 'Bouteille';

  @override
  String get comUnitSachet => 'Sachet';

  @override
  String get comUnitBoite => 'Boîte';

  @override
  String get comUnitRouleau => 'Rouleau';

  @override
  String get comUnitMetre => 'Mètre';

  @override
  String get comUnitKg => 'Kg';

  @override
  String get comUnitLitre => 'Litre';

  @override
  String get comUnitDouzaine => 'Douzaine';

  @override
  String get comUnitLot => 'Lot';

  @override
  String get comUnitPalette => 'Palette';

  @override
  String get comUnitTonne => 'Tonne';

  @override
  String get comProductNotFound => 'Ce produit n\'existe plus.';

  @override
  String get comChooseCustomer => 'Choisir un client';

  @override
  String get comNewSupplier => 'Nouveau fournisseur';

  @override
  String get comNewCustomer => 'Nouveau client';

  @override
  String get comSearchContact => 'Nom ou téléphone…';

  @override
  String get comNoContact => 'Aucun contact trouvé';

  @override
  String get comStockCard => 'Stock';

  @override
  String get comDistribution => 'Répartition';

  @override
  String get comEntry => 'Entrée';

  @override
  String get comExit => 'Sortie';

  @override
  String get comTransfer => 'Transfert';

  @override
  String get comBuy => 'Acheter';

  @override
  String get comPricesAndUnits => 'Prix et unités';

  @override
  String get comUnit => 'Unité';

  @override
  String get comProfit => 'Bénéfice';

  @override
  String get comLastMovements => 'Derniers mouvements';

  @override
  String get comSeeAll => 'Tout voir';

  @override
  String get comNoMovement => 'Aucun mouvement pour le moment';

  @override
  String get comSuppliers => 'Fournisseurs';

  @override
  String get comArchive => 'Archiver';

  @override
  String get comRestore => 'Réactiver';

  @override
  String get comArchiveConfirm =>
      'Archiver ce produit ? Il ne sera plus proposé à la vente ni à l\'achat. Son historique est conservé.';

  @override
  String get comBarcodeShort => 'Code-barres';

  @override
  String get comReferenceShort => 'Référence';

  @override
  String comMinimumAlert(String quantite) {
    return 'Alerte sous $quantite';
  }

  @override
  String get comToCheck => 'Stock à vérifier';

  @override
  String get comPendingSend => 'En attente d\'envoi';

  @override
  String get comCategoriesTitle => 'Catégories';

  @override
  String get comCategoriesEmptyTitle => 'Organisez vos produits';

  @override
  String get comCategoriesEmptyMessage =>
      'Choisissez un modèle adapté à votre commerce, ou créez vos propres catégories.';

  @override
  String get comUseTemplate => 'Utiliser un modèle';

  @override
  String get comChooseSector => 'Quel est votre commerce ?';

  @override
  String get comTemplateApplied => 'Catégories créées';

  @override
  String get comAddSubCategory => 'Ajouter une sous-catégorie';

  @override
  String get comDisable => 'Masquer';

  @override
  String get comEnable => 'Afficher';

  @override
  String get comSectorHardware => 'Quincaillerie';

  @override
  String get comSectorGrocery => 'Boutique / alimentation';

  @override
  String get comSectorSupermarket => 'Supermarché';

  @override
  String get comSectorTextile => 'Vêtements et chaussures';

  @override
  String get comSectorCosmetics => 'Cosmétique';

  @override
  String get comSectorElectronics => 'Téléphonie et électronique';

  @override
  String get comCatOutils => 'Outils';

  @override
  String get comCatMateriaux => 'Matériaux';

  @override
  String get comCatPeinture => 'Peinture';

  @override
  String get comCatPeintureInterieur => 'Intérieur';

  @override
  String get comCatPeintureExterieur => 'Extérieur';

  @override
  String get comCatPeinturePrimaire => 'Primaire';

  @override
  String get comCatPeintureVernis => 'Vernis';

  @override
  String get comCatPlomberie => 'Plomberie';

  @override
  String get comCatElectricite => 'Électricité';

  @override
  String get comCatVisserie => 'Visserie';

  @override
  String get comCatMenuiserie => 'Menuiserie';

  @override
  String get comCatAccessoires => 'Accessoires';

  @override
  String get comCatCarrelage => 'Carrelage';

  @override
  String get comCatBoissons => 'Boissons';

  @override
  String get comCatEpicerie => 'Épicerie';

  @override
  String get comCatFrais => 'Produits frais';

  @override
  String get comCatBoulangerie => 'Boulangerie';

  @override
  String get comCatHygiene => 'Hygiène';

  @override
  String get comCatMenage => 'Entretien de la maison';

  @override
  String get comCatCosmetique => 'Beauté';

  @override
  String get comCatVetements => 'Vêtements';

  @override
  String get comCatChaussures => 'Chaussures';

  @override
  String get comCatTelephonie => 'Téléphones';

  @override
  String get comCatElectronique => 'Électronique';

  @override
  String get comCatPapeterie => 'Papeterie';

  @override
  String get comMovementsTitle => 'Mouvements';

  @override
  String get comFamilyAll => 'Tous';

  @override
  String get comFamilyEntries => 'Entrées';

  @override
  String get comFamilyExits => 'Sorties';

  @override
  String get comFamilyTransfers => 'Transferts';

  @override
  String get comFamilyAdjustments => 'Ajustements';

  @override
  String get comFamilyLosses => 'Pertes';

  @override
  String get comToday => 'Aujourd\'hui';

  @override
  String get comYesterday => 'Hier';

  @override
  String comBy(String nom) {
    return 'par $nom';
  }

  @override
  String get comTypeEntry => 'Entrée';

  @override
  String get comTypeExit => 'Sortie';

  @override
  String get comTypeTransferOut => 'Transfert envoyé';

  @override
  String get comTypeTransferIn => 'Transfert reçu';

  @override
  String get comTypeInventory => 'Inventaire';

  @override
  String get comMovementRejected => 'Refusé par le serveur';

  @override
  String get comEmptyMovementsTitle => 'Aucun mouvement';

  @override
  String get comEmptyMovementsMessage =>
      'Les entrées, sorties et transferts apparaîtront ici.';

  @override
  String get comRemoveRejected => 'Retirer';

  @override
  String get comPeriodAll => 'Toutes les dates';

  @override
  String get comPeriodToday => 'Aujourd\'hui';

  @override
  String get comPeriodWeek => '7 derniers jours';

  @override
  String get comPeriodMonth => '30 derniers jours';

  @override
  String get comStockTitle => 'Stock';

  @override
  String get comStockSubtitle =>
      'Suivez vos produits, vos quantités et vos mouvements.';

  @override
  String get comKpiProducts => 'Produits';

  @override
  String get comKpiLow => 'Stock faible';

  @override
  String get comKpiOut => 'Ruptures';

  @override
  String get comKpiMovesToday => 'Mouvements du jour';

  @override
  String get comOrder => 'Commander';

  @override
  String get comStockEmptyTitle => 'Votre stock est encore vide';

  @override
  String get comStockEmptyMessage =>
      'Commencez par ajouter votre premier produit.';

  @override
  String get comNothingToReport => 'Rien à signaler : tout est en stock.';

  @override
  String get comToWatch => 'À surveiller';

  @override
  String get comSeeMovements => 'Voir les mouvements';

  @override
  String get comStockActions => 'Que voulez-vous faire ?';

  @override
  String comWatchLow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits en stock faible',
      one: '1 produit en stock faible',
    );
    return '$_temp0';
  }

  @override
  String comWatchOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits en rupture',
      one: '1 produit en rupture',
    );
    return '$_temp0';
  }

  @override
  String get comPurchasesTitle => 'Achats';

  @override
  String get comNewPurchase => 'Nouvel achat';

  @override
  String get comEditPurchase => 'Modifier l\'achat';

  @override
  String get comPurchaseEmptyTitle => 'Aucun achat';

  @override
  String get comPurchaseEmptyMessage =>
      'Enregistrez vos achats chez vos fournisseurs : le stock augmente à la réception.';

  @override
  String get comFilterToReceive => 'À recevoir';

  @override
  String get comFilterReceived => 'Reçus';

  @override
  String get comFilterCancelled => 'Annulés';

  @override
  String get comStatusOrdered => 'Commandé';

  @override
  String get comStatusPartlyReceived => 'Reçu en partie';

  @override
  String get comStatusReceived => 'Reçu';

  @override
  String get comStatusCancelled => 'Annulé';

  @override
  String get comSupplier => 'Fournisseur';

  @override
  String get comNoSupplierChosen => 'Choisir le fournisseur (facultatif)';

  @override
  String get comPurchaseDate => 'Date';

  @override
  String get comSupplierReference => 'N° de facture / bon (facultatif)';

  @override
  String get comProducts => 'Produits';

  @override
  String get comAddLine => 'Ajouter un produit';

  @override
  String comUnitPrice(String unite) {
    return 'Prix par $unite';
  }

  @override
  String comLastPrice(String montant) {
    return 'Dernier prix : $montant';
  }

  @override
  String get comTotal => 'Total';

  @override
  String get comSave => 'Enregistrer';

  @override
  String get comSaveAndReceive => 'Enregistrer et réceptionner';

  @override
  String get comPurchaseSaved => 'Achat enregistré';

  @override
  String get comReceive => 'Réceptionner';

  @override
  String get comReceiveTitle => 'Réception de la marchandise';

  @override
  String get comReceivedToday => 'Reçu aujourd\'hui';

  @override
  String get comOrdered => 'Commandé';

  @override
  String get comAlreadyReceived => 'Déjà reçu';

  @override
  String get comRemaining => 'Reste';

  @override
  String get comReceiveAll => 'Tout reçu';

  @override
  String get comNothingReceived => 'Rien';

  @override
  String get comConfirmReception => 'Valider la réception';

  @override
  String get comReceptionDone => 'Marchandise reçue : stock mis à jour';

  @override
  String get comStockImpact => 'Effet sur le stock';

  @override
  String get comReceptions => 'Réceptions';

  @override
  String get comCancelPurchase => 'Annuler l\'achat';

  @override
  String get comCancelPurchaseConfirm =>
      'Annuler cet achat ? La dette fournisseur sera annulée.';

  @override
  String get comDebt => 'Reste à payer';

  @override
  String get comPaid => 'Payé';

  @override
  String get comPaySupplier => 'Payer le fournisseur';

  @override
  String get comFullyPaid => 'Entièrement payé';

  @override
  String comLinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits',
      one: '1 produit',
    );
    return '$_temp0';
  }

  @override
  String comPurchaseOf(String date) {
    return 'Achat du $date';
  }

  @override
  String get comNoSupplier => 'Sans fournisseur';

  @override
  String get comEditLine => 'Modifier la ligne';

  @override
  String get comRemoveLine => 'Retirer';

  @override
  String get comApply => 'Valider';

  @override
  String get comSuppliersTitle => 'Fournisseurs';

  @override
  String get comSuppliersEmptyTitle => 'Aucun fournisseur';

  @override
  String get comSuppliersEmptyMessage =>
      'Ajoutez les personnes ou sociétés auprès de qui vous achetez.';

  @override
  String get comAddSupplier => 'Ajouter un fournisseur';

  @override
  String get comTotalBought => 'Total acheté';

  @override
  String get comLastPurchase => 'Dernier achat';

  @override
  String get comSuppliedProducts => 'Produits fournis';

  @override
  String get comPurchaseHistory => 'Historique des achats';

  @override
  String get comCall => 'Appeler';

  @override
  String get comOpenContact => 'Fiche contact';

  @override
  String get comNeverBought => 'Aucun achat pour le moment';

  @override
  String comPurchasesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count achats',
      one: '1 achat',
      zero: 'Aucun achat',
    );
    return '$_temp0';
  }

  @override
  String get comSalesTitle => 'Vendre';

  @override
  String get comSalesHistory => 'Ventes';

  @override
  String get comCart => 'Panier';

  @override
  String get comCartEmpty => 'Touchez un produit pour l\'ajouter au panier.';

  @override
  String comCartCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String get comCheckout => 'Encaisser';

  @override
  String get comBestSellers => 'Plus vendus';

  @override
  String get comPayment => 'Paiement';

  @override
  String get comPayNow => 'Payé maintenant';

  @override
  String get comOnCredit => 'À crédit';

  @override
  String get comCustomer => 'Client';

  @override
  String get comCustomerOptional => 'Client (facultatif)';

  @override
  String get comDiscount => 'Remise';

  @override
  String get comToPay => 'À payer';

  @override
  String comSaleDone(String montant) {
    return 'Vente enregistrée : $montant';
  }

  @override
  String get comConfirmSale => 'Valider la vente';

  @override
  String get comCashOpen => 'L\'argent entre dans la caisse ouverte.';

  @override
  String get comNoCashOpen =>
      'Aucune caisse ouverte : le paiement est enregistré sans caisse.';

  @override
  String comAvailable(String quantite) {
    return 'Disponible : $quantite';
  }

  @override
  String get comSalesEmptyTitle => 'Aucune vente';

  @override
  String get comSalesEmptyMessage => 'Vos ventes apparaîtront ici.';

  @override
  String comSaleOf(String date) {
    return 'Vente du $date';
  }

  @override
  String get comCancelSale => 'Annuler la vente';

  @override
  String get comCancelSaleConfirm =>
      'Annuler cette vente ? Les produits reviennent en stock.';

  @override
  String get comCancelReason => 'Motif (facultatif)';

  @override
  String get comSaleCancelledDone => 'Vente annulée';

  @override
  String get comCancelled => 'Annulée';

  @override
  String get comSalesToday => 'Ventes du jour';

  @override
  String get comNoShopAllowed => 'Vous n\'avez pas de boutique pour vendre.';

  @override
  String get comClearCart => 'Vider le panier';

  @override
  String get comChangeUnit => 'Quantité et unité';

  @override
  String get comPrice => 'Prix';

  @override
  String get comSeller => 'Vendeur';

  @override
  String get comNewSale => 'Nouvelle vente';

  @override
  String get comStepProductUnits => 'Produit et unités';

  @override
  String get comStepPricesStock => 'Prix et stock';

  @override
  String get comProductInfo => 'Le produit';

  @override
  String get comProductInfoHint =>
      'Une photo et un nom clair aident vos vendeurs à le reconnaître.';

  @override
  String get comPhotoShort => 'Photo';

  @override
  String get comHowCounted => 'Comment comptez-vous ce produit ?';

  @override
  String get comHowCountedHint =>
      'Choisissez la plus petite quantité que vous vendez : une pièce, un sac, un litre…';

  @override
  String get comPackagingTitle =>
      'Vendez-vous aussi par carton, paquet, sac… ?';

  @override
  String get comPackagingHint2 =>
      'Ajoutez l\'emballage et ce qu\'il contient : les prix et le stock seront calculés pour vous.';

  @override
  String get comPackagingName => 'Nom de l\'emballage';

  @override
  String comPackagingContains(String unite) {
    return 'Nombre de $unite dans 1 emballage';
  }

  @override
  String get comRetailPrice => 'Prix de vente au détail';

  @override
  String get comRetailPriceHint =>
      'Le prix habituel pour un client. Choisissez l\'unité de ce prix.';

  @override
  String get comWholesalePrice => 'Prix de vente en gros';

  @override
  String get comWholesalePriceHint =>
      'Le prix pour les gros acheteurs, souvent par carton.';

  @override
  String get comPurchasePrice => 'Prix d\'achat (facultatif)';

  @override
  String get comPurchasePriceHint =>
      'Ce que vous payez au fournisseur : pour voir votre bénéfice.';

  @override
  String get comPricePer => 'Prix pour 1 :';

  @override
  String comEquivalentPrice(String montant, String unite) {
    return 'Soit $montant par $unite';
  }

  @override
  String get comPriceSummary => 'Vos prix, calculés pour chaque unité';

  @override
  String get comAmountHint => 'Montant';

  @override
  String get comSaveChanges => 'Enregistrer les modifications';

  @override
  String get comStockAndAlert => 'Stock et alerte';

  @override
  String get comSupplierNone => 'Aucun fournisseur choisi';

  @override
  String get comReferenceHint => 'Ex. : CAR-0012';

  @override
  String get comGenerateReference => 'Proposer une référence';

  @override
  String get comChooseCategory => 'Choisir une catégorie';

  @override
  String get comBarcodeLabel => 'Code-barres';

  @override
  String get comBarcodeHint => 'Scannez ou tapez le code (facultatif)';

  @override
  String get comUnitPieceHelp => 'Ex. : carreau, ampoule';

  @override
  String get rcpTitle => 'Reçus';

  @override
  String get rcpSaleReceipt => 'REÇU DE VENTE';

  @override
  String get rcpNumberPending => 'Numéro attribué à la synchronisation';

  @override
  String get rcpSaleSaved => 'Vente enregistrée';

  @override
  String get rcpView => 'Voir le reçu';

  @override
  String get rcpShare => 'Partager';

  @override
  String get rcpPrint => 'Imprimer';

  @override
  String get rcpPdf => 'PDF';

  @override
  String get rcpNewSale => 'Nouvelle vente';

  @override
  String get rcpCounterCustomer => 'Client comptoir';

  @override
  String get rcpSelectCustomer => 'Sélectionner';

  @override
  String get rcpAddName => 'Ajouter un nom';

  @override
  String get rcpCustomerName => 'Nom du client';

  @override
  String get rcpPhoneOptional => 'Téléphone (facultatif)';

  @override
  String get rcpCreditNeedsCustomer =>
      'Vente à crédit : choisissez ou ajoutez le client.';

  @override
  String get rcpDeposit => 'Payé maintenant (facultatif)';

  @override
  String get rcpDepositHint =>
      'Laissez vide si le client ne paie rien aujourd\'hui.';

  @override
  String get rcpSubtotal => 'Sous-total';

  @override
  String get rcpPaid => 'Montant payé';

  @override
  String get rcpRemaining => 'Reste';

  @override
  String get rcpRemainingToPay => 'RESTE À PAYER';

  @override
  String get rcpShop => 'Boutique';

  @override
  String get rcpDate => 'Date';

  @override
  String get rcpTime => 'Heure';

  @override
  String get rcpThanks => 'Merci pour votre confiance.';

  @override
  String get rcpTagline => 'La gestion simple de votre activité';

  @override
  String get rcpProduct => 'Produit';

  @override
  String get rcpQty => 'Qté';

  @override
  String get rcpPrice => 'Prix';

  @override
  String get rcpLineTotal => 'Total';

  @override
  String get rcpStatus => 'Statut';

  @override
  String get rcpStatusValid => 'Validé';

  @override
  String get rcpStatusCancelled => 'Annulé';

  @override
  String get rcpStatusCredit => 'À crédit';

  @override
  String get rcpStatusPartial => 'Partiellement payé';

  @override
  String get rcpCancelledStamp => 'ANNULÉ';

  @override
  String rcpCancelledInfo(String date, String nom) {
    return 'Annulé le $date par $nom';
  }

  @override
  String get rcpEmptyTitle => 'Aucun reçu pour le moment';

  @override
  String get rcpEmptyMessage =>
      'Vos reçus apparaîtront ici après vos premières ventes.';

  @override
  String get rcpCreateSale => 'Créer une vente';

  @override
  String get rcpNoResultTitle => 'Aucun reçu trouvé';

  @override
  String get rcpNoResultMessage => 'Essayez un autre numéro, client ou date.';

  @override
  String get rcpSearchHint => 'N° de reçu, client, téléphone, produit…';

  @override
  String get rcpPeriodToday => 'Aujourd\'hui';

  @override
  String get rcpPeriodYesterday => 'Hier';

  @override
  String get rcpPeriodWeek => 'Cette semaine';

  @override
  String get rcpPeriodMonth => 'Ce mois';

  @override
  String get rcpPeriodCustom => 'Période…';

  @override
  String get rcpPeriodAll => 'Tout';

  @override
  String get rcpAllSellers => 'Tous les vendeurs';

  @override
  String get rcpAllPayments => 'Tous les paiements';

  @override
  String get rcpAllStatuses => 'Tous les statuts';

  @override
  String get rcpCredit => 'Crédit';

  @override
  String get rcpSales => 'Ventes';

  @override
  String get rcpShops => 'Boutiques';

  @override
  String get rcpLatest => 'Dernières ventes';

  @override
  String get rcpSeeAll => 'Voir tous les reçus';

  @override
  String get rcpFilters => 'Filtres';

  @override
  String get rcpReset => 'Effacer les filtres';

  @override
  String get rcpTraceability => 'Historique';

  @override
  String rcpCreatedBy(String nom) {
    return 'Vente enregistrée par $nom';
  }

  @override
  String get rcpOnDevice => 'Enregistrée sur l\'appareil, en attente d\'envoi';

  @override
  String rcpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reçus',
      one: '1 reçu',
      zero: 'Aucun reçu',
    );
    return '$_temp0';
  }

  @override
  String get expenseCatFuel => 'Carburant';

  @override
  String get expenseCatWater => 'Eau';

  @override
  String get expenseCatInternet => 'Téléphone et internet';

  @override
  String get expenseCatRepair => 'Réparation';

  @override
  String get expenseCatCleaning => 'Nettoyage';

  @override
  String get expenseCatSecurity => 'Gardiennage';

  @override
  String get expenseCatDelivery => 'Livraison';

  @override
  String get expenseCatBankFees => 'Frais bancaires';

  @override
  String get expenseCatInsurance => 'Assurance';

  @override
  String get cashNatureContribution => 'Apport';

  @override
  String get cashNatureWithdrawal => 'Retrait';

  @override
  String get cashNatureTransfer => 'Transfert';

  @override
  String get cashNatureRefund => 'Remboursement';

  @override
  String get cashNatureAdjustment => 'Ajustement';

  @override
  String get cashNatureOpeningBalance => 'Solde initial';

  @override
  String get cashNatureOther => 'Autre';

  @override
  String get cashGapReasonChange => 'Erreur de rendu monnaie';

  @override
  String get cashGapReasonUnrecorded => 'Dépense non enregistrée';

  @override
  String get cashGapReasonCounting => 'Erreur de comptage';

  @override
  String get cashGapReasonOther => 'Autre';

  @override
  String cashGapJustify(String amount) {
    return 'Un écart de $amount a été constaté. Indiquez sa cause.';
  }

  @override
  String get cashGapNoteRequired => 'Justification (obligatoire)';

  @override
  String get cashOperationReason => 'Motif';

  @override
  String get cashTransferTitle => 'Transfert';

  @override
  String get cashTransferFrom => 'Depuis';

  @override
  String get cashTransferTo => 'Vers';

  @override
  String get cashTransferSame =>
      'La source et la destination doivent être différentes.';

  @override
  String get cashTransferDone => 'Transfert enregistré';

  @override
  String get cashTransferCancel => 'Annuler le transfert';

  @override
  String get cashCompanyLevel => 'Entreprise (sans boutique)';

  @override
  String get cashIn => 'Entrée d\'argent';

  @override
  String get cashOut => 'Sortie d\'argent';

  @override
  String get cashSite => 'Boutique / site';

  @override
  String get cashScreenSubtitle =>
      'Suivez vos entrées, vos sorties et votre solde.';

  @override
  String get cashAllShops => 'Toutes les boutiques';

  @override
  String get cashAvailable => 'Solde disponible';

  @override
  String get cashShowAmounts => 'Afficher les montants';

  @override
  String get cashHideAmounts => 'Masquer les montants';

  @override
  String get cashCashOnHand => 'Espèces en caisse';

  @override
  String get cashIncoming => 'Entrées';

  @override
  String get cashOutgoing => 'Sorties';

  @override
  String get cashNet => 'Variation';

  @override
  String cashOperationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opérations',
      one: '1 opération',
      zero: 'Aucune opération',
    );
    return '$_temp0';
  }

  @override
  String get cashAddOperation => 'Ajouter une opération';

  @override
  String get cashBalanceTrend => 'Évolution du solde';

  @override
  String get cashInBreakdown => 'D\'où vient l\'argent';

  @override
  String get cashOutBreakdown => 'Où part l\'argent';

  @override
  String get cashByMode => 'Moyens d\'argent';

  @override
  String get cashComparison => 'Comparaison';

  @override
  String get cashPreviousPeriod => 'Période précédente';

  @override
  String get cashByShop => 'Par boutique';

  @override
  String get cashOperationsHistory => 'Opérations';

  @override
  String get cashSearchHint => 'Rechercher une opération…';

  @override
  String get cashFilterAll => 'Tout';

  @override
  String get cashReadyTitle => 'Votre caisse est prête';

  @override
  String get cashReadyMessage =>
      'Les ventes, paiements et dépenses apparaîtront automatiquement ici.';

  @override
  String get cashNoDataPeriod => 'Aucune donnée pour cette période.';

  @override
  String get cashBalanced => 'Équilibrée';

  @override
  String get cashGapLarge => 'Écart important';

  @override
  String get periodToday => 'Aujourd\'hui';

  @override
  String get periodYesterday => 'Hier';

  @override
  String get periodThisWeek => 'Cette semaine';

  @override
  String get periodThisMonth => 'Ce mois';

  @override
  String get periodThisYear => 'Cette année';

  @override
  String get periodAll => 'Tout';

  @override
  String get periodCustom => 'Personnalisé';

  @override
  String get period7Days => '7 j';

  @override
  String get period30Days => '30 j';

  @override
  String get period3Months => '3 mois';

  @override
  String get cashSrcSale => 'Vente';

  @override
  String get cashSrcCustomerPayment => 'Paiement client';

  @override
  String get cashSrcService => 'Prestation';

  @override
  String get cashSrcRent => 'Loyer';

  @override
  String get cashSrcPurchase => 'Achat';

  @override
  String get cashSrcSupplierPayment => 'Paiement fournisseur';

  @override
  String get cashSrcExpense => 'Dépense';

  @override
  String cashAlertGap(String amount, String register) {
    return 'Écart de $amount à la dernière clôture de $register.';
  }

  @override
  String cashAlertOutflowsUp(int percent) {
    return 'Sorties en hausse de $percent % par rapport à la semaine précédente.';
  }

  @override
  String get cashDetailDate => 'Date et heure';

  @override
  String get cashDetailSource => 'Source';

  @override
  String get cashDetailReference => 'Référence';

  @override
  String get cashDetailContact => 'Client / fournisseur';

  @override
  String get cashDetailOpen => 'Voir le détail';

  @override
  String get cashCancelOperation => 'Annuler l\'opération';

  @override
  String get cashCancelReason => 'Motif de l\'annulation';

  @override
  String get cashPending => 'En attente d\'envoi';

  @override
  String get financeManage => 'Gérer vos finances';

  @override
  String get periodDay => 'Jour';

  @override
  String get periodMonth => 'Mois';

  @override
  String get periodYear => 'Année';

  @override
  String get periodDates => 'Dates';

  @override
  String get periodPrevious => 'Précédent';

  @override
  String get periodNext => 'Suivant';

  @override
  String get periodChooseDates => 'Choisir les dates';

  @override
  String get expenseTotalPeriod => 'Total de la période';

  @override
  String expensesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dépenses',
      one: '1 dépense',
      zero: 'Aucune dépense',
    );
    return '$_temp0';
  }

  @override
  String get servicesTitle => 'Services & Prestations';

  @override
  String get servicesSubtitle =>
      'La gestion simple de vos interventions et devis';

  @override
  String get prestationsTitle => 'Prestations';

  @override
  String get planningServicesTitle => 'Planning des interventions';

  @override
  String get catalogueServicesTitle => 'Catalogue des prestations';

  @override
  String get devisServicesTitle => 'Devis de services';

  @override
  String get statutAFaire => 'À faire';

  @override
  String get statutPlanifiee => 'Planifiée';

  @override
  String get statutEnCours => 'En cours';

  @override
  String get statutTerminee => 'Terminée';

  @override
  String get statutLivree => 'Livrée';

  @override
  String get statutAnnulee => 'Annulée';

  @override
  String get prioriteFaible => 'Faible / À venir';

  @override
  String get prioriteAttentionJ2 => 'Attention (J-2)';

  @override
  String get prioriteUrgentJ1 => 'Urgent (J-1)';

  @override
  String get prioriteAujourdhui => 'À faire aujourd\'hui';

  @override
  String get prioriteEnRetard => 'En retard';

  @override
  String get nouvellePrestation => 'Nouvelle prestation';

  @override
  String get nouveauDevisService => 'Nouveau devis';

  @override
  String get nouveauServiceCatalogue => 'Nouveau service';

  @override
  String get convertirDevisEnPrestation => 'Convertir en prestation';

  @override
  String get demarrerTravail => 'Démarrer';

  @override
  String get terminerTravail => 'Terminer';

  @override
  String get livrerPrestation => 'Livrer au client';

  @override
  String get reporterEcheance => 'Reporter l\'échéance';

  @override
  String get motifReport => 'Motif du report';

  @override
  String get uniteForfait => 'Forfait';

  @override
  String get uniteHeure => 'Par heure';

  @override
  String get uniteJour => 'Par jour';

  @override
  String get uniteM2 => 'Par m²';

  @override
  String get uniteKm => 'Par km';

  @override
  String get unitePiece => 'Par pièce';

  @override
  String get statutDevisBrouillon => 'Brouillon';

  @override
  String get statutDevisEmis => 'Émis';

  @override
  String get statutDevisAccepte => 'Accepté';

  @override
  String get statutDevisRefuse => 'Refusé';

  @override
  String get statutDevisConverti => 'Converti en prestation';

  @override
  String get rapportsServicesTitle => 'Rapports & Rentabilité Services';

  @override
  String get performanceFinanciere => 'Performance Financière';

  @override
  String get totalFacture => 'Total Facturé';

  @override
  String get totalEncaisse => 'Total Encaissé';

  @override
  String get aRecouvrer => 'À Recouvrer';

  @override
  String get tauxRecouvrement => 'Taux de recouvrement';

  @override
  String get ventilationMainOeuvrePieces => 'Ventilation de la Valeur Facturée';

  @override
  String get mainOeuvre => 'Main d\'œuvre / Prestations';

  @override
  String get piecesStock => 'Pièces stock';

  @override
  String get transformationDevis => 'Transformation Devis';

  @override
  String get bonPriseEnCharge => 'Bon de prise en charge';

  @override
  String get rappelClient => 'Rappeler le client';

  @override
  String get envoyerWhatsApp => 'Envoyer WhatsApp';
}
