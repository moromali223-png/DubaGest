import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/core_providers.dart';

/// Détail d'un tarif officiel par durée (1, 3, 6, 12 mois) configuré sur le serveur.
class TarifDureeItem {
  const TarifDureeItem({
    required this.dureeMois,
    required this.montantTotal,
    required this.remisePourcentage,
    this.badgePromo,
    this.description,
  });

  final int dureeMois;
  final int montantTotal;
  final int remisePourcentage;
  final String? badgePromo;
  final String? description;

  factory TarifDureeItem.fromJson(Map<String, dynamic> json) {
    return TarifDureeItem(
      dureeMois: (json['duree_mois'] as num?)?.toInt() ?? 1,
      montantTotal: (json['montant_total'] as num?)?.toInt() ?? 0,
      remisePourcentage: (json['remise_pourcentage'] as num?)?.toInt() ?? 0,
      badgePromo: json['badge_promo'] as String?,
      description: json['description'] as String?,
    );
  }
}

/// Modèle métier complet d'un plan extrait dynamiquement du catalogue serveur.
class PlanCatalogueItem {
  const PlanCatalogueItem({
    required this.code,
    required this.nom,
    required this.description,
    required this.ordre,
    required this.prixMensuel,
    required this.devise,
    required this.maxActivites,
    required this.activites,
    required this.roles,
    required this.modules,
    this.tarifsDurees = const [],
  });

  final String code;
  final String nom;
  final String description;
  final int ordre;
  final int prixMensuel;
  final String devise;
  final int maxActivites;
  final List<Map<String, dynamic>> activites;
  final List<Map<String, dynamic>> roles;
  final List<dynamic> modules;
  final List<TarifDureeItem> tarifsDurees;

  factory PlanCatalogueItem.fromJson(Map<String, dynamic> json) {
    return PlanCatalogueItem(
      code: json['code'] as String? ?? 'NORMAL',
      nom: json['nom'] as String? ?? 'Normal',
      description: json['description'] as String? ?? '',
      ordre: (json['ordre'] as num?)?.toInt() ?? 1,
      prixMensuel: (json['prix_mensuel'] as num?)?.toInt() ?? 0,
      devise: json['devise'] as String? ?? 'XOF',
      maxActivites: (json['max_activites'] as num?)?.toInt() ?? 1,
      activites: (json['activites'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      roles: (json['roles'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      modules: (json['modules'] as List?) ?? const [],
      tarifsDurees: (json['tarifs_durees'] as List?)
              ?.map((e) => TarifDureeItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  /// Récupère le tarif serveur exact pour une durée donnée (1, 3, 6 ou 12 mois)
  TarifDureeItem tarifPour(int dureeMois) {
    return tarifsDurees.firstWhere(
      (t) => t.dureeMois == dureeMois,
      orElse: () => TarifDureeItem(
        dureeMois: dureeMois,
        montantTotal: dureeMois == 12 ? (prixMensuel * 10) : (prixMensuel * dureeMois),
        remisePourcentage: dureeMois == 12 ? 17 : 0,
        badgePromo: dureeMois == 12 ? '2 mois offerts' : null,
        description: dureeMois == 12 ? 'Abonnement annuel économique' : null,
      ),
    );
  }

  /// Récupère la limite d'utilisateurs pour l'activité commerce (ou max global)
  int? get maxUtilisateursCommerce {
    final act = activites.firstWhere(
      (a) => a['activite_code'] == 'COMMERCE',
      orElse: () => <String, dynamic>{},
    );
    return act['max_utilisateurs'] as int?;
  }

  /// Récupère la limite de boutiques/sites pour l'activité commerce
  int? get maxBoutiquesCommerce {
    final act = activites.firstWhere(
      (a) => a['activite_code'] == 'COMMERCE',
      orElse: () => <String, dynamic>{},
    );
    return act['max_perimetres'] as int?;
  }

  /// Libellé formaté des activités autorisées
  List<String> get libellesActivites {
    final list = <String>[];
    for (final a in activites) {
      final lib = a['activite_libelle'] as String? ?? a['activite_code'] as String? ?? '';
      if (lib.isNotEmpty && !list.contains(lib)) list.add(lib);
    }
    return list;
  }

  /// Liste propre des libellés de modules inclus
  List<String> get nomsModules {
    final result = <String>[];
    for (final m in modules) {
      if (m is Map) {
        final lib = m['libelle'] as String? ?? m['code'] as String? ?? '';
        if (lib.isNotEmpty && !result.contains(lib)) result.add(lib);
      } else if (m is String && !result.contains(m)) {
        result.add(m);
      }
    }
    return result;
  }

  /// Badge distinctif pour la mise en avant
  String get badgeLibelle {
    switch (code) {
      case 'NORMAL':
        return 'Essentiel';
      case 'MOYEN':
        return 'Recommandé';
      case 'PRO':
        return 'Tout illimité';
      default:
        return 'Formule $nom';
    }
  }

  /// Avantages majeurs selon la formule
  List<String> get pointsForts {
    switch (code) {
      case 'NORMAL':
        return [
          'Idéal pour débuter avec une boutique et petite équipe (jusqu\'à 3 utilisateurs)',
          'Gestion complète des stocks, ventes, caisse & reçus imprimables',
          'Suivi des clients, fournisseurs et dépenses courantes',
          'Sauvegardes sécurisées et fonctionnement 100% hors-ligne garanti',
        ];
      case 'MOYEN':
        return [
          'Jusqu\'à 2 boutiques ou agences opérationnelles distinctes',
          'Combinaison autorisée de 2 activités métiers (ex: Commerce + Services)',
          'Jusqu\'à 7 collaborateurs actifs avec gestion des permissions par rôle',
          'Intelligence commerciale, bilans avancés et alertes de rentabilité',
        ];
      case 'PRO':
        return [
          'Tous les secteurs d\'activité inclus sans restriction (Commerce, Services, Immobilier)',
          'Nombre illimité de boutiques, points de vente et agences',
          'Nombre illimité de collaborateurs avec contrôle d\'accès granulaire',
          'Supervision globale centralisée, synchronisation et assistance prioritaire',
        ];
      default:
        return [
          'Accès complet aux modules DubaGest',
          'Sauvegardes sécurisées et données conservées à vie',
        ];
    }
  }
}

/// Catalogue officiel de secours utilisé hors-ligne ou en cas d'indisponibilité réseau.
const List<PlanCatalogueItem> cataloguePlansParDefaut = [
  PlanCatalogueItem(
    code: 'NORMAL',
    nom: 'Normal',
    description: 'Gestion essentielle pour petite boutique et commerçant indépendant.',
    ordre: 1,
    prixMensuel: 1000,
    devise: 'XOF',
    maxActivites: 1,
    activites: [
      {
        'activite_code': 'COMMERCE',
        'activite_libelle': 'Commerce',
        'max_utilisateurs': 3,
        'max_perimetres': 1,
      },
    ],
    roles: [
      {'role_code': 'GESTIONNAIRE', 'max_membres': 1},
      {'role_code': 'CAISSIER', 'max_membres': 2},
    ],
    modules: [
      {'code': 'COMMERCE_VENTES', 'libelle': 'Ventes & Reçus'},
      {'code': 'COMMERCE_STOCK', 'libelle': 'Gestion des stocks'},
      {'code': 'COMMERCE_PRODUITS', 'libelle': 'Catalogue articles'},
      {'code': 'COMMERCE_CAISSE', 'libelle': 'Caisse quotidienne'},
      {'code': 'COMMUN_CONTACTS', 'libelle': 'Clients & Fournisseurs'},
    ],
    tarifsDurees: [
      TarifDureeItem(dureeMois: 1, montantTotal: 1000, remisePourcentage: 0),
      TarifDureeItem(dureeMois: 3, montantTotal: 3000, remisePourcentage: 0),
      TarifDureeItem(dureeMois: 6, montantTotal: 6000, remisePourcentage: 0),
      TarifDureeItem(dureeMois: 12, montantTotal: 10000, remisePourcentage: 17, badgePromo: '2 mois offerts'),
    ],
  ),
  PlanCatalogueItem(
    code: 'MOYEN',
    nom: 'Moyen',
    description: 'Multi-boutiques et multi-activités pour entreprises en croissance.',
    ordre: 2,
    prixMensuel: 2000,
    devise: 'XOF',
    maxActivites: 2,
    activites: [
      {
        'activite_code': 'COMMERCE',
        'activite_libelle': 'Commerce',
        'max_utilisateurs': 7,
        'max_perimetres': 2,
      },
      {
        'activite_code': 'SERVICES',
        'activite_libelle': 'Services',
        'max_utilisateurs': 7,
        'max_perimetres': 2,
      },
    ],
    roles: [
      {'role_code': 'GESTIONNAIRE', 'max_membres': 2},
      {'role_code': 'CAISSIER', 'max_membres': 5},
    ],
    modules: [
      {'code': 'COMMERCE_VENTES', 'libelle': 'Ventes & Factures'},
      {'code': 'COMMERCE_STOCK', 'libelle': 'Stocks multi-boutiques'},
      {'code': 'COMMERCE_PRODUITS', 'libelle': 'Catalogue articles'},
      {'code': 'COMMERCE_CAISSE', 'libelle': 'Caisse multi-sessions'},
      {'code': 'COMMUN_CONTACTS', 'libelle': 'Clients & Fournisseurs'},
      {'code': 'FINANCES_CHARGES', 'libelle': 'Dépenses & Charges'},
      {'code': 'FINANCES_CREANCES', 'libelle': 'Suivi des créances'},
      {'code': 'COMMERCE_INTELLIGENCE', 'libelle': 'Intelligence commerciale'},
    ],
    tarifsDurees: [
      TarifDureeItem(dureeMois: 1, montantTotal: 2000, remisePourcentage: 0),
      TarifDureeItem(dureeMois: 3, montantTotal: 6000, remisePourcentage: 0),
      TarifDureeItem(dureeMois: 6, montantTotal: 12000, remisePourcentage: 0),
      TarifDureeItem(dureeMois: 12, montantTotal: 20000, remisePourcentage: 17, badgePromo: '2 mois offerts'),
    ],
  ),
  PlanCatalogueItem(
    code: 'PRO',
    nom: 'Pro',
    description: 'La suite complète sans restriction pour grands commerces et immobilier.',
    ordre: 3,
    prixMensuel: 5000,
    devise: 'XOF',
    maxActivites: 3,
    activites: [
      {
        'activite_code': 'COMMERCE',
        'activite_libelle': 'Commerce',
        'max_utilisateurs': 999,
        'max_perimetres': 999,
      },
      {
        'activite_code': 'SERVICES',
        'activite_libelle': 'Services',
        'max_utilisateurs': 999,
        'max_perimetres': 999,
      },
      {
        'activite_code': 'IMMOBILIER',
        'activite_libelle': 'Immobilier',
        'max_utilisateurs': 999,
        'max_perimetres': 999,
      },
    ],
    roles: [
      {'role_code': 'ADMIN', 'max_membres': 999},
      {'role_code': 'GESTIONNAIRE', 'max_membres': 999},
      {'role_code': 'CAISSIER', 'max_membres': 999},
    ],
    modules: [
      {'code': 'COMMERCE_VENTES', 'libelle': 'Ventes & Factures'},
      {'code': 'COMMERCE_STOCK', 'libelle': 'Gestion avancée des stocks'},
      {'code': 'COMMERCE_PRODUITS', 'libelle': 'Catalogue articles & variantes'},
      {'code': 'COMMERCE_CAISSE', 'libelle': 'Caisse et clôtures'},
      {'code': 'COMMUN_CONTACTS', 'libelle': 'Clients, Fournisseurs, Locataires'},
      {'code': 'FINANCES_CHARGES', 'libelle': 'Dépenses & Charges'},
      {'code': 'FINANCES_CREANCES', 'libelle': 'Créances & Dettes'},
      {'code': 'IMMOBILIER_LOYERS', 'libelle': 'Loyers & Quittances'},
      {'code': 'COMMUN_DOCUMENTS', 'libelle': 'Éditeur & Justificatifs PDF'},
      {'code': 'COMMERCE_INTELLIGENCE', 'libelle': 'Intelligence commerciale'},
    ],
    tarifsDurees: [
      TarifDureeItem(dureeMois: 1, montantTotal: 5000, remisePourcentage: 0),
      TarifDureeItem(dureeMois: 3, montantTotal: 15000, remisePourcentage: 0),
      TarifDureeItem(dureeMois: 6, montantTotal: 30000, remisePourcentage: 0),
      TarifDureeItem(dureeMois: 12, montantTotal: 50000, remisePourcentage: 17, badgePromo: '2 mois offerts'),
    ],
  ),
];

/// Provider fournissant le catalogue officiel des plans depuis Supabase
/// avec persistance locale hors-ligne et repli automatique garanti en cas de coupure réseau.
final cataloguePlansProvider = FutureProvider.autoDispose<List<PlanCatalogueItem>>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  const cacheKey = 'cache_catalogue_plans_json_v1';

  try {
    final client = ref.watch(supabaseClientProvider);
    final res = await client.rpc('lister_catalogue_plans').timeout(const Duration(seconds: 4));
    final listRaw = res as List? ?? [];
    if (listRaw.isNotEmpty) {
      // Met en cache persistant local pour le mode hors-ligne
      await prefs.setString(cacheKey, jsonEncode(listRaw));
      return listRaw
          .map((e) => PlanCatalogueItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
  } catch (_) {
    // Mode hors-ligne ou serveur inaccessible : bascule immédiate sur le cache local ou le repli par défaut
  }

  // 1. Tenter la lecture depuis le cache local persistant
  try {
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      final listRaw = jsonDecode(cached) as List;
      if (listRaw.isNotEmpty) {
        return listRaw
            .map((e) => PlanCatalogueItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }
  } catch (_) {}

  // 2. Repli ultime garanti : Catalogue officiel DubaGest par défaut
  return cataloguePlansParDefaut;
});
