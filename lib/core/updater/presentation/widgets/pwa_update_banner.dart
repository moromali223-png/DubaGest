import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../providers/updater_providers.dart';

class PwaUpdateBanner extends ConsumerWidget {
  const PwaUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kIsWeb) return const SizedBox.shrink();

    final state = ref.watch(updaterNotifierProvider);
    final isAvailable = state.status == UpdaterStatus.updateAvailable || state.pwaUpdateReady;
    if (!isAvailable) return const SizedBox.shrink();

    final notifier = ref.read(updaterNotifierProvider.notifier);
    final isMandatory = state.versionInfo?.isMandatory ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF01226C),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Une nouvelle version de DubaGest est prête.',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => notifier.appliquerPwaUpdate(),
              child: const Text('Actualiser', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            if (!isMandatory) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                onPressed: () => notifier.state = notifier.state.copyWith(status: UpdaterStatus.idle),
                tooltip: 'Plus tard',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

