import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../providers/super_admin_providers.dart';
import '../widgets/super_admin_scaffold.dart';

class SuperAdminSponsorPage extends ConsumerStatefulWidget {
  const SuperAdminSponsorPage({super.key});

  @override
  ConsumerState<SuperAdminSponsorPage> createState() => _SuperAdminSponsorPageState();
}

class _SuperAdminSponsorPageState extends ConsumerState<SuperAdminSponsorPage> {
  final _searchCtrl = TextEditingController();
  String _filtreTexte = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _revoquerAcces(String entrepriseId, String nom) async {
    final motifCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cancel_rounded, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Révoquer l\'accès sponsorisé',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirmez-vous la révocation immédiate du sponsoring de "$nom" ?',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: motifCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motif obligatoire de révocation *',
                  hintText: 'Ex: Fin de convention de partenariat...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Veuillez renseigner un motif (5 caractères min).';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirmer la révocation'),
          ),
        ],
      ),
    );

    if (confirmer != true) return;

    try {
      final repo = ref.read(superAdminRepositoryProvider);
      await repo.revoquerAccesSponsorise(
        entrepriseId: entrepriseId,
        motif: motifCtrl.text.trim(),
      );
      ref.invalidate(superAdminEntreprisesProvider);
      ref.invalidate(superAdminDashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accès sponsorisé révoqué avec succès.'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red.shade900),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entreprisesAsync = ref.watch(superAdminEntreprisesProvider);

    return SuperAdminScaffold(
      currentIndex: 2,
      title: 'Partenaires & Accès Sponsorisés',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          tooltip: 'Actualiser',
          onPressed: () => ref.invalidate(superAdminEntreprisesProvider),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(superAdminEntreprisesProvider);
          ref.invalidate(superAdminDashboardProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Présentation des accès sponsorisés
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gestion des Partenariats & Accès Gratuits',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Accordez un abonnement standard à 0 FCFA pour des partenaires stratégiques ou des tests, tout en préservant le barème officiel.',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Colors.white12),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.shield_rounded, size: 16, color: Color(0xFF818CF8)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Traçabilité stricte : toute attribution ou révocation exige un motif obligatoire consigné dans le journal d\'audit.',
                            style: TextStyle(fontSize: 12, color: Color(0xFFC7D2FE), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Barre de recherche
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Rechercher un partenaire sponsorisé par nom...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                  suffixIcon: _filtreTexte.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _filtreTexte = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onChanged: (val) => setState(() => _filtreTexte = val.trim().toLowerCase()),
              ),

              const SizedBox(height: 20),

              // Liste des partenaires sponsorisés
              entreprisesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Text('Erreur : $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (entreprises) {
                  // Filtrer pour ne garder que les entreprises actuellement sponsorisées
                  final sponsorisees = entreprises.where((e) {
                    final matchSponsor = e.typeFacturation == 'SPONSORISE';
                    if (!matchSponsor) return false;
                    if (_filtreTexte.isEmpty) return true;
                    return e.nom.toLowerCase().contains(_filtreTexte) ||
                        (e.sponsorMotif?.toLowerCase().contains(_filtreTexte) ?? false);
                  }).toList();

                  // Calcul de la valeur commerciale globale offerte
                  final valeurTotale = sponsorisees.fold<num>(
                    0,
                    (somme, e) => somme + e.valeurCommercialeReference,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cartes métriques
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Partenaires actifs', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${sponsorisees.length}',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Valeur mensuelle offerte', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$valeurTotale FCFA / mois',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      if (sponsorisees.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_outline_rounded, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  _filtreTexte.isNotEmpty
                                      ? 'Aucun partenaire ne correspond à "$_filtreTexte".'
                                      : 'Aucun compte sponsorisé actif.',
                                  style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => context.go(Routes.superAdminEntreprises),
                                  icon: const Icon(Icons.business_rounded),
                                  label: const Text('Accéder au répertoire des entreprises'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sponsorisees.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final e = sponsorisees[index];
                            final plan = e.planCode ?? 'MOYEN';

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.star_rounded, color: Color(0xFFB45309), size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.nom,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                            ),
                                            Text(
                                              'Créateur : ${e.createurNom ?? e.createurEmail ?? '-'} • ${e.pays ?? ''}',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'OFFRE $plan (0 FCFA)',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (e.sponsorMotif != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFEF3C7)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Motif du partenariat :',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            e.sponsorMotif!,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                                          ),
                                          if (e.valeurCommercialeReference > 0) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Valeur commerciale : ${e.valeurCommercialeReference} FCFA / mois',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => context.go(Routes.superAdminEntreprise(e.id)),
                                        icon: const Icon(Icons.visibility_rounded, size: 16),
                                        label: const Text('Fiche détaillée'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFB45309)),
                                        onPressed: () => _revoquerAcces(e.id, e.nom),
                                        icon: const Icon(Icons.cancel_rounded, size: 16),
                                        label: const Text('Révoquer'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
