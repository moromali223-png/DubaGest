import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../../domain/entities/prestation.dart';
import '../services_providers.dart';

/// Écran des devis de services : Chiffrage, relances, acceptation et conversion 1-clic.
class ServicesDevisPage extends ConsumerStatefulWidget {
  const ServicesDevisPage({super.key});

  @override
  ConsumerState<ServicesDevisPage> createState() => _ServicesDevisPageState();
}

class _ServicesDevisPageState extends ConsumerState<ServicesDevisPage> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final droits = ref.watch(droitsServicesProvider);
    final devisAsync = ref.watch(devisServicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devis de prestations'),
        actions: const [
          SyncStatusButton(),
        ],
      ),
      floatingActionButton: droits.peutCreerDevis
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/services/devis/new'),
              icon: const Icon(Icons.add),
              label: const Text('Devis'),
            )
          : null,
      body: AsyncValueView<List<DevisPrestation>>(
        value: devisAsync,
        onRetry: () => ref.invalidate(devisServicesProvider),
        data: (devisList) {
          final filtres = devisList.where((d) {
            if (_recherche.isEmpty) return true;
            final q = _recherche.toLowerCase();
            return d.titre.toLowerCase().contains(q) || d.numero.toLowerCase().contains(q);
          }).toList();

          return ResponsiveBody(
            maxWidth: 860,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un devis...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _recherche.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _recherche = ''))
                          : null,
                    ),
                    onChanged: (val) => setState(() => _recherche = val.trim()),
                  ),
                ),
                Expanded(
                  child: filtres.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.request_quote_outlined, size: 48, color: AppColors.muted),
                                const SizedBox(height: 12),
                                const Text(
                                  'Aucun devis enregistré',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Créez des propositions chiffrées à convertir en 1-clic une fois validées.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filtres.length,
                          itemBuilder: (_, idx) {
                            final d = filtres[idx];
                            return _DevisCard(devis: d);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DevisCard extends ConsumerWidget {
  const _DevisCard({required this.devis});
  final DevisPrestation devis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (Color couleur, String libelle) = switch (devis.statut) {
      StatutDevis.brouillon => (AppColors.muted, 'Brouillon'),
      StatutDevis.envoye => (const Color(0xFF0284C7), 'Envoyé'),
      StatutDevis.accepte => (AppColors.green, 'Accepté'),
      StatutDevis.refuse => (AppColors.negative, 'Refusé'),
      StatutDevis.expire => (const Color(0xFFEA580C), 'Expiré'),
      StatutDevis.converti => (const Color(0xFF7C3AED), '✓ Converti en prestation'),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/services/devis/${devis.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          devis.numero,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.muted),
                        ),
                        Text(
                          devis.titre,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    montant(context, ref, devis.total),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF01226C)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      libelle,
                      style: TextStyle(color: couleur, fontWeight: FontWeight.w800, fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Émis le ${DateFormat('dd/MM/yyyy').format(devis.dateEmission)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
              if (devis.statut == StatutDevis.envoye || devis.statut == StatutDevis.brouillon || devis.statut == StatutDevis.accepte) ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (devis.statut != StatutDevis.accepte)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                        onPressed: () => _marquerAccepte(context, ref, devis.id),
                        child: const Text('Marquer accepté'),
                      ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Créer la prestation'),
                      onPressed: () => _convertirEnPrestation(context, ref, devis.id),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _marquerAccepte(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(gererServicesProvider).accepterDevis(id);
      ref.invalidate(devisServicesProvider);
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }

  Future<void> _convertirEnPrestation(BuildContext context, WidgetRef ref, String id) async {
    try {
      final p = await ref.read(gererServicesProvider).convertirDevisEnPrestation(id);
      ref.invalidate(devisServicesProvider);
      ref.invalidate(prestationsProvider);
      if (context.mounted) {
        showMessageSnackBar(context, 'Prestation créée avec succès à partir du devis !');
        context.push('/services/prestations/${p.id}');
      }
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }
}
