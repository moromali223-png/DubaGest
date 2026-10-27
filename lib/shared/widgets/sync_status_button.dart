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

  void _action(BuildContext context, WidgetRef ref, SyncState state) {
    ref.read(syncEngineProvider).requestSync(force: true);

    if (state.phase == SyncPhase.error || state.pendingCount > 0) {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => Consumer(
          builder: (ctx, ref, _) {
            final currentState = ref.watch(syncStateProvider).value ?? state;
            final isSyncing = currentState.phase == SyncPhase.syncing;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: currentState.phase == SyncPhase.error
                                ? Colors.red.withValues(alpha: 0.12)
                                : const Color(0xFF1E7E4E).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            currentState.phase == SyncPhase.error
                                ? Icons.sync_problem_rounded
                                : Icons.sync_rounded,
                            color: currentState.phase == SyncPhase.error
                                ? Colors.red
                                : const Color(0xFF1E7E4E),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Synchronisation',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                              ),
                              Text(
                                isSyncing
                                    ? 'Synchronisation en cours...'
                                    : (currentState.pendingCount > 0
                                        ? '${currentState.pendingCount} élément(s) en attente d\'envoi'
                                        : 'Toutes les données sont synchronisées'),
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (currentState.lastError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                currentState.lastError!,
                                style: const TextStyle(fontSize: 12.5, color: Colors.red, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: isSyncing
                          ? null
                          : () {
                              ref.read(syncEngineProvider).requestSync(force: true);
                            },
                      icon: isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(isSyncing ? 'Synchronisation...' : 'Synchroniser maintenant'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synchronisation avec le serveur lancée...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

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
      onPressed: () => _action(context, ref, state),
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
