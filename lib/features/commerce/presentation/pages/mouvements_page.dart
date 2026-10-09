import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';
import '../widgets/commerce_widgets.dart';
import '../widgets/mouvement_tuile.dart';

enum _Periode { tout, jour, semaine, mois }

/// Journal des mouvements, groupé par jour, lisible comme un cahier.
class MouvementsPage extends ConsumerStatefulWidget {
  const MouvementsPage({super.key, this.produitId});
  final String? produitId;

  @override
  ConsumerState<MouvementsPage> createState() => _MouvementsPageState();
}

class _MouvementsPageState extends ConsumerState<MouvementsPage> {
  FamilleMouvement? _famille;
  _Periode _periode = _Periode.tout;
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etatAsync = ref.watch(etatCommerceProvider);
    final boutiques = ref.watch(boutiquesVisiblesProvider);
    final produit = widget.produitId == null ? null : etatAsync.value?.produit(widget.produitId!);

    return Scaffold(
      appBar: AppBar(
        title: Text(produit == null ? l10n.comMovementsTitle : '${l10n.comMovementsTitle} · ${produit.nom}'),
        actions: const [SyncStatusButton()],
      ),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: etatAsync,
          onRetry: () => ref.invalidate(etatCommerceProvider),
          data: (etat) {
            final maintenant = DateTime.now();
            final debutJour = DateTime(maintenant.year, maintenant.month, maintenant.day);
            final depuis = switch (_periode) {
              _Periode.tout => null,
              _Periode.jour => debutJour,
              _Periode.semaine => debutJour.subtract(const Duration(days: 6)),
              _Periode.mois => debutJour.subtract(const Duration(days: 29)),
            };
            final ids = _recherche.trim().isEmpty ? null : etat.rechercher(_recherche).map((p) => p.id).toSet();
            final liste = [
              for (final m in etat.mouvementsDe(produitId: widget.produitId, boutiques: boutiques))
                if ((_famille == null || m.famille == _famille) &&
                    (depuis == null || !m.date.isBefore(depuis)) &&
                    (ids == null || ids.contains(m.produitId)))
                  m,
            ];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: Row(
                    children: [
                      if (widget.produitId == null)
                        Expanded(
                          child: TextField(
                            decoration:
                                InputDecoration(hintText: l10n.comSearchHint, prefixIcon: const Icon(Icons.search)),
                            onChanged: (t) => setState(() => _recherche = t),
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: AppSpacing.sm),
                      const BoutiqueSelecteur(),
                    ],
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                    children: [
                      for (final (f, texte) in [
                        (null, l10n.comFamilyAll),
                        (FamilleMouvement.entrees, l10n.comFamilyEntries),
                        (FamilleMouvement.sorties, l10n.comFamilyExits),
                        (FamilleMouvement.transferts, l10n.comFamilyTransfers),
                        (FamilleMouvement.ajustements, l10n.comFamilyAdjustments),
                        (FamilleMouvement.pertes, l10n.comFamilyLosses),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(texte),
                            selected: _famille == f,
                            onSelected: (_) => setState(() => _famille = f),
                          ),
                        ),
                      PopupMenuButton<_Periode>(
                        initialValue: _periode,
                        onSelected: (p) => setState(() => _periode = p),
                        itemBuilder: (_) => [
                          for (final (p, t) in [
                            (_Periode.tout, l10n.comPeriodAll),
                            (_Periode.jour, l10n.comPeriodToday),
                            (_Periode.semaine, l10n.comPeriodWeek),
                            (_Periode.mois, l10n.comPeriodMonth),
                          ])
                            PopupMenuItem(value: p, child: Text(t)),
                        ],
                        child: Chip(
                          avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                          label: Text(switch (_periode) {
                            _Periode.tout => l10n.comPeriodAll,
                            _Periode.jour => l10n.comPeriodToday,
                            _Periode.semaine => l10n.comPeriodWeek,
                            _Periode.mois => l10n.comPeriodMonth,
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: liste.isEmpty
                      ? EtatVide(
                          icone: Icons.history_rounded,
                          titre: l10n.comEmptyMovementsTitle,
                          message: l10n.comEmptyMovementsMessage,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
                          itemCount: liste.length,
                          itemBuilder: (_, i) {
                            final m = liste[i];
                            final jour = _jour(m.date);
                            final nouveauJour = i == 0 || _jour(liste[i - 1].date) != jour;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (nouveauJour)
                                  Padding(
                                    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 4),
                                    child: Text(_titreJour(context, jour),
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
                                  ),
                                MouvementTuile(mouvement: m, avecProduit: widget.produitId == null),
                                const Divider(height: 1),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static DateTime _jour(DateTime d) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  String _titreJour(BuildContext context, DateTime jour) {
    final l10n = context.l10n;
    final aujourdhui = _jour(DateTime.now());
    if (jour == aujourdhui) return l10n.comToday;
    if (jour == aujourdhui.subtract(const Duration(days: 1))) return l10n.comYesterday;
    return l10n.date(jour);
  }
}
