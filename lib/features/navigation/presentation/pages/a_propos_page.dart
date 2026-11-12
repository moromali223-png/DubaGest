import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/updater/presentation/providers/updater_providers.dart';
import '../../../../core/updater/presentation/widgets/dialog_mise_a_jour.dart';

class AProposPage extends ConsumerStatefulWidget {
  const AProposPage({super.key});

  @override
  ConsumerState<AProposPage> createState() => _AProposPageState();
}

class _AProposPageState extends ConsumerState<AProposPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updaterNotifierProvider.notifier).verifierMiseAJour();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updaterNotifierProvider);
    final notifier = ref.read(updaterNotifierProvider.notifier);
    final info = state.versionInfo;

    final isChecking = state.status == UpdaterStatus.checking;
    final isUpdateAvailable = state.status == UpdaterStatus.updateAvailable || (info?.isUpdateAvailable ?? false);
    final isUpToDate = state.status == UpdaterStatus.upToDate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('À propos de DubaGest', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A2522),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo DubaGest
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.green.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.storefront_rounded, color: Colors.white, size: 42),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'DubaGest',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A2522),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gestion Commerce, Services & Immobilier — Offline First',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                const SizedBox(height: 24),

                // Carte Version & Mises à jour
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Version installée',
                            style: TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              info != null
                                  ? 'v${info.installedVersionName} (Build ${info.installedVersionCode})'
                                  : 'v1.0.0 (Build 1)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 14),

                      // Statut du système de mise à jour
                      Row(
                        children: [
                          Icon(
                            isChecking
                                ? Icons.sync_rounded
                                : isUpdateAvailable
                                    ? Icons.system_update_rounded
                                    : Icons.verified_rounded,
                            size: 20,
                            color: isChecking
                                ? AppColors.muted
                                : isUpdateAvailable
                                    ? const Color(0xFFD97706)
                                    : AppColors.green,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isChecking
                                  ? 'Vérification en ligne...'
                                  : isUpdateAvailable
                                      ? 'Nouvelle version ${info?.latestVersionName ?? ''} disponible !'
                                      : 'Votre application est à jour.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isChecking
                                    ? AppColors.muted
                                    : isUpdateAvailable
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (isUpdateAvailable) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              if (kIsWeb) {
                                notifier.appliquerPwaUpdate();
                              } else {
                                DialogMiseAJour.show(context);
                              }
                            },
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Installer la mise à jour', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Bouton de vérification manuelle
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A2522),
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isChecking
                        ? null
                        : () => notifier.verifierMiseAJour(manuel: true),
                    icon: isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      isChecking ? 'Vérification...' : 'Vérifier les mises à jour',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Fiche technique / Sécurité
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    children: [
                      _LigneInfo(
                        titre: 'Infrastructure',
                        valeur: 'Cloudflare CDN + Supabase',
                      ),
                      Divider(height: 18, color: AppColors.border),
                      _LigneInfo(
                        titre: 'Base locale',
                        valeur: 'Drift SQLite (Offline-First)',
                      ),
                      Divider(height: 18, color: AppColors.border),
                      _LigneInfo(
                        titre: 'Plateforme',
                        valeur: kIsWeb ? 'PWA Web (WebKit / Chrome)' : 'Android Natif (APK)',
                      ),
                      Divider(height: 18, color: AppColors.border),
                      _LigneInfo(
                        titre: 'Contact officiel',
                        valeur: 'sphereduba@gmail.com',
                      ),
                    ],
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

class _LigneInfo extends StatelessWidget {
  const _LigneInfo({required this.titre, required this.valeur});
  final String titre;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(titre, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
        Text(valeur, style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w700)),
      ],
    );
  }
}

