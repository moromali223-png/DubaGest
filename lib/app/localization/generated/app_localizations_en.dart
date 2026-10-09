// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DubaGest';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonActive => 'Active';

  @override
  String get commonInactive => 'Inactive';

  @override
  String get commonOptional => 'Optional';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authLoginSubtitle => 'Access your company workspace';

  @override
  String get authEmail => 'Email address';

  @override
  String get authPassword => 'Password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authSignOutPendingTitle => 'Unsynced changes';

  @override
  String authSignOutPendingMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes will be sent',
      one: '1 change will be sent',
    );
    return '$_temp0 the next time you sign in on this device. Sign out anyway?';
  }

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authForgotPasswordTitle => 'Reset password';

  @override
  String get authForgotPasswordHelp =>
      'Enter your email address. You will receive a link to choose a new password.';

  @override
  String get authSendResetLink => 'Send link';

  @override
  String get authResetLinkSent =>
      'If an account exists for this address, an email has been sent.';

  @override
  String get authBackToLogin => 'Back to sign in';

  @override
  String get authChangePassword => 'Change password';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authPasswordChanged => 'Password changed.';

  @override
  String get authSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get validationRequired => 'Required field';

  @override
  String get validationEmail => 'Invalid email address';

  @override
  String validationPasswordLength(int min) {
    return 'At least $min characters';
  }

  @override
  String get validationPasswordsMismatch => 'Passwords do not match';

  @override
  String get errorNetwork => 'Unable to connect. Check your network.';

  @override
  String get errorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get errorEmailNotConfirmed => 'Email address not confirmed.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get errorSessionExpired => 'Your session has expired.';

  @override
  String get errorForbidden => 'You are not allowed to perform this action.';

  @override
  String get errorNotFound => 'Item not found.';

  @override
  String get errorConflict => 'This item was changed by someone else.';

  @override
  String get errorDuplicate => 'An item with this name already exists.';

  @override
  String get errorServer => 'The service is temporarily unavailable.';

  @override
  String get errorLocalStorage => 'Storage error on this device.';

  @override
  String get errorUnknown => 'An unexpected error occurred.';

  @override
  String get ruleSubscriptionInactive =>
      'Your company\'s subscription is not active.';

  @override
  String ruleActivityNotAllowed(String plan) {
    return 'Your $plan plan does not include this activity.';
  }

  @override
  String get ruleActivityInactive =>
      'This activity is not enabled for your company.';

  @override
  String ruleActivitiesLimit(String plan, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max activities',
      one: '1 activity',
    );
    return 'Your $plan plan allows at most $_temp0.';
  }

  @override
  String ruleUsersLimit(String plan, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max users',
      one: '1 user',
    );
    return 'Your $plan plan allows at most $_temp0.';
  }

  @override
  String ruleRoleLimit(String plan, int max, String role) {
    return 'Your $plan plan allows at most $max “$role”.';
  }

  @override
  String rulePerimetresLimit(String plan, int max, String activity) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max sites',
      one: '1 site',
    );
    return 'Your $plan plan allows at most $_temp0 for $activity.';
  }

  @override
  String ruleRoleNotAllowed(String plan) {
    return 'This role is not available with your $plan plan.';
  }

  @override
  String get ruleRoleActivityInactive =>
      'This role requires an activity that is not enabled.';

  @override
  String get ruleModuleNotInPlan => 'This module is not included in your plan.';

  @override
  String get rulePermissionDenied => 'Your role does not allow this action.';

  @override
  String get rulePerimetreDenied => 'You are not assigned to this site.';

  @override
  String get ruleLastAdmin =>
      'The company must keep at least one administrator.';

  @override
  String get ruleAssignmentNotNeeded =>
      'This role already has access to all sites.';

  @override
  String get ruleAssignmentActivityMismatch =>
      'This site does not belong to the role\'s activity.';

  @override
  String get ruleImmutable => 'This information can no longer be changed.';

  @override
  String get contextLoading => 'Preparing your workspace…';

  @override
  String get contextLoadError => 'Unable to load your workspace.';

  @override
  String get contextOfflineCache =>
      'Offline — showing data saved on this device.';

  @override
  String get contextNoEntrepriseTitle => 'No company';

  @override
  String get contextNoEntrepriseMessage =>
      'Your account is not linked to any company. Contact your administrator.';

  @override
  String get contextMemberSuspendedTitle => 'Access suspended';

  @override
  String contextMemberSuspendedMessage(String entreprise) {
    return 'Your access to $entreprise is suspended. Contact your administrator.';
  }

  @override
  String get contextEntrepriseSuspendedTitle => 'Company suspended';

  @override
  String contextEntrepriseSuspendedMessage(String entreprise) {
    return 'Access to $entreprise is temporarily suspended.';
  }

  @override
  String get navHome => 'Home';

  @override
  String get navAdministration => 'Administration';

  @override
  String get navSettings => 'Settings';

  @override
  String homeGreeting(String name) {
    return 'Hello $name';
  }

  @override
  String get homeGreetingAnonymous => 'Hello';

  @override
  String get homeNoModules => 'No module is available for your role.';

  @override
  String get homeSubscriptionInactive =>
      'Modules are unavailable until the subscription is active.';

  @override
  String get moduleComingSoonTitle => 'Coming soon';

  @override
  String get moduleComingSoonMessage =>
      'This module will be available in a future release.';

  @override
  String get accessDeniedTitle => 'Access denied';

  @override
  String get accessDeniedBackHome => 'Back to home';

  @override
  String get activityCommerce => 'Retail';

  @override
  String get activityServices => 'Services';

  @override
  String get activityImmobilier => 'Real estate';

  @override
  String get roleAdministrateur => 'Administrator';

  @override
  String get roleSuperviseur => 'Supervisor';

  @override
  String get roleGestionnaireStock => 'Stock manager';

  @override
  String get roleVendeur => 'Salesperson';

  @override
  String get planNormal => 'Normal';

  @override
  String get planMoyen => 'Medium';

  @override
  String get planPro => 'Pro';

  @override
  String get moduleAdminEntreprise => 'Company';

  @override
  String get moduleAdminUtilisateurs => 'Users';

  @override
  String get moduleAdminPerimetres => 'Shops and sites';

  @override
  String get moduleAdminAbonnement => 'Subscription';

  @override
  String get moduleCommerceProduits => 'Products';

  @override
  String get moduleCommerceStock => 'Stock';

  @override
  String get moduleCommerceVentes => 'Sales';

  @override
  String get moduleCommerceAchats => 'Purchases';

  @override
  String get moduleCommunContacts => 'Contacts';

  @override
  String get moduleCommerceFournisseurs => 'Suppliers';

  @override
  String get moduleFinancesCreances => 'Receivables / Payables';

  @override
  String get moduleFinancesCreancesCourt => 'Debts';

  @override
  String get moduleCommunContactsClients => 'Customers';

  @override
  String get moduleFinancesPaiements => 'Payments';

  @override
  String get moduleFinancesCaisse => 'Cash register';

  @override
  String get moduleFinancesDepenses => 'Expenses';

  @override
  String get moduleServicesServices => 'Catalog';

  @override
  String get moduleServicesPrestations => 'Services';

  @override
  String get moduleServicesPlanning => 'Schedule';

  @override
  String get moduleServicesDevis => 'Quotes';

  @override
  String get moduleServicesFacturation => 'Invoices & Receipts';

  @override
  String get moduleServicesRapports => 'Reports';

  @override
  String get moduleImmobilierBiens => 'Properties';

  @override
  String get moduleImmobilierProprietaires => 'Owners';

  @override
  String get moduleImmobilierLocataires => 'Tenants';

  @override
  String get moduleImmobilierLocations => 'Rentals';

  @override
  String get moduleImmobilierContrats => 'Contracts';

  @override
  String get moduleImmobilierLoyers => 'Rents';

  @override
  String get perimetreTypeBoutique => 'Shop';

  @override
  String get perimetreTypeAgence => 'Agency';

  @override
  String get perimetreTypeSite => 'Site';

  @override
  String get perimetreTypeUnite => 'Unit';

  @override
  String get perimetresEmpty => 'No site yet.';

  @override
  String get perimetreAdd => 'Add';

  @override
  String get perimetreNew => 'New site';

  @override
  String get perimetreEdit => 'Edit site';

  @override
  String get perimetreName => 'Name';

  @override
  String get perimetreCode => 'Code';

  @override
  String get perimetreActivity => 'Activity';

  @override
  String get perimetreType => 'Type';

  @override
  String get perimetreDeleteTitle => 'Delete this site?';

  @override
  String perimetreDeleteMessage(String name) {
    return '“$name” will no longer be accessible.';
  }

  @override
  String get usersEmpty => 'No users.';

  @override
  String get usersInvite => 'Add a user';

  @override
  String get usersInviteComingSoon =>
      'User invitations will be available in a future release.';

  @override
  String get usersYou => 'You';

  @override
  String get usersAssignments => 'Assigned sites';

  @override
  String get usersAllPerimetres => 'All sites';

  @override
  String get usersNoPerimetre => 'No site assigned';

  @override
  String get usersOnlineOnly => 'This action requires a connection.';

  @override
  String get subscriptionPlan => 'Plan';

  @override
  String get subscriptionStatus => 'Status';

  @override
  String get subscriptionStatusEssai => 'Trial';

  @override
  String get subscriptionStatusActif => 'Active';

  @override
  String get subscriptionStatusSuspendu => 'Suspended';

  @override
  String get subscriptionStatusExpire => 'Expired';

  @override
  String get subscriptionStatusAnnule => 'Cancelled';

  @override
  String subscriptionSince(String date) {
    return 'Since $date';
  }

  @override
  String subscriptionUntil(String date) {
    return 'Until $date';
  }

  @override
  String get subscriptionNone => 'No subscription.';

  @override
  String get subscriptionActivities => 'Activities';

  @override
  String get subscriptionUsage => 'Usage';

  @override
  String get subscriptionUsers => 'Users';

  @override
  String subscriptionUsageValue(int used, int max) {
    return '$used / $max';
  }

  @override
  String get entrepriseInfo => 'Details';

  @override
  String get entrepriseName => 'Name';

  @override
  String get entrepriseCountry => 'Country';

  @override
  String get entrepriseCurrency => 'Currency';

  @override
  String get entrepriseRole => 'Your role';

  @override
  String get syncUpToDate => 'Up to date';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending changes',
      one: '1 pending change',
    );
    return '$_temp0';
  }

  @override
  String get syncSyncing => 'Syncing…';

  @override
  String get syncError => 'Sync failed';

  @override
  String get syncOffline => 'Offline';

  @override
  String get syncOfflineBanner =>
      'Offline mode: your changes will be sent when the connection returns.';

  @override
  String syncLastSynced(String time) {
    return 'Last synced: $time';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncRecordPending => 'Waiting to be sent';

  @override
  String get syncRecordError => 'Not synced';

  @override
  String get syncRecordConflict => 'Changed elsewhere — server version kept';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsEntreprise => 'Company';

  @override
  String get settingsSync => 'Synchronization';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get authRegisterTitle => 'Create your account';

  @override
  String get authRegisterSubtitle => 'Free, in less than a minute.';

  @override
  String get authFirstName => 'First name';

  @override
  String get authLastName => 'Last name';

  @override
  String get authCreateAccount => 'Create my account';

  @override
  String get authNoAccount => 'No account yet?';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authSignInLink => 'Sign in';

  @override
  String get authRegisterLink => 'Create an account';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authOr => 'or';

  @override
  String get authCheckEmailTitle => 'Check your email';

  @override
  String authCheckEmailMessage(String email) {
    return 'A confirmation link was sent to $email. Open it, then sign in.';
  }

  @override
  String get authResetPasswordTitle => 'New password';

  @override
  String get errorAccountExists =>
      'This account already exists. Please sign in.';

  @override
  String get errorWeakPassword => 'Password is too weak.';

  @override
  String get errorOauthUnavailable =>
      'Google sign-in is not available right now.';

  @override
  String onboardingWelcome(String name) {
    return 'Welcome $name';
  }

  @override
  String get onboardingWelcomeAnonymous => 'Welcome';

  @override
  String get onboardingQuestion => 'What would you like to do?';

  @override
  String get onboardingCreateTitle => 'Create my company';

  @override
  String get onboardingCreateSubtitle => 'You will be its administrator.';

  @override
  String get onboardingJoinTitle => 'Join a company';

  @override
  String get onboardingJoinSubtitle =>
      'With the invitation sent by your manager.';

  @override
  String get companyName => 'Company name';

  @override
  String get companyPlan => 'Plan';

  @override
  String get companyActivities => 'Activities';

  @override
  String companyActivitiesHint(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Up to $max activities',
      one: 'Choose 1 activity',
    );
    return '$_temp0';
  }

  @override
  String get companyTrialInfo =>
      '14-day free trial. You will be the company administrator.';

  @override
  String get companyCreateButton => 'Create the company';

  @override
  String get joinCodeLabel => 'Invitation code';

  @override
  String get joinCodeHelp => 'Paste the code or open the link you received.';

  @override
  String get joinCheck => 'Check';

  @override
  String joinInvitedTo(String entreprise) {
    return 'Invitation to join $entreprise';
  }

  @override
  String joinRole(String role) {
    return 'Role: $role';
  }

  @override
  String joinForEmail(String email) {
    return 'For $email';
  }

  @override
  String joinExpires(String date) {
    return 'Valid until $date';
  }

  @override
  String get joinAccept => 'Accept the invitation';

  @override
  String get joinIgnore => 'Ignore';

  @override
  String get joinSignInToAccept =>
      'Sign in or create an account with the invited address to accept.';

  @override
  String get ruleInvitationInvalid => 'This invitation is invalid.';

  @override
  String get ruleInvitationExpired => 'This invitation has expired.';

  @override
  String get ruleInvitationUsed => 'This invitation has already been used.';

  @override
  String get ruleInvitationCancelled => 'This invitation was cancelled.';

  @override
  String get ruleInvitationOtherEmail =>
      'This invitation is for a different email address.';

  @override
  String get ruleInvitationNotCancellable =>
      'This invitation can no longer be cancelled.';

  @override
  String get ruleEmailNotConfirmed =>
      'Please confirm your email address first.';

  @override
  String get ruleAlreadyMember =>
      'This person is already a member of the company.';

  @override
  String get ruleCompanyAlreadyCreated => 'You have already created a company.';

  @override
  String get rulePlanInvalid => 'This plan is not available.';

  @override
  String get ruleActivityRequired => 'Choose at least one activity.';

  @override
  String get ruleNameInvalid => 'The name is too short.';

  @override
  String get rulePerimetreRequired => 'Choose at least one site for this role.';

  @override
  String get inviteTitle => 'Invite a user';

  @override
  String get inviteRole => 'Role';

  @override
  String get invitePerimetres => 'Allowed sites';

  @override
  String get inviteSend => 'Create the invitation';

  @override
  String get inviteNoRole => 'No role available with your plan.';

  @override
  String get inviteCreatedTitle => 'Invitation created';

  @override
  String inviteCreatedMessage(String email, String date) {
    return 'Share this link with $email. It is valid until $date and can be used once.';
  }

  @override
  String get inviteCopyLink => 'Copy link';

  @override
  String get inviteCopyCode => 'Copy code';

  @override
  String get inviteCopied => 'Copied';

  @override
  String get inviteCancel => 'Cancel invitation';

  @override
  String get invitationsTitle => 'Invitations';

  @override
  String get invitationStatusPending => 'Pending';

  @override
  String get invitationStatusAccepted => 'Accepted';

  @override
  String get invitationStatusExpired => 'Expired';

  @override
  String get invitationStatusCancelled => 'Cancelled';

  @override
  String get navSell => 'Sell';

  @override
  String get navStock => 'Stock';

  @override
  String get navFinances => 'Finances';

  @override
  String get navAccount => 'Account';

  @override
  String get financesComingSoon =>
      'The financial dashboard (revenue, collections, expenses, unpaid invoices) arrives with the Sales and Cash register modules.';

  @override
  String get menuActivities => 'My activities';

  @override
  String get menuPreferences => 'Preferences';

  @override
  String get menuSeeSubscription => 'View subscription';

  @override
  String get activityStatusActive => 'Active';

  @override
  String get activityActivate => 'Enable';

  @override
  String activityActivateTitle(String activity) {
    return 'Enable $activity?';
  }

  @override
  String get activityActivateMessage =>
      'This activity\'s modules will be added to your company. Then create its first site.';

  @override
  String get activityActivated => 'Activity enabled.';

  @override
  String get homeToday => 'Today';

  @override
  String get homeWatch => 'Needs attention';

  @override
  String get homeKpiPending =>
      'Figures will appear as soon as the first sales are recorded.';

  @override
  String get kpiRevenue => 'Revenue';

  @override
  String get kpiCollected => 'Collected';

  @override
  String get kpiExpenses => 'Expenses';

  @override
  String get kpiUnpaid => 'Unpaid invoices';

  @override
  String homeTrialDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Trial: $days days left',
      one: 'Trial: 1 day left',
      zero: 'Your trial ends today',
    );
    return '$_temp0';
  }

  @override
  String get homeTrialHint =>
      'Choose your plan to continue without interruption.';

  @override
  String get roleCaissier => 'Cashier';

  @override
  String get roleGestionnaireImmobilier => 'Property manager';

  @override
  String subscriptionUsageUnlimited(int used) {
    return '$used · unlimited';
  }

  @override
  String companyPlanPrice(String price) {
    return '$price / month';
  }

  @override
  String get entrepriseIdentity => 'Identity';

  @override
  String get entrepriseContact => 'Contact details';

  @override
  String get entrepriseLegal => 'Legal information';

  @override
  String get entreprisePreferences => 'Preferences';

  @override
  String get entreprisePhone => 'Phone';

  @override
  String get entrepriseAddress => 'Address';

  @override
  String get entrepriseCity => 'City';

  @override
  String get entrepriseTaxId => 'Tax ID';

  @override
  String get entrepriseTradeRegister => 'Trade register number';

  @override
  String get entrepriseDocLanguage => 'Document language';

  @override
  String get entrepriseSaved => 'Details saved.';

  @override
  String get entrepriseLogoLater =>
      'The logo can be added with attachments (next step).';

  @override
  String get moduleAdminAudit => 'Activity log';

  @override
  String get auditEmpty => 'No activity recorded yet.';

  @override
  String get auditSystem => 'System';

  @override
  String get auditActionCreation => 'Created';

  @override
  String get auditActionModification => 'Updated';

  @override
  String get auditActionArchivage => 'Archived';

  @override
  String get auditActionRestauration => 'Restored';

  @override
  String get auditActionSuppression => 'Deleted';

  @override
  String get auditEntityEntreprise => 'Company';

  @override
  String get auditEntityActivite => 'Activity';

  @override
  String get auditEntityAbonnement => 'Subscription';

  @override
  String get auditEntityMembre => 'Member';

  @override
  String get auditEntityAffectation => 'Site assignment';

  @override
  String get auditEntitySite => 'Site';

  @override
  String get auditEntityInvitation => 'Invitation';

  @override
  String auditOtherFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other fields',
      one: '1 other field',
    );
    return '$_temp0';
  }

  @override
  String get espaceTitle => 'Workspace';

  @override
  String get espaceGlobal => 'Overview';

  @override
  String get espaceActivity => 'Activity';

  @override
  String get espaceSite => 'Shop / site';

  @override
  String get commonClear => 'Clear';

  @override
  String ruleTextTooLong(int max) {
    return 'Text too long ($max characters maximum).';
  }

  @override
  String get homeCommonTools => 'Shared tools';

  @override
  String get contactRelationClient => 'Customer';

  @override
  String get contactRelationFournisseur => 'Supplier';

  @override
  String get contactRelationLocataire => 'Tenant';

  @override
  String get contactRelationProprietaire => 'Owner';

  @override
  String get contactRelationPrestataire => 'Contractor';

  @override
  String get contactTypePersonne => 'Person';

  @override
  String get contactTypeOrganisation => 'Organization';

  @override
  String get contactsSearchHint => 'Name, phone, email, city…';

  @override
  String get contactsFilterAll => 'All';

  @override
  String get contactsShowArchived => 'Archived';

  @override
  String get contactsEmpty =>
      'No contacts yet. Add your customers, suppliers, tenants…';

  @override
  String get contactsNoResult => 'No contact matches your search.';

  @override
  String get contactAdd => 'New contact';

  @override
  String get contactNew => 'New contact';

  @override
  String get contactEdit => 'Edit contact';

  @override
  String get contactDetailTitle => 'Contact';

  @override
  String get contactNotFound =>
      'This contact does not exist or is no longer accessible.';

  @override
  String get contactSaved => 'Contact saved.';

  @override
  String get contactArchived => 'Archived';

  @override
  String get contactArchive => 'Archive';

  @override
  String get contactRestore => 'Reactivate';

  @override
  String get contactArchiveTitle => 'Archive this contact?';

  @override
  String contactArchiveMessage(String name) {
    return '“$name” will no longer appear in lists. Their history is kept and you can reactivate them.';
  }

  @override
  String get contactRelationsNone => 'No relationship set';

  @override
  String get contactFieldNom => 'Last name';

  @override
  String get contactFieldRaisonSociale => 'Company name';

  @override
  String get contactFieldPrenom => 'First name';

  @override
  String get contactFieldTelephone => 'Phone';

  @override
  String get contactFieldWhatsapp => 'WhatsApp';

  @override
  String get contactWhatsappHint => 'Only if different from the phone number';

  @override
  String get contactFieldEmail => 'Email';

  @override
  String get contactFieldAdresse => 'Address';

  @override
  String get contactFieldVille => 'City';

  @override
  String get contactFieldRemarque => 'Note';

  @override
  String get contactFieldRelations => 'Relationship with the company';

  @override
  String get contactCall => 'Call';

  @override
  String get contactWhatsapp => 'WhatsApp';

  @override
  String get contactEmailAction => 'Email';

  @override
  String get contactActionUnavailable =>
      'This action is not available on this device.';

  @override
  String get contactHistoryTitle => 'History';

  @override
  String get contactHistoryEmpty =>
      'This contact\'s sales, payments and rents will appear here once those modules are available.';

  @override
  String get contactDuplicateTitle => 'This contact may already exist';

  @override
  String contactDuplicateMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records have the same name or phone.',
      one: 'One record has the same name or phone.',
    );
    return '$_temp0 Use the existing record to keep a single history.';
  }

  @override
  String get contactDuplicateOpen => 'Open record';

  @override
  String get contactDuplicateAddRelation => 'Add relationship';

  @override
  String get contactDuplicateCreateAnyway => 'Create anyway';

  @override
  String get contactHistoryNone =>
      'No amount due and no payment for this contact.';

  @override
  String get contactOwesUs => 'Owes us';

  @override
  String get contactWeOwe => 'We owe them';

  @override
  String get commonEdit => 'Edit';

  @override
  String get homeSeeFinances => 'See finances';

  @override
  String get validationAmount => 'Enter an amount greater than zero';

  @override
  String validationAmountMax(String max) {
    return 'At most $max';
  }

  @override
  String get paymentModeCash => 'Cash';

  @override
  String get paymentModeMobileMoney => 'Mobile money';

  @override
  String get paymentModeCard => 'Card';

  @override
  String get paymentModeTransfer => 'Bank transfer';

  @override
  String get paymentModeCheque => 'Cheque';

  @override
  String get paymentModeOther => 'Other';

  @override
  String get debtStateUnpaid => 'To collect';

  @override
  String get debtStateToPay => 'To pay';

  @override
  String get debtStatePartial => 'Partial';

  @override
  String get debtStateOverdue => 'Overdue';

  @override
  String get debtStatePaid => 'Settled';

  @override
  String get debtStateCancelled => 'Cancelled';

  @override
  String get cashMoveCollection => 'Cash in';

  @override
  String get cashMoveDisbursement => 'Cash out';

  @override
  String get cashMoveDeposit => 'Deposit';

  @override
  String get cashMoveWithdrawal => 'Withdrawal';

  @override
  String get financeRejectedTitle => 'Rejected by the server';

  @override
  String get financeRejectedMessage =>
      'This operation was not recorded (permissions, closed register or amount exceeded). It is not counted in any total.';

  @override
  String get financeRejectedRemove => 'Remove';

  @override
  String get financeRejectedShort => 'Rejected';

  @override
  String get financeNoContact => 'No contact';

  @override
  String get financeContact => 'Contact';

  @override
  String get financeInCash => 'In the register';

  @override
  String get financeToReceive => 'To receive';

  @override
  String get financeToPay => 'To pay';

  @override
  String financeOverdueAmount(String amount) {
    return '$amount overdue';
  }

  @override
  String get financeNotFound => 'Item not found or not accessible.';

  @override
  String get financeSite => 'Shop / branch';

  @override
  String get financeAllSites => 'Whole company';

  @override
  String get financePendingSync => 'Saved on this device, waiting to be sent';

  @override
  String get debtNewReceivable => 'New amount to receive';

  @override
  String get debtNewPayable => 'New amount to pay';

  @override
  String get debtShowSettled => 'Show settled';

  @override
  String get debtEmptyReceivable => 'Nobody owes you money.';

  @override
  String get debtEmptyPayable => 'You owe nothing for now.';

  @override
  String debtDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get debtDetailTitle => 'Amount due';

  @override
  String get debtRemaining => 'Remaining';

  @override
  String get debtPaid => 'Already paid';

  @override
  String get debtTotal => 'Total amount';

  @override
  String get debtDate => 'Date';

  @override
  String get debtDueDate => 'Due date';

  @override
  String get debtNoDueDate => 'No due date';

  @override
  String get debtCancelReason => 'Cancellation reason';

  @override
  String get debtCollect => 'Collect';

  @override
  String get debtPay => 'Pay';

  @override
  String get debtCancel => 'Cancel';

  @override
  String get debtPayments => 'Payments';

  @override
  String get debtNoPayment => 'No payment yet.';

  @override
  String get debtCancelTitle => 'Cancel this amount due?';

  @override
  String get debtCancelMessage =>
      'It will no longer be counted. It stays visible in the history.';

  @override
  String get debtEdit => 'Edit amount due';

  @override
  String get debtWhoOwes => 'Who has to pay?';

  @override
  String get debtOwedTo => 'Who do you owe?';

  @override
  String get debtLabel => 'Description';

  @override
  String get debtLabelHint => 'e.g. goods delivered on credit';

  @override
  String debtAlreadyPaid(String amount) {
    return 'Already paid: $amount. The total cannot be lower.';
  }

  @override
  String get paymentNew => 'Collect';

  @override
  String get paymentsEmpty => 'No payment recorded.';

  @override
  String get paymentCancellation => 'Payment cancellation';

  @override
  String get paymentIn => 'Money in';

  @override
  String get paymentOut => 'Money out';

  @override
  String get paymentCancelled => 'Cancelled';

  @override
  String get paymentSaved => 'Payment saved.';

  @override
  String get paymentNewIn => 'Collect';

  @override
  String get paymentNewOut => 'Pay';

  @override
  String get paymentFrom => 'Paid by';

  @override
  String get paymentTo => 'Paid to';

  @override
  String get paymentAmount => 'Amount';

  @override
  String get paymentMode => 'Payment method';

  @override
  String get paymentCashRegister => 'Cash register';

  @override
  String get paymentNoCashRegister => 'Outside the register';

  @override
  String get paymentNoOpenRegister =>
      'No open register: the payment will be recorded outside the register.';

  @override
  String get paymentSettlesReceivables => 'Settles amounts due';

  @override
  String get paymentSettlesPayables => 'Settles debts';

  @override
  String paymentRemainingOf(String amount) {
    return '$amount left';
  }

  @override
  String paymentUnallocated(String amount) {
    return '$amount unallocated (advance)';
  }

  @override
  String get paymentReference => 'Reference';

  @override
  String get paymentReferenceHint => 'Transaction or cheque number…';

  @override
  String get paymentNote => 'Note';

  @override
  String paymentConfirmIn(String amount) {
    return 'Collect $amount';
  }

  @override
  String paymentConfirmOut(String amount) {
    return 'Pay $amount';
  }

  @override
  String get paymentDetailTitle => 'Payment';

  @override
  String get paymentDate => 'Date';

  @override
  String get paymentCancelsPayment => 'Cancels the payment';

  @override
  String get paymentOpenOriginal => 'See the original payment';

  @override
  String get paymentCancelledBy => 'Cancelled on';

  @override
  String get paymentCancel => 'Cancel this payment';

  @override
  String get paymentCancelHint =>
      'A payment is never erased: its cancellation is recorded and the amounts due become due again.';

  @override
  String get paymentCancelTitle => 'Cancel this payment?';

  @override
  String paymentCancelMessage(String amount) {
    return 'A reverse payment of $amount will be recorded, and the register adjusted if it was cash.';
  }

  @override
  String get cashNew => 'New cash register';

  @override
  String get cashEmptyAdmin =>
      'No cash register. Create one for each shop or branch that handles cash.';

  @override
  String get cashEmpty => 'No accessible cash register.';

  @override
  String get cashOpenState => 'Open';

  @override
  String get cashClosedState => 'Closed';

  @override
  String cashOpenSince(String date) {
    return 'Open since $date';
  }

  @override
  String get cashBalance => 'Cash balance';

  @override
  String cashOpeningBalance(String amount) {
    return 'Opening float: $amount';
  }

  @override
  String get cashOpen => 'Open the register';

  @override
  String get cashClose => 'Close the register';

  @override
  String get cashMovements => 'Movements';

  @override
  String get cashNoMovement => 'No movement since opening.';

  @override
  String get cashHistory => 'Previous closings';

  @override
  String get cashClosingPending => 'Closing waiting to be sent';

  @override
  String cashClosingSummary(String expected, String counted) {
    return 'Expected $expected · counted $counted';
  }

  @override
  String get cashNoGap => 'No difference';

  @override
  String get cashOpeningAmount => 'Opening float';

  @override
  String get cashMoveReason => 'Reason';

  @override
  String cashExpected(String amount) {
    return 'Expected amount: $amount';
  }

  @override
  String get cashCounted => 'Counted amount';

  @override
  String cashGap(String amount) {
    return 'Difference: $amount';
  }

  @override
  String get cashClosingNote => 'Comment (optional)';

  @override
  String get cashName => 'Register name';

  @override
  String cashDefaultName(String site) {
    return '$site register';
  }

  @override
  String get ruleLabelInvalid =>
      'Enter a description (200 characters maximum).';

  @override
  String get ruleCommitmentCancelled => 'This amount due has been cancelled.';

  @override
  String get ruleCommitmentPaid =>
      'Payments are already recorded: cancel them first.';

  @override
  String ruleTotalBelowPaid(String amount) {
    return 'The total cannot be lower than what is already paid ($amount).';
  }

  @override
  String ruleAmountAboveRemaining(String amount) {
    return 'Amount higher than what remains due ($amount).';
  }

  @override
  String get ruleAllocationAbovePayment =>
      'The allocation exceeds the payment amount.';

  @override
  String get ruleAllocationWrongDirection =>
      'Money in can only settle an amount to receive, money out only an amount to pay.';

  @override
  String get ruleAllocationOtherContact =>
      'This amount due concerns another contact.';

  @override
  String get rulePaymentAlreadyCancelled =>
      'This payment is already cancelled.';

  @override
  String get ruleModeWithoutCash => 'Only cash goes through the register.';

  @override
  String get ruleDateInvalid => 'Invalid payment date.';

  @override
  String get ruleCashClosed => 'The register is closed: open it first.';

  @override
  String get ruleCashOpenSession => 'Close the register first.';

  @override
  String get ruleCashAlreadyOpen => 'This register is already open.';

  @override
  String get ruleCashInactive => 'This register is deactivated.';

  @override
  String ruleCashInsufficient(String amount) {
    return 'Not enough cash in the register (balance: $amount).';
  }

  @override
  String get ruleFinanceInconsistent =>
      'Operation impossible: inconsistent data. Refresh and try again.';

  @override
  String get financeExpensesMonth => 'Expenses this month';

  @override
  String get debtOpenExpense => 'See the expense';

  @override
  String get expenseCatRent => 'Rent';

  @override
  String get expenseCatEnergy => 'Electricity';

  @override
  String get expenseCatTransport => 'Transport';

  @override
  String get expenseCatSalaries => 'Salaries';

  @override
  String get expenseCatSupplies => 'Supplies';

  @override
  String get expenseCatCommunication => 'Communication and advertising';

  @override
  String get expenseCatMaintenance => 'Maintenance';

  @override
  String get expenseCatTaxes => 'Taxes';

  @override
  String get expenseCatOther => 'Other';

  @override
  String get expenseNew => 'New expense';

  @override
  String get expenseSaved => 'Expense saved.';

  @override
  String get expenseCategories => 'Categories';

  @override
  String get expensesEmpty => 'No expense recorded.';

  @override
  String get expenseCancelled => 'Cancelled';

  @override
  String get expenseToPay => 'To pay';

  @override
  String get expenseDetailTitle => 'Expense';

  @override
  String get expenseDate => 'Expense date';

  @override
  String get expenseSettlement => 'Settlement';

  @override
  String expensePaidWith(String mode) {
    return 'Paid · $mode';
  }

  @override
  String expenseToPayRemaining(String amount) {
    return 'To pay: $amount';
  }

  @override
  String get expenseSupplier => 'Supplier (optional)';

  @override
  String get expenseCancel => 'Cancel the expense';

  @override
  String get expenseEdit => 'Edit expense';

  @override
  String get expenseLabel => 'Description';

  @override
  String get expenseLabelHint => 'e.g. taxi for the delivery';

  @override
  String get expenseCategory => 'Category';

  @override
  String get expenseAmountLocked =>
      'The amount cannot be changed: cancel the expense and enter it again.';

  @override
  String get expenseCancelTitle => 'Cancel this expense?';

  @override
  String get expenseCancelMessagePaid =>
      'The payment will be cancelled (and the register adjusted for cash), then the expense. Nothing is erased from the history.';

  @override
  String get expenseCancelMessage =>
      'The linked amount to pay will be cancelled. Nothing is erased from the history.';

  @override
  String get expenseCategoryNew => 'New category';

  @override
  String get expenseCategoryName => 'Category name';

  @override
  String get expenseCategoriesHint =>
      'A deactivated category is no longer offered; expenses already recorded keep it.';

  @override
  String get expensePaidNow => 'Paid now';

  @override
  String get expensePayLater => 'Pay later';

  @override
  String get expenseReferenceHint => 'Invoice or receipt number…';

  @override
  String get ruleCommitmentLinked =>
      'This amount is linked to an expense: edit or cancel the expense.';

  @override
  String get ruleCategoryInvalid => 'Choose an active category.';

  @override
  String get ruleExpensePaid =>
      'This expense is paid: cancel its payment first.';

  @override
  String get ruleExpenseCancelled => 'This expense is cancelled.';

  @override
  String get moduleCommunDocuments => 'Documents';

  @override
  String get docTypeReceipt => 'Receipt';

  @override
  String get docTypeInvoice => 'Invoice';

  @override
  String get docTypeQuote => 'Quote';

  @override
  String get docTypeCreditNote => 'Credit note';

  @override
  String get docSearchHint => 'Document number or name…';

  @override
  String get docEmpty =>
      'No document issued. Receipts are issued from a payment\'s page.';

  @override
  String get docIssueReceipt => 'Issue the receipt';

  @override
  String docOpenReceipt(String numero) {
    return 'See receipt $numero';
  }

  @override
  String get docReceiptTitle => 'RECEIPT';

  @override
  String get docDate => 'Date';

  @override
  String get docReceivedFrom => 'Received from';

  @override
  String get docPaymentMode => 'Payment method';

  @override
  String get docReference => 'Reference';

  @override
  String get docAmountReceived => 'Amount received';

  @override
  String get docSettles => 'Payment for';

  @override
  String get docColumnLabel => 'Description';

  @override
  String get docColumnAmount => 'Paid';

  @override
  String get docColumnRemaining => 'Remaining';

  @override
  String docIssuedBy(String name) {
    return 'Issued by $name';
  }

  @override
  String get docGeneratedBy => 'Document generated by DubaGest';

  @override
  String get docCancelledStamp => 'CANCELLED';

  @override
  String docPhone(String value) {
    return 'Tel.: $value';
  }

  @override
  String docTaxId(String value) {
    return 'Tax ID: $value';
  }

  @override
  String docTradeRegister(String value) {
    return 'Trade register: $value';
  }

  @override
  String get ruleDocumentExists =>
      'A receipt has already been issued for this payment.';

  @override
  String get ruleDocumentOriginInvalid =>
      'A receipt can only be issued for a valid incoming payment.';

  @override
  String get ruleDocumentNumbersExhausted =>
      'No receipt number left on this device. Connect to the internet for a moment to reserve more.';

  @override
  String get ruleDocumentNumberInvalid =>
      'Invalid document number. Refresh and try again.';

  @override
  String get moduleCommunAgenda => 'Agenda';

  @override
  String get agendaTypeReminder => 'Reminder';

  @override
  String get agendaTypeMeeting => 'Appointment';

  @override
  String get agendaTypeTask => 'Task';

  @override
  String get agendaTypeFollowUp => 'Follow-up';

  @override
  String get agendaNew => 'New item';

  @override
  String get agendaEdit => 'Edit item';

  @override
  String get agendaMine => 'My tasks';

  @override
  String get agendaEmpty =>
      'Nothing planned. Add a reminder, a task or a follow-up.';

  @override
  String get agendaOverdue => 'Overdue';

  @override
  String get agendaToday => 'Today';

  @override
  String get agendaNextDays => 'Next 7 days';

  @override
  String get agendaLater => 'Later';

  @override
  String agendaAssignedTo(String name) {
    return 'Assigned to $name';
  }

  @override
  String get agendaMarkDone => 'Mark as done';

  @override
  String get agendaReopen => 'Mark as to do';

  @override
  String get agendaCancel => 'Cancel the item';

  @override
  String get agendaDueToReceive => 'Payment due to you';

  @override
  String get agendaDueToPay => 'Payment due by you';

  @override
  String agendaReminderBefore(String delay) {
    return 'Reminder $delay before';
  }

  @override
  String get agendaOpenDebt => 'See the amount due';

  @override
  String get agendaStatusTodo => 'To do';

  @override
  String get agendaStatusDone => 'Done';

  @override
  String get agendaStatusCancelled => 'Cancelled';

  @override
  String get agendaTitle => 'Title';

  @override
  String get agendaTitleHint => 'e.g. call Amadou about the balance';

  @override
  String get agendaWhen => 'Date and time';

  @override
  String get agendaReminder => 'Reminder';

  @override
  String get agendaNoReminder => 'No reminder';

  @override
  String get agendaAssignee => 'Assign to';

  @override
  String get agendaNobody => 'Nobody in particular';

  @override
  String get agendaMe => 'Me';

  @override
  String get agendaPlanFollowUp => 'Plan a follow-up';

  @override
  String agendaFollowUpTitle(String name) {
    return 'Follow up with $name';
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
      other: '$n hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String agendaDelayDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsEmpty => 'Nothing to report.';

  @override
  String get notificationsToHandle => 'To handle';

  @override
  String get notificationsReceived => 'Messages';

  @override
  String get notifOverdue => 'Overdue';

  @override
  String get notifDueSoon => 'Soon';

  @override
  String notifDebtsOverdue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n overdue amounts to receive',
      one: '1 overdue amount to receive',
    );
    return '$_temp0';
  }

  @override
  String notifCashOpenLong(String name) {
    return '$name open for more than 24 h';
  }

  @override
  String notifRejected(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n operations rejected by the server',
      one: '1 operation rejected by the server',
    );
    return '$_temp0';
  }

  @override
  String get notifRejectedHint => 'Open it to read the reason and remove it.';

  @override
  String notifAssigned(String name) {
    return '$name assigned you a task';
  }

  @override
  String notifDone(String name) {
    return '$name completed a task';
  }

  @override
  String get ruleAssigneeInvalid =>
      'This person is not an active member of the company.';

  @override
  String get ruleTargetInvalid => 'The linked record no longer exists.';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboard7Days => '7 days';

  @override
  String get dashboard30Days => '30 days';

  @override
  String get dashboardMonth => 'This month';

  @override
  String get dashboardEmpty =>
      'No operation in this period for this workspace.';

  @override
  String get dashboardFlows => 'Money in and out per day';

  @override
  String get dashboardExpensesByCategory => 'Expenses by category';

  @override
  String get dashboardTopDebtors => 'Who owes you the most';

  @override
  String get dashboardCollected => 'Collected';

  @override
  String get dashboardPaidOut => 'Paid out';

  @override
  String get dashboardNet => 'Net for the period';

  @override
  String get dashboardExpenses => 'Expenses';

  @override
  String get dashboardOtherCategories => 'Other categories';

  @override
  String get dashboardSeeAll => 'See all';

  @override
  String get searchHint => 'Search a contact, a receipt, a payment…';

  @override
  String get searchIntro =>
      'Name, phone, amount, receipt number… Search also works offline.';

  @override
  String get searchNoResult => 'No result.';

  @override
  String get searchDebts => 'Amounts due';

  @override
  String get moduleCommunRapports => 'Reports';

  @override
  String get reportCashJournal => 'Cash journal';

  @override
  String get reportCashJournalHint =>
      'All money received and paid out during the period.';

  @override
  String get reportExpenses => 'Expenses by category';

  @override
  String get reportExpensesHint =>
      'Number and total of the period\'s expenses, by category.';

  @override
  String get reportAgedReceivables => 'Aged receivables';

  @override
  String get reportAgedReceivablesHint =>
      'What each customer still owes, by how overdue it is.';

  @override
  String get reportCashClosings => 'Cash register closings';

  @override
  String get reportCashClosingsHint =>
      'Expected balance, counted amount and difference for each closing.';

  @override
  String reportPeriod(String start, String end) {
    return 'From $start to $end';
  }

  @override
  String reportAtDate(String date) {
    return 'As at $date';
  }

  @override
  String get reportTotal => 'Total';

  @override
  String reportNet(String amount) {
    return 'Net: $amount';
  }

  @override
  String get reportCount => 'Count';

  @override
  String get reportNotDue => 'Not due';

  @override
  String reportDaysRange(int a, int b) {
    return '$a–$b days';
  }

  @override
  String reportDaysOver(int n) {
    return 'Over $n days';
  }

  @override
  String get reportClosedOn => 'Closed on';

  @override
  String get reportExpected => 'Expected';

  @override
  String get reportGap => 'Difference';

  @override
  String get reportNone => 'No report available with your permissions.';

  @override
  String get reportEmpty => 'No data for this period.';

  @override
  String get reportExportPdf => 'Export as PDF';

  @override
  String reportGeneratedOn(String date) {
    return 'Generated on $date — DubaGest';
  }

  @override
  String get notesTitle => 'Notes and attachments';

  @override
  String get notesAddHint => 'Add a note…';

  @override
  String get notesAdd => 'Add the note';

  @override
  String get attachmentsTitle => 'Attachments';

  @override
  String get attachTakePhoto => 'Take a photo';

  @override
  String get attachChooseFile => 'Attach a file';

  @override
  String get attachOnlineHint =>
      'Photo or PDF, 10 MB maximum. Sending a file requires a connection.';

  @override
  String get attachFileTypes => 'Images and PDF';

  @override
  String attachSizeKb(int n) {
    return '$n KB';
  }

  @override
  String attachSizeMb(String value) {
    return '$value MB';
  }

  @override
  String get entrepriseLogoHint =>
      'The logo appears at the top of receipts (PNG, JPEG or WEBP, 2 MB maximum).';

  @override
  String get entrepriseLogoChange => 'Change the logo';

  @override
  String get entrepriseLogoSaved => 'Logo saved.';

  @override
  String get entrepriseLogoTypes => 'Images';

  @override
  String get ruleFileTypeInvalid =>
      'Format not accepted: photo (JPEG, PNG, WEBP) or PDF only.';

  @override
  String ruleFileTooLarge(int max) {
    return 'File too large ($max MB maximum).';
  }

  @override
  String get settingsCompanyProfile => 'Company profile';

  @override
  String get settingsPayments => 'Payments and receipts';

  @override
  String get settingsPaymentsHint => 'Payment methods offered, receipt note';

  @override
  String get settingsExpenseCategories => 'Expense categories';

  @override
  String get settingsPaymentModes => 'Payment methods offered';

  @override
  String get settingsPaymentModesHint =>
      'Only enabled methods are offered when recording. Payments already recorded are unchanged.';

  @override
  String get settingsPaymentModeCash => 'Goes through the cash register';

  @override
  String get settingsReceiptFooter => 'Note at the bottom of receipts';

  @override
  String get settingsReceiptFooterHint => 'E.g.: Thank you for your business.';

  @override
  String get settingsReceiptFooterNote =>
      'Printed on future receipts; receipts already issued are unchanged.';

  @override
  String get settingsSaved => 'Settings saved.';

  @override
  String get rulePaymentModesInvalid =>
      'Choose at least one payment method from the list.';

  @override
  String get rulePaymentModeDisabled =>
      'This payment method is no longer offered by the company. Choose another one.';

  @override
  String get comStatusInStock => 'In stock';

  @override
  String get comStatusLow => 'Low stock';

  @override
  String get comStatusOut => 'Out of stock';

  @override
  String get comAllShops => 'All shops';

  @override
  String get comChooseShop => 'Choose the shop';

  @override
  String get comShop => 'Shop';

  @override
  String get comShopRequired => 'Choose a shop';

  @override
  String get comBefore => 'Before';

  @override
  String get comAfter => 'After';

  @override
  String get comQuantity => 'Quantity';

  @override
  String get comQuantityInvalid => 'Enter a valid quantity';

  @override
  String comFractionNotAllowed(String unite) {
    return 'This product is counted in whole $unite';
  }

  @override
  String comFractionStep(String pas, String unite) {
    return 'In steps of $pas $unite';
  }

  @override
  String get comScan => 'Scan a barcode';

  @override
  String get comScanTitle => 'Scan';

  @override
  String get comTorch => 'Torch';

  @override
  String get comScanUnavailable =>
      'The camera is not available. Type the code instead.';

  @override
  String get comScanHint => 'Place the barcode inside the frame';

  @override
  String get comBarcodeUnknown => 'This code is not linked to any product';

  @override
  String get comChooseProduct => 'Choose a product';

  @override
  String get comSearchHint => 'Name, reference or barcode…';

  @override
  String get comAllCategories => 'All';

  @override
  String get comNoProductFound => 'No product found';

  @override
  String get comNoProductFoundHint => 'Try another word, or add this product.';

  @override
  String get comAddProduct => 'Add a product';

  @override
  String get comUsualProducts => 'Usual products';

  @override
  String get comAllProducts => 'All products';

  @override
  String get comProduct => 'Product';

  @override
  String get comFrom => 'From';

  @override
  String get comTo => 'To';

  @override
  String get comNewEntry => 'New stock entry';

  @override
  String get comSaveEntry => 'Save the entry';

  @override
  String get comNewExit => 'New stock exit';

  @override
  String get comConfirmExit => 'Confirm the exit';

  @override
  String get comTransferStock => 'Transfer stock';

  @override
  String get comConfirmTransfer => 'Confirm the transfer';

  @override
  String get comInventory => 'Stock count';

  @override
  String get comValidateInventory => 'Validate the count';

  @override
  String get comConfirmExitTitle => 'Confirm the exit?';

  @override
  String get comConfirmTransferTitle => 'Confirm the transfer?';

  @override
  String get comConfirmInventoryTitle => 'Validate the count?';

  @override
  String comCurrentStock(String quantite) {
    return 'Current stock: $quantite';
  }

  @override
  String get comHowMany => 'How many?';

  @override
  String get comCountedQuantity => 'How many did you count?';

  @override
  String get comWhy => 'Why this difference?';

  @override
  String get comReason => 'Reason';

  @override
  String get comNoteOptional => 'Note (optional)';

  @override
  String get comAddNote => 'Add a note';

  @override
  String get comStockPreview => 'Your stock';

  @override
  String comStockInsufficientInline(String disponible) {
    return 'Not enough stock · Available: $disponible';
  }

  @override
  String get comInventoryNoGap => 'No difference: the stock is right';

  @override
  String comInventoryGap(String ecart) {
    return 'Difference: $ecart';
  }

  @override
  String get comStockUpdated => 'Stock updated';

  @override
  String comTransferDone(String quantite, String boutique) {
    return '$quantite transferred to $boutique';
  }

  @override
  String get comReasonPurchase => 'Purchase';

  @override
  String get comReasonReturn => 'Return';

  @override
  String get comReasonAdjustment => 'Adjustment';

  @override
  String get comReasonSale => 'Sale';

  @override
  String get comReasonLoss => 'Loss';

  @override
  String get comReasonBreakage => 'Breakage';

  @override
  String get comReasonTransfer => 'Transfer';

  @override
  String get comReasonCountError => 'Counting error';

  @override
  String get comReasonMissing => 'Missing product';

  @override
  String get comReasonOther => 'Other';

  @override
  String ruleStockInsufficient(String disponible) {
    return 'Not enough stock: $disponible left.';
  }

  @override
  String get ruleQuantityInvalid => 'The quantity must be greater than zero.';

  @override
  String ruleFractionInvalid(String pas, String unite) {
    return 'Invalid quantity: this product is sold by $pas $unite.';
  }

  @override
  String get ruleUnitInvalid =>
      'Check the units: each unit has a different name and contains at least one base unit.';

  @override
  String get ruleBarcodeExists =>
      'This barcode is already used by another product.';

  @override
  String get ruleTransferSameShop => 'Choose two different shops.';

  @override
  String get ruleShopRequired => 'Choose the shop.';

  @override
  String get ruleLinesInvalid => 'Add at least one product with a quantity.';

  @override
  String ruleReceptionAbove(String reste) {
    return 'You cannot receive more than ordered (remaining: $reste).';
  }

  @override
  String get rulePurchaseReceived =>
      'This purchase has already been received: it can no longer be changed or cancelled.';

  @override
  String get rulePurchasePaid =>
      'This purchase is already paid: cancel the payment first.';

  @override
  String get rulePurchaseCancelled => 'This purchase is cancelled.';

  @override
  String get ruleSaleCancelled => 'This sale is already cancelled.';

  @override
  String get ruleSalePaid =>
      'This sale has been paid: cancel the payment in Finances first.';

  @override
  String get ruleCustomerRequired =>
      'For a sale on credit, choose the customer.';

  @override
  String get comProductsTitle => 'Products';

  @override
  String get comCategories => 'Categories';

  @override
  String get comManageCategories => 'Manage categories';

  @override
  String get comGridView => 'Grid view';

  @override
  String get comListView => 'List view';

  @override
  String get comEmptyProductsTitle => 'No products yet';

  @override
  String get comEmptyProductsMessage =>
      'Add your products to start managing your stock and your sales.';

  @override
  String comProductsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
      zero: 'No products',
    );
    return '$_temp0';
  }

  @override
  String comNoProductInCategory(String categorie) {
    return 'No products in $categorie';
  }

  @override
  String get comAddProductHere => 'Add a product here';

  @override
  String get comSeeProduct => 'View';

  @override
  String get comAddToStock => '+ Stock';

  @override
  String get comSell => 'Sell';

  @override
  String get comCreateProduct => 'Create the product';

  @override
  String get comBarcodeUnknownHint =>
      'Do you want to create a product with this code?';

  @override
  String get comArchived => 'Archived';

  @override
  String get comShowArchived => 'Archived products';

  @override
  String get comSortBy => 'Sort';

  @override
  String get comSortName => 'Name';

  @override
  String get comSortStock => 'Lowest stock';

  @override
  String get comSortPrice => 'Price';

  @override
  String get comSortBestSellers => 'Best sellers';

  @override
  String get comNewProduct => 'New product';

  @override
  String get comEditProduct => 'Edit product';

  @override
  String get comStepIdentity => 'The product';

  @override
  String get comStepUnits => 'Units and prices';

  @override
  String get comStepStock => 'Stock';

  @override
  String get comStepOptions => 'More options';

  @override
  String comStepOf(int etape, int total) {
    return 'Step $etape of $total';
  }

  @override
  String get comNext => 'Next';

  @override
  String get comPrevious => 'Previous';

  @override
  String get comSaveProduct => 'Save the product';

  @override
  String get comProductSaved => 'Product saved';

  @override
  String get comAddPhoto => 'Add a photo';

  @override
  String get comTakePhoto => 'Take a photo';

  @override
  String get comChooseFromGallery => 'Choose from the gallery';

  @override
  String get comPhotoHint =>
      'A photo helps your sellers recognise the product.';

  @override
  String get comMainPhoto => 'Main photo';

  @override
  String get comSetMainPhoto => 'Set as main';

  @override
  String get comRemovePhoto => 'Remove photo';

  @override
  String get comProductName => 'Product name';

  @override
  String get comProductNameHint => 'E.g. Tile 40×40';

  @override
  String get comNameRequired => 'Give the product a name';

  @override
  String get comCategory => 'Category';

  @override
  String get comSubCategory => 'Sub-category';

  @override
  String get comNoCategory => 'No category';

  @override
  String get comNewCategory => 'New category';

  @override
  String get comNewSubCategory => 'New sub-category';

  @override
  String get comCategoryName => 'Category name';

  @override
  String get comReference => 'Reference (optional)';

  @override
  String get comBarcode => 'Barcode (optional)';

  @override
  String get comCountedIn => 'I count this product in…';

  @override
  String get comOtherUnit => 'Other…';

  @override
  String get comUnitName => 'Unit name';

  @override
  String get comUnitNameHint => 'E.g. bundle, bucket, drum';

  @override
  String get comSalePrice => 'Selling price';

  @override
  String comSalePricePer(String unite) {
    return 'Selling price per $unite';
  }

  @override
  String comWholesalePricePer(String unite) {
    return 'Wholesale price per $unite';
  }

  @override
  String comPurchasePricePer(String unite) {
    return 'Purchase price per $unite (optional)';
  }

  @override
  String get comSellWholesale => 'I also sell wholesale';

  @override
  String get comRetail => 'Retail';

  @override
  String get comWholesale => 'Wholesale';

  @override
  String get comPurchase => 'Purchase';

  @override
  String get comPackagings => 'Packagings';

  @override
  String get comPackagingsHint =>
      'Do you buy or sell by carton, pack, bag…? Add them: the app does the maths.';

  @override
  String get comAddPackaging => 'Add a packaging';

  @override
  String get comCopyUnits => 'Copy from another product';

  @override
  String comOneUnitContains(String unite) {
    return '1 $unite contains';
  }

  @override
  String get comContains => 'contains';

  @override
  String comFactorRequired(String unite) {
    return 'How many $unite?';
  }

  @override
  String get comCalculated => 'calculated';

  @override
  String get comPriceSetByYou => 'price set by you';

  @override
  String comDiscountOf(String pourcent) {
    return '$pourcent% discount';
  }

  @override
  String comMarkupOf(String pourcent) {
    return '$pourcent% more than retail';
  }

  @override
  String get comPriceHigherWarning =>
      'Careful: this pack costs more than the units sold separately.';

  @override
  String get comBackToCalculated => 'Back to the calculated price';

  @override
  String comProfitPer(String montant, String unite) {
    return 'Profit: $montant per $unite';
  }

  @override
  String get comUnitsSummary => 'Summary';

  @override
  String get comInitialStock => 'Opening stock';

  @override
  String get comInitialStockHint => 'How many do you have today? (optional)';

  @override
  String get comInitialStockNote => 'Opening stock';

  @override
  String get comAlertThreshold => 'Warn me when fewer than… remain';

  @override
  String get comAlertThresholdHint => 'The product will show as “Low stock”.';

  @override
  String get comSellFractions => 'Sell in fractions';

  @override
  String get comSellFractionsHint => 'E.g. ½ can, 2.5 metres, 0.25 kg';

  @override
  String get comMinimumStep => 'Smallest quantity sold';

  @override
  String get comCharacteristics => 'Characteristics';

  @override
  String get comAddCharacteristic => 'Add a characteristic';

  @override
  String get comCharacteristicName => 'Name (e.g. warranty)';

  @override
  String get comMainSupplier => 'Main supplier';

  @override
  String get comChooseSupplier => 'Choose a supplier';

  @override
  String get comDescription => 'Description (optional)';

  @override
  String get comNone => 'None';

  @override
  String get comAttrMarque => 'Brand';

  @override
  String get comAttrModele => 'Model';

  @override
  String get comAttrCouleur => 'Colour';

  @override
  String get comAttrDimensions => 'Dimensions';

  @override
  String get comAttrFinition => 'Finish';

  @override
  String get comAttrVolume => 'Volume';

  @override
  String get comAttrType => 'Type';

  @override
  String get comAttrSection => 'Section';

  @override
  String get comAttrLongueur => 'Length';

  @override
  String get comAttrTaille => 'Size';

  @override
  String get comAttrPoids => 'Weight';

  @override
  String get comAttrEmplacement => 'Location';

  @override
  String get comUnitPiece => 'Piece';

  @override
  String get comUnitCarton => 'Carton';

  @override
  String get comUnitPaquet => 'Pack';

  @override
  String get comUnitSac => 'Bag';

  @override
  String get comUnitBidon => 'Can';

  @override
  String get comUnitBouteille => 'Bottle';

  @override
  String get comUnitSachet => 'Sachet';

  @override
  String get comUnitBoite => 'Box';

  @override
  String get comUnitRouleau => 'Roll';

  @override
  String get comUnitMetre => 'Metre';

  @override
  String get comUnitKg => 'Kg';

  @override
  String get comUnitLitre => 'Litre';

  @override
  String get comUnitDouzaine => 'Dozen';

  @override
  String get comUnitLot => 'Lot';

  @override
  String get comUnitPalette => 'Pallet';

  @override
  String get comUnitTonne => 'Tonne';

  @override
  String get comProductNotFound => 'This product no longer exists.';

  @override
  String get comChooseCustomer => 'Choose a customer';

  @override
  String get comNewSupplier => 'New supplier';

  @override
  String get comNewCustomer => 'New customer';

  @override
  String get comSearchContact => 'Name or phone…';

  @override
  String get comNoContact => 'No contact found';

  @override
  String get comStockCard => 'Stock';

  @override
  String get comDistribution => 'By shop';

  @override
  String get comEntry => 'Entry';

  @override
  String get comExit => 'Exit';

  @override
  String get comTransfer => 'Transfer';

  @override
  String get comBuy => 'Buy';

  @override
  String get comPricesAndUnits => 'Prices and units';

  @override
  String get comUnit => 'Unit';

  @override
  String get comProfit => 'Profit';

  @override
  String get comLastMovements => 'Latest movements';

  @override
  String get comSeeAll => 'See all';

  @override
  String get comNoMovement => 'No movement yet';

  @override
  String get comSuppliers => 'Suppliers';

  @override
  String get comArchive => 'Archive';

  @override
  String get comRestore => 'Restore';

  @override
  String get comArchiveConfirm =>
      'Archive this product? It will no longer be offered for sale or purchase. Its history is kept.';

  @override
  String get comBarcodeShort => 'Barcode';

  @override
  String get comReferenceShort => 'Reference';

  @override
  String comMinimumAlert(String quantite) {
    return 'Alert below $quantite';
  }

  @override
  String get comToCheck => 'Stock to check';

  @override
  String get comPendingSend => 'Waiting to be sent';

  @override
  String get comCategoriesTitle => 'Categories';

  @override
  String get comCategoriesEmptyTitle => 'Organise your products';

  @override
  String get comCategoriesEmptyMessage =>
      'Pick a template that fits your business, or create your own categories.';

  @override
  String get comUseTemplate => 'Use a template';

  @override
  String get comChooseSector => 'What is your business?';

  @override
  String get comTemplateApplied => 'Categories created';

  @override
  String get comAddSubCategory => 'Add a sub-category';

  @override
  String get comDisable => 'Hide';

  @override
  String get comEnable => 'Show';

  @override
  String get comSectorHardware => 'Hardware store';

  @override
  String get comSectorGrocery => 'Shop / grocery';

  @override
  String get comSectorSupermarket => 'Supermarket';

  @override
  String get comSectorTextile => 'Clothing and shoes';

  @override
  String get comSectorCosmetics => 'Cosmetics';

  @override
  String get comSectorElectronics => 'Phones and electronics';

  @override
  String get comCatOutils => 'Tools';

  @override
  String get comCatMateriaux => 'Building materials';

  @override
  String get comCatPeinture => 'Paint';

  @override
  String get comCatPeintureInterieur => 'Interior';

  @override
  String get comCatPeintureExterieur => 'Exterior';

  @override
  String get comCatPeinturePrimaire => 'Primer';

  @override
  String get comCatPeintureVernis => 'Varnish';

  @override
  String get comCatPlomberie => 'Plumbing';

  @override
  String get comCatElectricite => 'Electrical';

  @override
  String get comCatVisserie => 'Screws and bolts';

  @override
  String get comCatMenuiserie => 'Joinery';

  @override
  String get comCatAccessoires => 'Accessories';

  @override
  String get comCatCarrelage => 'Tiles';

  @override
  String get comCatBoissons => 'Drinks';

  @override
  String get comCatEpicerie => 'Groceries';

  @override
  String get comCatFrais => 'Fresh products';

  @override
  String get comCatBoulangerie => 'Bakery';

  @override
  String get comCatHygiene => 'Hygiene';

  @override
  String get comCatMenage => 'Household';

  @override
  String get comCatCosmetique => 'Beauty';

  @override
  String get comCatVetements => 'Clothing';

  @override
  String get comCatChaussures => 'Shoes';

  @override
  String get comCatTelephonie => 'Phones';

  @override
  String get comCatElectronique => 'Electronics';

  @override
  String get comCatPapeterie => 'Stationery';

  @override
  String get comMovementsTitle => 'Movements';

  @override
  String get comFamilyAll => 'All';

  @override
  String get comFamilyEntries => 'Entries';

  @override
  String get comFamilyExits => 'Exits';

  @override
  String get comFamilyTransfers => 'Transfers';

  @override
  String get comFamilyAdjustments => 'Adjustments';

  @override
  String get comFamilyLosses => 'Losses';

  @override
  String get comToday => 'Today';

  @override
  String get comYesterday => 'Yesterday';

  @override
  String comBy(String nom) {
    return 'by $nom';
  }

  @override
  String get comTypeEntry => 'Entry';

  @override
  String get comTypeExit => 'Exit';

  @override
  String get comTypeTransferOut => 'Transfer sent';

  @override
  String get comTypeTransferIn => 'Transfer received';

  @override
  String get comTypeInventory => 'Stock count';

  @override
  String get comMovementRejected => 'Rejected by the server';

  @override
  String get comEmptyMovementsTitle => 'No movements';

  @override
  String get comEmptyMovementsMessage =>
      'Entries, exits and transfers will appear here.';

  @override
  String get comRemoveRejected => 'Remove';

  @override
  String get comPeriodAll => 'All dates';

  @override
  String get comPeriodToday => 'Today';

  @override
  String get comPeriodWeek => 'Last 7 days';

  @override
  String get comPeriodMonth => 'Last 30 days';

  @override
  String get comStockTitle => 'Stock';

  @override
  String get comStockSubtitle =>
      'Track your products, quantities and movements.';

  @override
  String get comKpiProducts => 'Products';

  @override
  String get comKpiLow => 'Low stock';

  @override
  String get comKpiOut => 'Out of stock';

  @override
  String get comKpiMovesToday => 'Today\'s movements';

  @override
  String get comOrder => 'Order';

  @override
  String get comStockEmptyTitle => 'Your stock is still empty';

  @override
  String get comStockEmptyMessage => 'Start by adding your first product.';

  @override
  String get comNothingToReport => 'All good: everything is in stock.';

  @override
  String get comToWatch => 'To watch';

  @override
  String get comSeeMovements => 'See movements';

  @override
  String get comStockActions => 'What do you want to do?';

  @override
  String comWatchLow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products low on stock',
      one: '1 product low on stock',
    );
    return '$_temp0';
  }

  @override
  String comWatchOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products out of stock',
      one: '1 product out of stock',
    );
    return '$_temp0';
  }

  @override
  String get comPurchasesTitle => 'Purchases';

  @override
  String get comNewPurchase => 'New purchase';

  @override
  String get comEditPurchase => 'Edit purchase';

  @override
  String get comPurchaseEmptyTitle => 'No purchases yet';

  @override
  String get comPurchaseEmptyMessage =>
      'Record your purchases from suppliers: stock goes up when goods are received.';

  @override
  String get comFilterToReceive => 'To receive';

  @override
  String get comFilterReceived => 'Received';

  @override
  String get comFilterCancelled => 'Cancelled';

  @override
  String get comStatusOrdered => 'Ordered';

  @override
  String get comStatusPartlyReceived => 'Partly received';

  @override
  String get comStatusReceived => 'Received';

  @override
  String get comStatusCancelled => 'Cancelled';

  @override
  String get comSupplier => 'Supplier';

  @override
  String get comNoSupplierChosen => 'Choose the supplier (optional)';

  @override
  String get comPurchaseDate => 'Date';

  @override
  String get comSupplierReference => 'Invoice / note no. (optional)';

  @override
  String get comProducts => 'Products';

  @override
  String get comAddLine => 'Add a product';

  @override
  String comUnitPrice(String unite) {
    return 'Price per $unite';
  }

  @override
  String comLastPrice(String montant) {
    return 'Last price: $montant';
  }

  @override
  String get comTotal => 'Total';

  @override
  String get comSave => 'Save';

  @override
  String get comSaveAndReceive => 'Save and receive';

  @override
  String get comPurchaseSaved => 'Purchase saved';

  @override
  String get comReceive => 'Receive goods';

  @override
  String get comReceiveTitle => 'Receiving goods';

  @override
  String get comReceivedToday => 'Received today';

  @override
  String get comOrdered => 'Ordered';

  @override
  String get comAlreadyReceived => 'Already received';

  @override
  String get comRemaining => 'Remaining';

  @override
  String get comReceiveAll => 'All received';

  @override
  String get comNothingReceived => 'None';

  @override
  String get comConfirmReception => 'Confirm receipt';

  @override
  String get comReceptionDone => 'Goods received: stock updated';

  @override
  String get comStockImpact => 'Effect on stock';

  @override
  String get comReceptions => 'Receipts';

  @override
  String get comCancelPurchase => 'Cancel the purchase';

  @override
  String get comCancelPurchaseConfirm =>
      'Cancel this purchase? The amount owed to the supplier will be cancelled.';

  @override
  String get comDebt => 'Left to pay';

  @override
  String get comPaid => 'Paid';

  @override
  String get comPaySupplier => 'Pay the supplier';

  @override
  String get comFullyPaid => 'Fully paid';

  @override
  String comLinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
    );
    return '$_temp0';
  }

  @override
  String comPurchaseOf(String date) {
    return 'Purchase of $date';
  }

  @override
  String get comNoSupplier => 'No supplier';

  @override
  String get comEditLine => 'Edit line';

  @override
  String get comRemoveLine => 'Remove';

  @override
  String get comApply => 'Confirm';

  @override
  String get comSuppliersTitle => 'Suppliers';

  @override
  String get comSuppliersEmptyTitle => 'No suppliers yet';

  @override
  String get comSuppliersEmptyMessage =>
      'Add the people or companies you buy from.';

  @override
  String get comAddSupplier => 'Add a supplier';

  @override
  String get comTotalBought => 'Total bought';

  @override
  String get comLastPurchase => 'Last purchase';

  @override
  String get comSuppliedProducts => 'Products supplied';

  @override
  String get comPurchaseHistory => 'Purchase history';

  @override
  String get comCall => 'Call';

  @override
  String get comOpenContact => 'Contact card';

  @override
  String get comNeverBought => 'No purchase yet';

  @override
  String comPurchasesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count purchases',
      one: '1 purchase',
      zero: 'No purchases',
    );
    return '$_temp0';
  }

  @override
  String get comSalesTitle => 'Sell';

  @override
  String get comSalesHistory => 'Sales';

  @override
  String get comCart => 'Cart';

  @override
  String get comCartEmpty => 'Tap a product to add it to the cart.';

  @override
  String comCartCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get comCheckout => 'Checkout';

  @override
  String get comBestSellers => 'Best sellers';

  @override
  String get comPayment => 'Payment';

  @override
  String get comPayNow => 'Paid now';

  @override
  String get comOnCredit => 'On credit';

  @override
  String get comCustomer => 'Customer';

  @override
  String get comCustomerOptional => 'Customer (optional)';

  @override
  String get comDiscount => 'Discount';

  @override
  String get comToPay => 'To pay';

  @override
  String comSaleDone(String montant) {
    return 'Sale recorded: $montant';
  }

  @override
  String get comConfirmSale => 'Confirm the sale';

  @override
  String get comCashOpen => 'The money goes into the open cash drawer.';

  @override
  String get comNoCashOpen =>
      'No open cash drawer: the payment is recorded without one.';

  @override
  String comAvailable(String quantite) {
    return 'Available: $quantite';
  }

  @override
  String get comSalesEmptyTitle => 'No sales yet';

  @override
  String get comSalesEmptyMessage => 'Your sales will appear here.';

  @override
  String comSaleOf(String date) {
    return 'Sale of $date';
  }

  @override
  String get comCancelSale => 'Cancel the sale';

  @override
  String get comCancelSaleConfirm =>
      'Cancel this sale? The products go back into stock.';

  @override
  String get comCancelReason => 'Reason (optional)';

  @override
  String get comSaleCancelledDone => 'Sale cancelled';

  @override
  String get comCancelled => 'Cancelled';

  @override
  String get comSalesToday => 'Today\'s sales';

  @override
  String get comNoShopAllowed => 'You have no shop to sell from.';

  @override
  String get comClearCart => 'Empty the cart';

  @override
  String get comChangeUnit => 'Quantity and unit';

  @override
  String get comPrice => 'Price';

  @override
  String get comSeller => 'Seller';

  @override
  String get comNewSale => 'New sale';

  @override
  String get comStepProductUnits => 'Product and units';

  @override
  String get comStepPricesStock => 'Prices and stock';

  @override
  String get comProductInfo => 'The product';

  @override
  String get comProductInfoHint =>
      'A photo and a clear name help your sellers recognise it.';

  @override
  String get comPhotoShort => 'Photo';

  @override
  String get comHowCounted => 'How do you count this product?';

  @override
  String get comHowCountedHint =>
      'Pick the smallest quantity you sell: a piece, a bag, a litre…';

  @override
  String get comPackagingTitle => 'Do you also sell by carton, pack, bag…?';

  @override
  String get comPackagingHint2 =>
      'Add the packaging and what it holds: prices and stock are calculated for you.';

  @override
  String get comPackagingName => 'Packaging name';

  @override
  String comPackagingContains(String unite) {
    return 'Number of $unite in 1 packaging';
  }

  @override
  String get comRetailPrice => 'Retail selling price';

  @override
  String get comRetailPriceHint =>
      'The usual price for a customer. Choose the unit of this price.';

  @override
  String get comWholesalePrice => 'Wholesale selling price';

  @override
  String get comWholesalePriceHint =>
      'The price for bulk buyers, often per carton.';

  @override
  String get comPurchasePrice => 'Purchase price (optional)';

  @override
  String get comPurchasePriceHint =>
      'What you pay the supplier: to see your profit.';

  @override
  String get comPricePer => 'Price for 1:';

  @override
  String comEquivalentPrice(String montant, String unite) {
    return 'That is $montant per $unite';
  }

  @override
  String get comPriceSummary => 'Your prices, calculated for each unit';

  @override
  String get comAmountHint => 'Amount';

  @override
  String get comSaveChanges => 'Save changes';

  @override
  String get comStockAndAlert => 'Stock and alert';

  @override
  String get comSupplierNone => 'No supplier chosen';

  @override
  String get comReferenceHint => 'E.g. CAR-0012';

  @override
  String get comGenerateReference => 'Suggest a reference';

  @override
  String get comChooseCategory => 'Choose a category';

  @override
  String get comBarcodeLabel => 'Barcode';

  @override
  String get comBarcodeHint => 'Scan or type the code (optional)';

  @override
  String get comUnitPieceHelp => 'E.g. tile, bulb';

  @override
  String get rcpTitle => 'Receipts';

  @override
  String get rcpSaleReceipt => 'SALES RECEIPT';

  @override
  String get rcpNumberPending => 'Number assigned when synced';

  @override
  String get rcpSaleSaved => 'Sale recorded';

  @override
  String get rcpView => 'View receipt';

  @override
  String get rcpShare => 'Share';

  @override
  String get rcpPrint => 'Print';

  @override
  String get rcpPdf => 'PDF';

  @override
  String get rcpNewSale => 'New sale';

  @override
  String get rcpCounterCustomer => 'Walk-in customer';

  @override
  String get rcpSelectCustomer => 'Select';

  @override
  String get rcpAddName => 'Add a name';

  @override
  String get rcpCustomerName => 'Customer name';

  @override
  String get rcpPhoneOptional => 'Phone (optional)';

  @override
  String get rcpCreditNeedsCustomer =>
      'Credit sale: choose or add the customer.';

  @override
  String get rcpDeposit => 'Paid now (optional)';

  @override
  String get rcpDepositHint =>
      'Leave empty if the customer pays nothing today.';

  @override
  String get rcpSubtotal => 'Subtotal';

  @override
  String get rcpPaid => 'Amount paid';

  @override
  String get rcpRemaining => 'Remaining';

  @override
  String get rcpRemainingToPay => 'BALANCE DUE';

  @override
  String get rcpShop => 'Shop';

  @override
  String get rcpDate => 'Date';

  @override
  String get rcpTime => 'Time';

  @override
  String get rcpThanks => 'Thank you for your trust.';

  @override
  String get rcpTagline => 'Simple management for your business';

  @override
  String get rcpProduct => 'Product';

  @override
  String get rcpQty => 'Qty';

  @override
  String get rcpPrice => 'Price';

  @override
  String get rcpLineTotal => 'Total';

  @override
  String get rcpStatus => 'Status';

  @override
  String get rcpStatusValid => 'Valid';

  @override
  String get rcpStatusCancelled => 'Cancelled';

  @override
  String get rcpStatusCredit => 'On credit';

  @override
  String get rcpStatusPartial => 'Partly paid';

  @override
  String get rcpCancelledStamp => 'CANCELLED';

  @override
  String rcpCancelledInfo(String date, String nom) {
    return 'Cancelled on $date by $nom';
  }

  @override
  String get rcpEmptyTitle => 'No receipts yet';

  @override
  String get rcpEmptyMessage =>
      'Your receipts will appear here after your first sales.';

  @override
  String get rcpCreateSale => 'Create a sale';

  @override
  String get rcpNoResultTitle => 'No receipt found';

  @override
  String get rcpNoResultMessage => 'Try another number, customer or date.';

  @override
  String get rcpSearchHint => 'Receipt no., customer, phone, product…';

  @override
  String get rcpPeriodToday => 'Today';

  @override
  String get rcpPeriodYesterday => 'Yesterday';

  @override
  String get rcpPeriodWeek => 'This week';

  @override
  String get rcpPeriodMonth => 'This month';

  @override
  String get rcpPeriodCustom => 'Date range…';

  @override
  String get rcpPeriodAll => 'All';

  @override
  String get rcpAllSellers => 'All sellers';

  @override
  String get rcpAllPayments => 'All payments';

  @override
  String get rcpAllStatuses => 'All statuses';

  @override
  String get rcpCredit => 'Credit';

  @override
  String get rcpSales => 'Sales';

  @override
  String get rcpShops => 'Shops';

  @override
  String get rcpLatest => 'Latest sales';

  @override
  String get rcpSeeAll => 'See all receipts';

  @override
  String get rcpFilters => 'Filters';

  @override
  String get rcpReset => 'Clear filters';

  @override
  String get rcpTraceability => 'History';

  @override
  String rcpCreatedBy(String nom) {
    return 'Sale recorded by $nom';
  }

  @override
  String get rcpOnDevice => 'Saved on the device, waiting to be sent';

  @override
  String rcpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count receipts',
      one: '1 receipt',
      zero: 'No receipts',
    );
    return '$_temp0';
  }

  @override
  String get expenseCatFuel => 'Fuel';

  @override
  String get expenseCatWater => 'Water';

  @override
  String get expenseCatInternet => 'Phone and internet';

  @override
  String get expenseCatRepair => 'Repairs';

  @override
  String get expenseCatCleaning => 'Cleaning';

  @override
  String get expenseCatSecurity => 'Security guard';

  @override
  String get expenseCatDelivery => 'Delivery';

  @override
  String get expenseCatBankFees => 'Bank fees';

  @override
  String get expenseCatInsurance => 'Insurance';

  @override
  String get cashNatureContribution => 'Owner contribution';

  @override
  String get cashNatureWithdrawal => 'Withdrawal';

  @override
  String get cashNatureTransfer => 'Transfer';

  @override
  String get cashNatureRefund => 'Refund';

  @override
  String get cashNatureAdjustment => 'Adjustment';

  @override
  String get cashNatureOpeningBalance => 'Opening balance';

  @override
  String get cashNatureOther => 'Other';

  @override
  String get cashGapReasonChange => 'Change given incorrectly';

  @override
  String get cashGapReasonUnrecorded => 'Unrecorded expense';

  @override
  String get cashGapReasonCounting => 'Counting error';

  @override
  String get cashGapReasonOther => 'Other';

  @override
  String cashGapJustify(String amount) {
    return 'A difference of $amount was found. Please explain it.';
  }

  @override
  String get cashGapNoteRequired => 'Explanation (required)';

  @override
  String get cashOperationReason => 'Reason';

  @override
  String get cashTransferTitle => 'Transfer';

  @override
  String get cashTransferFrom => 'From';

  @override
  String get cashTransferTo => 'To';

  @override
  String get cashTransferSame => 'Source and destination must be different.';

  @override
  String get cashTransferDone => 'Transfer recorded';

  @override
  String get cashTransferCancel => 'Cancel transfer';

  @override
  String get cashCompanyLevel => 'Company (no shop)';

  @override
  String get cashIn => 'Money in';

  @override
  String get cashOut => 'Money out';

  @override
  String get cashSite => 'Shop / site';

  @override
  String get cashScreenSubtitle =>
      'Track your money in, money out and balance.';

  @override
  String get cashAllShops => 'All shops';

  @override
  String get cashAvailable => 'Available balance';

  @override
  String get cashShowAmounts => 'Show amounts';

  @override
  String get cashHideAmounts => 'Hide amounts';

  @override
  String get cashCashOnHand => 'Cash in register';

  @override
  String get cashIncoming => 'Money in';

  @override
  String get cashOutgoing => 'Money out';

  @override
  String get cashNet => 'Change';

  @override
  String cashOperationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count operations',
      one: '1 operation',
      zero: 'No operations',
    );
    return '$_temp0';
  }

  @override
  String get cashAddOperation => 'Add an operation';

  @override
  String get cashBalanceTrend => 'Balance trend';

  @override
  String get cashInBreakdown => 'Where the money comes from';

  @override
  String get cashOutBreakdown => 'Where the money goes';

  @override
  String get cashByMode => 'Payment methods';

  @override
  String get cashComparison => 'Comparison';

  @override
  String get cashPreviousPeriod => 'Previous period';

  @override
  String get cashByShop => 'By shop';

  @override
  String get cashOperationsHistory => 'Operations';

  @override
  String get cashSearchHint => 'Search an operation…';

  @override
  String get cashFilterAll => 'All';

  @override
  String get cashReadyTitle => 'Your cash register is ready';

  @override
  String get cashReadyMessage =>
      'Sales, payments and expenses will appear here automatically.';

  @override
  String get cashNoDataPeriod => 'No data for this period.';

  @override
  String get cashBalanced => 'Balanced';

  @override
  String get cashGapLarge => 'Large difference';

  @override
  String get periodToday => 'Today';

  @override
  String get periodYesterday => 'Yesterday';

  @override
  String get periodThisWeek => 'This week';

  @override
  String get periodThisMonth => 'This month';

  @override
  String get periodThisYear => 'This year';

  @override
  String get periodAll => 'All';

  @override
  String get periodCustom => 'Custom';

  @override
  String get period7Days => '7 d';

  @override
  String get period30Days => '30 d';

  @override
  String get period3Months => '3 mo';

  @override
  String get cashSrcSale => 'Sale';

  @override
  String get cashSrcCustomerPayment => 'Customer payment';

  @override
  String get cashSrcService => 'Service';

  @override
  String get cashSrcRent => 'Rent';

  @override
  String get cashSrcPurchase => 'Purchase';

  @override
  String get cashSrcSupplierPayment => 'Supplier payment';

  @override
  String get cashSrcExpense => 'Expense';

  @override
  String cashAlertGap(String amount, String register) {
    return 'Difference of $amount at the last closing of $register.';
  }

  @override
  String cashAlertOutflowsUp(int percent) {
    return 'Money out up $percent% compared with last week.';
  }

  @override
  String get cashDetailDate => 'Date and time';

  @override
  String get cashDetailSource => 'Source';

  @override
  String get cashDetailReference => 'Reference';

  @override
  String get cashDetailContact => 'Customer / supplier';

  @override
  String get cashDetailOpen => 'View details';

  @override
  String get cashCancelOperation => 'Cancel operation';

  @override
  String get cashCancelReason => 'Reason for cancellation';

  @override
  String get cashPending => 'Waiting to be sent';

  @override
  String get financeManage => 'Manage your finances';

  @override
  String get periodDay => 'Day';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodYear => 'Year';

  @override
  String get periodDates => 'Dates';

  @override
  String get periodPrevious => 'Previous';

  @override
  String get periodNext => 'Next';

  @override
  String get periodChooseDates => 'Choose dates';

  @override
  String get expenseTotalPeriod => 'Total for the period';

  @override
  String expensesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
      zero: 'No expenses',
    );
    return '$_temp0';
  }

  @override
  String get servicesTitle => 'Services & Interventions';

  @override
  String get servicesSubtitle =>
      'Simple management of your services and quotes';

  @override
  String get prestationsTitle => 'Services';

  @override
  String get planningServicesTitle => 'Intervention schedule';

  @override
  String get catalogueServicesTitle => 'Service catalog';

  @override
  String get devisServicesTitle => 'Service quotes';

  @override
  String get statutAFaire => 'To do';

  @override
  String get statutPlanifiee => 'Scheduled';

  @override
  String get statutEnCours => 'In progress';

  @override
  String get statutTerminee => 'Completed';

  @override
  String get statutLivree => 'Delivered';

  @override
  String get statutAnnulee => 'Cancelled';

  @override
  String get prioriteFaible => 'Low / Upcoming';

  @override
  String get prioriteAttentionJ2 => 'Warning (D-2)';

  @override
  String get prioriteUrgentJ1 => 'Urgent (D-1)';

  @override
  String get prioriteAujourdhui => 'Due today';

  @override
  String get prioriteEnRetard => 'Overdue';

  @override
  String get nouvellePrestation => 'New service';

  @override
  String get nouveauDevisService => 'New quote';

  @override
  String get nouveauServiceCatalogue => 'New catalog service';

  @override
  String get convertirDevisEnPrestation => 'Convert to service';

  @override
  String get demarrerTravail => 'Start';

  @override
  String get terminerTravail => 'Complete';

  @override
  String get livrerPrestation => 'Deliver to client';

  @override
  String get reporterEcheance => 'Postpone due date';

  @override
  String get motifReport => 'Postponement reason';

  @override
  String get uniteForfait => 'Flat rate';

  @override
  String get uniteHeure => 'Per hour';

  @override
  String get uniteJour => 'Per day';

  @override
  String get uniteM2 => 'Per m²';

  @override
  String get uniteKm => 'Per km';

  @override
  String get unitePiece => 'Per piece';

  @override
  String get statutDevisBrouillon => 'Draft';

  @override
  String get statutDevisEmis => 'Issued';

  @override
  String get statutDevisAccepte => 'Accepted';

  @override
  String get statutDevisRefuse => 'Declined';

  @override
  String get statutDevisConverti => 'Converted to service';

  @override
  String get rapportsServicesTitle => 'Services Reports & Profitability';

  @override
  String get performanceFinanciere => 'Financial Performance';

  @override
  String get totalFacture => 'Total Invoiced';

  @override
  String get totalEncaisse => 'Total Collected';

  @override
  String get aRecouvrer => 'To Collect';

  @override
  String get tauxRecouvrement => 'Collection Rate';

  @override
  String get ventilationMainOeuvrePieces => 'Breakdown of Invoiced Value';

  @override
  String get mainOeuvre => 'Labor / Services';

  @override
  String get piecesStock => 'Inventory Parts';

  @override
  String get transformationDevis => 'Quote Conversion';

  @override
  String get bonPriseEnCharge => 'Receipt / Intake Slip';

  @override
  String get rappelClient => 'Client Reminder';

  @override
  String get envoyerWhatsApp => 'Send WhatsApp';
}
