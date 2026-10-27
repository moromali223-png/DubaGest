import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
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

/// Workspace Finance dédié au Vendeur — Centré sur la caisse et les encaissements :
/// - Caisse physique de sa boutique (Session active, Solde espèces, Ouverture/Clôture)
/// - Encaissements de la journée ventilés par mode de règlement
/// - Accès direct aux créances clients (crédits à relancer/solder) et aux reçus de paiement
/// - Sans exposition des données stratégiques d'entreprise (comptes bancaires, marges, DAF).
class WorkspaceFinancesVendeur extends ConsumerStatefulWidget {
  const WorkspaceFinancesVendeur({super.key});

  @override
  ConsumerState<WorkspaceFinancesVendeur> createState() => _WorkspaceFinancesVendeurState();
}

class _WorkspaceFinancesVendeurState extends ConsumerState<WorkspaceFinancesVendeur> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final etatFinances = ref.watch(etatFinancesProvider).value;
    final etatCommerce = ref.watch(etatCommerceProvider).value;
    final espace = ref.watch(espaceCourantProvider);
    final devise = ref.watch(deviseProvider);
    final droits = ref.watch(droitsFinancesProvider);

    if (ctx == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C1412),
        body: LoadingView(),
      );
    }

    final prenom = ctx.nomComplet?.split(' ').first ?? 'Vendeur';
    final boutiqueCouranteId = espace.perimetreId ?? ref.watch(boutiqueCouranteProvider);
    final nomBoutiqueAffichee = boutiqueCouranteId != null
        ? nomBoutique(ref, boutiqueCouranteId)
        : (ctx.perimetres.where((p) => p.activite == espace.activite).firstOrNull?.nom ?? 'Boutique');

    // Détection de la caisse de la boutique
    final caisses = etatFinances?.caisses ?? const <Caisse>[];
    final caisseBoutique = boutiqueCouranteId != null
        ? caisses.where((c) => c.estActive && c.perimetreId == boutiqueCouranteId).firstOrNull
        : (caisses.where((c) => c.estActive).firstOrNull);

    final session = (caisseBoutique == null || etatFinances == null)
        ? null
        : etatFinances.sessionOuverte(caisseBoutique.id);

    // Calcul des ventes et encaissements du jour pour ce point de vente
    final now = DateTime.now();
    final debutJour = DateTime(now.year, now.month, now.day);
    final finJour = debutJour.add(const Duration(days: 1));

    final ventesToutes = etatCommerce?.ventes ?? const <Vente>[];
    final ventesBoutique = ventesToutes.where((v) {
      if (boutiqueCouranteId != null && v.perimetreId != boutiqueCouranteId) return false;
      return !v.annulee;
    }).toList();

    final ventesJour = ventesBoutique.where((v) {
      return v.date.isAfter(debutJour) && v.date.isBefore(finJour);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    int totalEncaisseJour = 0;
    int especes = 0;
    int mobileMoney = 0;
    int carte = 0;
    int credit = 0;

    for (final v in ventesJour) {
      if (v.reglement == ReglementVente.credit || (v.montantPaye < v.total && v.montantPaye == 0)) {
        credit += v.total;
      } else {
        totalEncaisseJour += v.montantPaye > 0 ? v.montantPaye : v.total;
        final mode = (v.modePaiement ?? '').toUpperCase();
        if (mode.contains('MOBILE') || mode.contains('ORANGE') || mode.contains('WAVE') || mode.contains('MOOV')) {
          mobileMoney += v.total;
        } else if (mode.contains('CARTE') || mode.contains('CARD')) {
          carte += v.total;
        } else {
          especes += v.total;
        }
      }
    }

    final formatHeure = DateFormat.Hm(Localizations.localeOf(context).toString());
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
              child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF2ECC71), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Point de Caisse',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 17),
                  ),
                  Text(
                    nomBoutiqueAffichee,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFA5B8B1), fontWeight: FontWeight.w500),
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
        maxWidth: 760,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(etatFinancesProvider);
            ref.invalidate(etatCommerceProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
            children: [
              // 1. Salutation & Date du jour
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour, $prenom 👋',
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
                  const SizedBox(width: AppSpacing.sm),
                  // Badge Boutique Active
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

              // 2. Carte Session de Caisse Active / Fermée
              _CarteSessionCaisseVendeur(
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

              // 3. Encaissements de la journée (Répartition claire)
              _SectionEncaissementsJour(
                total: totalEncaisseJour,
                especes: especes,
                mobileMoney: mobileMoney,
                carte: carte,
                credit: credit,
                devise: devise,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. Modules autorisés pour le vendeur (Ma Caisse, Créances, Paiements)
              const AccesModulesFinances(),
              const SizedBox(height: AppSpacing.lg),

              // 5. Derniers encaissements réalisés
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Derniers encaissements',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(Routes.financesOnglet(ModuleCodes.financesPaiements)),
                    child: const Text('Voir tout', style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              if (ventesJour.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141E1B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF223830)),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.point_of_sale_rounded, color: Color(0xFF5A756D), size: 36),
                        SizedBox(height: 10),
                        Text(
                          'Aucun encaissement aujourd’hui',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Les règlements de vos ventes s’afficheront automatiquement ici.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFA5B8B1), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...ventesJour.take(6).map((v) {
                  final estCredit = v.reglement == ReglementVente.credit;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141E1B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF223830)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: estCredit
                            ? AppColors.dette.withValues(alpha: 0.18)
                            : const Color(0xFF1E7E4E).withValues(alpha: 0.2),
                        child: Icon(
                          estCredit ? Icons.schedule_rounded : Icons.arrow_downward_rounded,
                          color: estCredit ? AppColors.dette : const Color(0xFF2ECC71),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        v.numero ?? 'Vente',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${formatHeure.format(v.date)} · ${estCredit ? 'Vente à crédit' : (v.modePaiement ?? 'Espèces')}',
                        style: const TextStyle(color: Color(0xFFA5B8B1), fontSize: 12),
                      ),
                      trailing: Text(
                        '${l10n.nombre(v.total)} $devise',
                        style: TextStyle(
                          color: estCredit ? AppColors.dette : const Color(0xFF2ECC71),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        if (v.paiementId != null) {
                          context.push(Routes.paiement(v.paiementId!));
                        } else {
                          context.push(Routes.ventes);
                        }
                      },
                    ),
                  );
                }),
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

/// Carte Statut Session de Caisse Vendeur
class _CarteSessionCaisseVendeur extends StatelessWidget {
  const _CarteSessionCaisseVendeur({
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
    final estOuverte = session != null;
    final formatHeure = DateFormat.Hm(Localizations.localeOf(context).toString());
    final solde = session?.soldeTheorique ?? session?.soldeInitial ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF141E1B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: estOuverte ? const Color(0xFF1E7E4E) : const Color(0xFF223830),
          width: 1.5,
        ),
        boxShadow: [
          if (estOuverte)
            BoxShadow(
              color: const Color(0xFF1E7E4E).withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      boxShadow: [
                        BoxShadow(
                          color: (estOuverte ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C)).withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    estOuverte ? 'Caisse ouverte' : 'Caisse fermée',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: estOuverte ? const Color(0xFF2ECC71) : const Color(0xFFA5B8B1),
                    ),
                  ),
                ],
              ),
              if (caisse != null)
                Flexible(
                  child: Text(
                    caisse!.nom,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFA5B8B1), fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          if (estOuverte) ...[
            Text(
              '${l10n.nombre(solde)} $devise',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Solde théorique en espèces (Ouverte à ${formatHeure.format(session!.ouverteLe)} · Fond: ${l10n.nombre(session!.soldeInitial)} $devise)',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFA5B8B1)),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (onFermer != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE74C3C),
                        side: const BorderSide(color: Color(0xFFE74C3C)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onFermer,
                      icon: const Icon(Icons.lock_clock_rounded, size: 16),
                      label: const Text('Clôturer la caisse', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                if (onMouvement != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E7E4E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onMouvement,
                    icon: const Icon(Icons.swap_vert_rounded, size: 18),
                    label: const Text('Entrée/Sortie', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            const Text(
              'Prêt pour le service ? Ouvrez votre session de caisse pour commencer à enregistrer les encaissements.',
              style: TextStyle(fontSize: 13, color: Color(0xFFA5B8B1), height: 1.3),
            ),
            const SizedBox(height: AppSpacing.md),
            if (onOuvrir != null)
              FilledButton.icon(
                key: const Key('btn-ouvrir-caisse-vendeur'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: const Color(0xFF0C1412),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onOuvrir,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Ouvrir la session de caisse', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
          ],
        ],
      ),
    );
  }
}

/// Récapitulatif visuel des encaissements de la journée
class _SectionEncaissementsJour extends StatelessWidget {
  const _SectionEncaissementsJour({
    required this.total,
    required this.especes,
    required this.mobileMoney,
    required this.carte,
    required this.credit,
    required this.devise,
  });

  final int total;
  final int especes;
  final int mobileMoney;
  final int carte;
  final int credit;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF141E1B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF223830)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Encaissements du jour',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E7E4E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${l10n.nombre(total)} $devise',
                  style: const TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _TuileModePaiement(
                  icone: Icons.payments_rounded,
                  titre: 'Espèces',
                  montant: '${l10n.nombre(especes)} $devise',
                  couleur: const Color(0xFF2ECC71),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TuileModePaiement(
                  icone: Icons.phone_android_rounded,
                  titre: 'Mobile Money',
                  montant: '${l10n.nombre(mobileMoney)} $devise',
                  couleur: const Color(0xFFDF9540),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _TuileModePaiement(
                  icone: Icons.credit_card_rounded,
                  titre: 'Carte / Banque',
                  montant: '${l10n.nombre(carte)} $devise',
                  couleur: const Color(0xFF3498DB),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TuileModePaiement(
                  icone: Icons.schedule_rounded,
                  titre: 'À crédit',
                  montant: '${l10n.nombre(credit)} $devise',
                  couleur: AppColors.dette,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TuileModePaiement extends StatelessWidget {
  const _TuileModePaiement({
    required this.icone,
    required this.titre,
    required this.montant,
    required this.couleur,
  });

  final IconData icone;
  final String titre;
  final String montant;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1412),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF223830)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icone, color: couleur, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFA5B8B1), fontWeight: FontWeight.w600),
                ),
                Text(
                  montant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
