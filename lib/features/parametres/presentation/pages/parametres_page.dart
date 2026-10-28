import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../../core/di/sync_providers.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../shared/widgets/language_selector.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../authentication/domain/entities/auth_state.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../../navigation/presentation/providers/navigation_providers.dart';
import '../../../super_admin/presentation/providers/super_admin_providers.dart';
import '../widgets/deconnexion.dart';

class ParametresPage extends ConsumerWidget {
  const ParametresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ctx = ref.watch(contexteActifProvider);
    final auth = ref.watch(authStateProvider).value;
    final sync = ref.watch(syncStateProvider).value ?? const SyncState();
    final estSuperAdmin = ref.watch(estSuperAdminProvider).value ?? false;
    final email = auth is Authenticated ? auth.user.email : null;

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs, bottom: AppSpacing.sm),
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
              Card(child: Column(children: children)),
            ],
          ),
        );

    Widget lien(Key key, IconData icone, String titre, String route, {String? sousTitre}) => ListTile(
          key: key,
          leading: Icon(icone),
          title: Text(titre),
          subtitle: sousTitre == null ? null : Text(sousTitre),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(route),
        );

    final syncLabel = switch (sync.phase) {
      SyncPhase.syncing => l10n.syncSyncing,
      SyncPhase.offline => l10n.syncOffline,
      SyncPhase.error => l10n.syncError,
      SyncPhase.idle when sync.pendingCount > 0 => l10n.syncPending(sync.pendingCount),
      SyncPhase.idle => l10n.syncUpToDate,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            section(l10n.settingsAccount, [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(ctx?.nomComplet ?? email ?? ''),
                subtitle: email == null ? null : Text(email),
              ),
              ListTile(
                leading: const Icon(Icons.password),
                title: Text(l10n.authChangePassword),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(Routes.changePassword),
              ),
            ]),
            if (estSuperAdmin)
              section('Administration Centrale', [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                  ),
                  title: const Text(
                    'Console Super Admin DubaGest',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Supervision des entreprises, accès sponsorisés, journal d\'audit'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(Routes.superAdmin),
                ),
              ]),
            section(l10n.languageLabel, const [LanguageList()]),
            section('Affichage & Thème', [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Consumer(
                  builder: (context, ref, _) {
                    final currentMode = ref.watch(themeModeControllerProvider);
                    return SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('Système'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded),
                          label: Text('Clair'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded),
                          label: Text('Sombre'),
                        ),
                      ],
                      selected: {currentMode},
                      onSelectionChanged: (selected) {
                        ref.read(themeModeControllerProvider.notifier).setThemeMode(selected.first);
                      },
                    );
                  },
                ),
              ),
            ]),
            if (ctx != null)
              section(l10n.settingsEntreprise, [
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(ctx.entreprise!.nom),
                  subtitle: Text(l10n.role(ctx.membre!.roleCode)),
                ),
                // Chaque réglage n'apparaît qu'avec le droit de le changer (ou de le voir).
                if (ref.watch(moduleAccessProvider(ModuleCodes.adminEntreprise)).isAllowed)
                  lien(const Key('parametres-fiche'), Icons.badge_outlined, l10n.settingsCompanyProfile,
                      ModuleRoutes.path(ModuleCodes.adminEntreprise)),
                if (ctx.permissionEngine.has(PermissionCodes.entrepriseManage))
                  lien(const Key('parametres-paiements'), Icons.payments_outlined, l10n.settingsPayments,
                      Routes.parametresPaiements, sousTitre: l10n.settingsPaymentsHint),
                if (ref.watch(droitsFinancesProvider).modifierDepenses)
                  lien(const Key('parametres-categories'), Icons.category_outlined, l10n.settingsExpenseCategories,
                      Routes.categoriesDepenses),
              ]),
            section(l10n.settingsSync, [
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(syncLabel),
                subtitle: sync.lastSyncedAt == null
                    ? null
                    : Text(l10n.syncLastSynced(l10n.dateTime(sync.lastSyncedAt!))),
                // Icône seule : un libellé long (grand texte, arabe) déborderait de la tuile.
                trailing: IconButton(
                  key: const Key('sync-maintenant'),
                  tooltip: l10n.syncNow,
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.read(syncEngineProvider).requestSync(),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('sign-out'),
              onPressed: () => seDeconnecter(context, ref),
              icon: const Icon(Icons.logout),
              label: Text(l10n.authSignOut),
            ),
          ],
        ),
      ),
    );
  }
}
