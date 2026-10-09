import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../providers/navigation_providers.dart';
import '../widgets/module_visuals.dart';

class AdministrationPage extends ConsumerWidget {
  const AdministrationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final modules = ref.watch(navigationModelProvider)?.modulesAdministration ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navAdministration), actions: const [SyncStatusButton()]),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Column(
                children: [
                  for (final m in modules)
                    ListTile(
                      key: ValueKey('admin-${m.code}'),
                      leading: Icon(moduleIcon(m.code)),
                      title: Text(l10n.module(m.code)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(ModuleRoutes.path(m.code)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
