import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/contrat_bail.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/contrat_widgets.dart';

class ContratsPage extends ConsumerStatefulWidget {
  const ContratsPage({super.key});

  @override
  ConsumerState<ContratsPage> createState() => _ContratsPageState();
}

class _ContratsPageState extends ConsumerState<ContratsPage> {
  String _recherche = '';
  StatutContratBail? _filtreStatut;
  TypeBail? _filtreType;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';

    final contratsAsync = ref.watch(contratsListProvider);
    final biens = ref.watch(biensListProvider).value ?? const [];
    final contacts = ref.watch(contactsProvider).value ?? const [];

    final tousLesContrats = contratsAsync.value ?? const [];

    final contratsFiltres = tousLesContrats.where((c) {
      if (_filtreStatut != null && c.statut != _filtreStatut) return false;
      if (_filtreType != null && c.typeBail != _filtreType) return false;

      if (_recherche.trim().isNotEmpty) {
        final query = _recherche.toLowerCase();
        final matchRef = c.reference.toLowerCase().contains(query);

        final bien = biens.where((b) => b.id == c.bienId).firstOrNull;
        final matchBien = bien != null && bien.nom.toLowerCase().contains(query);

        final locataire = contacts.where((contact) => contact.id == c.locataireId).firstOrNull;
        final matchLocataire =
            locataire != null && locataire.nomAffiche.toLowerCase().contains(query);

        return matchRef || matchBien || matchLocataire;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moduleImmobilierContrats),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: 'Nouveau contrat de bail',
            onPressed: () => context.push(Routes.contratNouveau),
          ),
        ],
      ),
      body: Column(
        children: [
          // En-tête KPI des contrats
          ContratsStatsHeader(contrats: tousLesContrats, devise: devise),

          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher par référence, locataire, bien...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _recherche.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _recherche = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _recherche = val),
            ),
          ),

          // Filtres par statut
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous les statuts'),
                  selected: _filtreStatut == null,
                  onSelected: (_) => setState(() => _filtreStatut = null),
                ),
                const SizedBox(width: 8),
                for (final statut in StatutContratBail.values) ...[
                  FilterChip(
                    label: Text(statut.libelle),
                    avatar: Icon(statut.icone, size: 14, color: statut.couleur),
                    selected: _filtreStatut == statut,
                    onSelected: (_) => setState(() => _filtreStatut = statut),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          // Filtres par type de bail
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous types'),
                  selected: _filtreType == null,
                  onSelected: (_) => setState(() => _filtreType = null),
                ),
                const SizedBox(width: 8),
                for (final type in TypeBail.values) ...[
                  FilterChip(
                    label: Text(type.libelle),
                    avatar: Icon(type.icone, size: 14, color: AppColors.primary),
                    selected: _filtreType == type,
                    onSelected: (_) => setState(() => _filtreType = type),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          // Liste des contrats
          Expanded(
            child: contratsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Erreur lors du chargement des contrats : $err',
                    style: const TextStyle(color: Color(0xFFEF4444)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (_) {
                if (contratsFiltres.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 72),
                    child: MessageView(
                      icon: Icons.history_edu_outlined,
                      title: tousLesContrats.isEmpty
                          ? 'Aucun contrat de bail'
                          : 'Aucun contrat correspondant',
                      message: tousLesContrats.isEmpty
                          ? 'Créez votre premier contrat de bail pour formaliser juridiquement une location.'
                          : 'Modifiez vos critères de recherche ou de filtre.',
                      action: tousLesContrats.isEmpty
                          ? FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                              onPressed: () => context.push(Routes.contratNouveau),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Créer un contrat'),
                            )
                          : null,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: contratsFiltres.length,
                  itemBuilder: (context, index) {
                    final contrat = contratsFiltres[index];
                    return ContratCard(contrat: contrat);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau contrat'),
        onPressed: () => context.push(Routes.contratNouveau),
      ),
    );
  }
}
