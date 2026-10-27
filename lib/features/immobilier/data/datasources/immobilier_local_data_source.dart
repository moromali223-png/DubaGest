import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/contrat_bail.dart';
import '../../domain/entities/echeance_loyer.dart';
import '../../domain/entities/locataire_immobilier.dart';
import '../../domain/entities/location_immobilier.dart';
import '../models/bien_mappers.dart';

/// Stockage local hors-ligne pour le module Immobilier (Biens et Locataires).
class ImmobilierLocalDataSource {
  ImmobilierLocalDataSource(this._db);

  final AppDatabase _db;

  // --- BIENS ---

  Future<List<BienImmobilier>> chargerBiens(String entrepriseId) async {
    final key = 'immobilier_biens_$entrepriseId';
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null || row.contenu.isEmpty) return const [];
    try {
      final list = jsonDecode(row.contenu) as List<dynamic>;
      return list.map((e) => BienMappers.bienFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> sauvegarderBiens(String entrepriseId, List<BienImmobilier> items) async {
    final key = 'immobilier_biens_$entrepriseId';
    final jsonStr = jsonEncode(items.map(BienMappers.bienToJson).toList());
    await _db.into(_db.jsonCache).insertOnConflictUpdate(
          JsonCacheCompanion.insert(
            cle: key,
            contenu: jsonStr,
            majLe: DateTime.now(),
          ),
        );
  }

  // --- LOCATAIRES (PROFILS) ---

  Future<List<ProfilLocataire>> chargerProfilsLocataires(String entrepriseId) async {
    final key = 'immobilier_locataires_profils_$entrepriseId';
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null || row.contenu.isEmpty) return const [];
    try {
      final list = jsonDecode(row.contenu) as List<dynamic>;
      return list.map((e) => ProfilLocataire.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> sauvegarderProfilsLocataires(String entrepriseId, List<ProfilLocataire> items) async {
    final key = 'immobilier_locataires_profils_$entrepriseId';
    final jsonStr = jsonEncode(items.map((p) => p.toJson()).toList());
    await _db.into(_db.jsonCache).insertOnConflictUpdate(
          JsonCacheCompanion.insert(
            cle: key,
            contenu: jsonStr,
            majLe: DateTime.now(),
          ),
        );
  }

  Future<ProfilLocataire?> chargerProfilLocataire(String contactId) async {
    final key = 'immobilier_locataire_profil_$contactId';
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null || row.contenu.isEmpty) return null;
    try {
      final map = jsonDecode(row.contenu) as Map<String, dynamic>;
      return ProfilLocataire.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> sauvegarderProfilLocataire(ProfilLocataire profil) async {
    final key = 'immobilier_locataire_profil_${profil.contactId}';
    final jsonStr = jsonEncode(profil.toJson());
    await _db.into(_db.jsonCache).insertOnConflictUpdate(
          JsonCacheCompanion.insert(
            cle: key,
            contenu: jsonStr,
            majLe: DateTime.now(),
          ),
        );

    // Mettre à jour aussi dans la liste globale de l'entreprise
    final existants = await chargerProfilsLocataires(profil.entrepriseId);
    final index = existants.indexWhere((p) => p.contactId == profil.contactId);
    final misAJour = List<ProfilLocataire>.from(existants);
    if (index >= 0) {
      misAJour[index] = profil;
    } else {
      misAJour.add(profil);
    }
    await sauvegarderProfilsLocataires(profil.entrepriseId, misAJour);
  }

  // --- LOCATIONS ---

  Future<List<LocationImmobilier>> chargerLocations(String entrepriseId) async {
    final key = 'immobilier_locations_$entrepriseId';
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null || row.contenu.isEmpty) return const [];
    try {
      final list = jsonDecode(row.contenu) as List<dynamic>;
      return list.map((e) => LocationImmobilier.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> sauvegarderLocations(String entrepriseId, List<LocationImmobilier> items) async {
    final key = 'immobilier_locations_$entrepriseId';
    final jsonStr = jsonEncode(items.map((loc) => loc.toJson()).toList());
    await _db.into(_db.jsonCache).insertOnConflictUpdate(
          JsonCacheCompanion.insert(
            cle: key,
            contenu: jsonStr,
            majLe: DateTime.now(),
          ),
        );
  }

  Future<void> sauvegarderLocation(LocationImmobilier location) async {
    final existants = await chargerLocations(location.entrepriseId);
    final index = existants.indexWhere((l) => l.id == location.id);
    final misAJour = List<LocationImmobilier>.from(existants);
    if (index >= 0) {
      misAJour[index] = location;
    } else {
      misAJour.insert(0, location);
    }
    await sauvegarderLocations(location.entrepriseId, misAJour);
  }

  // --- CONTRATS DE BAIL ---

  Future<List<ContratBail>> chargerContrats(String entrepriseId) async {
    final key = 'immobilier_contrats_$entrepriseId';
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null || row.contenu.isEmpty) return const [];
    try {
      final list = jsonDecode(row.contenu) as List<dynamic>;
      return list.map((e) => ContratBail.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> sauvegarderContrats(String entrepriseId, List<ContratBail> items) async {
    final key = 'immobilier_contrats_$entrepriseId';
    final jsonStr = jsonEncode(items.map((c) => c.toJson()).toList());
    await _db.into(_db.jsonCache).insertOnConflictUpdate(
          JsonCacheCompanion.insert(
            cle: key,
            contenu: jsonStr,
            majLe: DateTime.now(),
          ),
        );
  }

  Future<void> sauvegarderContrat(ContratBail contrat) async {
    final existants = await chargerContrats(contrat.entrepriseId);
    final index = existants.indexWhere((c) => c.id == contrat.id);
    final misAJour = List<ContratBail>.from(existants);
    if (index >= 0) {
      misAJour[index] = contrat;
    } else {
      misAJour.insert(0, contrat);
    }
    await sauvegarderContrats(contrat.entrepriseId, misAJour);
  }

  // --- ÉCHÉANCES DE LOYERS ---

  Future<List<EcheanceLoyer>> chargerEcheancesLoyers(String entrepriseId) async {
    final key = 'immobilier_echeances_loyers_$entrepriseId';
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null || row.contenu.isEmpty) return const [];
    try {
      final list = jsonDecode(row.contenu) as List<dynamic>;
      return list.map((e) => EcheanceLoyer.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> sauvegarderEcheancesLoyers(String entrepriseId, List<EcheanceLoyer> items) async {
    final key = 'immobilier_echeances_loyers_$entrepriseId';
    final jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
    await _db.into(_db.jsonCache).insertOnConflictUpdate(
          JsonCacheCompanion.insert(
            cle: key,
            contenu: jsonStr,
            majLe: DateTime.now(),
          ),
        );
  }

  Future<void> sauvegarderEcheanceLoyer(EcheanceLoyer echeance) async {
    final existants = await chargerEcheancesLoyers(echeance.entrepriseId);
    final index = existants.indexWhere((e) => e.id == echeance.id);
    final misAJour = List<EcheanceLoyer>.from(existants);
    if (index >= 0) {
      misAJour[index] = echeance;
    } else {
      misAJour.insert(0, echeance);
    }
    await sauvegarderEcheancesLoyers(echeance.entrepriseId, misAJour);
  }

  // --- FILE D'ATTENTE DE SYNCHRONISATION ---

  Future<void> empilerOperationSync({
    required String operationId,
    required String userId,
    required String entityTable,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
    int? baseVersion,
  }) async {
    await _db.into(_db.syncQueue).insertOnConflictUpdate(
          SyncQueueCompanion.insert(
            id: operationId,
            userId: userId,
            entityTable: entityTable,
            recordId: recordId,
            operation: operation,
            payload: jsonEncode(payload),
            baseVersion: Value(baseVersion),
            status: 'PENDING',
            attempts: const Value(0),
            createdAt: DateTime.now(),
          ),
        );
  }
}
