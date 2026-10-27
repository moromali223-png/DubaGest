import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../domain/entities/locataire_immobilier.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/locataire_widgets.dart';

class LocatairesPage extends ConsumerWidget {
  const LocatairesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locatairesAsync = ref.watch(locatairesListProvider);
    final locatairesFiltres = ref.watch(locatairesFiltresProvider);
    final tousLesLocataires = locatairesAsync.value ?? const [];
    final filtre = ref.watch(filtreLocatairesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moduleImmobilierLocataires),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Nouveau locataire',
            onPressed: () => context.push(Routes.contactNouveau(relation: RelationContact.locataire.code)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un locataire (nom, tél, ville...)...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppColors.surface,
                suffixIcon: filtre.recherche.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => ref.read(filtreLocatairesProvider.notifier).rechercher(''),
                      )
                    : null,
              ),
              onChanged: (val) => ref.read(filtreLocatairesProvider.notifier).rechercher(val),
            ),
          ),

          // Puces de filtres horizontales
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: filtre.statutFinancier == null && filtre.typePersonne == null,
                  onSelected: (_) => ref.read(filtreLocatairesProvider.notifier).reinitialiser(),
                ),
                const SizedBox(width: 8),
                for (final s in StatutFinancierLocataire.values) ...[
                  FilterChip(
                    avatar: Icon(s.icone, size: 14, color: s.couleur),
                    label: Text(s.libelle),
                    selected: filtre.statutFinancier == s,
                    selectedColor: s.couleur.withValues(alpha: 0.15),
                    onSelected: (sel) {
                      ref
                          .read(filtreLocatairesProvider.notifier)
                          .changerStatut(sel ? s : null);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                FilterChip(
                  label: const Text('Sociétés'),
                  selected: filtre.typePersonne == TypePersonne.organisation,
                  onSelected: (sel) {
                    ref
                        .read(filtreLocatairesProvider.notifier)
                        .changerType(sel ? TypePersonne.organisation : null);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Particuliers'),
                  selected: filtre.typePersonne == TypePersonne.personne,
                  onSelected: (sel) {
                    ref
                        .read(filtreLocatairesProvider.notifier)
                        .changerType(sel ? TypePersonne.personne : null);
                  },
                ),
              ],
            ),
          ),

          // En-tête avec compteur
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${locatairesFiltres.length} locataire(s) affiché(s)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
                if (filtre.statutFinancier != null || filtre.typePersonne != null || filtre.recherche.isNotEmpty)
                  InkWell(
                    onTap: () => ref.read(filtreLocatairesProvider.notifier).reinitialiser(),
                    child: const Text(
                      'Effacer filtres',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // Liste des locataires
          Expanded(
            child: locatairesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => MessageView(
                icon: Icons.error_outline,
                title: 'Erreur de chargement',
                message: err.toString(),
                action: FilledButton.icon(
                  onPressed: () => ref.invalidate(locatairesListProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ),
                data: (_) {
                if (tousLesLocataires.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: MessageView(
                      icon: Icons.people_outline_rounded,
                      title: 'Aucun locataire enregistré',
                      message:
                          'Enregistrez les locataires pour gérer leurs contrats de bail, quittances de loyer et impayés.',
                      action: FilledButton.icon(
                        icon: const Icon(Icons.person_add_rounded),
                        label: const Text('Créer un locataire'),
                        onPressed: () => context.push(
                          Routes.contactNouveau(relation: RelationContact.locataire.code),
                        ),
                      ),
                    ),
                  );
                }

                if (locatairesFiltres.isEmpty) {
                  return const Center(
                    child: Text('Aucun locataire ne correspond aux critères sélectionnés.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(locatairesListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
                    itemCount: locatairesFiltres.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final locataire = locatairesFiltres[index];
                      return LocataireCard(contact: locataire);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('locataire-add'),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nouveau Locataire'),
        onPressed: () => context.push(
          Routes.contactNouveau(relation: RelationContact.locataire.code),
        ),
      ),
    );
  }
}
