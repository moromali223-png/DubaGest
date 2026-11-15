import 'microfinance_enums.dart';

/// Compte de trésorerie dédié à l'activité Microfinance.
class MicrofinanceAccount {
  const MicrofinanceAccount({
    required this.id,
    required this.entrepriseId,
    this.perimetreId,
    required this.nom,
    this.typeCompte = TypeCompteMicrofinance.caissePhysique,
    this.sourceFondsDefaut = SourceFondsMicrofinance.capitalPersonnel,
    this.caisseId,
    this.numeroCompte,
    this.soldeInitial = 0,
    this.soldeActuel = 0,
    this.devise = 'XOF',
    this.estActif = true,
    this.observations,
    this.creePar,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String entrepriseId;
  final String? perimetreId;
  final String nom;
  final TypeCompteMicrofinance typeCompte;
  final SourceFondsMicrofinance sourceFondsDefaut;
  final String? caisseId;
  final String? numeroCompte;
  final int soldeInitial;
  final int soldeActuel;
  final String devise;
  final bool estActif;
  final String? observations;
  final String? creePar;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  MicrofinanceAccount copyWith({
    String? nom,
    TypeCompteMicrofinance? typeCompte,
    SourceFondsMicrofinance? sourceFondsDefaut,
    String? caisseId,
    String? numeroCompte,
    int? soldeInitial,
    int? soldeActuel,
    String? devise,
    bool? estActif,
    String? observations,
    int? version,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) =>
      MicrofinanceAccount(
        id: id,
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        nom: nom ?? this.nom,
        typeCompte: typeCompte ?? this.typeCompte,
        sourceFondsDefaut: sourceFondsDefaut ?? this.sourceFondsDefaut,
        caisseId: caisseId ?? this.caisseId,
        numeroCompte: numeroCompte ?? this.numeroCompte,
        soldeInitial: soldeInitial ?? this.soldeInitial,
        soldeActuel: soldeActuel ?? this.soldeActuel,
        devise: devise ?? this.devise,
        estActif: estActif ?? this.estActif,
        observations: observations ?? this.observations,
        creePar: creePar,
        version: version ?? this.version,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}

/// Mouvement de capital ou de trésorerie hors prêts (apport, retrait, dépense, transfert interne).
class MicrofinanceFundMovement {
  const MicrofinanceFundMovement({
    required this.id,
    required this.entrepriseId,
    this.perimetreId,
    required this.reference,
    required this.accountId,
    this.accountDestinationId,
    required this.typeMouvement,
    this.sourceFonds = SourceFondsMicrofinance.capitalPersonnel,
    required this.montant,
    this.modePaiement = ModePaiementMicrofinance.especes,
    required this.dateMouvement,
    required this.libelle,
    this.observations,
    this.estAnnule = false,
    this.motifAnnulation,
    this.creePar,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String entrepriseId;
  final String? perimetreId;
  final String reference;
  final String accountId;
  final String? accountDestinationId;
  final TypeMouvementFonds typeMouvement;
  final SourceFondsMicrofinance sourceFonds;
  final int montant;
  final ModePaiementMicrofinance modePaiement;
  final DateTime dateMouvement;
  final String libelle;
  final String? observations;
  final bool estAnnule;
  final String? motifAnnulation;
  final String? creePar;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

/// Emprunteur géré dans le module Microfinance (sans garantie ni caution obligatoire).
class MicrofinanceBorrower {
  const MicrofinanceBorrower({
    required this.id,
    required this.entrepriseId,
    this.perimetreId,
    required this.codeEmprunteur,
    this.contactId,
    required this.nomComplet,
    required this.telephone,
    this.whatsapp,
    this.adresse,
    this.localisation,
    this.profession,
    this.activite,
    this.typePiece,
    this.referencePiece,
    this.photoUrl,
    this.infosComplementaires,
    required this.dateInscription,
    this.observations,
    this.estActif = true,
    this.creePar,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String entrepriseId;
  final String? perimetreId;
  final String codeEmprunteur;
  final String? contactId;
  final String nomComplet;
  final String telephone;
  final String? whatsapp;
  final String? adresse;
  final String? localisation;
  final String? profession;
  final String? activite;
  final String? typePiece;
  final String? referencePiece;
  final String? photoUrl;
  final String? infosComplementaires;
  final DateTime dateInscription;
  final String? observations;
  final bool estActif;
  final String? creePar;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  String get initiales {
    final parts = nomComplet.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'EM';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  MicrofinanceBorrower copyWith({
    String? contactId,
    String? nomComplet,
    String? telephone,
    String? whatsapp,
    String? adresse,
    String? localisation,
    String? profession,
    String? activite,
    String? typePiece,
    String? referencePiece,
    String? photoUrl,
    String? infosComplementaires,
    String? observations,
    bool? estActif,
    int? version,
    DateTime? updatedAt,
  }) =>
      MicrofinanceBorrower(
        id: id,
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        codeEmprunteur: codeEmprunteur,
        contactId: contactId ?? this.contactId,
        nomComplet: nomComplet ?? this.nomComplet,
        telephone: telephone ?? this.telephone,
        whatsapp: whatsapp ?? this.whatsapp,
        adresse: adresse ?? this.adresse,
        localisation: localisation ?? this.localisation,
        profession: profession ?? this.profession,
        activite: activite ?? this.activite,
        typePiece: typePiece ?? this.typePiece,
        referencePiece: referencePiece ?? this.referencePiece,
        photoUrl: photoUrl ?? this.photoUrl,
        infosComplementaires: infosComplementaires ?? this.infosComplementaires,
        dateInscription: dateInscription,
        observations: observations ?? this.observations,
        estActif: estActif ?? this.estActif,
        creePar: creePar,
        version: version ?? this.version,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt,
      );
}

/// Dossier de prêt d'argent.
class MicrofinanceLoan {
  const MicrofinanceLoan({
    required this.id,
    required this.entrepriseId,
    this.perimetreId,
    required this.reference,
    required this.borrowerId,
    required this.accountId,
    required this.montantAccorde,
    required this.methodeInteret,
    this.tauxInteret = 0,
    this.montantInteretFixe = 0,
    required this.montantInteretTotal,
    required this.montantTotalARembourser,
    this.capitalRembourse = 0,
    this.interetRembourse = 0,
    required this.frequence,
    required this.dureeValeur,
    required this.nombreEcheances,
    required this.montantEcheanceIndicatif,
    this.modeDecaissement = ModePaiementMicrofinance.especes,
    required this.dateOctroi,
    this.dateDecaissement,
    required this.dateDebut,
    required this.dateFinPrevue,
    this.dateSolde,
    this.statut = StatutPret.enCours,
    this.conditionsParticulieres,
    this.observations,
    this.motifAnnulation,
    this.creePar,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String entrepriseId;
  final String? perimetreId;
  final String reference;
  final String borrowerId;
  final String accountId;

  /// Capital accordé (principal).
  final int montantAccorde;
  final MethodeCalculInteret methodeInteret;
  final double tauxInteret;
  final int montantInteretFixe;
  final int montantInteretTotal;
  final int montantTotalARembourser;
  final int capitalRembourse;
  final int interetRembourse;
  final FrequenceRemboursement frequence;
  final int dureeValeur;
  final int nombreEcheances;
  final int montantEcheanceIndicatif;
  final ModePaiementMicrofinance modeDecaissement;
  final DateTime dateOctroi;
  final DateTime? dateDecaissement;
  final DateTime dateDebut;
  final DateTime dateFinPrevue;
  final DateTime? dateSolde;
  final StatutPret statut;
  final String? conditionsParticulieres;
  final String? observations;
  final String? motifAnnulation;
  final String? creePar;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  int get totalRembourse => capitalRembourse + interetRembourse;
  int get resteAPayerTotal => (montantTotalARembourser - totalRembourse).clamp(0, montantTotalARembourser);
  int get capitalRestantARecuperer => (montantAccorde - capitalRembourse).clamp(0, montantAccorde);
  int get interetRestantARecuperer => (montantInteretTotal - interetRembourse).clamp(0, montantInteretTotal);
  double get progressionPourcent =>
      montantTotalARembourser <= 0 ? 0 : (totalRembourse / montantTotalARembourser * 100).clamp(0, 100);

  MicrofinanceLoan copyWith({
    String? accountId,
    int? capitalRembourse,
    int? interetRembourse,
    ModePaiementMicrofinance? modeDecaissement,
    DateTime? dateDecaissement,
    DateTime? dateSolde,
    StatutPret? statut,
    String? conditionsParticulieres,
    String? observations,
    String? motifAnnulation,
    int? version,
    DateTime? updatedAt,
  }) =>
      MicrofinanceLoan(
        id: id,
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        reference: reference,
        borrowerId: borrowerId,
        accountId: accountId ?? this.accountId,
        montantAccorde: montantAccorde,
        methodeInteret: methodeInteret,
        tauxInteret: tauxInteret,
        montantInteretFixe: montantInteretFixe,
        montantInteretTotal: montantInteretTotal,
        montantTotalARembourser: montantTotalARembourser,
        capitalRembourse: capitalRembourse ?? this.capitalRembourse,
        interetRembourse: interetRembourse ?? this.interetRembourse,
        frequence: frequence,
        dureeValeur: dureeValeur,
        nombreEcheances: nombreEcheances,
        montantEcheanceIndicatif: montantEcheanceIndicatif,
        modeDecaissement: modeDecaissement ?? this.modeDecaissement,
        dateOctroi: dateOctroi,
        dateDecaissement: dateDecaissement ?? this.dateDecaissement,
        dateDebut: dateDebut,
        dateFinPrevue: dateFinPrevue,
        dateSolde: dateSolde ?? this.dateSolde,
        statut: statut ?? this.statut,
        conditionsParticulieres: conditionsParticulieres ?? this.conditionsParticulieres,
        observations: observations ?? this.observations,
        motifAnnulation: motifAnnulation ?? this.motifAnnulation,
        creePar: creePar,
        version: version ?? this.version,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt,
      );
}

/// Échéance individuelle d'un prêt.
class MicrofinanceInstallment {
  const MicrofinanceInstallment({
    required this.id,
    required this.entrepriseId,
    this.perimetreId,
    required this.loanId,
    required this.borrowerId,
    required this.numeroEcheance,
    required this.datePrevue,
    required this.capitalPrevu,
    required this.interetPrevu,
    required this.montantTotalAttendu,
    this.capitalPaye = 0,
    this.interetPaye = 0,
    this.montantDejaPaye = 0,
    required this.resteAPayer,
    this.statut = StatutEcheance.aVenir,
    this.dateDernierPaiement,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String entrepriseId;
  final String? perimetreId;
  final String loanId;
  final String borrowerId;
  final int numeroEcheance;
  final DateTime datePrevue;
  final int capitalPrevu;
  final int interetPrevu;
  final int montantTotalAttendu;
  final int capitalPaye;
  final int interetPaye;
  final int montantDejaPaye;
  final int resteAPayer;
  final StatutEcheance statut;
  final DateTime? dateDernierPaiement;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  int get capitalRestant => (capitalPrevu - capitalPaye).clamp(0, capitalPrevu);
  int get interetRestant => (interetPrevu - interetPaye).clamp(0, interetPrevu);
  bool get estSoldee => resteAPayer <= 0;

  MicrofinanceInstallment copyWith({
    int? capitalPaye,
    int? interetPaye,
    int? montantDejaPaye,
    int? resteAPayer,
    StatutEcheance? statut,
    DateTime? dateDernierPaiement,
    int? version,
    DateTime? updatedAt,
  }) =>
      MicrofinanceInstallment(
        id: id,
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        loanId: loanId,
        borrowerId: borrowerId,
        numeroEcheance: numeroEcheance,
        datePrevue: datePrevue,
        capitalPrevu: capitalPrevu,
        interetPrevu: interetPrevu,
        montantTotalAttendu: montantTotalAttendu,
        capitalPaye: capitalPaye ?? this.capitalPaye,
        interetPaye: interetPaye ?? this.interetPaye,
        montantDejaPaye: montantDejaPaye ?? this.montantDejaPaye,
        resteAPayer: resteAPayer ?? this.resteAPayer,
        statut: statut ?? this.statut,
        dateDernierPaiement: dateDernierPaiement ?? this.dateDernierPaiement,
        version: version ?? this.version,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt,
      );
}

/// Détail de ventilation d'un remboursement sur une échéance précise.
class RepaymentInstallmentAllocation {
  const RepaymentInstallmentAllocation({
    required this.installmentId,
    required this.numeroEcheance,
    required this.montantAffecte,
    required this.partCapital,
    required this.partInteret,
  });

  final String installmentId;
  final int numeroEcheance;
  final int montantAffecte;
  final int partCapital;
  final int partInteret;

  Map<String, dynamic> toJson() => {
        'installment_id': installmentId,
        'numero_echeance': numeroEcheance,
        'montant_affecte': montantAffecte,
        'part_capital': partCapital,
        'part_interet': partInteret,
      };

  factory RepaymentInstallmentAllocation.fromJson(Map<String, dynamic> json) =>
      RepaymentInstallmentAllocation(
        installmentId: json['installment_id'] as String? ?? '',
        numeroEcheance: (json['numero_echeance'] as num?)?.toInt() ?? 0,
        montantAffecte: (json['montant_affecte'] as num?)?.toInt() ?? 0,
        partCapital: (json['part_capital'] as num?)?.toInt() ?? 0,
        partInteret: (json['part_interet'] as num?)?.toInt() ?? 0,
      );
}

/// Remboursement encaissé sur un prêt.
class MicrofinanceRepayment {
  const MicrofinanceRepayment({
    required this.id,
    required this.entrepriseId,
    this.perimetreId,
    required this.reference,
    required this.loanId,
    required this.borrowerId,
    required this.accountId,
    required this.datePaiement,
    required this.montantEncaisse,
    required this.partCapital,
    required this.partInteret,
    this.typeRemboursement = TypeRemboursement.complet,
    this.modePaiement = ModePaiementMicrofinance.especes,
    this.justificatifUrl,
    this.observations,
    this.detailsAffectation = const [],
    this.estAnnule = false,
    this.motifAnnulation,
    this.creePar,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String entrepriseId;
  final String? perimetreId;
  final String reference;
  final String loanId;
  final String borrowerId;
  final String accountId;
  final DateTime datePaiement;
  final int montantEncaisse;
  final int partCapital;
  final int partInteret;
  final TypeRemboursement typeRemboursement;
  final ModePaiementMicrofinance modePaiement;
  final String? justificatifUrl;
  final String? observations;
  final List<RepaymentInstallmentAllocation> detailsAffectation;
  final bool estAnnule;
  final String? motifAnnulation;
  final String? creePar;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  MicrofinanceRepayment copyWith({
    bool? estAnnule,
    String? motifAnnulation,
    String? observations,
    int? version,
    DateTime? updatedAt,
  }) =>
      MicrofinanceRepayment(
        id: id,
        entrepriseId: entrepriseId,
        perimetreId: perimetreId,
        reference: reference,
        loanId: loanId,
        borrowerId: borrowerId,
        accountId: accountId,
        datePaiement: datePaiement,
        montantEncaisse: montantEncaisse,
        partCapital: partCapital,
        partInteret: partInteret,
        typeRemboursement: typeRemboursement,
        modePaiement: modePaiement,
        justificatifUrl: justificatifUrl,
        observations: observations ?? this.observations,
        detailsAffectation: detailsAffectation,
        estAnnule: estAnnule ?? this.estAnnule,
        motifAnnulation: motifAnnulation ?? this.motifAnnulation,
        creePar: creePar,
        version: version ?? this.version,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt,
      );
}

/// Écriture du grand-livre financier central Microfinance.
class MicrofinanceTransaction {
  const MicrofinanceTransaction({
    required this.id,
    required this.entrepriseId,
    this.perimetreId,
    required this.reference,
    required this.dateTransaction,
    required this.typeTransaction,
    required this.montant,
    this.partCapital = 0,
    this.partInteret = 0,
    required this.sens,
    this.modePaiement = ModePaiementMicrofinance.especes,
    required this.accountId,
    this.accountDestinationId,
    this.loanId,
    this.repaymentId,
    this.fundId,
    this.borrowerId,
    this.transactionOrigineId,
    required this.libelle,
    this.observations,
    this.creePar,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String entrepriseId;
  final String? perimetreId;
  final String reference;
  final DateTime dateTransaction;
  final TypeTransactionMicrofinance typeTransaction;
  final int montant;
  final int partCapital;
  final int partInteret;
  final SensTransactionMicrofinance sens;
  final ModePaiementMicrofinance modePaiement;
  final String accountId;
  final String? accountDestinationId;
  final String? loanId;
  final String? repaymentId;
  final String? fundId;
  final String? borrowerId;
  final String? transactionOrigineId;
  final String libelle;
  final String? observations;
  final String? creePar;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

/// Trace d'audit immuable d'une opération Microfinance.
class MicrofinanceAuditLog {
  const MicrofinanceAuditLog({
    required this.id,
    required this.entrepriseId,
    this.perimetreId,
    required this.action,
    required this.entiteType,
    required this.entiteId,
    this.referenceEntite,
    this.utilisateurId,
    this.detailsAvant,
    this.detailsApres,
    this.motif,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String entrepriseId;
  final String? perimetreId;
  final String action;
  final String entiteType;
  final String entiteId;
  final String? referenceEntite;
  final String? utilisateurId;
  final Map<String, dynamic>? detailsAvant;
  final Map<String, dynamic>? detailsApres;
  final String? motif;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Consolidé financier du Tableau de bord Microfinance.
/// Distingue rigoureusement capital, créances, revenus (intérêts encaissés), dépenses et bénéfice net.
class MicrofinanceDashboardStats {
  const MicrofinanceDashboardStats({
    required this.capitalInitial,
    required this.apportsSupplementaires,
    required this.retraitsCapital,
    required this.capitalTotalDisponible,
    required this.totalMontantsDecaisses,
    required this.capitalRestantARecuperer,
    required this.totalInteretsPrevus,
    required this.totalInteretsEncaisses,
    required this.totalRemboursementsRecus,
    required this.nombreEmprunteurs,
    required this.nombrePretsActifs,
    required this.nombrePretsSoldes,
    required this.nombrePretsEnRetard,
    required this.montantTotalImpayes,
    required this.depensesFonctionnement,
    required this.resultatFinancierNet,
    this.nombreEcheancesAujourdhui = 0,
    this.montantEcheancesAujourdhui = 0,
    this.nombreEcheancesEnRetard = 0,
    this.nombrePretsAccordes = 0,
    this.nombrePretsTotalPortefeuille = 0,
    this.nombreRemboursementsRecus = 0,
    this.partCapitalRemboursee = 0,
    this.resteAPayerTotal = 0,
  });

  final int capitalInitial;
  final int apportsSupplementaires;
  final int retraitsCapital;
  final int capitalTotalDisponible;
  final int totalMontantsDecaisses;
  final int capitalRestantARecuperer;
  final int totalInteretsPrevus;
  final int totalInteretsEncaisses;
  final int totalRemboursementsRecus;
  final int nombreEmprunteurs;
  final int nombrePretsActifs;
  final int nombrePretsSoldes;
  final int nombrePretsEnRetard;
  final int montantTotalImpayes;
  final int depensesFonctionnement;
  final int resultatFinancierNet;
  final int nombreEcheancesAujourdhui;
  final int montantEcheancesAujourdhui;
  final int nombreEcheancesEnRetard;
  final int nombrePretsAccordes;
  final int nombrePretsTotalPortefeuille;
  final int nombreRemboursementsRecus;
  final int partCapitalRemboursee;
  final int resteAPayerTotal;

  /// Revenus réels = intérêts réellement encaissés (jamais le remboursement du capital).
  int get revenusReels => totalInteretsEncaisses;

  /// Taux de recouvrement du portefeuille (sur échéances exigibles ou total remboursé).
  double get tauxRecouvrementGlobal {
    final attendu = totalMontantsDecaisses + totalInteretsPrevus;
    if (attendu <= 0) return 0;
    return (totalRemboursementsRecus / attendu * 100).clamp(0, 100);
  }
}

/// Synthèse calculée pour un emprunteur donné.
class MicrofinanceBorrowerSummary {
  const MicrofinanceBorrowerSummary({
    required this.borrower,
    required this.nombrePretsTotal,
    required this.nombrePretsActifs,
    required this.nombrePretsEnRetard,
    required this.totalEmprunte,
    required this.totalRembourse,
    required this.resteAPayerTotal,
    required this.montantImpayes,
    required this.joursRetardMax,
  });

  final MicrofinanceBorrower borrower;
  final int nombrePretsTotal;
  final int nombrePretsActifs;
  final int nombrePretsEnRetard;
  final int totalEmprunte;
  final int totalRembourse;
  final int resteAPayerTotal;
  final int montantImpayes;
  final int joursRetardMax;
}

