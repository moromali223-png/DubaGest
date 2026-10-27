import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/immobilier_widgets.dart';

class ProprietairesPage extends ConsumerWidget {
  const ProprietairesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final proprietairesAsync = ref.watch(proprietairesListProvider);
    final proprietairesFiltres = ref.watch(proprietairesFiltresProvider);
    final tousLesProprietaires = proprietairesAsync.value ?? const [];
    final recherche = ref.watch(rechercheProprietaireProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moduleImmobilierProprietaires),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Nouveau propriétaire',
            onPressed: () => context.push(Routes.contactNouveau(relation: RelationContact.proprietaire.code)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un propriétaire (nom, téléphone...)...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppColors.surface,
                suffixIcon: recherche.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => ref.read(rechercheProprietaireProvider.notifier).set(''),
                      )
                    : null,
              ),
              onChanged: (val) => ref.read(rechercheProprietaireProvider.notifier).set(val),
            ),
          ),

          // En-tête avec compteur
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tousLesProprietaires.length} propriétaire(s) enregistré(s)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Liste des propriétaires
          Expanded(
            child: proprietairesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => MessageView(
                icon: Icons.error_outline,
                title: 'Erreur de chargement',
                message: err.toString(),
                action: FilledButton.icon(
                  onPressed: () => ref.invalidate(proprietairesListProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ),
              data: (_) {
                if (tousLesProprietaires.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: MessageView(
                      icon: Icons.badge_outlined,
                      title: 'Aucun propriétaire enregistré',
                      message:
                          'Enregistrez les propriétaires des biens pour lier leurs patrimoines et gérer les loyers.',
                      action: FilledButton.icon(
                        icon: const Icon(Icons.person_add_rounded),
                        label: const Text('Créer un propriétaire'),
                        onPressed: () => context.push(
                          Routes.contactNouveau(relation: RelationContact.proprietaire.code),
                        ),
                      ),
                    ),
                  );
                }

                if (proprietairesFiltres.isEmpty) {
                  return const Center(
                    child: Text('Aucun propriétaire ne correspond à votre recherche.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(proprietairesListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
                    itemCount: proprietairesFiltres.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final proprietaire = proprietairesFiltres[index];
                      return ProprietaireCard(contact: proprietaire);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('proprietaire-add'),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nouveau Propriétaire'),
        onPressed: () => context.push(
          Routes.contactNouveau(relation: RelationContact.proprietaire.code),
        ),
      ),
    );
  }
}
