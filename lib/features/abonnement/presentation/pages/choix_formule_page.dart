import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../providers/catalogue_plans_provider.dart';

/// PAGE 1 : Choix de la formule d'abonnement DubaGest.
/// Responsabilité stricte : présentation exhaustive des formules (Normal, Moyen, Pro),
/// prix de référence, quotas, activités autorisées, modules inclus, avantages et
/// validation du choix vers la Page 2 de règlement.
/// RÈGLE ABSOLUE : AUCUN PAIEMENT N'EST DÉCLENCHÉ SUR CETTE PAGE.
class ChoixFormulePage extends ConsumerStatefulWidget {
  const ChoixFormulePage({super.key});

  @override
  ConsumerState<ChoixFormulePage> createState() => _ChoixFormulePageState();
}

class _ChoixFormulePageState extends ConsumerState<ChoixFormulePage> {
  String? _formuleSelectionnee;
  final _currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    final plansAsync = ref.watch(cataloguePlansProvider);

    final planActuelCode = ctx?.abonnement?.planCode ?? 'NORMAL';
    _formuleSelectionnee ??= planActuelCode;

    final abo = ctx?.abonnement;
    final estEssai = abo?.statut == 'ESSAI';
    final estExpire = abo == null ||
        abo.statut == 'EXPIRE' ||
        (abo.dateFin != null && abo.dateFin!.isBefore(DateTime.now()));

    final bgColor = isDark ? const Color(0xFF111413) : const Color(0xFFF7F9F8);
    final cardBg = isDark ? const Color(0xFF1B1F1D) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C3330) : const Color(0xFFE2E8E5);
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
          l10n.subscriptionChoosePlanTitle,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
        ),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) {
          final isNetwork = e.toString().contains('SocketException') ||
              e.toString().contains('Failed host lookup') ||
              e.toString().contains('ClientException') ||
              e.toString().contains('Network');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                    size: 48,
                    color: isNetwork ? Colors.amber.shade700 : Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isNetwork
                        ? 'Connexion Internet non disponible.\nVeuillez vous connecter à Internet pour consulter et renouveler les offres en ligne.'
                        : 'Impossible de charger le catalogue des offres.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () => ref.refresh(cataloguePlansProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (plans) {
          if (plans.isEmpty) {
            return const Center(child: Text('Aucune formule disponible actuellement.'));
          }

          final planChoisi = plans.firstWhere(
            (p) => p.code == _formuleSelectionnee,
            orElse: () => plans.first,
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  // 1. Bannière contextuelle d'état (Période d'essai 10j, Expiré ou Renouvellement)
                  _buildBanniereContextuelle(context, isDark, estEssai, estExpire, abo?.dateFin, l10n),
                  const SizedBox(height: 20),

                  // 2. En-tête explicatif
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.subscriptionChoosePlanSubtitle,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l10n.subscriptionDataSafeNotice,
                              style: TextStyle(fontSize: 12, color: mutedTextColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Liste détaillée des cartes de formules (Normal, Moyen, Pro)
                  ...plans.map((p) {
                    final isSelected = p.code == _formuleSelectionnee;
                    final isCurrent = p.code == planActuelCode && !estExpire;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: isSelected ? 14 : 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => setState(() => _formuleSelectionnee = p.code),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // En-tête de la formule : Nom, Badge, Tarif mensuel
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              p.nom,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? AppColors.primarySoft
                                                    : (isDark ? const Color(0xFF262C2A) : const Color(0xFFEEF2F0)),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                p.badgeLibelle,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected ? AppColors.primary : mutedTextColor,
                                                ),
                                              ),
                                            ),
                                            if (isCurrent) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50.withValues(alpha: isDark ? 0.2 : 1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.blue.shade300),
                                                ),
                                                child: Text(
                                                  l10n.subscriptionCurrentPlan,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (p.description.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            p.description,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: mutedTextColor,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _currencyFormat.format(p.prixMensuel),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? AppColors.primary : textColor,
                                        ),
                                      ),
                                      Text(
                                        '/ mois',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: mutedTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Divider(height: 28, color: borderColor),

                              // Quotas majeurs (Utilisateurs, Boutiques/sites, Activités, Modules)
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _buildBadge(
                                    isDark,
                                    Icons.people_outline_rounded,
                                    p.maxUtilisateursCommerce == null
                                        ? 'Utilisateurs illimités'
                                        : '${p.maxUtilisateursCommerce} utilisateur(s) inclus',
                                  ),
                                  _buildBadge(
                                    isDark,
                                    Icons.storefront_outlined,
                                    p.maxBoutiquesCommerce == null
                                        ? 'Boutiques & Agences illimitées'
                                        : '${p.maxBoutiquesCommerce} boutique(s) / site(s)',
                                  ),
                                  _buildBadge(
                                    isDark,
                                    Icons.layers_outlined,
                                    '${p.maxActivites} activité(s) autorisée(s)',
                                  ),
                                  _buildBadge(
                                    isDark,
                                    Icons.dashboard_customize_outlined,
                                    '${p.modules.length} modules complets inclus',
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Secteurs d'activités autorisés
                              if (p.libellesActivites.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Text(
                                      'Activités disponibles : ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: mutedTextColor,
                                      ),
                                    ),
                                    Text(
                                      p.libellesActivites.join(' • '),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey.shade300 : AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Points forts et avantages détaillés
                              Text(
                                'Inclus dans la formule :',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...p.pointsForts.map(
                                (pt) => Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          pt,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  // 4. Validation du choix et passage à la Page 2 (Règlement)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 10,
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
                            Text(
                              l10n.subscriptionSelectedPlan,
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${planChoisi.nom} — ${_currencyFormat.format(planChoisi.prixMensuel)}/mois',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            // Validation : Redirection nette vers la Page 2 (Règlement)
                            // AUCUN PAIEMENT N'EST DÉCLENCHÉ SUR CETTE PAGE 1.
                            context.push('${Routes.reglementAbonnement}?plan=${planChoisi.code}');
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                          label: Text(
                            '${l10n.subscriptionValidatePlanButton} (${planChoisi.nom})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            l10n.subscriptionNoPaymentTriggered,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: mutedTextColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadge(bool isDark, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232927) : const Color(0xFFF1F5F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF333B38) : const Color(0xFFE2E8E5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade300 : AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanniereContextuelle(
    BuildContext context,
    bool isDark,
    bool estEssai,
    bool estExpire,
    DateTime? dateFin,
    dynamic l10n,
  ) {
    if (estExpire) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50.withValues(alpha: isDark ? 0.2 : 1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.red.shade800 : Colors.red.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100.withValues(alpha: isDark ? 0.3 : 1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, color: isDark ? Colors.red.shade300 : Colors.red.shade900, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.subscriptionExpiredTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.subscriptionExpiredDesc,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.red.shade300 : Colors.red.shade900,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (estEssai) {
      final jours = dateFin != null ? dateFin.difference(DateTime.now()).inDays : 0;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primarySoft.withValues(alpha: isDark ? 0.2 : 1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_outlined, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.subscriptionTrialActiveTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    jours > 0
                        ? l10n.subscriptionTrialRemainingDays(jours)
                        : l10n.subscriptionTrialEndedDesc,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final joursRestants = dateFin != null ? dateFin.difference(DateTime.now()).inDays : 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50.withValues(alpha: isDark ? 0.2 : 1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.green.shade800 : Colors.green.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade100.withValues(alpha: isDark ? 0.3 : 1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline, color: isDark ? Colors.green.shade300 : Colors.green.shade900, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abonnement actif',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.green.shade200 : Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  joursRestants > 0
                      ? l10n.subscriptionActiveRemaining(joursRestants)
                      : 'Choisissez une formule pour renouveler votre abonnement.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.green.shade300 : Colors.green.shade900,
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
