import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/di/sync_providers.dart';
import '../../core/sync/sync_models.dart';
import 'app_header_buttons.dart';

/// Indicateur de synchronisation (barre d'application). Un appui relance la sync.
class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key, this.boxed = false});

  /// Carré arrondi bordé (en-tête de l'accueil).
  final bool boxed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider).value ?? const SyncState();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    final (icon, label, color) = switch (state.phase) {
      SyncPhase.syncing => (Icons.sync, l10n.syncSyncing, null),
      SyncPhase.offline => (Icons.cloud_off_outlined, l10n.syncOffline, scheme.outline),
      SyncPhase.error => (Icons.sync_problem, l10n.syncError, scheme.error),
      SyncPhase.idle when state.pendingCount > 0 =>
        (Icons.cloud_upload_outlined, l10n.syncPending(state.pendingCount), null),
      SyncPhase.idle => (Icons.cloud_done_outlined, l10n.syncUpToDate, null),
    };

    return IconButton(
      style: boxed ? headerIconButtonStyle(context) : null,
      tooltip: label,
      onPressed: () => ref.read(syncEngineProvider).requestSync(),
      icon: Badge(
        isLabelVisible: state.pendingCount > 0,
        label: Text('${state.pendingCount}'),
        child: Icon(icon, color: color, semanticLabel: label),
      ),
    );
  }
}

/// Bandeau affiché tant que l'appareil est hors-ligne.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(syncStateProvider.select((s) => s.value?.phase == SyncPhase.offline));
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: !offline
          ? const SizedBox(width: double.infinity)
          : Material(
              color: scheme.secondaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 18, color: scheme.onSecondaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.syncOfflineBanner,
                          style: TextStyle(color: scheme.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Pastille de statut d'un enregistrement local.
class RecordSyncBadge extends StatelessWidget {
  const RecordSyncBadge({super.key, required this.status});
  final RecordSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (status) {
      RecordSyncStatus.synced => (null, null, null),
      RecordSyncStatus.pendingSync => (Icons.schedule, l10n.syncRecordPending, scheme.outline),
      RecordSyncStatus.syncError => (Icons.error_outline, l10n.syncRecordError, scheme.error),
      RecordSyncStatus.conflict => (Icons.merge_type, l10n.syncRecordConflict, scheme.tertiary),
    };
    if (icon == null) return const SizedBox.shrink();
    return Tooltip(message: label, child: Icon(icon, size: 18, color: color, semanticLabel: label));
  }
}
