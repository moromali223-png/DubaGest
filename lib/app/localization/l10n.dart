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
import '../../features/services/domain/services/moteur_echeances.dart';
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

  String role(String code) => switch (code) {
        RoleCodes.administrateur => roleAdministrateur,
        RoleCodes.superviseur => roleSuperviseur,
        RoleCodes.gestionnaireStock => roleGestionnaireStock,
        RoleCodes.vendeur => roleVendeur,
        RoleCodes.caissier => roleCaissier,
        RoleCodes.gestionnaireImmobilier => roleGestionnaireImmobilier,
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
}
