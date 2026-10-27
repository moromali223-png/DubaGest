import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../domain/entities/navigation_model.dart';
import '../providers/navigation_providers.dart';
import 'module_visuals.dart';

/// Modal affichant tous les modules disponibles classés par catégorie
/// (Activité, Outils communs, Finances, Administration).
Future<void> afficherTousLesModules(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TousLesModulesSheet(),
    );

class TousLesModulesSheet extends ConsumerStatefulWidget {
  const TousLesModulesSheet({super.key});

  @override
  ConsumerState<TousLesModulesSheet> createState() => _TousLesModulesSheetState();
}

class _TousLesModulesSheetState extends ConsumerState<TousLesModulesSheet> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nav = ref.watch(navigationModelProvider);
    if (nav == null) return const SizedBox.shrink();

    final contacts = nav.modulesCommuns.where((m) => m.code == ModuleCodes.communContacts).firstOrNull;

    // Construction intelligente des modules par activité
    List<AppModule> modulesActivite(ModuleSection sec) {
      if (sec.activite == ActiviteCode.commerce) {
        final liste = [...sec.modules];
        if (contacts != null && !liste.any((m) => m.code == ModuleCodes.communContacts)) {
          final i = liste.indexWhere((m) => m.code == ModuleCodes.commerceFournisseurs);
          liste.insert(i < 0 ? liste.length : i + 1, contacts);
        }
        if (!liste.any((m) => m.code == ModuleCodes.commerceIntelligence)) {
          liste.add(const AppModule(
            code: ModuleCodes.commerceIntelligence,
            activite: ActiviteCode.commerce,
            permissionAcces: 'sales.view',
            ordre: 16,
          ));
        }
        return liste;
      }

      if (sec.activite == ActiviteCode.services) {
        final liste = <AppModule>[];
        // 1. Prestations
        final prestations = sec.modules.where((m) => m.code == ModuleCodes.servicesPrestations).firstOrNull;
        if (prestations != null) liste.add(prestations);

        // 2. Planning (si non présent nativement)
        final planning = sec.modules.where((m) => m.code == ModuleCodes.servicesPlanning).firstOrNull;
        liste.add(planning ??
            const AppModule(
              code: ModuleCodes.servicesPlanning,
              activite: ActiviteCode.services,
              permissionAcces: 'prestations.view',
              ordre: 21,
            ));

        // 3. Devis
        final devis = sec.modules.where((m) => m.code == ModuleCodes.servicesDevis).firstOrNull;
        if (devis != null) {
          liste.add(devis);
        } else {
          liste.add(const AppModule(
            code: ModuleCodes.servicesDevis,
            activite: ActiviteCode.services,
            permissionAcces: 'quotes.view',
            ordre: 23,
          ));
        }

        // 4. Clients
        if (contacts != null) {
          liste.add(contacts);
        }

        // 5. Catalogue
        final catalogue = sec.modules.where((m) => m.code == ModuleCodes.servicesServices).firstOrNull;
        if (catalogue != null) liste.add(catalogue);

        // 6. Factures & Documents (si permissions documents)
        final aDocs = nav.modulesCommuns.any((m) => m.code == ModuleCodes.communDocuments);
        if (aDocs) {
          liste.add(const AppModule(
            code: ModuleCodes.servicesFacturation,
            activite: ActiviteCode.services,
            permissionAcces: 'documents.view',
            ordre: 25,
          ));
        }

        // 7. Rapports & Rentabilité
        liste.add(const AppModule(
          code: ModuleCodes.servicesRapports,
          activite: ActiviteCode.services,
          permissionAcces: 'services.view',
          ordre: 26,
        ));

        return liste;
      }

      return sec.modules;
    }

    String libelle(AppModule m, {ActiviteCode? activite}) {
      if (m.code == ModuleCodes.communContacts) {
        if (activite == ActiviteCode.commerce || activite == ActiviteCode.services) {
          return l10n.moduleCommunContactsClients;
        }
        return l10n.moduleCommunContacts;
      }
      return l10n.moduleCourt(m.code);
    }

    // Filtrage recherche
    final query = _recherche.trim().toLowerCase();
    bool match(AppModule m, {ActiviteCode? activite}) {
      if (query.isEmpty) return true;
      final nom = libelle(m, activite: activite).toLowerCase();
      final code = m.code.toLowerCase();
      return nom.contains(query) || code.contains(query);
    }

    Widget section(String titre, IconData icone, List<AppModule> modules, {Color? couleur, ActiviteCode? activite}) {
      final filtres = modules.where((m) => match(m, activite: activite)).toList();
      if (filtres.isEmpty) return const SizedBox.shrink();

      final themeCouleur = couleur ?? AppColors.green;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: themeCouleur.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icone, size: 16, color: themeCouleur),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  '${filtres.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: themeCouleur,
                  ),
                ),
              ],
            ),
          ),
          GridView.extent(
            maxCrossAxisExtent: 96,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            childAspectRatio: 0.84,
            children: [
              for (final m in filtres)
                InkWell(
                  key: ValueKey('modal-module-${m.code}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(ModuleRoutes.path(m.code));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: m.activite == ActiviteCode.services
                                  ? const Color(0xFF01226C).withValues(alpha: 0.2)
                                  : AppColors.border,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            moduleIcon(m.code),
                            color: m.activite == ActiviteCode.services ? const Color(0xFF01226C) : themeCouleur,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          libelle(m, activite: activite),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée supérieure
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tous les modules',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Barre de recherche de modules
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un module (Prestations, Devis, Caisse...)...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppColors.surface,
                suffixIcon: _recherche.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _recherche = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _recherche = val),
            ),
          ),
          const Divider(height: 1),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Modules des activités
                for (final sec in nav.sections)
                  section(
                    'Activité ${l10n.activite(sec.activite)}',
                    activiteIcon(sec.activite),
                    modulesActivite(sec),
                    couleur: sec.activite == ActiviteCode.services
                        ? const Color(0xFF01226C)
                        : sec.activite == ActiviteCode.immobilier
                            ? const Color(0xFF7C3AED)
                            : AppColors.green,
                    activite: sec.activite,
                  ),

                // Outils communs (carnet d'adresses centralisé, documents, agenda, rapports)
                section(
                  'Outils communs',
                  Icons.hub_outlined,
                  nav.modulesCommuns,
                  couleur: AppColors.gold,
                ),

                // Finances & Trésorerie
                section(
                  'Finances & Trésorerie',
                  Icons.account_balance_wallet_outlined,
                  nav.modulesFinances,
                  couleur: AppColors.green,
                ),

                // Administration
                if (nav.modulesAdministration.isNotEmpty)
                  section(
                    'Administration',
                    Icons.admin_panel_settings_outlined,
                    nav.modulesAdministration,
                    couleur: AppColors.muted,
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
