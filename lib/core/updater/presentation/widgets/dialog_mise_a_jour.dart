import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../providers/updater_providers.dart';

class DialogMiseAJour extends ConsumerWidget {
  const DialogMiseAJour({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DialogMiseAJour(),
    );
  }

  String _formatMo(int bytes) {
    if (bytes <= 0) return '0 Mo';
    final mo = bytes / (1024 * 1024);
    return '${mo.toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updaterNotifierProvider);
    final notifier = ref.read(updaterNotifierProvider.notifier);
    final info = state.versionInfo;

    final isMandatory = info?.isMandatory ?? false;
    final isDownloading = state.status == UpdaterStatus.downloading;
    final isReady = state.status == UpdaterStatus.readyToInstall;
    final hasError = state.status == UpdaterStatus.error;

    return PopScope(
      canPop: !isMandatory && !isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête : Logo + Titre + Badge version
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.system_update_rounded,
                          color: AppColors.green,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isMandatory ? 'Mise à jour requise' : 'Mise à jour disponible',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: isMandatory ? const Color(0xFFDC2626) : const Color(0xFF1A2522),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            info != null
                                ? 'Version ${info.latestVersionName} (actuelle : ${info.installedVersionName})'
                                : 'Nouvelle version de DubaGest',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),

                // Notes de version (Nouveautés)
                if (info != null && info.releaseNotes.isNotEmpty) ...[
                  const Text(
                    'Nouveautés & Corrections :',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2522),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final note in info.releaseNotes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4, right: 8),
                                    child: Icon(Icons.check_circle_rounded, color: AppColors.green, size: 14),
                                  ),
                                  Expanded(
                                    child: Text(
                                      note,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF4B5563),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Taille du fichier
                if (info != null && info.fileSize > 0 && !isDownloading) ...[
                  Row(
                    children: [
                      const Icon(Icons.folder_zip_outlined, size: 16, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Text(
                        'Taille du téléchargement : ${_formatMo(info.fileSize)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Progression du téléchargement réel
                if (isDownloading) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Téléchargement officiel...',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A2522)),
                            ),
                            Text(
                              '${(state.downloadProgress * 100).toInt()}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: state.downloadProgress > 0 ? state.downloadProgress : null,
                            minHeight: 7,
                            backgroundColor: const Color(0xFFE5E7EB),
                            color: AppColors.green,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatMo(state.receivedBytes)} / ${_formatMo(state.totalBytes)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Message d'erreur éventuel
                if (hasError && state.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Boutons d'action
                Row(
                  children: [
                    if (!isMandatory && !isDownloading) ...[
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.muted,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Plus tard', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: isMandatory ? 1 : 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isDownloading
                            ? null
                            : () {
                                if (isReady) {
                                  notifier.relancerInstallation();
                                } else {
                                  notifier.telechargerEtInstaller();
                                }
                              },
                        child: Text(
                          isReady
                              ? 'Installer maintenant'
                              : isDownloading
                                  ? 'Téléchargement...'
                                  : 'Mettre à jour maintenant',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

