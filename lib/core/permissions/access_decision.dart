import '../errors/failure.dart';

/// Codes de refus partagés avec PostgreSQL (`app.refuser`) : une seule
/// traduction pour une décision locale et une erreur serveur.
abstract final class RuleCodes {
  static const subscriptionInactive = 'ABONNEMENT_INACTIF';
  static const activityNotAllowed = 'ACTIVITE_NON_AUTORISEE';
  static const activityInactive = 'ACTIVITE_INACTIVE';
  static const activitiesLimit = 'LIMITE_ACTIVITES';
  static const usersLimit = 'LIMITE_UTILISATEURS';
  static const roleLimit = 'LIMITE_ROLE';
  static const perimetresLimit = 'LIMITE_PERIMETRES';
  static const roleNotAllowed = 'ROLE_NON_AUTORISE';
  static const roleActivityInactive = 'ROLE_ACTIVITE_INACTIVE';
  static const lastAdmin = 'DERNIER_ADMINISTRATEUR';
  static const immutable = 'PERIMETRE_IMMUABLE';
  static const assignmentActivityMismatch = 'AFFECTATION_ACTIVITE_INCOMPATIBLE';
  static const assignmentNotNeeded = 'AFFECTATION_INUTILE';

  // Création d'entreprise et invitations.
  static const companyAlreadyCreated = 'ENTREPRISE_DEJA_CREEE';
  static const planInvalid = 'PLAN_INVALIDE';
  static const activityRequired = 'ACTIVITE_REQUISE';
  static const nameInvalid = 'NOM_INVALIDE';
  static const emailInvalid = 'EMAIL_INVALIDE';
  static const alreadyMember = 'DEJA_MEMBRE';
  static const perimetreRequired = 'PERIMETRE_REQUIS';
  static const invitationInvalid = 'INVITATION_INVALIDE';
  static const invitationExpired = 'INVITATION_EXPIREE';
  static const invitationUsed = 'INVITATION_DEJA_UTILISEE';
  static const invitationCancelled = 'INVITATION_ANNULEE';
  static const invitationOtherEmail = 'INVITATION_EMAIL_DIFFERENT';
  static const invitationNotCancellable = 'INVITATION_NON_ANNULABLE';
  static const emailNotConfirmed = 'EMAIL_NON_CONFIRME';
  static const textTooLong = 'TEXTE_TROP_LONG';

  // Noyau financier (mêmes codes côté serveur et côté application).
  static const labelInvalid = 'LIBELLE_INVALIDE';
  static const amountInvalid = 'MONTANT_INVALIDE';
  static const commitmentCancelled = 'ENGAGEMENT_ANNULE';
  static const commitmentPaid = 'ENGAGEMENT_REGLE';
  static const totalBelowPaid = 'MONTANT_INFERIEUR_REGLE';
  static const amountAboveRemaining = 'MONTANT_SUPERIEUR_RESTE';
  static const allocationAbovePayment = 'AFFECTATION_SUPERIEURE_PAIEMENT';
  static const allocationWrongDirection = 'AFFECTATION_SENS_INCOMPATIBLE';
  static const allocationOtherContact = 'AFFECTATION_CONTACT_DIFFERENT';
  static const paymentAlreadyCancelled = 'PAIEMENT_DEJA_ANNULE';
  static const modeWithoutCash = 'MODE_SANS_CAISSE';
  static const dateInvalid = 'DATE_INVALIDE';
  static const cashClosed = 'CAISSE_FERMEE';
  static const cashOpenSession = 'CAISSE_OUVERTE';
  static const cashAlreadyOpen = 'CAISSE_DEJA_OUVERTE';
  static const cashInactive = 'CAISSE_INACTIVE';
  static const cashInsufficient = 'SOLDE_CAISSE_INSUFFISANT';
  static const commitmentLinked = 'ENGAGEMENT_LIE';
  static const categoryInvalid = 'CATEGORIE_INVALIDE';
  static const expensePaid = 'DEPENSE_PAYEE';
  static const expenseCancelled = 'DEPENSE_ANNULEE';
  static const recurringExpenseInvalid = 'DEPENSE_COURANTE_INVALIDE';
  static const dueAlreadyPaid = 'ECHEANCE_DEJA_PAYEE';
  static const transferDirect = 'TRANSFERT_DIRECT_INTERDIT';
  static const transferLinked = 'TRANSFERT_LIE';
  static const transferCancelled = 'TRANSFERT_ANNULE';
  static const transferSame = 'TRANSFERT_IDENTIQUE';
  static const natureIncompatible = 'NATURE_INCOMPATIBLE';
  static const reasonRequired = 'MOTIF_REQUIS';
  static const discrepancyJustificationRequired = 'JUSTIFICATION_ECART_REQUISE';
  static const documentExists = 'DOCUMENT_EXISTANT';
  static const documentOriginInvalid = 'ORIGINE_INVALIDE';
  static const documentNumbersExhausted = 'NUMEROS_EPUISES';
  static const documentNumberInvalid = {'BLOC_INVALIDE', 'NUMERO_HORS_BLOC', 'TYPE_DOCUMENT_INVALIDE'};
  static const assigneeInvalid = 'RESPONSABLE_INVALIDE';
  static const targetInvalid = 'CIBLE_INVALIDE';
  static const fileTypeInvalid = 'TYPE_FICHIER_INVALIDE';
  static const fileTooLarge = 'FICHIER_TROP_GROS';
  static const filePathInvalid = 'CHEMIN_INVALIDE';
  static const paymentModesInvalid = 'MODES_PAIEMENT_INVALIDES';
  static const paymentModeDisabled = 'MODE_PAIEMENT_DESACTIVE';

  // Commerce.
  static const stockInsufficient = 'STOCK_INSUFFISANT';
  static const quantityInvalid = 'QUANTITE_INVALIDE';
  static const fractionInvalid = 'FRACTION_INVALIDE';
  static const unitInvalid = 'UNITE_INVALIDE';
  static const barcodeExists = 'CODE_BARRES_EXISTANT';
  static const transferSameShop = 'TRANSFERT_MEME_BOUTIQUE';
  static const shopRequired = 'BOUTIQUE_REQUISE';
  static const linesInvalid = 'LIGNES_INVALIDES';
  static const receptionAboveOrdered = 'RECEPTION_SUPERIEURE';
  static const purchaseReceived = 'ACHAT_RECU';
  static const purchasePaid = 'ACHAT_PAYE';
  static const purchaseCancelled = 'ACHAT_ANNULE';
  static const saleCancelled = 'VENTE_ANNULEE';
  static const salePaid = 'VENTE_PAYEE';
  static const customerRequired = 'CLIENT_REQUIS';
  static const movementInvalid = 'MOUVEMENT_INVALIDE';
  static const productUsed = 'PRODUIT_UTILISE';

  /// Refus techniques (données incohérentes) : un seul message à l'utilisateur.
  static const financeInconsistent = {
    'AFFECTATION_INVALIDE', 'ENGAGEMENT_INTROUVABLE', 'PAIEMENT_INTROUVABLE',
    'PAIEMENT_ANNULATION_INVALIDE', 'MODE_PAIEMENT_INVALIDE', 'PERIMETRE_INCOHERENT',
    'PERIMETRE_INTROUVABLE', 'ACTIVITE_PERIMETRE_INCOHERENTE', 'CAISSE_INTROUVABLE',
    'SESSION_INTROUVABLE', 'SESSION_CLOTURE_REQUISE', 'SOLDE_REEL_REQUIS', 'TYPE_MOUVEMENT_INVALIDE',
  };

  // Décisions évaluées côté client uniquement.
  static const moduleNotInPlan = 'MODULE_NON_INCLUS';
  static const permissionDenied = 'PERMISSION_REFUSEE';
  static const perimetreDenied = 'PERIMETRE_NON_AUTORISE';
}

/// Résultat d'une vérification : AUTORISÉ, ou REFUSÉ avec une raison
/// exploitable par l'interface.
sealed class AccessDecision {
  const AccessDecision();

  static const allowed = AccessAllowed();

  bool get isAllowed => this is AccessAllowed;

  /// Enchaîne une vérification seulement si la précédente est autorisée.
  AccessDecision and(AccessDecision Function() next) =>
      isAllowed ? next() : this;
}

final class AccessAllowed extends AccessDecision {
  const AccessAllowed();
}

final class AccessDenied extends AccessDecision {
  const AccessDenied(this.ruleCode, [this.params = const {}]);

  final String ruleCode;
  final Map<String, Object?> params;

  Failure toFailure() => Failure.rule(ruleCode, params);

  @override
  String toString() => 'AccessDenied($ruleCode, $params)';
}
