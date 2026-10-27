import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/super_admin_providers.dart';
import '../widgets/donner_acces_sponsorise_dialog.dart';
import '../widgets/super_admin_scaffold.dart';

class SuperAdminDetailEntreprisePage extends ConsumerStatefulWidget {
  const SuperAdminDetailEntreprisePage({
    super.key,
    required this.entrepriseId,
  });

  final String entrepriseId;

  @override
  ConsumerState<SuperAdminDetailEntreprisePage> createState() => _SuperAdminDetailEntreprisePageState();
}

class _SuperAdminDetailEntreprisePageState extends ConsumerState<SuperAdminDetailEntreprisePage> {
  bool _actionEnCours = false;

  Future<void> _suspendreEntreprise(String nom) async {
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
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.block_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Suspendre l\'entreprise',
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
                'Êtes-vous sûr de vouloir suspendre "$nom" ? Ses membres ne pourront plus accéder à leurs données jusqu\'à réactivation.',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: motifCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motif obligatoire de suspension *',
                  hintText: 'Ex: Non-respect des conditions, impayé, enquête...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Veuillez saisir un motif explicite (5 caractères min).';
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
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirmer la suspension'),
          ),
        ],
      ),
    );

    if (confirmer != true) return;

    setState(() => _actionEnCours = true);
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      await repo.suspendreEntreprise(widget.entrepriseId, motifCtrl.text.trim());
      ref.invalidate(superAdminDetailEntrepriseProvider(widget.entrepriseId));
      ref.invalidate(superAdminEntreprisesProvider);
      ref.invalidate(superAdminDashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entreprise suspendue avec succès.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red.shade900),
        );
      }
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  Future<void> _reactiverEntreprise(String nom) async {
    final motifCtrl = TextEditingController();

    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Réactiver l\'entreprise',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirmez-vous la réactivation de l\'entreprise "$nom" ? Ses membres retrouveront l\'accès complet.',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motifCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Motif (optionnel)',
                hintText: 'Ex: Régularisation de compte...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Réactiver'),
          ),
        ],
      ),
    );

    if (confirmer != true) return;

    setState(() => _actionEnCours = true);
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      await repo.reactiverEntreprise(widget.entrepriseId, motif: motifCtrl.text.trim().isEmpty ? null : motifCtrl.text.trim());
      ref.invalidate(superAdminDetailEntrepriseProvider(widget.entrepriseId));
      ref.invalidate(superAdminEntreprisesProvider);
      ref.invalidate(superAdminDashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entreprise réactivée avec succès.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red.shade900),
        );
      }
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  Future<void> _revoquerAccesSponsorise(String nom) async {
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
              child: const Icon(Icons.card_membership_rounded, color: Colors.amber, size: 24),
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
                'L\'abonnement sponsorisé de "$nom" sera résilié immédiatement. L\'entreprise devra souscrire à une offre standard payante pour continuer.',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: motifCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motif de révocation *',
                  hintText: 'Ex: Fin du partenariat, réévaluation...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Veuillez saisir un motif valide (5 caractères min).';
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
            child: const Text('Révoquer'),
          ),
        ],
      ),
    );

    if (confirmer != true) return;

    setState(() => _actionEnCours = true);
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      await repo.revoquerAccesSponsorise(
        entrepriseId: widget.entrepriseId,
        motif: motifCtrl.text.trim(),
      );
      ref.invalidate(superAdminDetailEntrepriseProvider(widget.entrepriseId));
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
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(superAdminDetailEntrepriseProvider(widget.entrepriseId));

    return SuperAdminScaffold(
      currentIndex: 1,
      title: 'Détail de l\'entreprise',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          tooltip: 'Actualiser',
          onPressed: () => ref.invalidate(superAdminDetailEntrepriseProvider(widget.entrepriseId)),
        ),
      ],
      child: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erreur lors du chargement des détails :\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(superAdminDetailEntrepriseProvider(widget.entrepriseId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final entreprise = data['entreprise'] as Map<String, dynamic>? ?? {};
          final abonnements = (data['abonnements'] as List<dynamic>?) ?? [];
          final membres = (data['membres'] as List<dynamic>?) ?? [];
          final perimetres = (data['perimetres'] as List<dynamic>?) ?? [];

          final nom = entreprise['nom'] as String? ?? 'Entreprise sans nom';
          final statut = entreprise['statut'] as String? ?? 'INCONNU';
          final estSuspendue = statut == 'SUSPENDUE';
          final devise = entreprise['devise'] as String? ?? 'XOF';
          final pays = entreprise['pays'] as String? ?? '-';
          final ville = entreprise['ville'] as String? ?? '-';
          final tel = entreprise['telephone'] as String? ?? '-';
          final createur = entreprise['createur'] as Map<String, dynamic>? ?? {};
          final createurEmail = createur['email'] as String? ?? '-';
          final createurNom = createur['nom_complet'] as String? ?? '-';

          // Vérifier si un abonnement actif est sponsorisé
          final aboActif = abonnements.cast<Map<String, dynamic>?>().firstWhere(
                (a) => a != null && (a['statut'] == 'ACTIF' || a['statut'] == 'ESSAI'),
                orElse: () => null,
              );
          final estSponsorise = aboActif?['type_facturation'] == 'SPONSORISE';
          final planActuel = aboActif?['plan_code'] as String?;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card de l'entreprise
                    _buildHeaderCard(
                      nom: nom,
                      statut: statut,
                      estSuspendue: estSuspendue,
                      pays: pays,
                      ville: ville,
                      tel: tel,
                      devise: devise,
                      createurEmail: createurEmail,
                      createurNom: createurNom,
                      createdAt: entreprise['created_at']?.toString() ?? '',
                      estSponsorise: estSponsorise,
                    ),

                    const SizedBox(height: 20),

                    // Actions Super Admin
                    _buildActionsBar(
                      nom: nom,
                      estSuspendue: estSuspendue,
                      estSponsorise: estSponsorise,
                      planActuel: planActuel,
                    ),

                    const SizedBox(height: 24),

                    // Grille : Abonnements / Membres / Périmètres
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 900;
                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    _buildAbonnementsCard(abonnements, devise),
                                    const SizedBox(height: 20),
                                    _buildPerimetresCard(perimetres),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 4,
                                child: _buildMembresCard(membres),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildAbonnementsCard(abonnements, devise),
                              const SizedBox(height: 20),
                              _buildMembresCard(membres),
                              const SizedBox(height: 20),
                              _buildPerimetresCard(perimetres),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (_actionEnCours)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard({
    required String nom,
    required String statut,
    required bool estSuspendue,
    required String pays,
    required String ville,
    required String tel,
    required String devise,
    required String createurEmail,
    required String createurNom,
    required String createdAt,
    required bool estSponsorise,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: estSuspendue ? Colors.red.shade200 : const Color(0xFFE2E8F0),
          width: estSuspendue ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: estSuspendue
                        ? [Colors.red.shade700, Colors.red.shade900]
                        : [const Color(0xFF0F172A), const Color(0xFF334155)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    nom.isNotEmpty ? nom.substring(0, 1).toUpperCase() : 'E',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nom,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                        ),
                        _buildStatutBadge(statut, estSuspendue),
                        if (estSponsorise) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 14, color: Color(0xFFB45309)),
                                SizedBox(width: 4),
                                Text(
                                  'SPONSORISÉ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Créé par : $createurNom ($createurEmail)',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _buildInfoItem(Icons.public_rounded, 'Pays / Ville', '$pays, $ville'),
              _buildInfoItem(Icons.phone_rounded, 'Téléphone', tel),
              _buildInfoItem(Icons.monetization_on_rounded, 'Devise légale', devise),
              _buildInfoItem(Icons.calendar_today_rounded, 'Date création', createdAt.split('T').first),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatutBadge(String statut, bool estSuspendue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: estSuspendue ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statut,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: estSuspendue ? const Color(0xFF991B1B) : const Color(0xFF166534),
        ),
      ),
    );
  }

  Widget _buildActionsBar({
    required String nom,
    required bool estSuspendue,
    required bool estSponsorise,
    required String? planActuel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'ACTIONS ADMINISTRATEUR :',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF475569)),
          ),

          // Suspendre / Réactiver
          if (estSuspendue)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _reactiverEntreprise(nom),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Réactiver l\'entreprise'),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _suspendreEntreprise(nom),
              icon: const Icon(Icons.block_rounded, size: 18),
              label: const Text('Suspendre l\'entreprise'),
            ),

          // Donner ou modifier l'accès sponsorisé
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final ok = await DonnerAccesSponsoriseDialog.show(
                context,
                entrepriseId: widget.entrepriseId,
                entrepriseNom: nom,
                planActuel: planActuel,
              );
              if (ok == true) {
                ref.invalidate(superAdminDetailEntrepriseProvider(widget.entrepriseId));
                ref.invalidate(superAdminEntreprisesProvider);
                ref.invalidate(superAdminDashboardProvider);
              }
            },
            icon: const Icon(Icons.star_rounded, size: 18),
            label: Text(estSponsorise ? 'Modifier l\'accès sponsorisé' : 'Accorder accès sponsorisé (0 FCFA)'),
          ),

          // Révoquer l'accès sponsorisé si actif
          if (estSponsorise)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB45309),
                side: const BorderSide(color: Color(0xFFF59E0B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _revoquerAccesSponsorise(nom),
              icon: const Icon(Icons.cancel_rounded, size: 18),
              label: const Text('Révoquer le sponsoring'),
            ),
        ],
      ),
    );
  }

  Widget _buildAbonnementsCard(List<dynamic> abonnements, String devise) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card_rounded, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Historique des abonnements & Licences',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Text(
                '${abonnements.length} enregistrement(s)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (abonnements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucun abonnement enregistré pour cette entreprise.',
                style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: abonnements.length,
              separatorBuilder: (_, _) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final abo = abonnements[index] as Map<String, dynamic>;
                final planCode = abo['plan_code'] as String? ?? 'NORMAL';
                final statut = abo['statut'] as String? ?? '-';
                final typeFacturation = abo['type_facturation'] as String? ?? 'STANDARD';
                final estSponsor = typeFacturation == 'SPONSORISE';
                final dateDebut = abo['date_debut']?.toString().split('T').first ?? '-';
                final dateFin = abo['date_fin']?.toString().split('T').first ?? 'Illimité';
                final motif = abo['sponsor_motif'] as String?;
                final valRef = abo['valeur_commerciale_reference'];

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: estSponsor ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: estSponsor ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              planCode,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statut == 'ACTIF' ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statut,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statut == 'ACTIF' ? const Color(0xFF166534) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (estSponsor)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'SPONSORISÉ (0 FCFA)',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Période : $dateDebut → $dateFin',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                      if (estSponsor && motif != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Motif du sponsoring : $motif',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                              ),
                              if (valRef != null)
                                Text(
                                  'Valeur commerciale de référence : $valRef $devise / mois',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMembresCard(List<dynamic> membres) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Utilisateurs & Équipe',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Text(
                '${membres.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (membres.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucun membre répertorié.',
                style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: membres.length,
              separatorBuilder: (_, _) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final m = membres[index] as Map<String, dynamic>;
                final nom = m['nom_complet'] as String? ?? 'Sans nom';
                final email = m['email'] as String? ?? '-';
                final role = m['role_code'] as String? ?? 'COLLABORATEUR';
                final statut = m['statut'] as String? ?? 'ACTIF';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: Text(
                      nom.isNotEmpty ? nom.substring(0, 1).toUpperCase() : 'U',
                      style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    nom,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    email,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          role,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statut,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statut == 'ACTIF' ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPerimetresCard(List<dynamic> perimetres) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store_rounded, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Périmètres & Sites d\'activité',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Text(
                '${perimetres.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (perimetres.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucun périmètre configuré.',
                style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: perimetres.map((p) {
                final perim = p as Map<String, dynamic>;
                final nom = perim['nom'] as String? ?? 'Périmètre';
                final code = perim['code'] as String? ?? '';
                final type = perim['type'] as String? ?? 'SITE';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.business_rounded, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('$code ($type)', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
