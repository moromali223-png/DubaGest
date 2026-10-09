import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';

class AbonnementPage extends ConsumerWidget {
  const AbonnementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ctx = ref.watch(contexteActifProvider);
    final abonnement = ctx?.abonnement;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moduleAdminAbonnement)),
      body: ctx == null || abonnement == null
          ? EmptyView(message: l10n.subscriptionNone)
          : RefreshIndicator(
              onRefresh: () => ref.read(contexteSessionProvider.notifier).rafraichir(),
              child: ResponsiveBody(
                child: Builder(builder: (context) {
                  final limites = ctx.limites();
                  final usage = ctx.consommation;
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.subscriptionPlan, style: theme.textTheme.labelLarge),
                              Text(l10n.plan(abonnement.planCode), style: theme.textTheme.headlineSmall),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Chip(
                                    avatar: Icon(
                                      limites.abonnementActif ? Icons.check_circle : Icons.warning_amber,
                                      size: 18,
                                    ),
                                    label: Text(l10n.abonnementStatut(abonnement.statut)),
                                  ),
                                  Text(l10n.subscriptionSince(l10n.date(abonnement.dateDebut))),
                                  if (abonnement.dateFin != null)
                                    Text(l10n.subscriptionUntil(l10n.date(abonnement.dateFin!))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SectionTitle(l10n.subscriptionUsage),
                      Card(
                        child: Column(
                          children: [
                            _UsageTile(
                              label: l10n.subscriptionUsers,
                              used: usage.utilisateurs,
                              max: limites.maxUtilisateurs,
                            ),
                            for (final a in limites.activitesActives)
                              _UsageTile(
                                label: '${l10n.moduleAdminPerimetres} · ${l10n.activite(a)}',
                                used: usage.perimetresParActivite[a] ?? 0,
                                max: limites.maxPerimetres(a),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SectionTitle(l10n.subscriptionActivities),
                      Card(
                        child: Column(
                          children: [
                            for (final a in ctx.activites)
                              ListTile(
                                title: Text(l10n.activite(a.activite)),
                                trailing: Text(a.estActive ? l10n.commonActive : l10n.commonInactive),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs, bottom: AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({required this.label, required this.used, required this.max});
  final String label;
  final int used;

  /// `null` = illimité : pas de jauge.
  final int? max;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = this.max;
    final ratio = max == null || max == 0 ? 1.0 : (used / max).clamp(0.0, 1.0);
    return ListTile(
      title: Text(label),
      trailing: Text(context.l10n.usage(used, max)),
      subtitle: max == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: LinearProgressIndicator(
                value: ratio,
                color: ratio >= 1 ? scheme.error : null,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
    );
  }
}
