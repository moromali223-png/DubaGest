import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../../domain/entities/prestation.dart';
import '../services_providers.dart';

/// Section affichée dans la fiche contact détaillant l'historique de ses prestations
/// de services, ses devis associés, ses encours et des actions rapides.
class HistoriqueServicesContact extends ConsumerWidget {
  const HistoriqueServicesContact({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final droits = ref.watch(droitsServicesProvider);
    if (!droits.peutVoirPrestations) return const SizedBox.shrink();

    final prestations = ref.watch(prestationsContactProvider(contactId));
    final devis = ref.watch(devisContactProvider(contactId));

    final totalFacture = prestations.fold<int>(0, (sum, p) => sum + p.total);
    final totalRestantDu = prestations.fold<int>(0, (sum, p) => sum + p.soldeRestant);
    final enCoursCount = prestations.where((p) => p.statut == StatutPrestation.enCours || p.statut == StatutPrestation.aFaire).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de section avec actions
            Row(
              children: [
                const Icon(Icons.handyman_outlined, color: Color(0xFF01226C), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Prestations & Services',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                  ),
                ),
                if (droits.peutCreerPrestations)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () => context.push('${Routes.prestationNouvelle}?contactId=$contactId'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Prestation', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // KPIs client
            if (prestations.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _KpiItem(
                      label: 'Prestations',
                      valeur: '${prestations.length}',
                      sousTitre: enCoursCount > 0 ? '$enCoursCount en cours' : 'Toutes terminées',
                    ),
                    Container(height: 30, width: 1, color: AppColors.border),
                    _KpiItem(
                      label: 'Total facturé',
                      valeur: montant(context, ref, totalFacture),
                    ),
                    if (totalRestantDu > 0) ...[
                      Container(height: 30, width: 1, color: AppColors.border),
                      _KpiItem(
                        label: 'Solde dû',
                        valeur: montant(context, ref, totalRestantDu),
                        color: const Color(0xFFDF9540),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Liste des prestations récentes
            if (prestations.isEmpty && devis.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aucune prestation enregistrée pour ce client.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              )
            else ...[
              if (prestations.isNotEmpty) ...[
                const Text('Interventions récentes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 6),
                for (final p in prestations.take(5))
                  _PrestationClientTile(prestation: p),
              ],
              if (devis.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Devis associés', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 6),
                for (final d in devis.take(3))
                  _DevisClientTile(devis: d),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiItem extends StatelessWidget {
  const _KpiItem({required this.label, required this.valeur, this.sousTitre, this.color});
  final String label;
  final String valeur;
  final String? sousTitre;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            valeur,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color ?? const Color(0xFF01226C)),
            textAlign: TextAlign.center,
          ),
          if (sousTitre != null) ...[
            const SizedBox(height: 1),
            Text(sousTitre!, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _PrestationClientTile extends ConsumerWidget {
  const _PrestationClientTile({required this.prestation});
  final Prestation prestation;

  Color _statutColor(StatutPrestation statut) {
    switch (statut) {
      case StatutPrestation.aFaire:
        return const Color(0xFF6B7280);
      case StatutPrestation.planifiee:
        return const Color(0xFF3B82F6);
      case StatutPrestation.enCours:
        return const Color(0xFFDF9540);
      case StatutPrestation.terminee:
        return const Color(0xFF10B981);
      case StatutPrestation.livree:
        return const Color(0xFF059669);
      case StatutPrestation.annulee:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = prestation;
    final color = _statutColor(p.statut);

    return InkWell(
      onTap: () => context.push(Routes.prestation(p.id)),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.ink)),
                  Text(
                    '${p.statut.libelle}${p.echeanceJour != null ? ' · Échéance ${p.echeanceJour!.day}/${p.echeanceJour!.month}' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  montant(context, ref, p.total),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF01226C)),
                ),
                if (p.soldeRestant > 0)
                  Text(
                    'Reste: ${montant(context, ref, p.soldeRestant)}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFDF9540)),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _DevisClientTile extends ConsumerWidget {
  const _DevisClientTile({required this.devis});
  final DevisPrestation devis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = devis;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.titre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink)),
                Text('${d.numero} · ${d.statut.libelle}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          Text(
            montant(context, ref, d.total),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
