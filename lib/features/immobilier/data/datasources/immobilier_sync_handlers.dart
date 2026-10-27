import '../../../../core/errors/failure.dart';
import '../../../../core/sync/sync_contracts.dart';
import '../../../../core/sync/sync_models.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/contrat_bail.dart';
import '../../domain/entities/echeance_loyer.dart';
import '../../domain/entities/locataire_immobilier.dart';
import '../../domain/entities/location_immobilier.dart';
import '../models/bien_mappers.dart';
import 'immobilier_local_data_source.dart';

/// Fabrique des gestionnaires de synchronisation pour les 5 entités immobilières.
List<SyncEntityHandler> immobilierSyncHandlers(
  ImmobilierLocalDataSource local,
  SyncCursorStore cursors,
) =>
    [
      ImmobilierBiensSyncHandler(local, cursors),
      ImmobilierLocatairesProfilsSyncHandler(local, cursors),
      ImmobilierLocationsSyncHandler(local, cursors),
      ImmobilierContratsSyncHandler(local, cursors),
      ImmobilierEcheancesSyncHandler(local, cursors),
    ];

/// Synchronisation de la table `immobilier_biens`.
class ImmobilierBiensSyncHandler implements SyncEntityHandler {
  ImmobilierBiensSyncHandler(this._local, this._cursors);

  final ImmobilierLocalDataSource _local;
  final SyncCursorStore _cursors;

  @override
  String get table => 'immobilier_biens';

  @override
  Future<void> applyRemoteRows(List<Map<String, dynamic>> rows) async {
    final parEntreprise = <String, List<BienImmobilier>>{};

    for (final json in rows) {
      if (json['deleted_at'] != null) continue;
      final bien = BienMappers.bienFromJson(json);
      parEntreprise.putIfAbsent(bien.entrepriseId, () => []).add(bien);
    }

    for (final entry in parEntreprise.entries) {
      final actuels = await _local.chargerBiens(entry.key);
      final mapActuels = {for (final b in actuels) b.id: b};
      for (final distant in entry.value) {
        mapActuels[distant.id] = distant;
      }
      await _local.sauvegarderBiens(entry.key, mapActuels.values.toList());
    }
  }

  @override
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    final bien = BienMappers.bienFromJson(serverRow);
    final actuels = await _local.chargerBiens(bien.entrepriseId);
    final map = {for (final b in actuels) b.id: b};
    map[bien.id] = bien;
    await _local.sauvegarderBiens(bien.entrepriseId, map.values.toList());
  }

  @override
  Future<void> onConflict(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    await onPushApplied(op, serverRow);
  }

  @override
  Future<void> onRejected(SyncOperation op, Failure failure) async {
    await _cursors.reset(table);
  }
}

/// Synchronisation de la table `immobilier_locataires_profils`.
class ImmobilierLocatairesProfilsSyncHandler implements SyncEntityHandler {
  ImmobilierLocatairesProfilsSyncHandler(this._local, this._cursors);

  final ImmobilierLocalDataSource _local;
  final SyncCursorStore _cursors;

  @override
  String get table => 'immobilier_locataires_profils';

  @override
  Future<void> applyRemoteRows(List<Map<String, dynamic>> rows) async {
    final parEntreprise = <String, List<ProfilLocataire>>{};

    for (final json in rows) {
      final profil = ProfilLocataire.fromJson(json);
      parEntreprise.putIfAbsent(profil.entrepriseId, () => []).add(profil);
    }

    for (final entry in parEntreprise.entries) {
      final actuels = await _local.chargerProfilsLocataires(entry.key);
      final mapActuels = {for (final p in actuels) p.contactId: p};
      for (final distant in entry.value) {
        mapActuels[distant.contactId] = distant;
      }
      await _local.sauvegarderProfilsLocataires(entry.key, mapActuels.values.toList());
    }
  }

  @override
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    final profil = ProfilLocataire.fromJson(serverRow);
    await _local.sauvegarderProfilLocataire(profil);
  }

  @override
  Future<void> onConflict(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    await onPushApplied(op, serverRow);
  }

  @override
  Future<void> onRejected(SyncOperation op, Failure failure) async {
    await _cursors.reset(table);
  }
}

/// Synchronisation de la table `immobilier_locations`.
class ImmobilierLocationsSyncHandler implements SyncEntityHandler {
  ImmobilierLocationsSyncHandler(this._local, this._cursors);

  final ImmobilierLocalDataSource _local;
  final SyncCursorStore _cursors;

  @override
  String get table => 'immobilier_locations';

  @override
  Future<void> applyRemoteRows(List<Map<String, dynamic>> rows) async {
    final parEntreprise = <String, List<LocationImmobilier>>{};

    for (final json in rows) {
      if (json['deleted_at'] != null) continue;
      final loc = LocationImmobilier.fromJson(json);
      parEntreprise.putIfAbsent(loc.entrepriseId, () => []).add(loc);
    }

    for (final entry in parEntreprise.entries) {
      final actuels = await _local.chargerLocations(entry.key);
      final mapActuels = {for (final l in actuels) l.id: l};
      for (final distant in entry.value) {
        mapActuels[distant.id] = distant;
      }
      await _local.sauvegarderLocations(entry.key, mapActuels.values.toList());
    }
  }

  @override
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    final loc = LocationImmobilier.fromJson(serverRow);
    await _local.sauvegarderLocation(loc);
  }

  @override
  Future<void> onConflict(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    await onPushApplied(op, serverRow);
  }

  @override
  Future<void> onRejected(SyncOperation op, Failure failure) async {
    await _cursors.reset(table);
  }
}

/// Synchronisation de la table `immobilier_contrats`.
class ImmobilierContratsSyncHandler implements SyncEntityHandler {
  ImmobilierContratsSyncHandler(this._local, this._cursors);

  final ImmobilierLocalDataSource _local;
  final SyncCursorStore _cursors;

  @override
  String get table => 'immobilier_contrats';

  @override
  Future<void> applyRemoteRows(List<Map<String, dynamic>> rows) async {
    final parEntreprise = <String, List<ContratBail>>{};

    for (final json in rows) {
      if (json['deleted_at'] != null) continue;
      final contrat = ContratBail.fromJson(json);
      parEntreprise.putIfAbsent(contrat.entrepriseId, () => []).add(contrat);
    }

    for (final entry in parEntreprise.entries) {
      final actuels = await _local.chargerContrats(entry.key);
      final mapActuels = {for (final c in actuels) c.id: c};
      for (final distant in entry.value) {
        mapActuels[distant.id] = distant;
      }
      await _local.sauvegarderContrats(entry.key, mapActuels.values.toList());
    }
  }

  @override
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    final contrat = ContratBail.fromJson(serverRow);
    await _local.sauvegarderContrat(contrat);
  }

  @override
  Future<void> onConflict(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    await onPushApplied(op, serverRow);
  }

  @override
  Future<void> onRejected(SyncOperation op, Failure failure) async {
    await _cursors.reset(table);
  }
}

/// Synchronisation de la table `immobilier_echeances_loyers`.
class ImmobilierEcheancesSyncHandler implements SyncEntityHandler {
  ImmobilierEcheancesSyncHandler(this._local, this._cursors);

  final ImmobilierLocalDataSource _local;
  final SyncCursorStore _cursors;

  @override
  String get table => 'immobilier_echeances_loyers';

  @override
  Future<void> applyRemoteRows(List<Map<String, dynamic>> rows) async {
    final parEntreprise = <String, List<EcheanceLoyer>>{};

    for (final json in rows) {
      if (json['deleted_at'] != null) continue;
      final echeance = EcheanceLoyer.fromJson(json);
      parEntreprise.putIfAbsent(echeance.entrepriseId, () => []).add(echeance);
    }

    for (final entry in parEntreprise.entries) {
      final actuels = await _local.chargerEcheancesLoyers(entry.key);
      final mapActuels = {for (final e in actuels) e.id: e};
      for (final distant in entry.value) {
        mapActuels[distant.id] = distant;
      }
      await _local.sauvegarderEcheancesLoyers(entry.key, mapActuels.values.toList());
    }
  }

  @override
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    final echeance = EcheanceLoyer.fromJson(serverRow);
    await _local.sauvegarderEcheanceLoyer(echeance);
  }

  @override
  Future<void> onConflict(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    await onPushApplied(op, serverRow);
  }

  @override
  Future<void> onRejected(SyncOperation op, Failure failure) async {
    await _cursors.reset(table);
  }
}
