import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/paiement_abonnement.dart';
import '../providers/catalogue_plans_provider.dart';
import '../providers/paiement_abonnement_providers.dart';

/// Modal Bottom Sheet & Vue UI/UX fidèle aux maquettes utilisateur :
/// "Réactivez votre compte pour continuer"
/// Gère :
/// 1. Écran d'accueil de réactivation (Image 1 : Souscrire maintenant / Se déconnecter).
/// 2. Écran de sélection de durée (Image 2 : Cartes avec radio, durée, prix FCFA et badges droits).
/// 3. Écran de choix d'opérateur Mobile Money (Orange Money, LigdiCash) et confirmation sécurisée.
class ReactivezCompteBottomSheet extends ConsumerStatefulWidget {
  const ReactivezCompteBottomSheet({
    super.key,
    this.initialPlanCode,
    this.startAtStep = 1,
    this.isPageMode = false,
    this.onClose,
  });

  /// Code du plan sélectionné (ex: NORMAL, MOYEN, PRO)
  final String? initialPlanCode;

  /// Étape de départ (1: Image 1, 2: Image 2 direct)
  final int startAtStep;

  /// Vrai si affiché en tant que page plein écran ou faux si bottom-sheet modal
  final bool isPageMode;

  /// Callback de fermeture
  final VoidCallback? onClose;

  /// Ouvre la bottom sheet en modal au-dessus de l'application
  static Future<void> show(
    BuildContext context, {
    String? initialPlanCode,
    int startAtStep = 1,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => ReactivezCompteBottomSheet(
        initialPlanCode: initialPlanCode,
        startAtStep: startAtStep,
        isPageMode: false,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  ConsumerState<ReactivezCompteBottomSheet> createState() => _ReactivezCompteBottomSheetState();
}

class _ReactivezCompteBottomSheetState extends ConsumerState<ReactivezCompteBottomSheet> {
  late int _currentStep;
  late int _selectedDurationMonths;
  final TextEditingController _telephoneController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  // Palette officielle DubaGest : Vert Émeraude (#1E7E4E) & Ardoise Sombre (#141A17)
  static const Color _sheetBg = Color(0xFF141A17); // Ardoise très sombre élégante
  static const Color _cardBg = Color(0xFF1B2420); // Surface sombre
  static const Color _cardSelectedBg = Color(0xFF1F3029); // Surface sélectionnée rehaussée
  static const Color _badgeBg = Color(0xFF101614); // Badge sobre
  static const Color _primaryGreen = Color(0xFF1E7E4E); // Vert Émeraude DubaGest officiel
  static const Color _primaryGreenDark = Color(0xFF15633D); // Vert foncé
  static const Color _primaryGreenLight = Color(0xFF2ECC71); // Vert éclatant
  static const Color _primaryGreenSoft = Color(0xFFE8F5EE); // Vert clair
  static const Color _dangerRed = Color(0xFFEF4444); // Rouge déconnexion / annuler
  static const Color _goldYellow = Color(0xFFA6A26B); // Teinte dorée / alerte
  static const Color _textWhite = Colors.white;
  static const Color _textMuted = Color(0xFFA5B8B1); // Teinte onInkMuted DubaGest

  String _formaterMontant(int montant) {
    final formatte = NumberFormat('#,##0', 'fr_FR').format(montant).replaceAll(',', ' ');
    return '$formatte FCFA';
  }

  @override
  void initState() {
    super.initState();
    _currentStep = widget.startAtStep;
    _selectedDurationMonths = 1; // 1 mois par défaut (en 1ère position)

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final code = widget.initialPlanCode;
      if (code != null && code.isNotEmpty) {
        ref.read(paiementAbonnementNotifierProvider.notifier).changerPlan(code);
      }
      ref.read(paiementAbonnementNotifierProvider.notifier).changerPrestataire(PrestatairePaiement.ligdiCash);
      ref.read(paiementAbonnementNotifierProvider.notifier).changerDuree(_selectedDurationMonths);
    });
  }

  @override
  void dispose() {
    _telephoneController.dispose();
    super.dispose();
  }

  void _onSelectDuration(int months) {
    setState(() => _selectedDurationMonths = months);
    ref.read(paiementAbonnementNotifierProvider.notifier).changerDuree(months);
  }

  @override
  Widget build(BuildContext context) {
    final ctxAsync = ref.watch(contexteSessionProvider);
    final plansAsync = ref.watch(cataloguePlansProvider);
    final paiementState = ref.watch(paiementAbonnementNotifierProvider);
    final paiementNotifier = ref.read(paiementAbonnementNotifierProvider.notifier);

    return ctxAsync.when(
      loading: () => _buildLoadingContainer(),
      error: (e, _) => _buildErrorContainer('Erreur session: $e'),
      data: (session) {
        final abonnement = session?.abonnement;
        final planCodeActuel = abonnement?.planCode ?? 'NORMAL';
        final planCodeCible = paiementState.planCodeCible.isNotEmpty
            ? paiementState.planCodeCible
            : planCodeActuel;

        if (plansAsync.isLoading && !plansAsync.hasValue) {
          return _buildLoadingContainer();
        }

        final plans = plansAsync.value ?? cataloguePlansParDefaut;
        PlanCatalogueItem? planActif;
        for (final p in plans) {
          if (p.code.toUpperCase() == planCodeCible.toUpperCase()) {
            planActif = p;
            break;
          }
        }
        planActif ??= plans.isNotEmpty ? plans.first : cataloguePlansParDefaut.first;

            final content = Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _sheetBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Poignée discrète
                      Center(
                        child: Container(
                          width: 42,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // En-tête officiel selon Image 1 & Image 2
                      const Text(
                        'Réactivez votre compte\npour continuer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textWhite,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Votre accès a pris fin. Pour continuer à profiter de nos services, choisissez une option pour réactiver votre accès.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Affichage conditionnel selon l'étape courante
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: switch (_currentStep) {
                          1 => _buildStep1Intro(planActif!),
                          2 => _buildStep2ChoixDuree(planActif!, plans, paiementNotifier),
                          3 => _buildStep3Paiement(planActif!, paiementState, paiementNotifier),
                          _ => _buildStep1Intro(planActif!),
                        },
                      ),

                      // Module de test Sandbox (accessible pour tester le règlement sans attendre 10 jours)
                      const SizedBox(height: 20),
                      _buildBanniereSandbox(paiementNotifier, abonnement?.statut?.name),
                    ],
                  ),
                ),
              ),
            );

            return content;
      },
    );
  }

  // ===========================================================================
  // ÉTAPE 1 : Accueil Réactivation (Fidèle à l'Image 1)
  // ===========================================================================
  Widget _buildStep1Intro(PlanCatalogueItem plan) {
    final prixMensuel = plan.prixMensuel > 0
        ? plan.prixMensuel
        : switch (plan.code.toUpperCase()) {
            'PRO' => 5000,
            'MOYEN' => 2000,
            _ => 1000,
          };
    return Column(
      key: const ValueKey('step-1-intro'),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primaryGreen.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_rounded, color: _primaryGreenLight, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Formule ${plan.nom} • ${_formaterMontant(prixMensuel)} / mois',
                  style: const TextStyle(
                    color: _textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Bouton principal Vert Émeraude : "Souscrire maintenant"
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            key: const Key('btn-souscrire-maintenant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: _primaryGreen.withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => setState(() => _currentStep = 2),
            child: const Text(
              'Souscrire maintenant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Bouton secondaire rouge : "Se déconnecter"
        TextButton(
          key: const Key('btn-se-deconnecter'),
          style: TextButton.styleFrom(
            foregroundColor: _dangerRed,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          ),
          onPressed: _seDeconnecter,
          child: const Text(
            'Se déconnecter',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // ÉTAPE 2 : Sélection de la durée (Fidèle à l'Image 2)
  // ===========================================================================
  Widget _buildStep2ChoixDuree(
    PlanCatalogueItem plan,
    List<PlanCatalogueItem> plans,
    PaiementAbonnementNotifier notifier,
  ) {
    // Calcul précis d'après les tarifs officiels DubaGest (1 000 F, 2 000 F, 5 000 F)
    final tarif1 = _obtenirTarif(plan, 1);
    final tarif3 = _obtenirTarif(plan, 3);
    final tarif6 = _obtenirTarif(plan, 6);
    final tarif12 = _obtenirTarif(plan, 12);

    return Column(
      key: const ValueKey('step-2-durees'),
      children: [
        // Sélecteur direct des formules DubaGest (Normal 1000F, Moyen 2000F, Pro 5000F)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              for (final p in (plans.isNotEmpty ? plans : [plan]))
                Expanded(
                  child: InkWell(
                    onTap: () => notifier.changerPlan(p.code),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: p.code == plan.code ? _primaryGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.nom,
                            style: TextStyle(
                              color: p.code == plan.code ? Colors.white : _textWhite,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${_formaterMontant(p.prixMensuel)}/m',
                            style: TextStyle(
                              color: p.code == plan.code ? Colors.white.withValues(alpha: 0.9) : _textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Carte 1 : 1 mois (Nouvel ordre : en 1ère position)
        _buildDureeCard(
          dureeMois: 1,
          titreDuree: '1 mois',
          prixMontant: tarif1,
          packNom: 'Pack Mensuel',
          badgeInfo: 'Sans engagement',
          isSelected: _selectedDurationMonths == 1,
          onTap: () => _onSelectDuration(1),
        ),
        const SizedBox(height: 12),

        // Carte 2 : 3 mois (Pack Trimestriel)
        _buildDureeCard(
          dureeMois: 3,
          titreDuree: '3 mois',
          prixMontant: tarif3,
          packNom: 'Pack Trimestriel',
          badgeInfo: 'Idéal pour débuter',
          isSelected: _selectedDurationMonths == 3,
          onTap: () => _onSelectDuration(3),
        ),
        const SizedBox(height: 12),

        // Carte 3 : 6 mois (Pack Semestriel)
        _buildDureeCard(
          dureeMois: 6,
          titreDuree: '6 mois',
          prixMontant: tarif6,
          packNom: 'Pack Semestriel',
          badgeInfo: 'Tranquillité 6 mois',
          isSelected: _selectedDurationMonths == 6,
          onTap: () => _onSelectDuration(6),
        ),
        const SizedBox(height: 12),

        // Carte 4 : 12 mois (Pack Annuel - 2 mois offerts)
        _buildDureeCard(
          dureeMois: 12,
          titreDuree: '12 mois',
          prixMontant: tarif12,
          packNom: 'Pack Annuel',
          badgeInfo: '2 mois offerts !',
          badgeBonus: '2 mois offerts',
          isSelected: _selectedDurationMonths == 12,
          onTap: () => _onSelectDuration(12),
        ),
        const SizedBox(height: 24),

        // Bouton Vert Émeraude : "Continuer"
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            key: const Key('btn-continuer-duree'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: _primaryGreen.withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => setState(() => _currentStep = 3),
            child: const Text(
              'Continuer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Bouton rouge : "Annuler"
        TextButton(
          key: const Key('btn-annuler-duree'),
          style: TextButton.styleFrom(
            foregroundColor: _dangerRed,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          ),
          onPressed: () {
            if (_currentStep > 1 && widget.startAtStep == 1) {
              setState(() => _currentStep = 1);
            } else if (widget.onClose != null) {
              widget.onClose!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
          child: const Text(
            'Annuler',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CARTE DE SÉLECTION DE DURÉE (Stylée 100% comme l'Image 2)
  // ===========================================================================
  Widget _buildDureeCard({
    required int dureeMois,
    required String titreDuree,
    required int prixMontant,
    required String packNom,
    required String badgeInfo,
    String? badgeBonus,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final prixTexte = _formaterMontant(prixMontant);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _cardSelectedBg : _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: _primaryGreenLight, width: 1.8)
              : Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Row(
          children: [
            // Radio bouton personnalisé avec glow vert émeraude
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _primaryGreenLight : Colors.white.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: _primaryGreenLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Colonne gauche : Durée & Montant en FCFA
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titreDuree,
                    style: const TextStyle(
                      color: _textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    prixTexte,
                    style: TextStyle(
                      color: isSelected ? _primaryGreenLight : _textMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Colonne droite : Badge sombre avec titre de pack & icône étoile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _badgeBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    packNom,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: _primaryGreenLight, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        badgeInfo,
                        style: const TextStyle(
                          color: _textWhite,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ÉTAPE 3 : Moyen de paiement & Confirmation (Orange Money / LigdiCash)
  // ===========================================================================
  Widget _buildStep3Paiement(
    PlanCatalogueItem plan,
    PaiementAbonnementState state,
    PaiementAbonnementNotifier notifier,
  ) {
    final montantTotal = _obtenirTarif(plan, _selectedDurationMonths);
    final montantFormate = _formaterMontant(montantTotal);

    final tx = state.transactionCourante;
    final statut = tx?.statut;

    // Si la transaction est en cours, afficher l'écran de suivi
    if (statut != null && (statut == StatutTransactionAbonnement.enAttente || statut == StatutTransactionAbonnement.enCours)) {
      return _buildSuiviTransaction(tx!, statut, notifier);
    }

    if (statut == StatutTransactionAbonnement.confirme) {
      return _buildSuccesTransaction(tx!);
    }

    return Column(
      key: const ValueKey('step-3-paiement'),
      children: [
        // Encart récapitulatif
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryGreen.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Formule ${plan.nom} • $_selectedDurationMonths mois',
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    montantFormate,
                    style: const TextStyle(
                      color: _primaryGreenLight,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Choix de l'opérateur (LigdiCash actif / Orange Money bientôt disponible)
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Moyen de paiement Mobile Money',
            style: TextStyle(
              color: _textWhite,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // LigdiCash (Opérationnel et sélectionné par défaut)
        _buildOperateurOption(
          nom: 'LigdiCash',
          sousTitre: 'Paiement mobile sécurisé (Orange, Wave, Moov, Carte)',
          couleur: const Color(0xFF1E88E5),
          icone: Icons.account_balance_wallet_outlined,
          isSelected: state.prestataire == PrestatairePaiement.ligdiCash,
          estDisponible: true,
          onTap: () => notifier.changerPrestataire(PrestatairePaiement.ligdiCash),
        ),
        const SizedBox(height: 10),

        // Orange Money (Désactivé temporairement jusqu'à validation de son API officielle)
        _buildOperateurOption(
          nom: 'Orange Money',
          sousTitre: 'Burkina Faso, Côte d\'Ivoire, Sénégal',
          couleur: const Color(0xFFFF7900),
          icone: Icons.phone_android_rounded,
          isSelected: false,
          estDisponible: false,
          badgeStatut: 'Bientôt disponible',
          onTap: null,
        ),
        const SizedBox(height: 16),

        // Champ numéro de téléphone
        TextField(
          controller: _telephoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: _cardBg,
            labelText: 'Numéro de compte Mobile Money (optionnel)',
            labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
            hintText: 'Ex: 70 00 00 00',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            prefixIcon: const Icon(Icons.phone_iphone_rounded, color: _primaryGreenLight),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _primaryGreenLight, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Bouton Vert Émeraude : Payer
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            key: const Key('btn-payer-maintenant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: _primaryGreen.withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: state.estEnChargement
                ? null
                : () async {
                    final tel = _telephoneController.text.trim();
                    if (state.prestataire == PrestatairePaiement.orangeMoney && tel.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Veuillez saisir votre numéro Mobile Money'),
                          backgroundColor: _dangerRed,
                        ),
                      );
                      return;
                    }
                    notifier.changerTelephone(tel);
                    final ok = await notifier.initialiserPaiement();
                    if (ok && mounted) {
                      final url = ref.read(paiementAbonnementNotifierProvider).transactionCourante?.urlPaiement;
                      if (url != null && url.isNotEmpty) {
                        final uri = Uri.tryParse(url);
                        if (uri != null) {
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (_) {}
                        }
                      }
                    } else if (!ok && mounted && state.erreur != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: ${state.erreur}'),
                          backgroundColor: _dangerRed,
                        ),
                      );
                    }
                  },
            child: state.estEnChargement
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : Text(
                    'Payer $montantFormate',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Bouton retour rouge
        TextButton(
          key: const Key('btn-retour-step-2'),
          style: TextButton.styleFrom(
            foregroundColor: _dangerRed,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          ),
          onPressed: () => setState(() => _currentStep = 2),
          child: const Text(
            'Retour',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperateurOption({
    required String nom,
    required String sousTitre,
    required Color couleur,
    required IconData icone,
    required bool isSelected,
    required VoidCallback? onTap,
    bool estDisponible = true,
    String? badgeStatut,
  }) {
    final contenu = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? _cardSelectedBg : _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: isSelected
            ? Border.all(color: _primaryGreenLight, width: 1.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: estDisponible ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: estDisponible ? couleur : couleur.withValues(alpha: 0.6), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      nom,
                      style: TextStyle(
                        color: estDisponible ? _textWhite : _textWhite.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (badgeStatut != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          badgeStatut,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  sousTitre,
                  style: TextStyle(
                    color: estDisponible ? _textMuted : _textMuted.withValues(alpha: 0.45),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (estDisponible)
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off,
              color: isSelected ? _primaryGreenLight : Colors.white30,
              size: 20,
            )
          else
            Icon(
              Icons.lock_outline_rounded,
              color: Colors.white.withValues(alpha: 0.25),
              size: 18,
            ),
        ],
      ),
    );

    if (!estDisponible || onTap == null) {
      return Opacity(
        opacity: 0.55,
        child: contenu,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: contenu,
    );
  }

  // ===========================================================================
  // SUIVI DE LA TRANSACTION (Validation USSD ou Redirection LigdiCash)
  // ===========================================================================
  Widget _buildSuiviTransaction(
    TransactionAbonnementItem tx,
    StatutTransactionAbonnement statut,
    PaiementAbonnementNotifier notifier,
  ) {
    final estLigdicash = tx.prestataire == PrestatairePaiement.ligdiCash;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryGreen.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              color: _primaryGreenLight,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            estLigdicash ? 'Paiement LigdiCash initié...' : 'Validation en cours...',
            style: const TextStyle(
              color: _textWhite,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            estLigdicash
                ? 'Une page de règlement sécurisée LigdiCash a été ouverte.\nFinalisez votre paiement puis confirmez ci-dessous.'
                : 'Un message de confirmation a été envoyé sur votre mobile.\nValidez l\'opération avec votre code secret Mobile Money.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Réf: ${tx.referenceInterne}',
              style: const TextStyle(color: _textWhite, fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          if (tx.urlPaiement != null && tx.urlPaiement!.isNotEmpty) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryGreenLight,
                side: const BorderSide(color: _primaryGreenLight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final uri = Uri.tryParse(tx.urlPaiement!);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Rouvrir la page LigdiCash', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => notifier.verifierStatutTransaction(tx.referenceInterne),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Vérifier la confirmation', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _dangerRed),
            onPressed: () => notifier.annulerTransaction(tx.referenceInterne),
            child: const Text('Annuler cette tentative', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccesTransaction(TransactionAbonnementItem tx) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'Paiement confirmé !',
            style: const TextStyle(
              color: _textWhite,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre compte DubaGest a été réactivé avec succès.\nToutes vos fonctionnalités sont à nouveau disponibles.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: _primaryGreen.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                if (widget.onClose != null) {
                  widget.onClose!();
                } else {
                  context.go(Routes.home);
                }
              },
              child: const Text(
                'Accéder à mon espace',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // UTILITAIRES DE TARIFICATION
  // ===========================================================================
  int _obtenirTarif(PlanCatalogueItem plan, int dureeMois, [int? fallbackDefaut]) {
    final tarif = plan.tarifPour(dureeMois);
    if (tarif.montantTotal > 0) return tarif.montantTotal;
    // Formules officielles DubaGest : Normal 1000F, Moyen 2000F, Pro 5000F
    final prixMensuel = plan.prixMensuel > 0
        ? plan.prixMensuel
        : switch (plan.code.toUpperCase()) {
            'PRO' => 5000,
            'MOYEN' => 2000,
            _ => 1000,
          };
    if (dureeMois == 12) {
      return prixMensuel * 10; // Remise officielle : 2 mois offerts !
    }
    return prixMensuel * dureeMois;
  }

  void _seDeconnecter() async {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    await ref.read(signOutProvider).call();
  }

  Widget _buildBanniereSandbox(PaiementAbonnementNotifier notifier, Object? statutAbo) {
    final statutTexte = statutAbo is Enum ? statutAbo.name : (statutAbo?.toString() ?? 'Inconnu');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sandbox LigdiCash (Test)',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Statut: $statutTexte',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Permet de contourner les 10 jours d\'essai pour tester le règlement LigdiCash immédiatement (réservé aux tests).',
            style: TextStyle(color: _textMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('btn-test-fin-essai'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final ok = await notifier.contournerEssaiPourTest('ACCELERER_FIN_ESSAI');
                    if (ok && mounted) {
                      setState(() => _currentStep = 2);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test Sandbox : Fin des 10 jours simulée. Vous pouvez tester le règlement.'),
                          backgroundColor: Colors.amber,
                        ),
                      );
                    }
                  },
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Simuler fin 10j', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('btn-test-reset-essai'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryGreenLight,
                    side: BorderSide(color: _primaryGreenLight.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final ok = await notifier.contournerEssaiPourTest('REINITIALISER_ESSAI');
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test Sandbox : Période d\'essai de 10 jours réinitialisée.'),
                          backgroundColor: _primaryGreen,
                        ),
                      );
                    }
                  },
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Réinitialiser essai', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingContainer() {
    return Container(
      height: 280,
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _primaryGreenLight),
      ),
    );
  }

  Widget _buildErrorContainer(String message) {
    final isNetwork = message.contains('SocketException') ||
        message.contains('Failed host lookup') ||
        message.contains('ClientException') ||
        message.contains('Network') ||
        message.contains('connexion');

    final messageAffiche = isNetwork
        ? 'Connexion Internet non disponible.\nVeuillez vous connecter à Internet (Wi-Fi ou données mobiles) pour renouveler votre formule en ligne.'
        : message;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNetwork ? Icons.wifi_off_rounded : Icons.error_outline,
            color: isNetwork ? _goldYellow : _dangerRed,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            isNetwork ? 'Mode hors-ligne' : 'Information',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            messageAffiche,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => ref.refresh(contexteSessionProvider),
                  child: const Text('Réessayer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

