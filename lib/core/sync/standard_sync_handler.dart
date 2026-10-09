import '../errors/failure.dart';
import 'sync_contracts.dart';
import 'sync_models.dart';

/// État local d'une ligne synchronisée.
class LigneLocale {
  const LigneLocale({required this.statut, required this.version, required this.ligne});
  final RecordSyncStatus statut;
  final int? version;

  /// Ligne locale brute (type propre à l'entité), comparée par [StockageSynchronise.memeContenu].
  final Object ligne;
}

/// Ce qu'une entité doit fournir pour être synchronisée par [StandardSyncHandler].
abstract interface class StockageSynchronise {
  String get table;
  Future<LigneLocale?> lire(String id);

  /// Écrit la ligne serveur (une ligne supprimée côté serveur est retirée).
  Future<void> ecrireDepuisServeur(Map<String, dynamic> ligne, RecordSyncStatus statut);
  Future<void> supprimer(String id);
  Future<void> marquer(String id, RecordSyncStatus statut);
  Future<void> mettreAJourVersion(String id, int version);

  /// Les champs modifiables locaux sont-ils identiques à ceux du serveur ?
  bool memeContenu(LigneLocale locale, Map<String, dynamic> serveur);
}

/// Politique de synchronisation commune à toutes les entités du socle :
/// - descente : une ligne modifiée localement et non envoyée est conservée ;
///   une ligne déjà à jour n'est pas réécrite (le conflit reste signalé) ;
///   une ligne en erreur est remplacée par l'état réel du serveur ;
/// - montée appliquée : version serveur reprise, ligne « synchronisée » si
///   l'utilisateur ne l'a pas retouchée entre-temps ;
/// - conflit : la version serveur gagne et la ligne est marquée ;
/// - refus définitif : la ligne est marquée et la table sera relue.
class StandardSyncHandler implements SyncEntityHandler {
  StandardSyncHandler(this._stockage, this._curseurs, this._transaction);

  final StockageSynchronise _stockage;
  final SyncCursorStore _curseurs;
  final LocalTransaction _transaction;

  @override
  String get table => _stockage.table;

  @override
  Future<void> applyRemoteRows(List<Map<String, dynamic>> rows) => _transaction(() async {
        for (final json in rows) {
          final locale = await _stockage.lire(json['id'] as String);
          if (locale != null) {
            if (locale.statut == RecordSyncStatus.pendingSync) continue;
            final versionServeur = json['version'] as int? ?? 0;
            final aJour = (locale.version ?? -1) >= versionServeur && json['deleted_at'] == null;
            if (aJour && locale.statut != RecordSyncStatus.syncError) continue;
          }
          await _stockage.ecrireDepuisServeur(json, RecordSyncStatus.synced);
        }
      });

  @override
  Future<void> onPushApplied(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) return;
    await _transaction(() async {
      final id = serverRow['id'] as String;
      final locale = await _stockage.lire(id);
      if (locale == null) return;
      if (serverRow['deleted_at'] != null) {
        await _stockage.supprimer(id);
      } else if (_stockage.memeContenu(locale, serverRow)) {
        await _stockage.ecrireDepuisServeur(serverRow, RecordSyncStatus.synced);
      } else {
        await _stockage.mettreAJourVersion(id, serverRow['version'] as int);
      }
    });
  }

  @override
  Future<void> onConflict(SyncOperation op, Map<String, dynamic>? serverRow) async {
    if (serverRow == null) {
      await _stockage.supprimer(op.recordId);
    } else {
      await _stockage.ecrireDepuisServeur(serverRow, RecordSyncStatus.conflict);
    }
  }

  @override
  Future<void> onRejected(SyncOperation op, Failure failure) async {
    await _stockage.marquer(op.recordId, RecordSyncStatus.syncError);
    await _curseurs.reset(table);
  }
}
