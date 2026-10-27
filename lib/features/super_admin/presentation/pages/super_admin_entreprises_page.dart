import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../providers/super_admin_providers.dart';
import '../widgets/donner_acces_sponsorise_dialog.dart';
import '../widgets/super_admin_scaffold.dart';

class SuperAdminEntreprisesPage extends ConsumerStatefulWidget {
  const SuperAdminEntreprisesPage({super.key});

  @override
  ConsumerState<SuperAdminEntreprisesPage> createState() => _SuperAdminEntreprisesPageState();
}

class _SuperAdminEntreprisesPageState extends ConsumerState<SuperAdminEntreprisesPage> {
  final _searchCtrl = TextEditingController();
  String? _statutFiltre;
  String? _planFiltre;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _appliquerFiltres() {
    ref.read(superAdminEntreprisesFiltreProvider.notifier).state = EntreprisesFiltreParams(
      recherche: _searchCtrl.text.trim(),
      statut: _statutFiltre,
      plan: _planFiltre,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entreprisesAsync = ref.watch(superAdminEntreprisesProvider);
    final fmtDate = DateFormat('dd/MM/yyyy');

    return SuperAdminScaffold(
      currentIndex: 1,
      title: 'Gestion des entreprises',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Actualiser',
          onPressed: () => ref.invalidate(superAdminEntreprisesProvider),
        ),
      ],
      child: ResponsiveBody(
        maxWidth: 1100,
        child: Column(
          children: [
            // Barre de recherche et filtres
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Rechercher par nom d\'entreprise...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                _appliquerFiltres();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    onSubmitted: (_) => _appliquerFiltres(),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Toutes'),
                          selected: _statutFiltre == null && _planFiltre == null,
                          onSelected: (_) {
                            setState(() {
                              _statutFiltre = null;
                              _planFiltre = null;
                            });
                            _appliquerFiltres();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Actives'),
                          selected: _statutFiltre == 'ACTIVE',
                          onSelected: (sel) {
                            setState(() => _statutFiltre = sel ? 'ACTIVE' : null);
                            _appliquerFiltres();
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Suspendues'),
                          selected: _statutFiltre == 'SUSPENDUE',
                          onSelected: (sel) {
                            setState(() => _statutFiltre = sel ? 'SUSPENDUE' : null);
                            _appliquerFiltres();
                          },
                        ),
                        const SizedBox(width: 12),
                        Container(width: 1, height: 20, color: const Color(0xFFCBD5E1)),
                        const SizedBox(width: 12),
                        for (final p in ['NORMAL', 'MOYEN', 'PRO']) ...[
                          FilterChip(
                            label: Text('Plan $p'),
                            selected: _planFiltre == p,
                            onSelected: (sel) {
                              setState(() => _planFiltre = sel ? p : null);
                              _appliquerFiltres();
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Liste des entreprises
            Expanded(
              child: entreprisesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.negative),
                      const SizedBox(height: 12),
                      Text('Erreur : $e'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.invalidate(superAdminEntreprisesProvider),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
                data: (entreprises) {
                  if (entreprises.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucune entreprise trouvée pour ces critères.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entreprises.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final e = entreprises[i];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: e.estActive ? const Color(0xFFE2E8F0) : AppColors.negative.withValues(alpha: 0.4),
                          ),
                        ),
                        child: InkWell(
                          onTap: () => context.go(Routes.superAdminEntreprise(e.id)),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: e.estActive
                                          ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                          : AppColors.negative.withValues(alpha: 0.1),
                                      foregroundColor: e.estActive ? const Color(0xFF2563EB) : AppColors.negative,
                                      child: Text(
                                        e.nom.isNotEmpty ? e.nom[0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.nom,
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Créée le ${fmtDate.format(e.createdAt.toLocal())}${e.createurEmail != null ? ' par ${e.createurEmail}' : ''}',
                                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Badge Statut Entreprise
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: e.estActive ? AppColors.greenSoft : AppColors.negativeSoft,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        e.statut,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: e.estActive ? AppColors.green : AppColors.negative,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    // Formule
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Text(
                                        'Plan ${e.planCode ?? 'AUCUN'}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                      ),
                                    ),
                                    // Badge Sponsorisé
                                    if (e.estSponsorise)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3E8FF),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFD8B4FE)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.stars_rounded, size: 13, color: Color(0xFF7C3AED)),
                                            SizedBox(width: 4),
                                            Text(
                                              'SPONSORISÉ (0 F)',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Quotas réels
                                    Text(
                                      '• ${e.nbUtilisateurs} utilisateur${e.nbUtilisateurs > 1 ? 's' : ''} • ${e.nbPerimetres} site${e.nbPerimetres > 1 ? 's' : ''}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => DonnerAccesSponsoriseDialog.show(
                                        context,
                                        entrepriseId: e.id,
                                        entrepriseNom: e.nom,
                                        planActuel: e.planCode,
                                      ),
                                      icon: const Icon(Icons.stars_rounded, size: 16),
                                      label: const Text('Accès sponsorisé', style: TextStyle(fontWeight: FontWeight.bold)),
                                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED)),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => context.go(Routes.superAdminEntreprise(e.id)),
                                      icon: const Icon(Icons.visibility_outlined, size: 16),
                                      label: const Text('Inspecter'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
