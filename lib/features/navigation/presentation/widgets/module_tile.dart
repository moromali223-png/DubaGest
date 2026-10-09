import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../modules/domain/entities/app_module.dart';
import 'module_visuals.dart';

import 'tous_les_modules_sheet.dart';

/// Rangée de modules en icônes : 4 par ligne.
class ModuleGrid extends StatelessWidget {
  const ModuleGrid({super.key, required this.modules, this.maxItems = 7, this.onPlusPressed});
  final List<AppModule> modules;
  final int maxItems;
  final VoidCallback? onPlusPressed;

  @override
  Widget build(BuildContext context) {
    final visible = modules.take(maxItems).toList();

    return GridView.extent(
      maxCrossAxisExtent: 92,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.xs,
      childAspectRatio: 0.85,
      children: [
        for (var i = 0; i < visible.length; i++) ModuleTile(module: visible[i], mis: i == 0),
        _PlusTile(
          onTap: onPlusPressed ?? () => afficherTousLesModules(context),
        ),
      ],
    );
  }
}

class _PlusTile extends StatelessWidget {
  const _PlusTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.grid_view_rounded, color: AppColors.green, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              'Plus',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModuleTile extends StatelessWidget {
  const ModuleTile({super.key, required this.module, this.mis = false});
  final AppModule module;

  /// Premier module de la section, mis en avant (fond menthe douce #E8F5EE).
  final bool mis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = context.l10n.moduleCourt(module.code);
    return InkWell(
      key: ValueKey('module-${module.code}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(ModuleRoutes.path(module.code)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: mis ? AppColors.greenSoft : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: mis
                    ? Border.all(color: AppColors.green.withValues(alpha: 0.15), width: 1.2)
                    : Border.all(color: AppColors.border, width: 1.2),
              ),
              child: Icon(
                moduleIcon(module.code),
                color: AppColors.green,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: mis ? FontWeight.w700 : FontWeight.w600,
                color: AppColors.ink,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
