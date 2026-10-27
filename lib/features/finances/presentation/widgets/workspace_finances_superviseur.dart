import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/kpi_card.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../commerce/domain/entities/commerce.dart';
import '../../../commerce/presentation/commerce_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../domain/entities/caisse_tresorerie_models.dart';
import '../../domain/entities/finances.dart';
import '../../domain/services/etat_finances.dart';
import '../../domain/usecases/gerer_finances.dart';
import '../pages/finances_page.dart';
import '../providers/finances_providers.dart';
import 'caisse_dialogs.dart';
import 'finances_widgets.dart';

/// Espace Finances dédié au Superviseur de Boutique.
///
/// Adapté strictement à ses prérogatives opérationnelles de gestion de boutique :
/// - Caisse de sa boutique (ouverture, clôture, mouvements espèces/mobile)
/// - Dépenses opérationnelles de la boutique (saisie et historique)
/// - Créances & Dettes clients de la boutique (suivi des impayés et recouvrement)
/// - Encaissements et reçus de paiement de la boutique
///
/// Toutes les données sont scrupuleusement restreintes à son périmètre boutique.
/// Aucun accès aux comptes bancaires corporate, consolidation groupe ou DAF.
class WorkspaceFinancesSuperviseur extends ConsumerStatefulWidget {
  const WorkspaceFinancesSuperviseur({super.key});

  @override
  ConsumerState<WorkspaceFinancesSuperviseur> createState() => _WorkspaceFinancesSuperviseurState();
}

class _WorkspaceFinancesSuperviseurState extends ConsumerState<WorkspaceFinancesSuperviseur> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final etatFinances = ref.watch(etatFinancesProvider).value;
    final etatCommerce = ref.watch(etatCommerceProvider).value;
    final espace = ref.watch(espaceCourantProvider);
    final devise = ref.watch(deviseProvider);
    final unite = devise == 'XOF' ? 'FCFA' : devise;
    final droits = ref.watch(droitsFinancesProvider);

    if (ctx == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C1412),
        body: LoadingView(),
      );
    }

    final prenom = ctx.nomComplet?.split(' ').first ?? 'Superviseur';
    final boutiqueCouranteId = espace.perimetreId ?? ref.watch(boutiqueCouranteProvider);
    final nomBoutiqueAffichee = boutiqueCouranteId != null
        ? nomBoutique(ref, boutiqueCouranteId)
        : (ctx.perimetres.where((p) => p.activite == espace.activite).firstOrNull?.nom ?? 'Boutique');

    // Caisse de la boutique
    final caisses = etatFinances?.caisses ?? const <Caisse>[];
    final caisseBoutique = boutiqueCouranteId != null
        ? caisses.where((c) => c.estActive && c.perimetreId == boutiqueCouranteId).firstOrNull
        : (caisses.where((c) => c.estActive).firstOrNull);

    final session = (caisseBoutique == null || etatFinances == null)
        ? null
        : etatFinances.sessionOuverte(caisseBoutique.id);

    // Date & filtres
    final now = DateTime.now();
    final debutJour = DateTime(now.year, now.month, now.day);
    final finJour = debutJour.add(const Duration(days: 1));

    bool estCeJour(DateTime d) => d.isAfter(debutJour) && d.isBefore(finJour);

    // 1. Encaissements du jour
    final paiementsJour = [
      if (etatFinances != null)
        for (final p in etatFinances.paiements)
          if (!p.refuse && !p.estAnnulation && p.sens == SensPaiement.entree && estCeJour(p.datePaiement))
            if (boutiqueCouranteId == null || p.perimetreId == boutiqueCouranteId) p,
    ];
    final totalEncaisseJour = paiementsJour.fold<int>(0, (s, p) => s + p.montant);

    // 2. Dépenses du jour de la boutique
    final depensesJour = [
      if (etatFinances != null)
        for (final d in etatFinances.depenses)
          if (!d.refusee && estCeJour(d.dateDepense))
            if (boutiqueCouranteId == null || d.perimetreId == boutiqueCouranteId) d,
    ];
    final totalDepensesJour = depensesJour.fold<int>(0, (s, d) => s + d.montant);

    // 3. Créances clients de la boutique (engagements à recevoir)
    final creancesBoutique = [
      if (etatFinances != null)
        for (final e in etatFinances.engagements)
          if (!e.refuse && e.sens == SensEngagement.aRecevoir)
            if (boutiqueCouranteId == null || e.perimetreId == boutiqueCouranteId) e,
    ];
    final totalCreancesReste = creancesBoutique.fold<int>(
      0,
      (s, e) => s + (etatFinances?.suivi(e).reste ?? e.montantTotal),
    );

    // Solde net de la boutique ce jour
    final soldeNetJour = totalEncaisseJour - totalDepensesJour;

    String fmt(int montant) => l10n.nombre(montant);
    final formatDate = DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString());

    return Scaffold(
      backgroundColor: const Color(0xFF0C1412),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1412),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E7E4E).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2ECC71), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Finances Boutique',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 17),
                  ),
                  Text(
                    nomBoutiqueAffichee,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFA5B8B1), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: const [
          SyncStatusButton(),
        ],
      ),
      body: ResponsiveBody(
        maxWidth: 820,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(etatFinancesProvider);
            ref.invalidate(etatCommerceProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
            children: [
              // 1. En-tête Salutation & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour, $prenom ',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatDate.format(now),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFA5B8B1),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141E1B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF223830)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF2ECC71)),
                        const SizedBox(width: 6),
                        Text(
                          nomBoutiqueAffichee,
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // 2. Carte Session de Caisse de la boutique
              _CarteSessionCaisseSuperviseur(
                caisse: caisseBoutique,
                session: session,
                devise: devise,
                droits: droits,
                onOuvrir: (caisseBoutique != null && droits.ouvrirCaisse && etatFinances != null)
                    ? () => _ouvrirCaisse(caisseBoutique, etatFinances)
                    : null,
                onFermer: (session != null && droits.cloturerCaisse && etatFinances != null)
                    ? () => showClotureCaisseModal(context, etat: etatFinances, session: session)
                    : null,
                onMouvement: (session != null && droits.mouvementerCaisse && etatFinances != null)
                    ? () => _choisirSens(etatFinances, caisseBoutique?.perimetreId)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. Les 4 KPI Financiers Opérationnels de la boutique
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.34,
                children: [
                  KpiCard(
                    label: 'Encaissé ce jour',
                    value: fmt(totalEncaisseJour),
                    unit: unite,
                    tone: KpiTone.primary,
                    trend: KpiTrend(
                      '• ${paiementsJour.length} encaissement(s)',
                      paiementsJour.isNotEmpty ? KpiTrendKind.good : KpiTrendKind.neutral,
                    ),
                    onTap: () => context.push(Routes.financesOnglet(ModuleCodes.financesPaiements)),
                  ),
                  KpiCard(
                    label: 'Dépenses du jour',
                    value: fmt(totalDepensesJour),
                    unit: unite,
                    tone: KpiTone.dark,
                    trend: KpiTrend(
                      '• ${depensesJour.length} dépense(s)',
                      depensesJour.isNotEmpty ? KpiTrendKind.neutral : KpiTrendKind.good,
                    ),
                    onTap: () => context.push(Routes.financesOnglet(ModuleCodes.financesDepenses)),
                  ),
                  KpiCard(
                    label: 'Créances clients',
                    value: fmt(totalCreancesReste),
                    unit: unite,
                    tone: KpiTone.light,
                    trend: KpiTrend(
                      totalCreancesReste > 0 ? '• À recouvrer' : '• À jour',
                      totalCreancesReste > 0 ? KpiTrendKind.bad : KpiTrendKind.good,
                    ),
                    onTap: () => context.push(Routes.financesOnglet(ModuleCodes.financesCreances)),
                  ),
                  KpiCard(
                    label: 'Solde net du jour',
                    value: fmt(soldeNetJour),
                    unit: unite,
                    tone: KpiTone.light,
                    trend: KpiTrend(
                      soldeNetJour >= 0 ? '• Bénéficiaire' : '• Déficitaire',
                      soldeNetJour >= 0 ? KpiTrendKind.good : KpiTrendKind.bad,
                    ),
                    onTap: () => context.push(Routes.financesOnglet(ModuleCodes.financesCaisse)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. Actions rapides Superviseur
              const Text(
                'Actions Rapides Finance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ActionBoutonFinance(
                      icon: Icons.payments_outlined,
                      label: '+ Saisie Dépense',
                      color: AppColors.negative,
                      onTap: () => context.push(Routes.depenseNouvelle),
                    ),
                    const SizedBox(width: 8),
                    _ActionBoutonFinance(
                      icon: Icons.point_of_sale_rounded,
                      label: 'Caisse Boutique',
                      color: const Color(0xFF2ECC71),
                      onTap: () => context.push(Routes.financesOnglet(ModuleCodes.financesCaisse)),
                    ),
                    const SizedBox(width: 8),
                    _ActionBoutonFinance(
                      icon: Icons.request_page_outlined,
                      label: 'Recouvrer Créance',
                      color: const Color(0xFF7C3AED),
                      onTap: () => context.push(Routes.financesOnglet(ModuleCodes.financesCreances)),
                    ),
                    const SizedBox(width: 8),
                    _ActionBoutonFinance(
                      icon: Icons.receipt_long_rounded,
                      label: 'Reçus de Paiement',
                      color: const Color(0xFF0284C7),
                      onTap: () => context.push(Routes.financesOnglet(ModuleCodes.financesPaiements)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 5. Modules autorisés pour le superviseur
              const AccesModulesFinances(),
              const SizedBox(height: AppSpacing.lg),

              // 6. Dernières dépenses de la boutique
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Dernières dépenses boutique',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(Routes.financesOnglet(ModuleCodes.financesDepenses)),
                    child: const Text('Voir tout →', style: TextStyle(color: Color(0xFF2ECC71), fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (depensesJour.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141E1B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF223830)),
                  ),
                  child: const Center(
                    child: Text(
                      'Aucune dépense enregistrée aujourd\'hui pour cette boutique.',
                      style: TextStyle(color: Color(0xFFA5B8B1), fontSize: 13),
                    ),
                  ),
                )
              else
                ...depensesJour.take(5).map((d) => _TileDepenseSuperviseur(depense: d, unite: unite, fmt: fmt)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrirCaisse(Caisse caisse, EtatFinances etat) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final controleur = TextEditingController();
    final fond = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF141E1B),
        title: Text('${l10n.cashOpen} · ${caisse.nom}', style: const TextStyle(color: Colors.white)),
        content: ChampMontant(
          controller: controleur,
          label: l10n.cashOpeningAmount,
          autofocus: true,
          obligatoire: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(l10n.commonCancel, style: const TextStyle(color: Color(0xFFA5B8B1))),
          ),
          FilledButton(
            key: const Key('caisse-ouvrir-confirmer'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
            onPressed: () => Navigator.pop(d, ChampMontant.lire(controleur.text) ?? 0),
            child: Text(l10n.cashOpen, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    controleur.dispose();
    if (fond == null || !mounted) return;
    try {
      await ref.read(gererCaisseProvider).ouvrir(ctx, etat, caisse, soldeInitial: fond);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    }
  }

  Future<void> _choisirSens(EtatFinances etat, String? perimetreId) async {
    final l10n = context.l10n;
    final sens = await showModalBottomSheet<SensPaiement>(
      context: context,
      backgroundColor: const Color(0xFF141E1B),
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
              title: Text(l10n.cashIn, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              onTap: () => Navigator.pop(ctx, SensPaiement.entree),
            ),
            ListTile(
              key: const Key('caisse-choix-sortie'),
              leading: const CircleAvatar(
                backgroundColor: AppColors.negativeSoft,
                child: Icon(Icons.north_east_rounded, color: AppColors.negative),
              ),
              title: Text(l10n.cashOut, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              onTap: () => Navigator.pop(ctx, SensPaiement.sortie),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (sens == null || !mounted) return;
    await showNouvelleOperationModal(context, etat: etat, perimetreIdParDefaut: perimetreId, sensInitial: sens);
  }
}

class _CarteSessionCaisseSuperviseur extends StatelessWidget {
  const _CarteSessionCaisseSuperviseur({
    required this.caisse,
    required this.session,
    required this.devise,
    required this.droits,
    this.onOuvrir,
    this.onFermer,
    this.onMouvement,
  });

  final Caisse? caisse;
  final SessionCaisse? session;
  final String devise;
  final DroitsFinances droits;
  final VoidCallback? onOuvrir;
  final VoidCallback? onFermer;
  final VoidCallback? onMouvement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unite = devise == 'XOF' ? 'FCFA' : devise;
    final estOuverte = session != null;
    final solde = session?.soldeTheorique ?? session?.soldeInitial ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141E1B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: estOuverte ? const Color(0xFF1E7E4E).withValues(alpha: 0.5) : const Color(0xFF223830),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: estOuverte ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    estOuverte ? 'Caisse ouverte' : 'Caisse fermée',
                    style: TextStyle(
                      color: estOuverte ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (caisse != null)
                Text(
                  caisse!.nom,
                  style: const TextStyle(color: Color(0xFFA5B8B1), fontSize: 12, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.nombre(solde),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Solde théorique en caisse ($unite)',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFFA5B8B1), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!estOuverte && onOuvrir != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onOuvrir,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E7E4E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 16),
                    label: const Text('Ouvrir la caisse', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              if (estOuverte) ...[
                if (onMouvement != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMouvement,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF2E453D)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF2ECC71)),
                      label: const Text('Mouvement', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onFermer != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onFermer,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE74C3C),
                        side: const BorderSide(color: Color(0xFF4A2525)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(Icons.lock_rounded, size: 16),
                      label: const Text('Clôturer', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBoutonFinance extends StatelessWidget {
  const _ActionBoutonFinance({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileDepenseSuperviseur extends StatelessWidget {
  const _TileDepenseSuperviseur({
    required this.depense,
    required this.unite,
    required this.fmt,
  });

  final Depense depense;
  final String unite;
  final String Function(int) fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141E1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223830)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.negative.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_upward_rounded, color: AppColors.negative, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  depense.libelle,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  depense.beneficiaire ?? 'Dépense courante',
                  style: const TextStyle(color: Color(0xFFA5B8B1), fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '- ${fmt(depense.montant)} $unite',
            style: const TextStyle(
              color: AppColors.negative,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
