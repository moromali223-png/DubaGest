import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../providers/super_admin_providers.dart';
import '../widgets/super_admin_scaffold.dart';

class SuperAdminDashboardPage extends ConsumerWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(superAdminDashboardProvider);
    final fmt = NumberFormat.decimalPattern('fr');

    return SuperAdminScaffold(
      currentIndex: 0,
      title: 'Tableau de bord central',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Actualiser les métriques',
          onPressed: () => ref.invalidate(superAdminDashboardProvider),
        ),
      ],
      child: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.negative),
                const SizedBox(height: 12),
                Text('Erreur de chargement des métriques : $e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(superAdminDashboardProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ResponsiveBody(
            maxWidth: 1100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bannière de bienvenue Super Admin
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, size: 36, color: Colors.amberAccent),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Administration Globale DubaGest',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Supervision sécurisée des entreprises, abonnements, partenaires et incidents.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Grille des Métriques Clés (KPIs)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 800 ? 4 : (constraints.maxWidth >= 500 ? 2 : 1);
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: crossAxisCount == 4 ? 1.4 : 1.6,
                      children: [
                        _KpiCard(
                          titre: 'Entreprises enregistrées',
                          valeur: fmt.format(data.totalEntreprises),
                          sousTitre: '${data.entreprisesActives} actives • ${data.entreprisesSuspendues} suspendues',
                          icone: Icons.business_rounded,
                          couleur: const Color(0xFF2563EB),
                          onTap: () => context.go(Routes.superAdminEntreprises),
                        ),
                        _KpiCard(
                          titre: 'Utilisateurs globaux',
                          valeur: fmt.format(data.totalUtilisateurs),
                          sousTitre: 'Comptes authentifiés',
                          icone: Icons.people_alt_rounded,
                          couleur: const Color(0xFF0D9488),
                        ),
                        _KpiCard(
                          titre: 'Abonnements actifs',
                          valeur: fmt.format(data.abonnementsActifs),
                          sousTitre: '${data.abonnementsExpires} expirés',
                          icone: Icons.receipt_long_rounded,
                          couleur: AppColors.green,
                        ),
                        _KpiCard(
                          titre: 'Accès Sponsorisés',
                          valeur: fmt.format(data.abonnementsSponsorises),
                          sousTitre: 'Partenaires à 0 FCFA',
                          icone: Icons.stars_rounded,
                          couleur: const Color(0xFF7C3AED),
                          onTap: () => context.go(Routes.superAdminSponsorises),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Raccourcis Rapides
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => context.go(Routes.superAdminEntreprises),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Rechercher une entreprise'),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => context.go(Routes.superAdminSponsorises),
                        icon: const Icon(Icons.add_moderator_rounded),
                        label: const Text('Gérer les partenaires'),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Dernières actions administratives (Audit)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.history_rounded, size: 20, color: AppColors.ink),
                                SizedBox(width: 8),
                                Text(
                                  'Dernières opérations d\'administration',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => context.go(Routes.superAdminAudit),
                              child: const Text('Tout voir'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (data.activitesRecentes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'Aucune action administrative récente enregistrée.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                          )
                        else
                          for (final log in data.activitesRecentes) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: _couleurAction(log.action).withValues(alpha: 0.12),
                                foregroundColor: _couleurAction(log.action),
                                child: Icon(_iconeAction(log.action), size: 18),
                              ),
                              title: Text(
                                _libelleAction(log.action),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              subtitle: Text(
                                '${log.adminNom ?? log.adminEmail ?? 'Système'} • Cible: ${log.cibleType} (${log.cibleId.length > 8 ? log.cibleId.substring(0, 8) : log.cibleId})',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                              trailing: Text(
                                DateFormat('dd/MM HH:mm').format(log.createdAt.toLocal()),
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ),
                            if (log != data.activitesRecentes.last) const Divider(height: 1),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _couleurAction(String action) => switch (action) {
        'SUSPENSION_ENTREPRISE' || 'REVOCATION_ACCES_SPONSORISE' => AppColors.negative,
        'REACTIVATION_ENTREPRISE' => AppColors.green,
        'ATTRIBUTION_ACCES_SPONSORISE' => const Color(0xFF7C3AED),
        'BOOTSTRAP_INITIAL' || 'PROMOTION_SUPER_ADMIN' => const Color(0xFFEA580C),
        _ => const Color(0xFF2563EB),
      };

  IconData _iconeAction(String action) => switch (action) {
        'SUSPENSION_ENTREPRISE' => Icons.block_rounded,
        'REVOCATION_ACCES_SPONSORISE' => Icons.cancel_outlined,
        'REACTIVATION_ENTREPRISE' => Icons.check_circle_outline,
        'ATTRIBUTION_ACCES_SPONSORISE' => Icons.stars_rounded,
        'BOOTSTRAP_INITIAL' || 'PROMOTION_SUPER_ADMIN' => Icons.shield_rounded,
        _ => Icons.info_outline,
      };

  String _libelleAction(String action) => switch (action) {
        'SUSPENSION_ENTREPRISE' => 'Suspension d\'entreprise',
        'REACTIVATION_ENTREPRISE' => 'Réactivation d\'entreprise',
        'ATTRIBUTION_ACCES_SPONSORISE' => 'Attribution accès sponsorisé',
        'REVOCATION_ACCES_SPONSORISE' => 'Révocation accès sponsorisé',
        'BOOTSTRAP_INITIAL' => 'Bootstrap initial Super Admin',
        'PROMOTION_SUPER_ADMIN' => 'Promotion Super Admin',
        _ => action,
      };
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.titre,
    required this.valeur,
    required this.sousTitre,
    required this.icone,
    required this.couleur,
    this.onTap,
  });

  final String titre;
  final String valeur;
  final String sousTitre;
  final IconData icone;
  final Color couleur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      titre,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icone, size: 18, color: couleur),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    valeur,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: couleur),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sousTitre,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
