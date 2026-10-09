import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../core/permissions/permission_codes.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../../parametres/presentation/widgets/deconnexion.dart';
import '../providers/navigation_providers.dart';
import 'aide_support_dialog.dart';
import 'conditions_confidentialite_dialog.dart';
import 'module_visuals.dart';

/// Menu ☰ : profil, entreprise et formule, activités (actives, activables ou
/// non incluses), administration, aide, conditions / confidentialité, déconnexion.
/// Tout ce qui est proposé ici respecte les droits et la formule réels.
class AppMenuDrawer extends ConsumerWidget {
  const AppMenuDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final nav = ref.watch(navigationModelProvider);
    if (ctx == null || nav == null) return const Drawer();

    void aller(String path) {
      Navigator.of(context).pop();
      context.go(path);
    }

    final nom = ctx.nomComplet ?? '';
    final initiales = nom.trim().isEmpty
        ? '?'
        : nom.trim().split(RegExp(r'\s+')).take(2).map((m) => m.characters.first.toUpperCase()).join();
    final abonnement = ctx.abonnement;
    // Les activités non actives ne sont montrées qu'à qui gère l'entreprise
    // ou consulte l'abonnement (pas d'offre commerciale pour un vendeur).
    final voitOffres = ctx.permissionEngine.hasAny(
      const [PermissionCodes.entrepriseManage, PermissionCodes.subscriptionView],
    );
    final actives = {for (final a in ctx.activites) if (a.estActive) a.activite};

    return Drawer(
      key: const Key('app-menu'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.green,
                  child: Text(initiales,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nom, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(l10n.role(ctx.membre!.roleCode),
                          style: const TextStyle(color: AppColors.onInkMuted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(backgroundColor: AppColors.inkRaised, foregroundColor: Colors.white),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inkRaised,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ctx.entreprise!.nom,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  if (abonnement != null)
                    Text(
                      '${l10n.subscriptionPlan} ${l10n.plan(abonnement.planCode)} · '
                      '${l10n.abonnementStatut(abonnement.statut)}',
                      style: const TextStyle(color: AppColors.onInkMuted, fontSize: 12),
                    ),
                ],
              ),
            ),

            _Titre(l10n.menuActivities),
            for (final a in ActiviteCode.values)
              if (actives.contains(a))
                _ActiviteActive(activite: a, onTap: () => aller(Routes.home))
              else if (voitOffres)
                _ActiviteDisponible(ctx: ctx, activite: a, onSeePlans: () {
                  if (ref.read(moduleAccessProvider(ModuleCodes.adminAbonnement)).isAllowed) {
                    aller(ModuleRoutes.path(ModuleCodes.adminAbonnement));
                  }
                }),

            if (nav.modulesAdministration.isNotEmpty) ...[
              _Titre(l10n.navAdministration),
              for (final m in nav.modulesAdministration)
                _Ligne(icon: moduleIcon(m.code), label: l10n.module(m.code), onTap: () => aller(ModuleRoutes.path(m.code))),
            ],

            const _Titre('Aide & Légal'),
            _Ligne(
              key: const Key('menu-aide'),
              icon: Icons.help_outline_rounded,
              label: '❓ Aide',
              onTap: () {
                Navigator.of(context).pop();
                AideSupportDialog.show(context);
              },
            ),
            _Ligne(
              key: const Key('menu-conditions'),
              icon: Icons.description_outlined,
              label: '📜 Conditions / confidentialité',
              onTap: () {
                Navigator.of(context).pop();
                ConditionsConfidentialiteDialog.show(context);
              },
            ),

            _Titre(l10n.menuPreferences),
            _Ligne(
              key: const Key('menu-mon-compte'),
              icon: Icons.person_outline_rounded,
              label: 'Mon compte personnel',
              onTap: () => aller(Routes.settings),
            ),
            _Ligne(icon: Icons.translate, label: l10n.languageLabel, onTap: () => aller(Routes.settings)),

            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('menu-sign-out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF4A99F),
                side: const BorderSide(color: AppColors.inkBorder),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await seDeconnecter(context, ref);
              },
              icon: const Icon(Icons.logout),
              label: Text(l10n.authSignOut),
            ),
          ],
        ),
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: AppColors.onInkMuted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        minTileHeight: 48,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: AppColors.greenOnDark),
        title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      );
}

class _ActiviteActive extends StatelessWidget {
  const _ActiviteActive({required this.activite, required this.onTap});
  final ActiviteCode activite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        key: ValueKey('menu-activity-${activite.code}'),
        onTap: onTap,
        tileColor: AppColors.inkRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: _IconeActivite(activite: activite, active: true),
        title: Text(l10n.activite(activite),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppColors.greenOnDark, borderRadius: BorderRadius.circular(99)),
          child: Text(l10n.activityStatusActive,
              style: const TextStyle(color: AppColors.ink, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

/// Activité non active : activable (bouton) ou non incluse (raison + lien abonnement).
class _ActiviteDisponible extends ConsumerStatefulWidget {
  const _ActiviteDisponible({required this.ctx, required this.activite, required this.onSeePlans});
  final ContexteSession ctx;
  final ActiviteCode activite;
  final VoidCallback onSeePlans;

  @override
  ConsumerState<_ActiviteDisponible> createState() => _ActiviteDisponibleState();
}

class _ActiviteDisponibleState extends ConsumerState<_ActiviteDisponible> {
  bool _enCours = false;

  Future<void> _activer() async {
    final l10n = context.l10n;
    final nom = l10n.activite(widget.activite);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.activityActivateTitle(nom)),
        content: Text(l10n.activityActivateMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l10n.activityActivate)),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    setState(() => _enCours = true);
    try {
      await ref.read(activerActiviteProvider).call(widget.ctx, widget.activite);
      await ref.read(contexteSessionProvider.notifier).rafraichir();
      if (mounted) showMessageSnackBar(context, l10n.activityActivated);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final decision = ref.read(activerActiviteProvider).verifier(widget.ctx, widget.activite);
    final limiteFormule = decision is AccessDenied &&
        {RuleCodes.activitiesLimit, RuleCodes.activityNotAllowed}.contains(decision.ruleCode);

    return Container(
      key: ValueKey('menu-activity-${widget.activite.code}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconeActivite(activite: widget.activite, active: false),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.activite(widget.activite),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (decision is AccessDenied) const Icon(Icons.lock_outline, size: 18, color: AppColors.onInkMuted),
            ],
          ),
          if (decision is AccessDenied) ...[
            const SizedBox(height: 6),
            Text(l10n.decision(decision), style: const TextStyle(color: AppColors.onInkMuted, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          if (decision.isAllowed)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _enCours ? null : _activer,
              child: Text(l10n.activityActivate),
            )
          else if (limiteFormule)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: widget.onSeePlans,
              child: Text(l10n.menuSeeSubscription),
            ),
        ],
      ),
    );
  }
}

class _IconeActivite extends StatelessWidget {
  const _IconeActivite({required this.activite, required this.active});
  final ActiviteCode activite;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? AppColors.green : AppColors.inkRaised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(activiteIcon(activite),
            size: 20, color: active ? Colors.white : AppColors.onInkMuted),
      );
}
