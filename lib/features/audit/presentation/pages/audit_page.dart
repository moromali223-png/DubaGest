import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/entree_audit.dart';
import '../providers/audit_providers.dart';

/// Journal d'activité : qui a fait quoi, quand, avant / après.
/// Aucun nom technique affiché : entités, actions et champs sont traduits.
class AuditPage extends ConsumerWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final journal = ref.watch(journalProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moduleAdminAudit)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(journalProvider.future),
        child: ResponsiveBody(
          child: AsyncValueView<List<EntreeAudit>>(
            value: journal,
            isEmpty: (l) => l.isEmpty,
            emptyMessage: l10n.auditEmpty,
            onRetry: () => ref.invalidate(journalProvider),
            data: (entrees) => ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: entrees.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _Entree(entree: entrees[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Entree extends StatelessWidget {
  const _Entree({required this.entree});
  final EntreeAudit entree;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final e = entree;
    final (icone, couleur) = switch (e.action) {
      AuditAction.creation => (Icons.add_circle_outline, AppColors.positive),
      AuditAction.modification => (Icons.edit_outlined, AppColors.green),
      AuditAction.archivage || AuditAction.suppression => (Icons.archive_outlined, AppColors.warning),
      AuditAction.restauration => (Icons.unarchive_outlined, AppColors.green),
    };

    final lignes = <String>[];
    var autres = 0;
    if (e.action == AuditAction.modification) {
      for (final champ in e.champs) {
        final libelle = libelleChamp(l10n, champ);
        if (libelle == null) {
          autres++;
          continue;
        }
        lignes.add('$libelle : ${valeur(l10n, champ, e.avant[champ])} → ${valeur(l10n, champ, e.apres[champ])}');
      }
    } else {
      final nom = (e.apres['nom'] ?? e.avant['nom'] ?? e.apres['email'] ?? e.avant['email'])?.toString();
      if (nom != null) lignes.add(nom);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icone, color: couleur, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${libelleAction(l10n, e.action)} · ${libelleEntite(l10n, e.entiteType)}',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text('${e.auteurNom ?? (e.auteurId == null ? l10n.auditSystem : '—')} · ${l10n.dateTime(e.date)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                  for (final l in lignes.take(4))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(l, style: theme.textTheme.bodyMedium),
                    ),
                  if (autres > 0 || lignes.length > 4)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.auditOtherFields(autres + (lignes.length > 4 ? lignes.length - 4 : 0)),
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
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

String libelleAction(AppLocalizations l10n, AuditAction a) => switch (a) {
      AuditAction.creation => l10n.auditActionCreation,
      AuditAction.modification => l10n.auditActionModification,
      AuditAction.archivage => l10n.auditActionArchivage,
      AuditAction.restauration => l10n.auditActionRestauration,
      AuditAction.suppression => l10n.auditActionSuppression,
    };

String libelleEntite(AppLocalizations l10n, String table) => switch (table) {
      'entreprises' => l10n.auditEntityEntreprise,
      'entreprise_activites' => l10n.auditEntityActivite,
      'abonnements' => l10n.auditEntityAbonnement,
      'membres_entreprise' => l10n.auditEntityMembre,
      'membre_perimetres' => l10n.auditEntityAffectation,
      'perimetres' => l10n.auditEntitySite,
      'invitations' => l10n.auditEntityInvitation,
      _ => '—',
    };

/// Libellé utilisateur d'un champ, ou `null` s'il n'a pas de sens pour lui
/// (identifiants techniques) : il est alors seulement compté.
String? libelleChamp(AppLocalizations l10n, String champ) => switch (champ) {
      'nom' => l10n.perimetreName,
      'code' => l10n.perimetreCode,
      'type' => l10n.perimetreType,
      'est_actif' || 'est_active' || 'statut' => l10n.subscriptionStatus,
      'role_code' => l10n.inviteRole,
      'telephone' => l10n.entreprisePhone,
      'adresse' => l10n.entrepriseAddress,
      'ville' => l10n.entrepriseCity,
      'pays' => l10n.entrepriseCountry,
      'devise' => l10n.entrepriseCurrency,
      'langue_defaut' => l10n.entrepriseDocLanguage,
      'identifiant_fiscal' => l10n.entrepriseTaxId,
      'registre_commerce' => l10n.entrepriseTradeRegister,
      'plan_code' => l10n.subscriptionPlan,
      'email' => l10n.authEmail,
      'activite_code' => l10n.espaceActivity,
      _ => null,
    };

String valeur(AppLocalizations l10n, String champ, Object? v) {
  if (v == null || (v is String && v.isEmpty)) return '—';
  if (v is bool) return v ? l10n.commonActive : l10n.commonInactive;
  return switch (champ) {
    'role_code' => l10n.role('$v'),
    'activite_code' => l10n.activiteCode(v),
    'plan_code' => l10n.plan('$v'),
    _ => '$v',
  };
}
