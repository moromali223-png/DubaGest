import 'package:flutter/material.dart';

/// Prestataires de paiement supportés pour les abonnements DubaGest.
enum PrestatairePaiement {
  orangeMoney(
    code: 'ORANGE_MONEY',
    nom: 'Orange Money',
    description: 'Paiement mobile sécurisé par Orange Money',
    couleurPrimaire: Color(0xFFFF7900), // Orange officiel Orange Money
    icone: Icons.phone_android_rounded,
  ),
  ligdiCash(
    code: 'LIGDICASH',
    nom: 'LigdiCash',
    description: 'Paiement mobile sécurisé par LigdiCash (Burkina Faso & UEMOA)',
    couleurPrimaire: Color(0xFF1E88E5), // Bleu LigdiCash
    icone: Icons.account_balance_wallet_outlined,
  );

  const PrestatairePaiement({
    required this.code,
    required this.nom,
    required this.description,
    required this.couleurPrimaire,
    required this.icone,
  });

  final String code;
  final String nom;
  final String description;
  final Color couleurPrimaire;
  final IconData icone;

  static PrestatairePaiement fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'ORANGE_MONEY':
        return PrestatairePaiement.orangeMoney;
      case 'LIGDICASH':
        return PrestatairePaiement.ligdiCash;
      default:
        return PrestatairePaiement.orangeMoney;
    }
  }
}

/// Statuts du cycle de vie d'une transaction d'abonnement.
/// 5 états essentiels : En attente, En cours, Confirmé, Échoué, Annulé (plus Remboursé)
enum StatutTransactionAbonnement {
  enAttente('EN_ATTENTE', 'En attente'),
  enCours('EN_COURS', 'En cours de traitement'),
  confirme('CONFIRME', 'Paiement confirmé'),
  echoue('ECHOUE', 'Paiement échoué'),
  annule('ANNULE', 'Paiement annulé'),
  rembourse('REMBOURSE', 'Remboursé');

  const StatutTransactionAbonnement(this.code, this.libelle);

  final String code;
  final String libelle;

  static StatutTransactionAbonnement fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'EN_ATTENTE':
        return StatutTransactionAbonnement.enAttente;
      case 'EN_COURS':
        return StatutTransactionAbonnement.enCours;
      case 'CONFIRME':
        return StatutTransactionAbonnement.confirme;
      case 'ECHOUE':
        return StatutTransactionAbonnement.echoue;
      case 'ANNULE':
        return StatutTransactionAbonnement.annule;
      case 'REMBOURSE':
        return StatutTransactionAbonnement.rembourse;
      default:
        return StatutTransactionAbonnement.enAttente;
    }
  }

  Color get color {
    switch (this) {
      case StatutTransactionAbonnement.confirme:
        return const Color(0xFF10B981); // Vert succès
      case StatutTransactionAbonnement.enCours:
        return const Color(0xFF3B82F6); // Bleu info
      case StatutTransactionAbonnement.enAttente:
        return const Color(0xFFF59E0B); // Ambre attente
      case StatutTransactionAbonnement.echoue:
        return const Color(0xFFEF4444); // Rouge échec
      case StatutTransactionAbonnement.annule:
        return const Color(0xFF6B7280); // Gris annulé
      case StatutTransactionAbonnement.rembourse:
        return const Color(0xFF8B5CF6); // Violet remboursé
    }
  }

  IconData get icon {
    switch (this) {
      case StatutTransactionAbonnement.confirme:
        return Icons.check_circle_rounded;
      case StatutTransactionAbonnement.enCours:
        return Icons.sync_rounded;
      case StatutTransactionAbonnement.enAttente:
        return Icons.hourglass_top_rounded;
      case StatutTransactionAbonnement.echoue:
        return Icons.error_outline_rounded;
      case StatutTransactionAbonnement.annule:
        return Icons.cancel_outlined;
      case StatutTransactionAbonnement.rembourse:
        return Icons.assignment_return_outlined;
    }
  }
}

/// Alias pour l'affichage et la compatibilité des listes de transactions.
typedef TransactionAbonnementItem = TransactionAbonnement;

/// Modèle métier d'une transaction de paiement d'abonnement DubaGest.
class TransactionAbonnement {
  const TransactionAbonnement({
    required this.id,
    required this.entrepriseId,
    this.userId,
    this.abonnementId,
    required this.planCode,
    required this.dureeMois,
    required this.montant,
    required this.devise,
    required this.prestataire,
    required this.referenceInterne,
    this.referencePrestataire,
    this.tokenTransaction,
    this.urlPaiement,
    this.environnement = 'TEST',
    required this.statut,
    required this.estDemo,
    this.diagnostic = const {},
    required this.createdAt,
    this.confirmedAt,
    this.cancelledAt,
    this.failedAt,
  });

  final String id;
  final String entrepriseId;
  final String? userId;
  final String? abonnementId;
  final String planCode;
  final int dureeMois;
  final int montant;
  final String devise;
  final PrestatairePaiement prestataire;
  final String referenceInterne;
  final String? referencePrestataire;
  final String? tokenTransaction;
  final String? urlPaiement;
  final String environnement;
  final StatutTransactionAbonnement statut;
  final bool estDemo;
  final Map<String, dynamic> diagnostic;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final DateTime? failedAt;

  factory TransactionAbonnement.fromJson(Map<String, dynamic> json) {
    return TransactionAbonnement(
      id: json['id'] as String? ?? '',
      entrepriseId: json['entreprise_id'] as String? ?? '',
      userId: json['user_id'] as String?,
      abonnementId: json['abonnement_id'] as String?,
      planCode: json['plan_code'] as String? ?? 'NORMAL',
      dureeMois: (json['duree_mois'] as num?)?.toInt() ?? 1,
      montant: (json['montant'] as num?)?.toInt() ?? 0,
      devise: json['devise'] as String? ?? 'XOF',
      prestataire: PrestatairePaiement.fromCode(json['prestataire'] as String? ?? 'ORANGE_MONEY'),
      referenceInterne: json['reference_interne'] as String? ?? '',
      referencePrestataire: json['reference_prestataire'] as String?,
      tokenTransaction: json['token_transaction'] as String?,
      urlPaiement: json['url_paiement'] as String?,
      environnement: json['environnement'] as String? ?? 'TEST',
      statut: StatutTransactionAbonnement.fromCode(json['statut'] as String? ?? 'EN_ATTENTE'),
      estDemo: json['est_demo'] as bool? ?? false,
      diagnostic: json['diagnostic'] is Map ? Map<String, dynamic>.from(json['diagnostic'] as Map) : const {},
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      confirmedAt: json['confirmed_at'] != null ? DateTime.tryParse(json['confirmed_at'].toString()) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'].toString()) : null,
      failedAt: json['failed_at'] != null ? DateTime.tryParse(json['failed_at'].toString()) : null,
    );
  }
}

/// Enregistrement dans l'historique officiel des renouvellements d'abonnements.
class HistoriqueRenouvellementItem {
  const HistoriqueRenouvellementItem({
    required this.id,
    required this.typeOperation,
    this.ancienPlanCode,
    required this.nouveauPlanCode,
    required this.dureeMois,
    required this.montant,
    required this.devise,
    this.prestataire,
    this.ancienneDateFin,
    required this.nouvelleDateFin,
    required this.createdAt,
  });

  final String id;
  final String typeOperation;
  final String? ancienPlanCode;
  final String nouveauPlanCode;
  final int dureeMois;
  final int montant;
  final String devise;
  final String? prestataire;
  final DateTime? ancienneDateFin;
  final DateTime nouvelleDateFin;
  final DateTime createdAt;

  String get typeOperationLisible {
    switch (typeOperation) {
      case 'FIN_ESSAI':
        return 'Fin d\'essai gratuit';
      case 'RENOUVELLEMENT':
        return 'Renouvellement';
      case 'CHANGEMENT_FORMULE':
        return 'Changement de formule';
      case 'NOUVELLE_SOUSCRIPTION':
        return 'Première souscription';
      case 'SPONSORISE':
        return 'Accès sponsorisé';
      default:
        return typeOperation;
    }
  }

  factory HistoriqueRenouvellementItem.fromJson(Map<String, dynamic> json) {
    return HistoriqueRenouvellementItem(
      id: json['id'] as String? ?? '',
      typeOperation: json['type_operation'] as String? ?? 'RENOUVELLEMENT',
      ancienPlanCode: json['ancien_plan_code'] as String?,
      nouveauPlanCode: json['nouveau_plan_code'] as String? ?? 'NORMAL',
      dureeMois: (json['duree_mois'] as num?)?.toInt() ?? 1,
      montant: (json['montant'] as num?)?.toInt() ?? 0,
      devise: json['devise'] as String? ?? 'XOF',
      prestataire: json['prestataire'] as String?,
      ancienneDateFin: json['ancienne_date_fin'] != null
          ? DateTime.tryParse(json['ancienne_date_fin'].toString())
          : null,
      nouvelleDateFin: json['nouvelle_date_fin'] != null
          ? DateTime.tryParse(json['nouvelle_date_fin'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Information de disponibilité d'un prestataire.
class DisponibilitePrestataire {
  const DisponibilitePrestataire({
    required this.prestataire,
    required this.estConfigure,
    required this.message,
  });

  final PrestatairePaiement prestataire;
  final bool estConfigure;
  final String message;

  static const String messageNonConfigure =
      'Paiement en ligne bientôt disponible pour ce moyen de paiement.';
}
