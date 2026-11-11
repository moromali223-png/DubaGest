import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../providers/paiement_abonnement_providers.dart';
import '../widgets/reactivez_compte_bottom_sheet.dart';

/// PAGE 2 : Règlement de l'abonnement ou réabonnement DubaGest.
/// Responsabilité stricte : règlement sécurisé, sélection de la durée (1, 3, 6, 12 mois),
/// choix du moyen de paiement (Orange Money, LigdiCash), calcul automatique du total
/// d'après les tarifs serveurs et activation après confirmation effective.
/// NE MÉLANGE PAS LE CHOIX DE LA FORMULE AVEC LE PAIEMENT.
/// Interface 100% fidèle aux maquettes d'expiration / réabonnement.
class PaiementAbonnementPage extends ConsumerStatefulWidget {
  const PaiementAbonnementPage({super.key, this.initialPlanCode});

  final String? initialPlanCode;

  @override
  ConsumerState<PaiementAbonnementPage> createState() => _PaiementAbonnementPageState();
}

class _PaiementAbonnementPageState extends ConsumerState<PaiementAbonnementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialPlanCode != null && widget.initialPlanCode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(paiementAbonnementNotifierProvider.notifier).changerPlan(widget.initialPlanCode!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final ctxAsync = ref.watch(contexteSessionProvider);
    final paiementState = ref.watch(paiementAbonnementNotifierProvider);
    final paiementNotifier = ref.read(paiementAbonnementNotifierProvider.notifier);

    final bgColor = isDark ? const Color(0xFF111413) : const Color(0xFF141715);
    final cardBg = isDark ? const Color(0xFF181B1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cardBg,
        foregroundColor: textColor,
        centerTitle: false,
        title: Text(
          l10n.subscriptionPaymentTitle,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFA6A26B), // Teinte dorée cohérente
          unselectedLabelColor: mutedTextColor,
          indicatorColor: const Color(0xFFA6A26B),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(icon: const Icon(Icons.payment_rounded, size: 20), text: l10n.subscriptionPaymentTabPay),
            Tab(icon: const Icon(Icons.history_rounded, size: 20), text: l10n.subscriptionPaymentTabHistory),
          ],
        ),
      ),
      body: ctxAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFA6A26B))),
        error: (e, _) {
          final isNetwork = e.toString().contains('SocketException') ||
              e.toString().contains('Failed host lookup') ||
              e.toString().contains('ClientException');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                    size: 48,
                    color: isNetwork ? const Color(0xFFA6A26B) : Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isNetwork
                        ? 'Connexion Internet requise pour le paiement en ligne.\nVeuillez vérifier votre réseau.'
                        : 'Erreur de chargement de la session.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFA6A26B)),
                    onPressed: () => ref.refresh(contexteSessionProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.black),
                    label: const Text('Réessayer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
        data: (session) {
          final abonnement = session?.abonnement;
          final estExpire = abonnement == null ||
              abonnement.statut == 'EXPIRE' ||
              (abonnement.dateFin != null && abonnement.dateFin!.isBefore(DateTime.now()));

          return TabBarView(
            controller: _tabController,
            children: [
              // Onglet 1 : Formulaire fidèle aux maquettes d'expiration / réabonnement
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: ReactivezCompteBottomSheet(
                        initialPlanCode: widget.initialPlanCode ?? paiementState.planCodeCible,
                        startAtStep: estExpire ? 1 : 2,
                        isPageMode: true,
                      ),
                    ),
                  ),
                ),
              ),

              // Onglet 2 : Historique des transactions et renouvellements
              _buildHistoriqueTab(context, theme, isDark, paiementState, paiementNotifier, l10n),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoriqueTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    PaiementAbonnementState state,
    PaiementAbonnementNotifier notifier,
    dynamic l10n,
  ) {
    const cardBg = Color(0xFF1E211F);
    final borderColor = Colors.white.withValues(alpha: 0.08);
    const textColor = Colors.white;
    const mutedTextColor = Color(0xFFB0B7B3);

    if (state.chargementHistorique) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFA6A26B)));
    }

    if (state.historiqueTransactions.isEmpty && state.historiqueRenouvellements.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => notifier.chargerHistorique(),
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 56, color: mutedTextColor),
                  SizedBox(height: 12),
                  Text('Aucun historique de paiement pour le moment', style: TextStyle(color: mutedTextColor, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => notifier.chargerHistorique(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.historiqueRenouvellements.isNotEmpty) ...[
            Text(
              l10n.subscriptionRenewalsHistoryTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
            ),
            const SizedBox(height: 10),
            ...state.historiqueRenouvellements.map((ren) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFA6A26B).withValues(alpha: 0.15),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFFA6A26B), size: 20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ren.typeOperationLisible, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                      Text(
                        _currencyFormat.format(ren.montant),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFA6A26B)),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 3),
                      Text(
                        'Formule ${ren.nouveauPlanCode} (${ren.dureeMois} mois) • Valide jusqu\'au ${DateFormat('dd/MM/yyyy').format(ren.nouvelleDateFin)}',
                        style: const TextStyle(fontSize: 12, color: mutedTextColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(ren.createdAt),
                        style: const TextStyle(fontSize: 11, color: mutedTextColor),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],

          const Text(
            'Transactions bancaires & Mobile Money',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
          ),
          const SizedBox(height: 10),
          ...state.historiqueTransactions.map((tx) {
            final statut = tx.statut;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: statut.color.withValues(alpha: 0.12),
                  child: Icon(tx.prestataire.icone, color: tx.prestataire.couleurPrimaire, size: 20),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tx.prestataire.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                    Text(
                      _currencyFormat.format(tx.montant),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFA6A26B)),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Text(
                      'Formule ${tx.planCode} (${tx.dureeMois} mois) • Réf: ${tx.referenceInterne}',
                      style: const TextStyle(fontSize: 12, color: mutedTextColor),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statut.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statut.libelle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statut.color,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt),
                          style: const TextStyle(fontSize: 11, color: mutedTextColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
