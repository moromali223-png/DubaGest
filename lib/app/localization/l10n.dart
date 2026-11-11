import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../core/errors/failure.dart';
import '../../core/permissions/access_decision.dart';
import '../../features/abonnement/domain/entities/abonnement.dart';
import '../../features/activites/domain/entities/activite.dart';
import '../../features/contacts/domain/entities/contact.dart';
import '../../features/invitations/domain/entities/invitation.dart';
import '../../features/perimetres/domain/entities/perimetre.dart';
import '../../features/roles/domain/entities/role.dart';
import '../../features/services/domain/entities/prestation.dart';
import '../../features/services/domain/entities/service_catalogue.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Libellés traduits des codes de catalogue et messages d'erreur.
/// Aucun code technique n'est affiché tel quel à l'utilisateur.
extension AppLabels on AppLocalizations {
  String activite(ActiviteCode a) => switch (a) {
        ActiviteCode.commerce => activityCommerce,
        ActiviteCode.services => activityServices,
        ActiviteCode.immobilier => activityImmobilier,
      };

  String activiteCode(Object? code) {
    final a = ActiviteCode.tryParse(code as String?);
    return a == null ? (code?.toString() ?? '') : activite(a);
  }

  String role(String code) => switch (code.toUpperCase()) {
        RoleCodes.administrateur => roleAdministrateur,
        RoleCodes.superviseur => roleSuperviseur,
        RoleCodes.gestionnaireStock => roleGestionnaireStock,
        RoleCodes.vendeur => roleVendeur,
        RoleCodes.caissier => roleCaissier,
        RoleCodes.gestionnaireImmobilier => roleGestionnaireImmobilier,
        'GESTIONNAIRE_SERVICES' => 'Gestionnaire de services',
        'PRESTATAIRE' => 'Prestataire de services',
        _ => code,
      };

  String plan(String? code) => switch (code) {
        'NORMAL' => planNormal,
        'MOYEN' => planMoyen,
        'PRO' => planPro,
        _ => code ?? '',
      };

  String abonnementStatut(AbonnementStatut s) => switch (s) {
        AbonnementStatut.essai => subscriptionStatusEssai,
        AbonnementStatut.actif => subscriptionStatusActif,
        AbonnementStatut.suspendu => subscriptionStatusSuspendu,
        AbonnementStatut.expire => subscriptionStatusExpire,
        AbonnementStatut.annule => subscriptionStatusAnnule,
      };

  String invitationStatut(InvitationStatut s) => switch (s) {
        InvitationStatut.pending => invitationStatusPending,
        InvitationStatut.accepted => invitationStatusAccepted,
        InvitationStatut.expired => invitationStatusExpired,
        InvitationStatut.cancelled => invitationStatusCancelled,
        InvitationStatut.invalid => ruleInvitationInvalid,
      };

  /// Raison lisible pour un aperçu d'invitation non acceptable.
  String invitationRefus(InvitationStatut s) => switch (s) {
        InvitationStatut.expired => ruleInvitationExpired,
        InvitationStatut.accepted => ruleInvitationUsed,
        InvitationStatut.cancelled => ruleInvitationCancelled,
        _ => ruleInvitationInvalid,
      };

  String typePerimetre(PerimetreType t) => switch (t) {
        PerimetreType.boutique => perimetreTypeBoutique,
        PerimetreType.agence => perimetreTypeAgence,
        PerimetreType.site => perimetreTypeSite,
        PerimetreType.unite => perimetreTypeUnite,
      };

  String relationContact(RelationContact r) => switch (r) {
        RelationContact.client => contactRelationClient,
        RelationContact.fournisseur => contactRelationFournisseur,
        RelationContact.locataire => contactRelationLocataire,
        RelationContact.proprietaire => contactRelationProprietaire,
        RelationContact.prestataire => contactRelationPrestataire,
      };

  String statutPrestation(StatutPrestation s) => switch (s) {
        StatutPrestation.aFaire => statutAFaire,
        StatutPrestation.planifiee => statutPlanifiee,
        StatutPrestation.enCours => statutEnCours,
        StatutPrestation.terminee => statutTerminee,
        StatutPrestation.livree => statutLivree,
        StatutPrestation.annulee => statutAnnulee,
      };

  String statutDevis(StatutDevis s) => switch (s) {
        StatutDevis.brouillon => statutDevisBrouillon,
        StatutDevis.envoye => statutDevisEmis,
        StatutDevis.accepte => statutDevisAccepte,
        StatutDevis.refuse => statutDevisRefuse,
        StatutDevis.expire => statutDevisRefuse,
        StatutDevis.converti => statutDevisConverti,
      };

  String uniteFacturation(UniteFacturation u) => switch (u) {
        UniteFacturation.forfait => uniteForfait,
        UniteFacturation.heure => uniteHeure,
        UniteFacturation.jour => uniteJour,
        UniteFacturation.piece => unitePiece,
        UniteFacturation.m2 => uniteM2,
        UniteFacturation.km => uniteKm,
      };

  String prioriteEcheance(PrioriteEcheance p) => switch (p) {
        PrioriteEcheance.faible => prioriteFaible,
        PrioriteEcheance.attention => prioriteAttentionJ2,
        PrioriteEcheance.urgent => prioriteUrgentJ1,
        PrioriteEcheance.aujourdhui => prioriteAujourdhui,
        PrioriteEcheance.enRetard => prioriteEnRetard,
      };

  String module(String code) => switch (code) {
        'admin.entreprise' => moduleAdminEntreprise,
        'admin.utilisateurs' => moduleAdminUtilisateurs,
        'admin.perimetres' => moduleAdminPerimetres,
        'admin.abonnement' => moduleAdminAbonnement,
        'admin.audit' => moduleAdminAudit,
        'commun.contacts' => moduleCommunContacts,
        'commun.documents' => moduleCommunDocuments,
        'commun.agenda' => moduleCommunAgenda,
        'commun.rapports' => moduleCommunRapports,
        'commerce.produits' => moduleCommerceProduits,
        'commerce.stock' => moduleCommerceStock,
        'commerce.ventes' => moduleCommerceVentes,
        'commerce.achats' => moduleCommerceAchats,
        'commerce.fournisseurs' => moduleCommerceFournisseurs,
        'commerce.intelligence' => 'Intelligence commerciale',
        'commerce.benefice' => 'Bénéfice commercial',
        'finances.creances' => moduleFinancesCreances,
        'finances.paiements' => moduleFinancesPaiements,
        'finances.caisse' => moduleFinancesCaisse,
        'finances.depenses' => moduleFinancesDepenses,
        'services.services' => moduleServicesServices,
        'services.prestations' => moduleServicesPrestations,
        'services.planning' => moduleServicesPlanning,
        'services.devis' => moduleServicesDevis,
        'services.facturation' => moduleServicesFacturation,
        'services.rapports' => moduleServicesRapports,
        'immobilier.biens' => moduleImmobilierBiens,
        'immobilier.proprietaires' => moduleImmobilierProprietaires,
        'immobilier.locataires' => moduleImmobilierLocataires,
        'immobilier.locations' => moduleImmobilierLocations,
        'immobilier.contrats' => moduleImmobilierContrats,
        'immobilier.loyers' => moduleImmobilierLoyers,
        _ => code,
      };

  /// Libellé court pour les tuiles (accueil, « Plus ») où la place manque.
  String moduleCourt(String code) => switch (code) {
        'finances.creances' => moduleFinancesCreancesCourt,
        'commerce.intelligence' => 'Intelligence',
        'commerce.benefice' => 'Bénéfice',
        _ => module(code),
      };

  String decision(AccessDenied denied) => rule(denied.ruleCode, denied.params);

  String failure(Object error) {
    final f = error is Failure ? error : Failure(FailureKind.unknown, cause: error);
    return switch (f.kind) {
      FailureKind.businessRule => rule(f.ruleCode ?? '', f.params),
      FailureKind.network => errorNetwork,
      FailureKind.invalidCredentials => errorInvalidCredentials,
      FailureKind.emailNotConfirmed => errorEmailNotConfirmed,
      FailureKind.accountExists => errorAccountExists,
      FailureKind.weakPassword => errorWeakPassword,
      FailureKind.oauthUnavailable => errorOauthUnavailable,
      FailureKind.rateLimited => errorRateLimited,
      FailureKind.sessionExpired => errorSessionExpired,
      FailureKind.forbidden => errorForbidden,
      FailureKind.notFound => errorNotFound,
      FailureKind.conflict => errorConflict,
      FailureKind.duplicate => errorDuplicate,
      FailureKind.server => errorServer,
      FailureKind.localStorage => errorLocalStorage,
      FailureKind.unknown => errorUnknown,
    };
  }

  String rule(String code, Map<String, Object?> params) {
    final planLabel = plan(params['plan'] as String?);
    final max = (params['max'] as num?)?.toInt() ?? 0;
    return switch (code) {
      RuleCodes.subscriptionInactive => ruleSubscriptionInactive,
      RuleCodes.activityNotAllowed => ruleActivityNotAllowed(planLabel),
      RuleCodes.activityInactive => ruleActivityInactive,
      RuleCodes.activitiesLimit => ruleActivitiesLimit(planLabel, max),
      RuleCodes.usersLimit => ruleUsersLimit(planLabel, max),
      RuleCodes.roleLimit => ruleRoleLimit(planLabel, max, role('${params['role']}')),
      RuleCodes.perimetresLimit =>
        rulePerimetresLimit(planLabel, max, activiteCode(params['activite'])),
      RuleCodes.roleNotAllowed => ruleRoleNotAllowed(planLabel),
      RuleCodes.roleActivityInactive => ruleRoleActivityInactive,
      RuleCodes.moduleNotInPlan => ruleModuleNotInPlan,
      RuleCodes.permissionDenied => rulePermissionDenied,
      RuleCodes.perimetreDenied => rulePerimetreDenied,
      RuleCodes.lastAdmin => ruleLastAdmin,
      RuleCodes.assignmentNotNeeded => ruleAssignmentNotNeeded,
      RuleCodes.assignmentActivityMismatch => ruleAssignmentActivityMismatch,
      RuleCodes.immutable => ruleImmutable,
      RuleCodes.companyAlreadyCreated => ruleCompanyAlreadyCreated,
      RuleCodes.planInvalid => rulePlanInvalid,
      RuleCodes.activityRequired => ruleActivityRequired,
      RuleCodes.nameInvalid => ruleNameInvalid,
      RuleCodes.emailInvalid => validationEmail,
      RuleCodes.alreadyMember => ruleAlreadyMember,
      RuleCodes.perimetreRequired => rulePerimetreRequired,
      RuleCodes.invitationInvalid => ruleInvitationInvalid,
      RuleCodes.invitationExpired => ruleInvitationExpired,
      RuleCodes.invitationUsed => ruleInvitationUsed,
      RuleCodes.invitationCancelled => ruleInvitationCancelled,
      RuleCodes.invitationOtherEmail => ruleInvitationOtherEmail,
      RuleCodes.invitationNotCancellable => ruleInvitationNotCancellable,
      RuleCodes.emailNotConfirmed => ruleEmailNotConfirmed,
      RuleCodes.textTooLong => ruleTextTooLong(max),
      RuleCodes.labelInvalid => ruleLabelInvalid,
      RuleCodes.amountInvalid => validationAmount,
      RuleCodes.commitmentCancelled => ruleCommitmentCancelled,
      RuleCodes.commitmentPaid => ruleCommitmentPaid,
      RuleCodes.totalBelowPaid => ruleTotalBelowPaid(nombre(_n(params['regle']))),
      RuleCodes.amountAboveRemaining => ruleAmountAboveRemaining(nombre(_n(params['reste']))),
      RuleCodes.allocationAbovePayment => ruleAllocationAbovePayment,
      RuleCodes.allocationWrongDirection => ruleAllocationWrongDirection,
      RuleCodes.allocationOtherContact => ruleAllocationOtherContact,
      RuleCodes.paymentAlreadyCancelled => rulePaymentAlreadyCancelled,
      RuleCodes.modeWithoutCash => ruleModeWithoutCash,
      RuleCodes.dateInvalid => ruleDateInvalid,
      RuleCodes.cashClosed => ruleCashClosed,
      RuleCodes.cashOpenSession => ruleCashOpenSession,
      RuleCodes.cashAlreadyOpen => ruleCashAlreadyOpen,
      RuleCodes.cashInactive => ruleCashInactive,
      RuleCodes.cashInsufficient => ruleCashInsufficient(nombre(_n(params['solde']))),
      RuleCodes.commitmentLinked => ruleCommitmentLinked,
      RuleCodes.categoryInvalid => ruleCategoryInvalid,
      RuleCodes.expensePaid => ruleExpensePaid,
      RuleCodes.expenseCancelled => ruleExpenseCancelled,
      RuleCodes.documentExists => ruleDocumentExists,
      RuleCodes.documentOriginInvalid => ruleDocumentOriginInvalid,
      RuleCodes.documentNumbersExhausted => ruleDocumentNumbersExhausted,
      _ when RuleCodes.documentNumberInvalid.contains(code) => ruleDocumentNumberInvalid,
      RuleCodes.assigneeInvalid => ruleAssigneeInvalid,
      RuleCodes.targetInvalid => ruleTargetInvalid,
      RuleCodes.fileTypeInvalid => ruleFileTypeInvalid,
      RuleCodes.fileTooLarge => ruleFileTooLarge(max),
      RuleCodes.filePathInvalid => ruleFinanceInconsistent,
      RuleCodes.paymentModesInvalid => rulePaymentModesInvalid,
      RuleCodes.paymentModeDisabled => rulePaymentModeDisabled,
      _ when RuleCodes.financeInconsistent.contains(code) => ruleFinanceInconsistent,
      RuleCodes.stockInsufficient => ruleStockInsufficient(_quantite(params['disponible'], params['unite'])),
      RuleCodes.quantityInvalid => ruleQuantityInvalid,
      RuleCodes.fractionInvalid =>
        ruleFractionInvalid(_quantite(params['pas'], null), '${params['unite'] ?? ''}'.trim()),
      RuleCodes.unitInvalid => ruleUnitInvalid,
      RuleCodes.barcodeExists => ruleBarcodeExists,
      RuleCodes.transferSameShop => ruleTransferSameShop,
      RuleCodes.shopRequired => ruleShopRequired,
      RuleCodes.linesInvalid => ruleLinesInvalid,
      RuleCodes.receptionAboveOrdered => ruleReceptionAbove(_quantite(params['reste'], null)),
      RuleCodes.purchaseReceived => rulePurchaseReceived,
      RuleCodes.purchasePaid => rulePurchasePaid,
      RuleCodes.purchaseCancelled => rulePurchaseCancelled,
      RuleCodes.saleCancelled => ruleSaleCancelled,
      RuleCodes.salePaid => ruleSalePaid,
      RuleCodes.customerRequired => ruleCustomerRequired,
      RuleCodes.movementInvalid => ruleFinanceInconsistent,
      RuleCodes.discrepancyJustificationRequired => 'Une note explicative est obligatoire pour tout écart d\'inventaire constaté.',
      RuleCodes.productUsed => 'Ce produit ne peut pas être supprimé car il possède un historique d\'opérations (ventes, achats ou stock).',
      _ => errorUnknown,
    };
  }

  /// Quantité d'un message de refus (« 5 », « 2,5 sacs »), selon la langue.
  String _quantite(Object? valeur, Object? unite) {
    final texte = valeur is num
        ? NumberFormat('#,##0.####', localeName).format(valeur)
        : (valeur is String ? (num.tryParse(valeur) == null ? valeur : NumberFormat('#,##0.####', localeName).format(num.parse(valeur))) : '0');
    return unite == null ? texte : '$texte $unite';
  }

  int _n(Object? v) => (v as num?)?.toInt() ?? 0;

  /// « 3 / 7 », ou « 3 · illimité » quand la formule n'a pas de limite.
  String usage(int used, int? max) =>
      max == null ? subscriptionUsageUnlimited(used) : subscriptionUsageValue(used, max);

  /// Nombre entier formaté selon la langue (séparateurs de milliers).
  String nombre(int valeur) => NumberFormat.decimalPattern(localeName).format(valeur);

  /// Montant entier dans la devise de l'entreprise, formaté selon la langue.
  String montant(int valeur, String devise) =>
      '${NumberFormat.decimalPattern(localeName).format(valeur)} ${devise == 'XOF' ? 'FCFA' : devise}';

  /// Date au format de la langue courante.
  String date(DateTime value) => DateFormat.yMMMMd(localeName).format(value.toLocal());

  /// Délai lisible : « 15 min », « 1 h », « 1 jour ».
  String delai(int minutes) => minutes % 1440 == 0 && minutes > 0
      ? agendaDelayDays(minutes ~/ 1440)
      : minutes % 60 == 0 && minutes > 0
          ? agendaDelayHours(minutes ~/ 60)
          : agendaDelayMinutes(minutes);

  /// « octobre 2026 », selon la langue.
  String mois(DateTime value) => DateFormat.yMMMM(localeName).format(value);

  String dateTime(DateTime value) => DateFormat.yMMMd(localeName).add_Hm().format(value.toLocal());

  // --- Subscriptions & Payments Localization ---
  String get subscriptionChoosePlanTitle => switch (localeName) {
        'ar' => 'باقات اشتراك دباجيست',
        'en' => 'DubaGest Subscription Plans',
        _ => 'Formules d\'abonnement DubaGest',
      };

  String get subscriptionChoosePlanSubtitle => switch (localeName) {
        'ar' => 'اختر باقتك المثالية للعمل',
        'en' => 'Select your ideal plan',
        _ => 'Sélectionnez votre formule idéale',
      };

  String get subscriptionPaymentTitle => switch (localeName) {
        'ar' => 'تسوية ودفع الاشتراك',
        'en' => 'Subscription Payment',
        _ => 'Règlement de l\'abonnement',
      };

  String get subscriptionPaymentTabPay => switch (localeName) {
        'ar' => 'اشتراك / تجديد',
        'en' => 'Subscribe / Renew',
        _ => 'Souscrire / Renouveler',
      };

  String get subscriptionPaymentTabHistory => switch (localeName) {
        'ar' => 'سجل المدفوعات',
        'en' => 'Payment History',
        _ => 'Historique des paiements',
      };

  String get subscriptionTrialActiveTitle => switch (localeName) {
        'ar' => 'فترة تجربة مجانية لمدة 10 أيام جارية',
        'en' => '10-day free trial period in progress',
        _ => 'Période d\'essai gratuit de 10 jours en cours',
      };

  String subscriptionTrialRemainingDays(int days) => switch (localeName) {
        'ar' => 'تبقى لك $days يوم من التجربة المجانية.',
        'en' => 'You have $days day(s) of free trial remaining.',
        _ => 'Il vous reste $days jour(s) d\'essai gratuit.',
      };

  String get subscriptionTrialEndedTitle => switch (localeName) {
        'ar' => 'انتهت فترة التجربة المجانية (10 أيام)',
        'en' => '10-day free trial ended',
        _ => 'Période d\'essai de 10 jours terminée',
      };

  String get subscriptionTrialEndedDesc => switch (localeName) {
        'ar' => 'انتهت فترة التجربة المجانية. بيانات شركتك محفوظة بأمان تام. اختر باقتك وسدد اشتراكك للمتابعة دون انقطاع.',
        'en' => 'Your 10-day free trial has ended. Your business data is safely preserved. Choose your plan and settle payment to continue without interruption.',
        _ => 'Vos 10 jours d\'essai gratuit ont pris fin. Vos données d\'entreprise sont précieusement conservées. Choisissez votre formule et réglez votre abonnement pour continuer sans interruption.',
      };

  String get subscriptionExpiredTitle => switch (localeName) {
        'ar' => 'انتهت صلاحية الاشتراك — يرجى إعادة الاشتراك',
        'en' => 'Subscription expired — Renewal required',
        _ => 'Abonnement expiré — Réabonnement requis',
      };

  String get subscriptionExpiredDesc => switch (localeName) {
        'ar' => 'انتهى اشتراك شركتك. جميع بياناتك ومستخدميك وسجلاتك محفوظة بالكامل. يرجى تجديد اشتراكك الآن.',
        'en' => 'Your company subscription has expired. All your data, users and history are safely preserved. Renew your subscription now.',
        _ => 'L\'abonnement de votre entreprise est arrivé à expiration. Toutes vos données, utilisateurs et historiques sont soigneusement conservés. Renouvelez votre abonnement dès maintenant.',
      };

  String subscriptionActiveBanner(String planCode) => switch (localeName) {
        'ar' => 'اشتراك نشط: باقة ${plan(planCode)}',
        'en' => 'Active subscription: ${plan(planCode)} Plan',
        _ => 'Abonnement actif : Formule ${plan(planCode)}',
      };

  String subscriptionActiveRemaining(int days) => switch (localeName) {
        'ar' => 'تبقى لك $days يوم في فترة اشتراكك الحالية.',
        'en' => 'You have $days day(s) remaining on your active period.',
        _ => 'Il vous reste $days jour(s) sur votre période active.',
      };

  String get subscriptionChangePlan => switch (localeName) {
        'ar' => 'تغيير الباقة',
        'en' => 'Change plan',
        _ => 'Changer de formule',
      };

  String get subscriptionSelectedPlan => switch (localeName) {
        'ar' => 'الباقة المختارة',
        'en' => 'Selected plan',
        _ => 'Formule choisie',
      };

  String get subscriptionCurrentPlan => switch (localeName) {
        'ar' => 'الباقة الحالية',
        'en' => 'Current plan',
        _ => 'Formule actuelle',
      };

  String get subscriptionDuration => switch (localeName) {
        'ar' => 'مدة الاشتراك',
        'en' => 'Subscription duration',
        _ => 'Durée de l\'abonnement',
      };

  String get subscriptionPaymentMethod => switch (localeName) {
        'ar' => 'طريقة الدفع',
        'en' => 'Payment method',
        _ => 'Moyen de paiement',
      };

  String get subscriptionOrderSummary => switch (localeName) {
        'ar' => 'ملخص الطلب',
        'en' => 'Order summary',
        _ => 'Récapitulatif de la commande',
      };

  String get subscriptionTotalToPay => switch (localeName) {
        'ar' => 'المبلغ الإجمالي للدفع',
        'en' => 'Total to pay',
        _ => 'Total à régler',
      };

  String get subscriptionValidatePlanButton => switch (localeName) {
        'ar' => 'تأكيد والانتقال إلى الدفع',
        'en' => 'Confirm and proceed to payment',
        _ => 'Valider et passer au règlement',
      };

  String get subscriptionNoPaymentTriggered => switch (localeName) {
        'ar' => 'لن يتم إجراء أي خصم في هذه الصفحة.',
        'en' => 'No charge will be made on this page.',
        _ => 'Aucun prélèvement ne sera effectué sur cette page.',
      };

  String get subscriptionDataSafeNotice => switch (localeName) {
        'ar' => 'جميع بياناتك وإعداداتك وسجلاتك محفوظة دون أي فقدان.',
        'en' => 'All your data, settings and history are preserved without any loss.',
        _ => 'Toutes vos données, configurations et historiques sont conservés sans aucune perte.',
      };

  String subscriptionPendingMobilePrompt(String provider) => switch (localeName) {
        'ar' => 'يرجى تأكيد المعاملة على هاتفك المحمول ($provider)...',
        'en' => 'Please validate the transaction on your mobile phone ($provider)...',
        _ => 'Veuillez valider la transaction sur votre téléphone mobile ($provider)...',
      };

  String get subscriptionCancelTransaction => switch (localeName) {
        'ar' => 'إلغاء المعاملة',
        'en' => 'Cancel transaction',
        _ => 'Annuler la transaction',
      };

  String get subscriptionCheckStatus => switch (localeName) {
        'ar' => 'التحقق من حالة الدفع',
        'en' => 'Check payment status',
        _ => 'Vérifier le statut du paiement',
      };

  String get subscriptionBackToPlans => switch (localeName) {
        'ar' => 'الرجوع للباقات',
        'en' => 'Back to plans',
        _ => 'Retour aux formules',
      };

  String get subscriptionRenewalsHistoryTitle => switch (localeName) {
        'ar' => 'سجل التجديدات',
        'en' => 'Renewal history',
        _ => 'Historique des renouvellements',
      };

  String get subscriptionEmptyHistory => switch (localeName) {
        'ar' => 'لا يوجد سجل مدفوعات حتى الآن.',
        'en' => 'No payment history yet.',
        _ => 'Aucun historique de paiement pour le moment.',
      };
}
