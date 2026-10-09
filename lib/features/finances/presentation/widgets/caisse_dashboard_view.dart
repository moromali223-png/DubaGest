import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../../domain/entities/caisse_tresorerie_models.dart';
import '../../domain/entities/finances.dart';
import '../../domain/services/etat_finances.dart';
import '../providers/finances_providers.dart';
import 'caisse_dialogs.dart';
import 'caisse_labels.dart';
import 'caisse_stats_widgets.dart';
import 'finances_widgets.dart';

/// Caisse : combien j'ai, combien est entré, combien est sorti, et pourquoi.
/// Tout vient des paiements réels (ventes, dettes, achats, dépenses…) : rien
/// n'est ressaisi ici, sauf ce qui n'a pas d'autre source.
class CaisseDashboardView extends ConsumerStatefulWidget {
  const CaisseDashboardView({super.key, required this.etat, this.perimetreIdInitial, this.caisseIdSpecifique});

  final EtatFinances etat;
  final String? perimetreIdInitial;
  final String? caisseIdSpecifique;

  @override
  ConsumerState<CaisseDashboardView> createState() => _CaisseDashboardViewState();
}

class _CaisseDashboardViewState extends ConsumerState<CaisseDashboardView> {
  late String? _site = widget.caisseIdSpecifique == null
      ? widget.perimetreIdInitial
      : widget.etat.caisses.where((c) => c.id == widget.caisseIdSpecifique).firstOrNull?.perimetreId;
  FiltrePeriode _periode = FiltrePeriode.aujourdhui;
  SensPaiement? _sens;
  ModePaiement? _mode;
  String _recherche = '';
  bool _masque = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etat = widget.etat;
    final service = ref.watch(caisseTresorerieServiceProvider);
    final droits = ref.watch(droitsFinancesProvider);
    final sites = (ref.watch(perimetresProvider).value ?? const []).where((p) => p.estActif).toList();
    final nomsSites = ref.watch(nomsPerimetresProvider);
    final contacts = {
      for (final e in (ref.watch(contactsParIdProvider).value ?? const {}).entries) e.key: e.value.nomAffiche,
    };

    // Caisse physique de la boutique choisie (ou l'unique caisse).
    final caissesVisibles = etat.caisses
        .where((c) => c.estActive && (_site == null || c.perimetreId == _site))
        .toList();
    final caisse = widget.caisseIdSpecifique != null
        ? etat.caisses.where((c) => c.id == widget.caisseIdSpecifique).firstOrNull
        : (caissesVisibles.length == 1 ? caissesVisibles.single : null);
    final session = caisse == null ? null : etat.sessionOuverte(caisse.id);
    final derniereCloture = caisse == null
        ? null
        : (etat.sessions.where((s) => s.caisseId == caisse.id && !s.ouverte).toList()
                ..sort((a, b) => (b.fermeeLe ?? b.ouverteLe).compareTo(a.fermeeLe ?? a.ouverteLe)))
              .firstOrNull;

    final resume = service.resumePeriode(etat, _periode, perimetreId: _site);
    final comparaison = service.comparaisonPeriode(etat, _periode, perimetreId: _site);
    final alertes = service.alertes(etat, perimetreId: _site);
    final operations = service.historique(
      etat,
      filtre: _periode,
      recherche: _recherche,
      sens: _sens,
      mode: _mode,
      perimetreId: _site,
      nomsBoutiques: nomsSites,
      nomsContacts: contacts,
    );
    final aucuneOperation = etat.paiements.isEmpty && etat.mouvements.isEmpty;

    final statistiques = <Widget>[
      EvolutionTresorerieChart(
        points7j: service.evolution(etat, 7, perimetreId: _site),
        points30j: service.evolution(etat, 30, perimetreId: _site),
        points90j: service.evolution(etat, 90, perimetreId: _site),
      ),
      SoldesParModeCard(soldes: resume.soldesParMode, masque: _masque),
      if (comparaison != null) ComparaisonPeriodeCard(comp: comparaison, filtre: _periode, masque: _masque),
      RepartitionCard(
        lignes: service.repartition(etat, _periode, entrees: true, perimetreId: _site),
        entrees: true,
        masque: _masque,
      ),
      RepartitionCard(
        lignes: service.repartition(etat, _periode, entrees: false, perimetreId: _site),
        entrees: false,
        masque: _masque,
      ),
      MoyensPaiementCard(
        proportions: service.moyensPaiementEncaissement(etat, _periode, perimetreId: _site),
        masque: _masque,
      ),
      if (sites.length > 1 && _site == null)
        FluxBoutiquesCard(
          boutiques: service.fluxParBoutique(etat, _periode),
          masque: _masque,
          onSelectBoutique: (id) => setState(() => _site = id),
        ),
    ];

    return LayoutBuilder(
      builder: (context, contraintes) {
        final large = contraintes.maxWidth >= 840;
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
          children: [
            Text(l10n.cashScreenSubtitle, style: const TextStyle(color: AppColors.muted)),
            if (sites.length > 1 && widget.caisseIdSpecifique == null) ...[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String?>(
                key: const Key('caisse-boutique'),
                initialValue: _site,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.storefront_outlined), isDense: true),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.cashAllShops)),
                  for (final s in sites) DropdownMenuItem(value: s.id, child: Text(s.nom)),
                ],
                onChanged: (v) => setState(() => _site = v),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (alertes.isNotEmpty)
              AlertesTresorerieWidget(alertes: alertes, nomsCaisses: {for (final c in etat.caisses) c.id: c.nom}),
            SoldeDisponibleCard(
              total: resume.tresorerieTotale,
              especes: resume.soldeEspeces,
              masque: _masque,
              onMasquer: () => setState(() => _masque = !_masque),
              caisse: caisse,
              session: session,
              derniereCloture: derniereCloture,
              onOuvrir: droits.ouvrirCaisse && caisse != null ? () => _ouvrirCaisse(caisse) : null,
              onFermer: droits.cloturerCaisse && session != null
                  ? () => showClotureCaisseModal(context, etat: etat, session: session)
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            ResumePeriodeCard(
              filtre: _periode,
              resume: resume,
              masque: _masque,
              onFiltreChanged: (f) => setState(() => _periode = f),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (droits.encaisser)
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('caisse-action-ajouter'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      onPressed: () => _choisirSens(etat),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.cashAddOperation),
                    ),
                  ),
                if (droits.encaisser && droits.transferer) const SizedBox(width: AppSpacing.sm),
                if (droits.transferer)
                  OutlinedButton.icon(
                    key: const Key('caisse-action-transfert'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                    onPressed: () => showTransfertModal(context, etat: etat, perimetreIdParDefaut: _site),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(l10n.cashTransferTitle),
                  ),
              ],
            ),
            if (aucuneOperation) ...[
              const SizedBox(height: AppSpacing.xl),
              EmptyView(icon: Icons.savings_outlined, message: '${l10n.cashReadyTitle}\n${l10n.cashReadyMessage}'),
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              if (large)
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final s in statistiques)
                      SizedBox(width: (contraintes.maxWidth - AppSpacing.md * 3) / 2, child: s),
                  ],
                )
              else
                for (final s in statistiques)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: s,
                  ),
              const SizedBox(height: AppSpacing.md),
              _Historique(
                operations: operations,
                masque: _masque,
                sens: _sens,
                mode: _mode,
                nomsSites: nomsSites,
                multiSites: sites.length > 1 && _site == null,
                onRecherche: (v) => setState(() => _recherche = v),
                onSens: (v) => setState(() => _sens = v),
                onMode: (v) => setState(() => _mode = v),
                onOuvrir: (op) => showDetailOperationModal(context, etat: etat, operation: op),
              ),
            ],
          ],
        );
      },
    );
  }

  /// « + Ajouter » : d'abord deux choix clairs, entrée ou sortie.
  Future<void> _choisirSens(EtatFinances etat) async {
    final l10n = context.l10n;
    final sens = await showModalBottomSheet<SensPaiement>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('caisse-choix-entree'),
              leading: const CircleAvatar(
                backgroundColor: AppColors.positiveSoft,
                child: Icon(Icons.south_west_rounded, color: AppColors.positive),
              ),
              title: Text(l10n.cashIn, style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx, SensPaiement.entree),
            ),
            ListTile(
              key: const Key('caisse-choix-sortie'),
              leading: const CircleAvatar(
                backgroundColor: AppColors.negativeSoft,
                child: Icon(Icons.north_east_rounded, color: AppColors.negative),
              ),
              title: Text(l10n.cashOut, style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx, SensPaiement.sortie),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (sens == null || !mounted) return;
    await showNouvelleOperationModal(context, etat: etat, perimetreIdParDefaut: _site, sensInitial: sens);
  }

  Future<void> _ouvrirCaisse(Caisse caisse) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final controleur = TextEditingController();
    final fond = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${l10n.cashOpen} · ${caisse.nom}'),
        content: ChampMontant(
          controller: controleur,
          label: l10n.cashOpeningAmount,
          autofocus: true,
          obligatoire: false,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l10n.commonCancel)),
          FilledButton(
            key: const Key('caisse-ouvrir-confirmer'),
            onPressed: () => Navigator.pop(d, ChampMontant.lire(controleur.text) ?? 0),
            child: Text(l10n.cashOpen),
          ),
        ],
      ),
    );
    controleur.dispose();
    if (fond == null || !mounted) return;
    try {
      await ref.read(gererCaisseProvider).ouvrir(ctx, widget.etat, caisse, soldeInitial: fond);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    }
  }
}

/// Historique : recherche rapide, filtres légers, opérations par jour.
class _Historique extends StatelessWidget {
  const _Historique({
    required this.operations,
    required this.masque,
    required this.sens,
    required this.mode,
    required this.nomsSites,
    required this.multiSites,
    required this.onRecherche,
    required this.onSens,
    required this.onMode,
    required this.onOuvrir,
  });

  final List<OperationTresorerie> operations;
  final bool masque;
  final SensPaiement? sens;
  final ModePaiement? mode;
  final Map<String, String> nomsSites;
  final bool multiSites;
  final ValueChanged<String> onRecherche;
  final ValueChanged<SensPaiement?> onSens;
  final ValueChanged<ModePaiement?> onMode;
  final ValueChanged<OperationTresorerie> onOuvrir;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.cashOperationsHistory,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('caisse-recherche'),
          decoration: InputDecoration(
            hintText: l10n.cashSearchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
          ),
          onChanged: onRecherche,
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (valeur, texte) in [
                (null, l10n.cashFilterAll),
                (SensPaiement.entree, l10n.cashIncoming),
                (SensPaiement.sortie, l10n.cashOutgoing),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                  child: ChoiceChip(label: Text(texte), selected: sens == valeur, onSelected: (_) => onSens(valeur)),
                ),
              PopupMenuButton<ModePaiement?>(
                key: const Key('caisse-filtre-mode'),
                onSelected: onMode,
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(value: null, checked: mode == null, child: Text(l10n.cashFilterAll)),
                  for (final m in ModePaiement.values)
                    CheckedPopupMenuItem(value: m, checked: mode == m, child: Text(l10n.modePaiement(m))),
                ],
                child: Chip(
                  avatar: Icon(mode == null ? Icons.filter_list_rounded : iconeMode(mode!), size: 18),
                  label: Text(mode == null ? l10n.paymentMode : l10n.modePaiement(mode!)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (operations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              l10n.cashNoDataPeriod,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          )
        else
          for (final (i, op) in operations.indexed) ...[
            if (i == 0 || !_memeJour(operations[i - 1].date, op.date))
              Padding(
                padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.xs),
                child: Text(
                  l10n.date(op.date),
                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
                ),
              ),
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                key: Key('caisse-op-${op.id}'),
                onTap: () => onOuvrir(op),
                leading: CircleAvatar(
                  backgroundColor: op.origine == OrigineMouvement.transfert
                      ? AppColors.background
                      : (op.estEntree ? AppColors.positiveSoft : AppColors.negativeSoft),
                  foregroundColor: op.origine == OrigineMouvement.transfert
                      ? AppColors.muted
                      : (op.estEntree ? AppColors.positive : AppColors.negative),
                  child: Icon(iconeOrigine(op.origine), size: 20),
                ),
                title: Text(
                  op.libelle ?? l10n.origineMouvement(op.origine),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(op.date)),
                    if (op.libelle != null) l10n.origineMouvement(op.origine),
                    l10n.modePaiement(op.mode),
                    if (multiSites && op.perimetreId != null) nomsSites[op.perimetreId] ?? '',
                    if (op.enAttente) l10n.cashPending,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: masque
                    ? const Text('• • •')
                    : Montant(op.montant, signe: op.estEntree, barre: op.estAnnule || op.estRefuse || op.estAnnulation),
              ),
            ),
          ],
      ],
    );
  }

  static bool _memeJour(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
