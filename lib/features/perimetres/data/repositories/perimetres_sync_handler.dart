import '../../../../core/sync/standard_sync_handler.dart';
import '../../../../core/sync/sync_contracts.dart';
import '../datasources/perimetre_local_data_source.dart';

/// Synchronisation des périmètres : politique commune du socle.
class PerimetresSyncHandler extends StandardSyncHandler {
  PerimetresSyncHandler(PerimetreLocalDataSource local, SyncCursorStore cursors)
      : super(local, cursors, local.enTransaction);
}
