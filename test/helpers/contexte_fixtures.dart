import 'package:dubagest/features/entreprise/data/models/contexte_session_model.dart';
import 'package:dubagest/features/entreprise/domain/entities/contexte_session.dart';

/// Réponse de `get_contexte_session` reproduisant le catalogue de la
/// migration (règles NORMAL / MOYEN / PRO), pour tester les moteurs sans serveur.
/// `null` = illimité.
const _limitesPlans = <String, Map<String, Object>>{
  'NORMAL': {
    'max_activites': 1,
    'activites': <String, List<int?>>{'COMMERCE': [3, 1], 'SERVICES': [1, 1], 'IMMOBILIER': [1, 1]},
    'roles': <String, int?>{
      'ADMINISTRATEUR': 1, 'GESTIONNAIRE_STOCK': 1, 'VENDEUR': 1, 'CAISSIER': 1, 'GESTIONNAIRE_IMMOBILIER': 1,
    },
  },
  'MOYEN': {
    'max_activites': 2,
    'activites': <String, List<int?>>{'COMMERCE': [7, 2], 'SERVICES': [1, 1], 'IMMOBILIER': [1, 1]},
    'roles': <String, int?>{
      'ADMINISTRATEUR': 1, 'SUPERVISEUR': 2, 'GESTIONNAIRE_STOCK': 2, 'VENDEUR': 2, 'CAISSIER': 2,
      'GESTIONNAIRE_IMMOBILIER': 1,
    },
  },
  'PRO': {
    'max_activites': 3,
    'activites': <String, List<int?>>{
      'COMMERCE': [null, null], 'SERVICES': [null, null], 'IMMOBILIER': [null, null],
    },
    'roles': <String, int?>{
      'ADMINISTRATEUR': null, 'SUPERVISEUR': null, 'GESTIONNAIRE_STOCK': null, 'VENDEUR': null,
      'CAISSIER': null, 'GESTIONNAIRE_IMMOBILIER': null,
    },
  },
};

const _modules = {
  'admin.entreprise': (null, 'entreprise.view', 1),
  'admin.utilisateurs': (null, 'users.view', 2),
  'admin.perimetres': (null, 'perimetres.view', 3),
  'admin.abonnement': (null, 'subscription.view', 4),
  'admin.audit': (null, 'audit.view', 5),
  'commun.contacts': (null, 'contacts.view', 6),
  'commun.documents': (null, 'documents.view', 11),
  'commun.agenda': (null, 'agenda.view', 12),
  'commun.rapports': (null, 'reports.view', 13),
  'commerce.produits': ('COMMERCE', 'products.view', 10),
  'commerce.stock': ('COMMERCE', 'stock.view', 11),
  'commerce.ventes': ('COMMERCE', 'sales.view', 12),
  'commerce.achats': ('COMMERCE', 'purchases.view', 13),
  'commerce.fournisseurs': ('COMMERCE', 'suppliers.view', 15),
  'finances.creances': (null, 'receivables.view', 7),
  'finances.paiements': (null, 'payments.view', 8),
  'finances.caisse': (null, 'cash.view', 9),
  'finances.depenses': (null, 'expenses.view', 10),
  'services.services': ('SERVICES', 'services.view', 20),
  'services.prestations': ('SERVICES', 'prestations.view', 22),
  'services.devis': ('SERVICES', 'quotes.view', 23),
  'services.facturation': ('SERVICES', 'invoices.view', 24),
  'immobilier.biens': ('IMMOBILIER', 'properties.view', 30),
  'immobilier.proprietaires': ('IMMOBILIER', 'owners.view', 31),
  'immobilier.locataires': ('IMMOBILIER', 'tenants.view', 32),
  'immobilier.locations': ('IMMOBILIER', 'rentals.view', 33),
  'immobilier.contrats': ('IMMOBILIER', 'contracts.view', 34),
  'immobilier.loyers': ('IMMOBILIER', 'rents.view', 35),
};

const vendeurPermissions = {
  'perimetres.view', 'products.view', 'stock.view', 'sales.view', 'sales.create',
  'contacts.view', 'contacts.create', 'contacts.update', 'cash.view', 'cash.open', 'cash.move',
  'payments.view', 'payments.create', 'receivables.view',
  'documents.view', 'documents.create', 'documents.print', 'documents.share', 'agenda.view',
};

/// Toutes les permissions (rôle administrateur).
Set<String> adminPermissions() => {
      'entreprise.view', 'entreprise.manage', 'users.view', 'users.manage', 'users.invite',
      'perimetres.view', 'perimetres.manage', 'perimetres.access_all', 'subscription.view',
      for (final m in _modules.values) m.$2,
      'sales.create', 'sales.update', 'products.create', 'products.update', 'stock.create', 'stock.update',
      'purchases.create', 'purchases.update', 'suppliers.create',
      'contacts.create', 'contacts.update', 'contacts.archive',
      'receivables.manage', 'payments.create', 'payments.cancel', 'cash.open', 'cash.move', 'cash.close', 'cash.transfer', 'cash.adjust',
      'expenses.create', 'expenses.update', 'expenses.cancel', 'expenses.recurring',
      'documents.create', 'documents.print', 'documents.share', 'agenda.manage',
    };

String _categorie(String module) => module.startsWith('admin.')
    ? 'ADMIN'
    : module.startsWith('commun.')
        ? 'COMMUN'
        : module.startsWith('finances.')
            ? 'FINANCES'
            : 'METIER';

const entrepriseId = 'e-1';
const userId = 'u-1';

Map<String, dynamic> contexteJson({
  String plan = 'MOYEN',
  List<String> activites = const ['COMMERCE'],
  String role = 'ADMINISTRATEUR',
  Set<String>? permissions,
  String membreStatut = 'ACTIF',
  String entrepriseStatut = 'ACTIVE',
  String abonnementStatut = 'ACTIF',
  DateTime? dateFin,
  int utilisateurs = 1,
  Map<String, int> membresParRole = const {'ADMINISTRATEUR': 1},
  Map<String, int> perimetresParActivite = const {},
  List<Map<String, dynamic>> perimetres = const [],
  bool avecEntreprise = true,
}) {
  final p = _limitesPlans[plan]!;
  final limites = p['activites']! as Map<String, List<int?>>;
  return {
    'server_time': '2026-10-03T10:00:00Z',
    'profil': {'id': userId, 'nom_complet': 'Awa Diallo', 'langue': 'fr'},
    'entreprises': [
      if (avecEntreprise) {'id': entrepriseId, 'nom': 'Alpha'},
    ],
    'entreprise': !avecEntreprise
        ? null
        : {'id': entrepriseId, 'nom': 'Alpha', 'statut': entrepriseStatut, 'pays': 'ML', 'devise': 'XOF'},
    'membre': !avecEntreprise ? null : {'id': 'm-1', 'role_code': role, 'statut': membreStatut},
    'permissions': [...(permissions ?? (role == 'ADMINISTRATEUR' ? adminPermissions() : vendeurPermissions))],
    'abonnement': {
      'id': 'a-1',
      'plan_code': plan,
      'statut': abonnementStatut,
      'date_debut': '2026-01-01T00:00:00Z',
      'date_fin': dateFin?.toIso8601String(),
    },
    'plan': {
      'code': plan,
      'nom': plan,
      'max_activites': p['max_activites'],
      'activites': [
        for (final e in limites.entries)
          {'activite_code': e.key, 'max_utilisateurs': e.value[0], 'max_perimetres': e.value[1]},
      ],
      'roles': [
        for (final e in (p['roles']! as Map<String, int?>).entries)
          {'role_code': e.key, 'max_membres': e.value},
      ],
      'modules': _modules.keys.toList(),
    },
    'activites': [
      for (final a in activites)
        {'code': a, 'est_active': true, 'type_perimetre_defaut': a == 'COMMERCE' ? 'BOUTIQUE' : 'AGENCE'},
    ],
    'roles': [
      {'code': 'ADMINISTRATEUR', 'activite_code': null, 'acces_tous_perimetres': true},
      {'code': 'SUPERVISEUR', 'activite_code': 'COMMERCE', 'acces_tous_perimetres': false},
      {'code': 'GESTIONNAIRE_STOCK', 'activite_code': 'COMMERCE', 'acces_tous_perimetres': false},
      {'code': 'VENDEUR', 'activite_code': 'COMMERCE', 'acces_tous_perimetres': false},
      {'code': 'CAISSIER', 'activite_code': 'COMMERCE', 'acces_tous_perimetres': false},
      {'code': 'GESTIONNAIRE_IMMOBILIER', 'activite_code': 'IMMOBILIER', 'acces_tous_perimetres': false},
    ],
    'modules': [
      for (final e in _modules.entries)
        {
          'code': e.key,
          'activite_code': e.value.$1,
          'permission_acces': e.value.$2,
          'ordre': e.value.$3,
          'categorie': _categorie(e.key),
        },
    ],
    'perimetres': perimetres,
    'usage': {
      'utilisateurs': utilisateurs,
      'membres_par_role': membresParRole,
      'perimetres_par_activite': perimetresParActivite,
    },
  };
}

ContexteSession contexte({
  String plan = 'MOYEN',
  List<String> activites = const ['COMMERCE'],
  String role = 'ADMINISTRATEUR',
  Set<String>? permissions,
  String membreStatut = 'ACTIF',
  String entrepriseStatut = 'ACTIVE',
  String abonnementStatut = 'ACTIF',
  DateTime? dateFin,
  int utilisateurs = 1,
  Map<String, int> membresParRole = const {'ADMINISTRATEUR': 1},
  Map<String, int> perimetresParActivite = const {},
  List<Map<String, dynamic>> perimetres = const [],
  bool avecEntreprise = true,
}) =>
    ContexteSessionModel.fromJson(
      contexteJson(
        plan: plan,
        activites: activites,
        role: role,
        permissions: permissions,
        membreStatut: membreStatut,
        entrepriseStatut: entrepriseStatut,
        abonnementStatut: abonnementStatut,
        dateFin: dateFin,
        utilisateurs: utilisateurs,
        membresParRole: membresParRole,
        perimetresParActivite: perimetresParActivite,
        perimetres: perimetres,
        avecEntreprise: avecEntreprise,
      ),
      userId: userId,
      chargeLe: DateTime(2026, 10, 3),
      depuisCache: false,
    );

Map<String, dynamic> perimetreJson(String id, {String activite = 'COMMERCE', String nom = 'Boutique'}) => {
      'id': id,
      'entreprise_id': entrepriseId,
      'activite_code': activite,
      'type': activite == 'COMMERCE' ? 'BOUTIQUE' : 'AGENCE',
      'nom': nom,
      'code': null,
      'est_actif': true,
      'version': 1,
      'updated_at': '2026-10-01T00:00:00Z',
    };
