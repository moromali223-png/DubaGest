import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/app_logger.dart';

abstract interface class ContexteRemoteDataSource {
  Future<Map<String, dynamic>> fetch({String? entrepriseId});
}

class SupabaseContexteRemoteDataSource implements ContexteRemoteDataSource {
  SupabaseContexteRemoteDataSource(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> fetch({String? entrepriseId}) async {
    try {
      final res = await _client.rpc<Map<String, dynamic>>(
        'get_contexte_session',
        params: {'p_entreprise_id': entrepriseId},
      ).timeout(const Duration(seconds: 4));
      return res;
    } catch (e) {
      final failure = ErrorMapper.map(e);
      if (failure.kind == FailureKind.network) {
        AppLogger.warning(
          'Hors-ligne / timeout détecté lors du chargement distant du contexte: $e',
          tag: 'contexte',
        );
        rethrow;
      }

      AppLogger.warning(
        'Erreur lors de l\'appel RPC get_contexte_session, tentative de fallback direct: $e',
        tag: 'contexte',
      );
      try {
        return await _fetchFallback(entrepriseId: entrepriseId).timeout(const Duration(seconds: 5));
      } catch (fallbackError) {
        AppLogger.error(
          'Échec du fallback direct contexte: $fallbackError',
          tag: 'contexte',
        );
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> _fetchFallback({String? entrepriseId}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const AuthException('Utilisateur non connecté');
    }

    // 1. Profil utilisateur
    Map<String, dynamic>? profil;
    try {
      final p = await _client.from('profiles').select().eq('id', uid).maybeSingle();
      if (p != null) {
        profil = Map<String, dynamic>.from(p);
      }
    } catch (_) {}

    // 2. Membres entreprises de cet utilisateur
    final membres = await _client
        .from('membres_entreprise')
        .select('id, entreprise_id, role_code, statut, created_at')
        .eq('user_id', uid);
    final membresList = List<Map<String, dynamic>>.from(membres as List);

    final entrepriseIds = membresList.map((m) => m['entreprise_id'] as String).toSet().toList();

    // 3. Entreprises
    List<Map<String, dynamic>> entreprises = [];
    if (entrepriseIds.isNotEmpty) {
      final ents = await _client
          .from('entreprises')
          .select('id, nom, statut, pays, devise, langue_defaut')
          .inFilter('id', entrepriseIds);
      entreprises = List<Map<String, dynamic>>.from(ents as List);
    }

    final entreprisesResume = entreprises
        .map((e) => {'id': e['id'], 'nom': e['nom']})
        .toList()
      ..sort((a, b) => (a['nom'] as String? ?? '').compareTo(b['nom'] as String? ?? ''));

    final base = <String, dynamic>{
      'server_time': DateTime.now().toIso8601String(),
      'profil': profil ?? {'id': uid, 'nom_complet': profil?['nom_complet'] ?? ''},
      'entreprises': entreprisesResume,
    };

    // Sélectionner le membre actif
    Map<String, dynamic>? selectedMembre;
    if (entrepriseId != null) {
      selectedMembre = membresList.cast<Map<String, dynamic>?>().firstWhere(
            (m) => m?['entreprise_id'] == entrepriseId,
            orElse: () => null,
          );
    } else {
      final sorted = List<Map<String, dynamic>>.from(membresList)
        ..sort((a, b) {
          final aActif = a['statut'] == 'ACTIF' ? 1 : 0;
          final bActif = b['statut'] == 'ACTIF' ? 1 : 0;
          if (aActif != bActif) return bActif.compareTo(aActif);
          final aDate = a['created_at']?.toString() ?? '';
          final bDate = b['created_at']?.toString() ?? '';
          return bDate.compareTo(aDate);
        });
      if (sorted.isNotEmpty) {
        selectedMembre = sorted.first;
      }
    }

    if (selectedMembre == null) {
      return {
        ...base,
        'entreprise': null,
        'membre': null,
      };
    }

    final eid = selectedMembre['entreprise_id'] as String;
    final currentEntreprise = entreprises.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['id'] == eid,
          orElse: () => null,
        );

    // 4. Roles & permissions
    List<Map<String, dynamic>> rolesList = [];
    try {
      final rolesListRaw = await _client.from('roles').select('code, activite_code, ordre, libelle');
      rolesList = List<Map<String, dynamic>>.from(rolesListRaw as List);
    } catch (_) {}

    List<Map<String, dynamic>> rolesPermissions = [];
    try {
      final rolesPermissionsRaw = await _client.from('roles_permissions').select('role_code, permission_code');
      rolesPermissions = List<Map<String, dynamic>>.from(rolesPermissionsRaw as List);
    } catch (_) {}

    final userRole = selectedMembre['role_code'] as String;
    final userRoleUpper = userRole.toUpperCase();
    final isAdmin = userRoleUpper == 'ADMINISTRATEUR' || userRoleUpper == 'ADMIN';

    final Set<String> userPermissionsSet = {};
    if (selectedMembre['statut'] == 'ACTIF') {
      if (isAdmin) {
        // L'administrateur a l'intégralité des permissions existantes
        userPermissionsSet.addAll(rolesPermissions.map((rp) => rp['permission_code'] as String));
        // Permissions socle garanties pour l'administrateur
        userPermissionsSet.addAll([
          'receivables.view', 'receivables.manage',
          'payments.view', 'payments.create',
          'cash.view', 'cash.open', 'cash.move', 'cash.close',
          'expenses.view', 'expenses.create', 'expenses.manage',
          'sales.view', 'sales.create',
          'stock.view', 'stock.manage',
          'products.view', 'products.manage',
          'contacts.view', 'contacts.create', 'contacts.manage',
          'documents.view', 'documents.create',
          'perimetres.access_all', 'perimetres.manage',
          'users.view', 'users.manage',
          'subscription.view', 'subscription.manage',
          'enterprise.manage',
        ]);
      } else {
        for (final rp in rolesPermissions) {
          if (rp['role_code']?.toString().toUpperCase() == userRoleUpper) {
            userPermissionsSet.add(rp['permission_code'] as String);
          }
        }
      }
    }

    final hasAccessAll = isAdmin || userPermissionsSet.contains('perimetres.access_all');

    // 5. Modules actifs
    List<Map<String, dynamic>> modulesJson = [];
    try {
      final moRaw = await _client
          .from('modules')
          .select('code, activite_code, permission_acces, ordre, categorie')
          .eq('est_actif', true);
      modulesJson = List<Map<String, dynamic>>.from(moRaw as List)
        ..sort((a, b) => (a['ordre'] as int? ?? 0).compareTo(b['ordre'] as int? ?? 0));
    } catch (_) {}

    if (modulesJson.isEmpty) {
      // Modules indispensables par défaut si la table modules est vide ou indisponible
      modulesJson = [
        {'code': 'finances.creances', 'activite_code': null, 'permission_acces': 'receivables.view', 'ordre': 7, 'categorie': 'FINANCES'},
        {'code': 'finances.paiements', 'activite_code': null, 'permission_acces': 'payments.view', 'ordre': 8, 'categorie': 'FINANCES'},
        {'code': 'finances.caisse', 'activite_code': null, 'permission_acces': 'cash.view', 'ordre': 9, 'categorie': 'FINANCES'},
        {'code': 'finances.depenses', 'activite_code': null, 'permission_acces': 'expenses.view', 'ordre': 10, 'categorie': 'FINANCES'},
        {'code': 'commerce.ventes', 'activite_code': 'COMMERCE', 'permission_acces': 'sales.view', 'ordre': 1, 'categorie': 'METIER'},
        {'code': 'commerce.stock', 'activite_code': 'COMMERCE', 'permission_acces': 'stock.view', 'ordre': 2, 'categorie': 'METIER'},
        {'code': 'commerce.produits', 'activite_code': 'COMMERCE', 'permission_acces': 'products.view', 'ordre': 3, 'categorie': 'METIER'},
        {'code': 'commun.contacts', 'activite_code': null, 'permission_acces': 'contacts.view', 'ordre': 4, 'categorie': 'COMMUN'},
        {'code': 'commun.documents', 'activite_code': null, 'permission_acces': 'documents.view', 'ordre': 5, 'categorie': 'COMMUN'},
      ];
    }

    final allModuleCodes = modulesJson.map((m) => m['code'] as String).toList();

    // 6. Abonnement
    Map<String, dynamic>? abonnement;
    String? planCode;
    try {
      final abosRaw = await _client
          .from('abonnements')
          .select('id, plan_code, statut, date_debut, date_fin, type_facturation')
          .eq('entreprise_id', eid);
      final abos = List<Map<String, dynamic>>.from(abosRaw as List);
      if (abos.isNotEmpty) {
        abos.sort((a, b) {
          final aActive = (a['statut'] == 'ACTIF' || a['statut'] == 'ESSAI') ? 1 : 0;
          final bActive = (b['statut'] == 'ACTIF' || b['statut'] == 'ESSAI') ? 1 : 0;
          if (aActive != bActive) return bActive.compareTo(aActive);
          final aDebut = a['date_debut']?.toString() ?? '';
          final bDebut = b['date_debut']?.toString() ?? '';
          return bDebut.compareTo(aDebut);
        });
        abonnement = abos.first;
        planCode = abonnement['plan_code'] as String?;
      }
    } catch (_) {}

    // Si aucun abonnement en base ou expiré, garantir un abonnement d'essai/actif par défaut
    abonnement ??= {
      'id': 'def-abo',
      'plan_code': 'NORMAL',
      'statut': 'ACTIF',
      'type_facturation': 'COMMERCIAL',
      'date_debut': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      'date_fin': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
    };
    planCode ??= abonnement['plan_code'] as String? ?? 'NORMAL';

    // 7. Plan et modules autorisés
    Map<String, dynamic>? planJson;
    try {
      final planData = await _client.from('plans').select('code, nom, max_activites').eq('code', planCode).maybeSingle();
      if (planData != null) {
        final paRaw = await _client.from('plan_activites').select('activite_code, max_utilisateurs, max_perimetres').eq('plan_code', planCode);
        final prRaw = await _client.from('plan_roles').select('role_code, max_membres').eq('plan_code', planCode);
        final pmRaw = await _client.from('plan_modules').select('module_code').eq('plan_code', planCode);

        final planModList = (pmRaw as List).map((m) => m['module_code'] as String).toSet();
        // Inclure impérativement les modules indispensables si absents
        planModList.addAll(['finances.creances', 'finances.paiements', 'finances.caisse', 'finances.depenses']);

        planJson = {
          'code': planData['code'],
          'nom': planData['nom'],
          'max_activites': planData['max_activites'],
          'activites': paRaw,
          'roles': prRaw,
          'modules': planModList.toList(),
        };
      }
    } catch (_) {}

    planJson ??= {
      'code': planCode,
      'nom': 'Formule Complète',
      'max_activites': 10,
      'activites': [],
      'roles': [],
      'modules': allModuleCodes,
    };

    // 8. Entreprise Activités
    List<Map<String, dynamic>> activitesJson = [];
    try {
      final eaRaw = await _client.from('entreprise_activites').select('activite_code, est_active').eq('entreprise_id', eid);
      final eaList = List<Map<String, dynamic>>.from(eaRaw as List);
      final allActRaw = await _client.from('activites').select('code, ordre, type_perimetre_defaut');
      final allAct = {for (final a in allActRaw as List) a['code'] as String: a};

      activitesJson = eaList.map((ea) {
        final code = ea['activite_code'] as String;
        final act = allAct[code] as Map<String, dynamic>?;
        return {
          'code': code,
          'est_active': ea['est_active'] == true,
          'type_perimetre_defaut': act?['type_perimetre_defaut'],
          'ordre': act?['ordre'] ?? 0,
        };
      }).toList()..sort((a, b) => (a['ordre'] as int).compareTo(b['ordre'] as int));
    } catch (_) {}

    if (activitesJson.isEmpty) {
      activitesJson = [
        {'code': 'COMMERCE', 'est_active': true, 'type_perimetre_defaut': 'BOUTIQUE', 'ordre': 1},
      ];
    }

    // 9. Périmètres
    List<Map<String, dynamic>> perimetresJson = [];
    if (selectedMembre['statut'] == 'ACTIF') {
      try {
        final perimRaw = await _client
            .from('perimetres')
            .select('id, entreprise_id, activite_code, type, nom, code, est_actif, version, updated_at')
            .eq('entreprise_id', eid)
            .isFilter('deleted_at', null);
        final allPerims = List<Map<String, dynamic>>.from(perimRaw as List);

        if (hasAccessAll) {
          perimetresJson = allPerims;
        } else {
          final mpRaw = await _client.from('membre_perimetres').select('perimetre_id').eq('membre_id', selectedMembre['id'] as String);
          final allowedIds = (mpRaw as List).map((m) => m['perimetre_id'] as String).toSet();
          perimetresJson = allPerims.where((p) => allowedIds.contains(p['id'])).toList();
        }
        perimetresJson.sort((a, b) => (a['nom'] as String? ?? '').compareTo(b['nom'] as String? ?? ''));
      } catch (_) {}
    }

    // 10. Usage / Consommation
    Map<String, dynamic> usageJson = {
      'utilisateurs': 0,
      'membres_par_role': <String, int>{},
      'perimetres_par_activite': <String, int>{},
    };
    try {
      final allMembresRaw = await _client.from('membres_entreprise').select('role_code, statut').eq('entreprise_id', eid).eq('statut', 'ACTIF');
      final allM = List<Map<String, dynamic>>.from(allMembresRaw as List);
      final membresParRole = <String, int>{};
      for (final m in allM) {
        final r = m['role_code'] as String;
        membresParRole[r] = (membresParRole[r] ?? 0) + 1;
      }

      final perimsParActivite = <String, int>{};
      for (final p in perimetresJson) {
        final act = p['activite_code'] as String? ?? '';
        if (act.isNotEmpty) {
          perimsParActivite[act] = (perimsParActivite[act] ?? 0) + 1;
        }
      }

      usageJson = {
        'utilisateurs': allM.length,
        'membres_par_role': membresParRole,
        'perimetres_par_activite': perimsParActivite,
      };
    } catch (_) {}

    final rolesFormat = rolesList.map((r) {
      final code = r['code'] as String;
      final codeUpper = code.toUpperCase();
      final accesTous = rolesPermissions.any((rp) =>
              rp['role_code']?.toString().toUpperCase() == codeUpper &&
              rp['permission_code'] == 'perimetres.access_all') ||
          codeUpper == 'ADMINISTRATEUR' ||
          codeUpper == 'SUPERVISEUR';
      return {
        'code': code,
        'activite_code': r['activite_code'],
        'acces_tous_perimetres': accesTous,
      };
    }).toList();

    return {
      ...base,
      'entreprise': currentEntreprise,
      'membre': {
        'id': selectedMembre['id'],
        'role_code': selectedMembre['role_code'],
        'statut': selectedMembre['statut'],
      },
      'role': {
        'code': userRole,
        'activite_code': rolesList.cast<Map<String, dynamic>?>().firstWhere((r) => r?['code'] == userRole, orElse: () => null)?['activite_code'],
      },
      'permissions': userPermissionsSet.toList(),
      'abonnement': abonnement,
      'plan': planJson,
      'activites': activitesJson,
      'roles': rolesFormat,
      'modules': modulesJson,
      'perimetres': perimetresJson,
      'usage': usageJson,
    };
  }
}
