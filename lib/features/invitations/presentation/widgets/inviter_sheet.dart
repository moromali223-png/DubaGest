import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/permissions/access_decision.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../authentication/presentation/widgets/auth_form_scaffold.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../../domain/entities/invitation.dart';
import '../providers/invitations_providers.dart';

/// Administrateur → Inviter : e-mail, rôle (parmi ceux du plan), périmètres.
Future<void> showInviterSheet(BuildContext context) async {
  final creee = await showModalBottomSheet<(String, InvitationCreee)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _InviterForm(),
  );
  if (creee != null && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (_) => InvitationCreeeDialog(email: creee.$1, invitation: creee.$2),
    );
  }
}

class _InviterForm extends ConsumerStatefulWidget {
  const _InviterForm();

  @override
  ConsumerState<_InviterForm> createState() => _InviterFormState();
}

class _InviterFormState extends ConsumerState<_InviterForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _role;
  final Set<String> _perimetres = {};
  bool _envoi = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  IconData _roleIcon(String roleCode) {
    switch (roleCode.toUpperCase()) {
      case 'ADMINISTRATEUR':
        return Icons.admin_panel_settings_rounded;
      case 'SUPERVISEUR':
        return Icons.verified_user_rounded;
      case 'GESTIONNAIRE_STOCK':
        return Icons.inventory_2_rounded;
      case 'VENDEUR':
        return Icons.point_of_sale_rounded;
      case 'CAISSIER':
        return Icons.payments_rounded;
      case 'GESTIONNAIRE_IMMOBILIER':
        return Icons.apartment_rounded;
      case 'GESTIONNAIRE_SERVICES':
        return Icons.design_services_rounded;
      case 'PRESTATAIRE':
        return Icons.handyman_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  Future<void> _submit(List<Perimetre> tous) async {
    if (!_formKey.currentState!.validate() || _role == null) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    setState(() => _envoi = true);
    try {
      final creee = await ref.read(creerInvitationProvider).call(
            ctx,
            email: _email.text,
            roleCode: _role!,
            perimetres: () {
              final sel = tous.where((p) => _perimetres.contains(p.id)).toList();
              if (sel.isEmpty && tous.isNotEmpty && ref.read(creerInvitationProvider).perimetresRequis(ctx, _role!)) {
                final com = tous.where((p) => p.activite == ActiviteCode.commerce).toList();
                return [com.isNotEmpty ? com.first : tous.first];
              }
              return sel;
            }(),
          );
      ref.invalidate(invitationsProvider);
      if (mounted) Navigator.of(context).pop((_email.text.trim().toLowerCase(), creee));
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final ctx = ref.watch(contexteActifProvider);
    if (ctx == null) return const SizedBox.shrink();

    final usecase = ref.watch(creerInvitationProvider);
    final roles = usecase.rolesProposables(ctx);

    final localPerimetres = ref.watch(perimetresProvider).value ?? const <Perimetre>[];
    final perimetres = localPerimetres.isNotEmpty ? localPerimetres : ctx.perimetres;

    final requis = _role != null && usecase.perimetresRequis(ctx, _role!);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Entête professionnel
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.inviteTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Configurez le profil et les accès du collaborateur',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Champ E-mail
              TextFormField(
                key: const Key('invite-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.authEmail,
                  hintText: 'collaborateur@exemple.com',
                  prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                ),
                validator: (v) => AuthValidators.email(
                  v,
                  required: l10n.validationRequired,
                  invalid: l10n.validationEmail,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Titre de section Rôle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.inviteRole,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '1 rôle requis',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              if (roles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(l10n.inviteNoRole, style: const TextStyle(color: AppColors.muted)),
                ),

              // Liste des rôles au format Carte moderne
              for (final e in roles.entries)
                Builder(
                  builder: (context) {
                    final roleCode = e.key;
                    final decision = e.value;
                    final isAllowed = decision.isAllowed;
                    final isSelected = _role == roleCode;
                    final roleAccessGlobal = ctx.roles[roleCode]?.accesTousPerimetres ?? false;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: InkWell(
                        key: ValueKey('invite-role-$roleCode'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: isAllowed
                            ? () {
                                setState(() {
                                  _role = roleCode;
                                  _perimetres.clear();
                                  // Pré-sélection automatique de la boutique par défaut (ex: Boutique A ou boutique unique)
                                  final req = usecase.perimetresRequis(ctx, roleCode);
                                  if (req && perimetres.isNotEmpty) {
                                    final commerceSites = perimetres.where((p) => p.activite == ActiviteCode.commerce).toList();
                                    final defaut = commerceSites.isNotEmpty ? commerceSites.first : perimetres.first;
                                    _perimetres.add(defaut.id);
                                  }
                                });
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primarySoft.withOpacity(0.6)
                                : isAllowed
                                    ? theme.colorScheme.surface
                                    : theme.colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : isAllowed
                                      ? theme.colorScheme.outlineVariant.withOpacity(0.6)
                                      : theme.colorScheme.outlineVariant.withOpacity(0.2),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : isAllowed
                                          ? theme.colorScheme.surfaceContainerHighest
                                          : theme.colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _roleIcon(roleCode),
                                  size: 20,
                                  color: isSelected
                                      ? Colors.white
                                      : isAllowed
                                          ? theme.colorScheme.onSurface
                                          : theme.disabledColor,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          l10n.role(roleCode),
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isAllowed
                                                ? theme.colorScheme.onSurface
                                                : theme.disabledColor,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (isAllowed)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: roleAccessGlobal
                                                  ? Colors.blue.withOpacity(0.1)
                                                  : Colors.teal.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              roleAccessGlobal ? 'Accès global' : 'Sur site',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: roleAccessGlobal ? Colors.blue.shade700 : Colors.teal.shade700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (decision is AccessDenied)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          l10n.decision(decision),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? AppColors.primary
                                    : isAllowed
                                        ? AppColors.muted
                                        : theme.disabledColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Section Périmètres / Sites (obligatoire pour Vendeur, Caissier, etc.)
              if (requis) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _perimetres.isEmpty
                          ? AppColors.gold.withOpacity(0.5)
                          : AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 18,
                                color: _perimetres.isEmpty ? AppColors.goldDark : AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Boutiques / Sites d\'affectation *',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (perimetres.length > 1)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_perimetres.length == perimetres.length) {
                                    _perimetres.clear();
                                  } else {
                                    _perimetres.addAll(perimetres.map((p) => p.id));
                                  }
                                });
                              },
                              child: Text(
                                _perimetres.length == perimetres.length ? 'Désélectionner' : 'Tout cocher',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ce rôle nécessite au moins un site de rattachement pour opérer.',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      if (perimetres.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Aucun site ou boutique n\'a été créé dans votre entreprise. Rendez-vous dans Paramètres > Boutiques pour créer votre premier site.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final p in perimetres)
                          Builder(builder: (_) {
                            final decision = usecase.peutAffecter(ctx, _role!, p);
                            final canSelect = decision.isAllowed;
                            final isChecked = _perimetres.contains(p.id);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: canSelect
                                    ? () {
                                        setState(() {
                                          if (isChecked) {
                                            _perimetres.remove(p.id);
                                          } else {
                                            _perimetres.add(p.id);
                                          }
                                        });
                                      }
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isChecked ? AppColors.primarySoft.withOpacity(0.5) : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isChecked
                                          ? AppColors.primary
                                          : theme.colorScheme.outlineVariant.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                        color: isChecked ? AppColors.primary : AppColors.muted,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.nom,
                                              style: TextStyle(
                                                fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                                                color: canSelect ? theme.colorScheme.onSurface : theme.disabledColor,
                                              ),
                                            ),
                                            Text(
                                              decision is AccessDenied
                                                  ? l10n.decision(decision)
                                                  : l10n.activite(p.activite),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: decision is AccessDenied ? theme.colorScheme.error : AppColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),

                      if (_perimetres.isEmpty && perimetres.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 14, color: Colors.orange.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'Cochez au moins une boutique ci-dessus pour continuer',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Bouton Soumettre avec indication claire
              FilledButton.icon(
                key: const Key('invite-submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _envoi || _role == null || (requis && _perimetres.isEmpty)
                    ? null
                    : () => _submit(perimetres),
                icon: _envoi
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _envoi ? 'Envoi en cours...' : l10n.inviteSend,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Boîte de dialogue affichant le code PIN à 6 chiffres avec compte à rebours 5 minutes.
class InvitationCreeeDialog extends ConsumerStatefulWidget {
  const InvitationCreeeDialog({super.key, required this.email, required this.invitation});
  final String email;
  final InvitationCreee invitation;

  @override
  ConsumerState<InvitationCreeeDialog> createState() => _InvitationCreeeDialogState();
}

class _InvitationCreeeDialogState extends ConsumerState<InvitationCreeeDialog> {
  late String _currentCode;
  late DateTime _expiresAt;
  bool _renvoiEnCours = false;

  @override
  void initState() {
    super.initState();
    _currentCode = widget.invitation.token;
    _expiresAt = widget.invitation.expiresAt;
  }

  String _formatCountdown() {
    final reste = _expiresAt.difference(DateTime.now());
    if (reste.isNegative) return 'Expiré (00:00)';
    final minutes = reste.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secondes = reste.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secondes';
  }

  Future<void> _copier(String texte, String message) async {
    await Clipboard.setData(ClipboardData(text: texte));
    if (mounted) showMessageSnackBar(context, message);
  }

  Future<void> _partagerWhatsApp() async {
    final message = "Bonjour, voici votre code DubaGest pour rejoindre l'entreprise : *$_currentCode*\n"
        "(Ce code est valable pendant 5 minutes).\n"
        "Ouvrez l'application DubaGest et cliquez sur 'Collaborateur' pour le saisir.";
    await _copier(message, 'Message copié ! Vous pouvez le coller directement dans WhatsApp.');
  }

  Future<void> _renvoyerNouveauCode() async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    setState(() => _renvoiEnCours = true);
    try {
      final renvoyer = ref.read(renvoyerInvitationProvider);
      final invitation = Invitation(
        id: widget.invitation.id,
        email: widget.email,
        roleCode: '',
        statut: InvitationStatut.pending,
        expiresAt: _expiresAt,
        createdAt: DateTime.now(),
      );
      final nouveau = await renvoyer(ctx, invitation);
      setState(() {
        _currentCode = nouveau.token;
        _expiresAt = nouveau.expiresAt;
      });
      if (mounted) showMessageSnackBar(context, 'Nouveau code à 6 chiffres généré avec succès !');
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _renvoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estExpire = _expiresAt.isBefore(DateTime.now());

    // Découpage du code pour un affichage spacieux : '123 456'
    final codeAffiche = _currentCode.length == 6
        ? '${_currentCode.substring(0, 3)} ${_currentCode.substring(3)}'
        : _currentCode;

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        final countdownText = _formatCountdown();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: theme.colorScheme.surface,
          titlePadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
          contentPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pin_rounded, color: Color(0xFF1E7E4E), size: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Code PIN Collaborateur',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Transmettez ce code unique à votre collaborateur (${widget.email}) pour lui permettre de rejoindre immédiatement votre entreprise.',
                  style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: AppSpacing.md),

                // Cadre géant du code PIN à 6 chiffres
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: estExpire ? const Color(0xFFEF4444) : const Color(0xFF01226C).withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      SelectableText(
                        codeAffiche,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: estExpire ? const Color(0xFFEF4444) : const Color(0xFF01226C),
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Indicateur d'expiration
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: estExpire ? const Color(0xFFEF4444) : const Color(0xFFDF9540),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            countdownText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: estExpire ? const Color(0xFFEF4444) : const Color(0xFFDF9540),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Boutons de partage rapide (WhatsApp & Copie)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E7E4E),
                          side: const BorderSide(color: Color(0xFF1E7E4E)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _partagerWhatsApp,
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF01226C),
                          side: const BorderSide(color: Color(0xFF01226C)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _copier(_currentCode, 'Code à 6 chiffres copié !'),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copier', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Bouton Renvoyer un nouveau code
                TextButton.icon(
                  onPressed: _renvoiEnCours ? null : _renvoyerNouveauCode,
                  icon: _renvoiEnCours
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    _renvoiEnCours ? 'Génération...' : 'Générer un nouveau code (5 min)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF01226C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}
