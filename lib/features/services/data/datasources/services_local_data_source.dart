import 'dart:convert';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/prestation.dart';
import '../../domain/entities/service_catalogue.dart';
import '../models/services_mappers.dart';

/// Stockage local hors-ligne pour le module Services.
class ServicesLocalDataSource {
  ServicesLocalDataSource(this._db);

  final AppDatabase _db;

  // --- CATALOGUE ---

  Future<List<ServiceCatalogue>> chargerCatalogue(String entrepriseId) async {
    final key = 'services_catalogue_$entrepriseId';
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null || row.contenu.isEmpty) return const [];
    try {
      final list = jsonDecode(row.contenu) as List<dynamic>;
      return list.map((e) => ServicesMappers.serviceFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> sauvegarderCatalogue(String entrepriseId, List<ServiceCatalogue> items) async {
    final key = 'services_catalogue_$entrepriseId';
    final jsonStr = jsonEncode(items.map(ServicesMappers.serviceToJson).toList());
    await _db.into(_db.jsonCache).insertOnConflictUpdate(
          JsonCacheCompanion.insert(
            cle: key,
            contenu: jsonStr,
            majLe: DateTime.now(),
          ),
        );
  }

  // --- PRESTATIONS ---

  Future<List<Prestation>> chargerPrestations(String entrepriseId, {String? perimetreId}) async {
    final key = 'prestations_${entrepriseId}_${perimetreId ?? 'all'}';
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null || row.contenu.isEmpty) return const [];
    try {
      final list = jsonDecode(row.contenu) as List<dynamic>;
      return list.map((e) => ServicesMappers.prestationFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> sauvegarderPrestations(String entrepriseId, List<Prestation> prestations, {String? perimetreId}) async {
    final key = 'prestations_${entrepriseId}_${perimetreId ?? 'all'}';
    final jsonStr = jsonEncode(prestations.map(ServicesMappers.prestationToJson).toList());
    await _db.into(_db.jsonCache).insertOnConflictUpdate(
          JsonCacheCompanion.insert(
            cle: key,
            contenu: jsonStr,
            majLe: DateTime.now(),
          ),
        );
  }

  // --- DEVIS ---

  Future<List<DevisPrestation>> chargerDevis(String entrepriseId, {String? perimetreId}) async {
    final key = 'devis_services_${entrepriseId}_${perimetreId ?? 'all'}';
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null || row.contenu.isEmpty) return const [];
    try {
      final list = jsonDecode(row.contenu) as List<dynamic>;
      return list.map((e) => ServicesMappers.devisFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> sauvegarderDevis(String entrepriseId, List<DevisPrestation> devis, {String? perimetreId}) async {
    final key = 'devis_services_${entrepriseId}_${perimetreId ?? 'all'}';
    final jsonStr = jsonEncode(devis.map(ServicesMappers.devisToJson).toList());
    await _db.into(_db.jsonCache).insertOnConflictUpdate(
          JsonCacheCompanion.insert(
            cle: key,
            contenu: jsonStr,
            majLe: DateTime.now(),
          ),
        );
  }

  // --- HISTORIQUE ---

  Future<List<PrestationHistorique>> chargerHistorique(String prestationId) async {
    final key = 'historique_prestation_$prestationId';
    final row = await (_db.select(_db.jsonCache)..where((t) => t.cle.equals(key))).getSingleOrNull();
    if (row == null || row.contenu.isEmpty) return const [];
    try {
      final list = jsonDecode(row.contenu) as List<dynamic>;
      return list.map((e) => ServicesMappers.historiqueFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> sauvegarderHistorique(String prestationId, List<PrestationHistorique> historique) async {
    final key = 'historique_prestation_$prestationId';
    final jsonStr = jsonEncode(historique.map(ServicesMappers.historiqueToJson).toList());
    await _db.into(_db.jsonCache).insertOnConflictUpdate(
          JsonCacheCompanion.insert(
            cle: key,
            contenu: jsonStr,
            majLe: DateTime.now(),
          ),
        );
  }

  // --- FILE D'ATTENTE DE SYNCHRONISATION (SYNC_QUEUE) ---

  Future<void> empilerOperationSync({
    required String operationId,
    required String userId,
    required String entityTable,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await _db.into(_db.syncQueue).insertOnConflictUpdate(
          SyncQueueCompanion.insert(
            id: operationId,
            userId: userId,
            entityTable: entityTable,
            recordId: recordId,
            operation: operation,
            payload: jsonEncode(payload),
            status: 'PENDING',
            createdAt: DateTime.now(),
          ),
        );
  }
}
