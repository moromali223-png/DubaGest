import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/caisse_tresorerie_models.dart';
import '../../domain/entities/finances.dart';
import 'caisse_labels.dart';
import 'finances_widgets.dart';

/// Carte de base des statistiques : titre + contenu, bordure légère.
class _Carte extends StatelessWidget {
  const _Carte({required this.titre, required this.icone, required this.child, this.action});
  final String titre;
  final IconData icone;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icone, size: 20, color: AppColors.green),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  titre,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    ),
  );
}

class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Text(
      context.l10n.cashNoDataPeriod,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.muted),
    ),
  );
}

/// 1. Solde disponible : grand chiffre masquable, espèces en caisse, état de
/// la caisse de la boutique et son action (ouvrir / fermer).
class SoldeDisponibleCard extends StatelessWidget {
  const SoldeDisponibleCard({
    super.key,
    required this.total,
    required this.especes,
    required this.masque,
    required this.onMasquer,
    this.caisse,
    this.session,
    this.derniereCloture,
    this.onOuvrir,
    this.onFermer,
  });

  final int total;
  final int especes;
  final bool masque;
  final VoidCallback onMasquer;
  final Caisse? caisse;
  final SessionCaisse? session;

  /// Dernière clôture (caisse fermée) : son contrôle reste visible.
  final SessionCaisse? derniereCloture;
  final VoidCallback? onOuvrir;
  final VoidCallback? onFermer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ouverte = session != null;
    const blanc = TextStyle(color: Colors.white);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.cashAvailable.toUpperCase(),
                    style: blanc.copyWith(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
                IconButton(
                  key: const Key('caisse-masquer'),
                  tooltip: masque ? l10n.cashShowAmounts : l10n.cashHideAmounts,
                  onPressed: onMasquer,
                  icon: Icon(masque ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white),
                ),
              ],
            ),
            MontantMasquable(
              total,
              masque: masque,
              style: blanc.copyWith(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Wrap : sur un téléphone étroit, le montant passe à la ligne.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                const Icon(Icons.payments_outlined, size: 16, color: Colors.white70),
                Text('${l10n.cashCashOnHand} :', style: blanc.copyWith(color: Colors.white70)),
                MontantMasquable(
                  especes,
                  masque: masque,
                  style: blanc.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (caisse != null) ...[
              const Divider(color: Colors.white24, height: AppSpacing.lg * 1.5),
              Row(
                children: [
                  Icon(ouverte ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ouverte
                          ? '${caisse!.nom} · ${l10n.cashOpenSince(l10n.dateTime(session!.ouverteLe))}'
                          : '${caisse!.nom} · ${l10n.cashClosedState}',
                      style: blanc.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                    ),
                  ),
                  if (!ouverte && derniereCloture?.ecart != null) _EtatControle(cloture: derniereCloture!),
                ],
              ),
              if ((ouverte && onFermer != null) || (!ouverte && onOuvrir != null)) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: ouverte
                      ? OutlinedButton.icon(
                          key: const Key('caisse-cloturer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: onFermer,
                          icon: const Icon(Icons.lock_outline_rounded, size: 18),
                          label: Text(l10n.cashClose),
                        )
                      : FilledButton.icon(
                          key: const Key('caisse-ouvrir'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.green,
                          ),
                          onPressed: onOuvrir,
                          icon: const Icon(Icons.lock_open_rounded, size: 18),
                          label: Text(l10n.cashOpen),
                        ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Contrôle de la dernière clôture : équilibrée / écart / écart important
/// (au moins 5 % du montant attendu : indépendant de la devise).
class _EtatControle extends StatelessWidget {
  const _EtatControle({required this.cloture});
  final SessionCaisse cloture;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ecart = cloture.ecart ?? 0;
    final attendu = (cloture.soldeTheorique ?? 0).abs();
    final important = ecart.abs() * 20 >= attendu;
    final (texte, icone) = ecart == 0
        ? (l10n.cashBalanced, Icons.check_circle_outline)
        : important
        ? (l10n.cashGapLarge, Icons.warning_amber_rounded)
        : (l10n.cashGap(l10n.nombre(ecart)), Icons.error_outline);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: ecart == 0 ? AppColors.positive : AppColors.negative),
          const SizedBox(width: 4),
          Text(
            texte,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ecart == 0 ? AppColors.positive : AppColors.negative,
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. Entrées / sorties / variation de la période choisie.
class ResumePeriodeCard extends StatelessWidget {
  const ResumePeriodeCard({
    super.key,
    required this.filtre,
    required this.resume,
    required this.onFiltreChanged,
    required this.masque,
  });

  final FiltrePeriode filtre;
  final ResumeTresorerie resume;
  final ValueChanged<FiltrePeriode> onFiltreChanged;
  final bool masque;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget bloc(String titre, int montant, bool? signe, Color fond, Color texte) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titre,
              style: TextStyle(color: texte, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: MontantMasquable(
                montant,
                masque: masque,
                signe: signe,
                style: TextStyle(color: texte, fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
    final net = resume.variationNette;
    return _Carte(
      titre: l10n.filtrePeriode(filtre),
      icone: Icons.today_outlined,
      action: PopupMenuButton<FiltrePeriode>(
        key: const Key('caisse-periode'),
        icon: const Icon(Icons.tune_rounded, size: 20),
        onSelected: onFiltreChanged,
        itemBuilder: (_) => [
          for (final f in FiltrePeriode.values)
            CheckedPopupMenuItem(value: f, checked: f == filtre, child: Text(l10n.filtrePeriode(f))),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              bloc(l10n.cashIncoming, resume.entrees, true, AppColors.positiveSoft, AppColors.positive),
              const SizedBox(width: AppSpacing.xs),
              bloc(l10n.cashOutgoing, resume.sorties, false, AppColors.negativeSoft, AppColors.negative),
              const SizedBox(width: AppSpacing.xs),
              bloc(
                l10n.cashNet,
                net.abs(),
                net == 0 ? null : net > 0,
                AppColors.background,
                net >= 0 ? AppColors.ink : AppColors.negative,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.cashOperationsCount(resume.nombreOperations),
            style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// 3. Où est l'argent : solde de chaque moyen d'argent (jamais mélangé).
class SoldesParModeCard extends StatelessWidget {
  const SoldesParModeCard({super.key, required this.soldes, required this.masque});
  final Map<ModePaiement, int> soldes;
  final bool masque;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lignes = soldes.entries.where((e) => e.value != 0 || e.key == ModePaiement.especes).toList();
    return _Carte(
      titre: l10n.cashByMode,
      icone: Icons.account_balance_wallet_outlined,
      child: Column(
        children: [
          for (final e in lignes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: couleurMode(e.key).withValues(alpha: 0.12),
                    child: Icon(iconeMode(e.key), size: 16, color: couleurMode(e.key)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(l10n.modePaiement(e.key), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  MontantMasquable(
                    e.value,
                    masque: masque,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: e.value < 0 ? AppColors.negative : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 4. Évolution réelle du solde (7 j, 30 j, 3 mois).
class EvolutionTresorerieChart extends StatefulWidget {
  const EvolutionTresorerieChart({super.key, required this.points7j, required this.points30j, required this.points90j});
  final List<PointEvolutionTresorerie> points7j;
  final List<PointEvolutionTresorerie> points30j;
  final List<PointEvolutionTresorerie> points90j;

  @override
  State<EvolutionTresorerieChart> createState() => _EvolutionTresorerieChartState();
}

class _EvolutionTresorerieChartState extends State<EvolutionTresorerieChart> {
  int _jours = 7;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final points = switch (_jours) {
      30 => widget.points30j,
      90 => widget.points90j,
      _ => widget.points7j,
    };
    final aucunMouvement = points.every((p) => p.entrees == 0 && p.sorties == 0);
    final etiquettes = [
      for (final p in points)
        _jours <= 7
            ? MaterialLocalizations.of(context).narrowWeekdays[p.date.weekday % 7]
            : '${p.date.day}/${p.date.month}',
    ];
    return _Carte(
      titre: l10n.cashBalanceTrend,
      icone: Icons.show_chart_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 7, label: Text(l10n.period7Days)),
              ButtonSegment(value: 30, label: Text(l10n.period30Days)),
              ButtonSegment(value: 90, label: Text(l10n.period3Months)),
            ],
            selected: {_jours},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _jours = s.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: AppSpacing.md),
          if (points.length < 2 || aucunMouvement)
            const _Vide()
          else
            SizedBox(
              height: 160,
              child: CustomPaint(
                painter: _CourbeSolde(
                  soldes: [for (final p in points) p.solde],
                  etiquettes: etiquettes,
                  directionTexte: Directionality.of(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CourbeSolde extends CustomPainter {
  _CourbeSolde({required this.soldes, required this.etiquettes, required this.directionTexte});
  final List<int> soldes;
  final List<String> etiquettes;
  final TextDirection directionTexte;

  @override
  void paint(Canvas canvas, Size size) {
    var minV = soldes.reduce(math.min).toDouble();
    var maxV = soldes.reduce(math.max).toDouble();
    if (maxV == minV) {
      maxV += 1;
      minV -= 1;
    }
    const bas = 20.0;
    final h = size.height - bas;
    final pas = size.width / (soldes.length - 1);
    double x(int i) => directionTexte == TextDirection.rtl ? size.width - i * pas : i * pas;
    double y(int v) => h - (v - minV) / (maxV - minV) * (h - 8) - 4;

    canvas.drawLine(Offset(0, h), Offset(size.width, h), Paint()..color = AppColors.border);
    final ligne = Path()..moveTo(x(0), y(soldes[0]));
    final aire = Path()
      ..moveTo(x(0), h)
      ..lineTo(x(0), y(soldes[0]));
    for (var i = 1; i < soldes.length; i++) {
      ligne.lineTo(x(i), y(soldes[i]));
      aire.lineTo(x(i), y(soldes[i]));
    }
    aire
      ..lineTo(x(soldes.length - 1), h)
      ..close();
    canvas.drawPath(aire, Paint()..color = AppColors.green.withValues(alpha: 0.10));
    canvas.drawPath(
      ligne,
      Paint()
        ..color = AppColors.green
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(x(soldes.length - 1), y(soldes.last)), 4, Paint()..color = AppColors.green);

    final tp = TextPainter(textDirection: directionTexte);
    final tous = (soldes.length / 6).ceil();
    for (var i = 0; i < soldes.length; i++) {
      if (i % tous != 0 && i != soldes.length - 1) continue;
      tp.text = TextSpan(
        text: etiquettes[i],
        style: const TextStyle(color: AppColors.muted, fontSize: 10),
      );
      tp.layout();
      tp.paint(canvas, Offset((x(i) - tp.width / 2).clamp(0, size.width - tp.width), h + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _CourbeSolde old) => old.soldes != soldes || old.directionTexte != directionTexte;
}

/// 5. D'où vient l'argent (entrées) / où il part (sorties), par origine.
class RepartitionCard extends StatelessWidget {
  const RepartitionCard({super.key, required this.lignes, required this.entrees, required this.masque});
  final List<LigneRepartition> lignes;
  final bool entrees;
  final bool masque;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Carte(
      titre: entrees ? l10n.cashInBreakdown : l10n.cashOutBreakdown,
      icone: entrees ? Icons.south_west_rounded : Icons.north_east_rounded,
      child: lignes.isEmpty
          ? const _Vide()
          : Column(
              children: [
                for (final (i, l) in lignes.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(iconeOrigine(l.origine), size: 16, color: AppColors.muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.origineMouvement(l.origine),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            MontantMasquable(
                              l.montant,
                              masque: masque,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            SizedBox(
                              width: 48,
                              child: Text(
                                '${l.pourcentage.round()} %',
                                textAlign: TextAlign.end,
                                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: l.pourcentage / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.background,
                            color: couleurRang(i, entree: entrees),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 6. Entrées par moyen d'argent.
class MoyensPaiementCard extends StatelessWidget {
  const MoyensPaiementCard({super.key, required this.proportions, required this.masque});
  final List<ProportionModePaiement> proportions;
  final bool masque;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Carte(
      titre: '${l10n.cashIncoming} · ${l10n.cashByMode}',
      icone: Icons.donut_large_rounded,
      child: proportions.isEmpty
          ? const _Vide()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        for (final p in proportions)
                          Expanded(
                            flex: math.max(1, p.pourcentage.round()),
                            child: ColoredBox(color: couleurMode(p.mode)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final p in proportions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(iconeMode(p.mode), size: 16, color: couleurMode(p.mode)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(l10n.modePaiement(p.mode))),
                        MontantMasquable(
                          p.montant,
                          masque: masque,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            '${p.pourcentage.round()} %',
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 7. Comparaison avec la période précédente : jamais de pourcentage sans
/// base comparable.
class ComparaisonPeriodeCard extends StatelessWidget {
  const ComparaisonPeriodeCard({super.key, required this.comp, required this.filtre, required this.masque});
  final ComparaisonPeriodeFinances comp;
  final FiltrePeriode filtre;
  final bool masque;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget ligne(String titre, int actuel, int avant, double? evolution, {required bool sortie}) {
      // Plus d'entrées : bien ; plus de sorties : à surveiller.
      final bon = evolution == null ? null : (sortie ? evolution <= 0 : evolution >= 0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(titre, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MontantMasquable(
                  actuel,
                  masque: masque,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${l10n.cashPreviousPeriod} : ', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                    MontantMasquable(
                      avant,
                      masque: masque,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(
              width: 64,
              child: evolution == null
                  ? const SizedBox.shrink()
                  : Text(
                      '${evolution >= 0 ? '+' : '−'}${evolution.abs().round()} %',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: bon! ? AppColors.positive : AppColors.negative,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return _Carte(
      titre: '${l10n.cashComparison} · ${l10n.filtrePeriode(filtre)}',
      icone: Icons.compare_arrows_rounded,
      child: Column(
        children: [
          ligne(l10n.cashIncoming, comp.entrees, comp.entreesPrecedentes, comp.evolutionEntrees, sortie: false),
          const Divider(height: 12),
          ligne(l10n.cashOutgoing, comp.sorties, comp.sortiesPrecedentes, comp.evolutionSorties, sortie: true),
        ],
      ),
    );
  }
}

/// 8. Comparaison des boutiques (vue globale, multi-boutiques uniquement).
class FluxBoutiquesCard extends ConsumerWidget {
  const FluxBoutiquesCard({super.key, required this.boutiques, required this.masque, this.onSelectBoutique});
  final List<FluxBoutiqueFinances> boutiques;
  final bool masque;
  final ValueChanged<String>? onSelectBoutique;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final noms = ref.watch(nomsPerimetresProvider);
    return _Carte(
      titre: l10n.cashByShop,
      icone: Icons.storefront_outlined,
      child: Column(
        children: [
          for (final b in boutiques)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onSelectBoutique == null ? null : () => onSelectBoutique!(b.perimetreId),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: b.caisseOuverte ? AppColors.positive : AppColors.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(noms[b.perimetreId] ?? '—', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        MontantMasquable(
                          b.tresorerieTotale,
                          masque: masque,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: AppSpacing.md,
                      children: [
                        MontantMasquable(b.entrees, masque: masque, signe: true, style: const TextStyle(fontSize: 12)),
                        MontantMasquable(b.sorties, masque: masque, signe: false, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const Divider(height: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 9. Alertes utiles uniquement.
class AlertesTresorerieWidget extends ConsumerWidget {
  const AlertesTresorerieWidget({super.key, required this.alertes, required this.nomsCaisses});
  final List<AlerteTresorerie> alertes;
  final Map<String, String> nomsCaisses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    return Column(
      children: [
        for (final a in alertes)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: a.type == TypeAlerteTresorerie.ecartCaisse ? AppColors.negativeSoft : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  a.type == TypeAlerteTresorerie.ecartCaisse ? Icons.warning_amber_rounded : Icons.trending_up_rounded,
                  color: a.type == TypeAlerteTresorerie.ecartCaisse ? AppColors.negative : AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(switch (a.type) {
                    TypeAlerteTresorerie.ecartCaisse => l10n.cashAlertGap(
                      l10n.montant(a.montant ?? 0, devise),
                      nomsCaisses[a.caisseId] ?? '',
                    ),
                    TypeAlerteTresorerie.sortiesEnHausse => l10n.cashAlertOutflowsUp(a.pourcentage ?? 0),
                  }, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
