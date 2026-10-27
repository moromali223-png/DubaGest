import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/language_selector.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../authentication/domain/entities/auth_state.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/invitation.dart';
import '../providers/invitations_providers.dart';

final _acceptationControllerProvider =
    NotifierProvider.autoDispose<FormActionController, AsyncValue<void>>(FormActionController.new);

/// Rejoindre une entreprise avec un code PIN à 6 chiffres ou un lien.
class JoinCompanyPage extends ConsumerStatefulWidget {
  const JoinCompanyPage({super.key, this.tokenFromLink});
  final String? tokenFromLink;

  @override
  ConsumerState<JoinCompanyPage> createState() => _JoinCompanyPageState();
}

class _JoinCompanyPageState extends ConsumerState<JoinCompanyPage> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    final fromLink = widget.tokenFromLink;
    if (fromLink != null && fromLink.isNotEmpty) {
      Future.microtask(() => ref.read(invitationEnAttenteProvider.notifier).memoriser(fromLink));
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _accepter(String token) async {
    final accepter = ref.read(accepterInvitationProvider);
    final ok = await ref.read(_acceptationControllerProvider.notifier).run(() => accepter(token));
    if (!ok) return;
    ref.invalidate(invitationEnAttenteProvider);
    await ref.read(contexteSessionProvider.notifier).rafraichir();
    if (mounted) context.go(Routes.home);
  }

  Future<void> _ignorer() async {
    await ref.read(invitationEnAttenteProvider.notifier).oublier();
    if (mounted) context.go(Routes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connecte = ref.watch(authStateProvider).value is Authenticated;
    final rawToken = (widget.tokenFromLink?.isNotEmpty ?? false)
        ? widget.tokenFromLink
        : ref.watch(invitationEnAttenteProvider);
    final token = rawToken?.trim().isNotEmpty == true ? rawToken!.trim() : null;

    ref.listen(_acceptationControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) showFailureSnackBar(context, error);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1E293B)),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Text(
          l10n.onboardingJoinTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 18),
        ),
        actions: const [LanguageMenuButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: token == null
                  ? _SaisiePin6Chiffres(
                      controller: _code,
                      onSubmit: (code) => ref.read(invitationEnAttenteProvider.notifier).memoriser(code),
                    )
                  : _Apercu(
                      token: token,
                      connecte: connecte,
                      enCours: ref.watch(_acceptationControllerProvider).isLoading,
                      onAccepter: () => _accepter(token),
                      onIgnorer: _ignorer,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Saisie moderne, réactive et intuitive du code PIN à 6 chiffres
class _SaisiePin6Chiffres extends StatefulWidget {
  const _SaisiePin6Chiffres({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  State<_SaisiePin6Chiffres> createState() => _SaisiePin6ChiffresState();
}

class _SaisiePin6ChiffresState extends State<_SaisiePin6Chiffres> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    final initial = widget.controller.text.trim();
    if (initial.length == 6) {
      for (var i = 0; i < 6; i++) {
        _controllers[i].text = initial[i];
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        for (var i = 0; i < 6 && (index + i) < 6 && i < digits.length; i++) {
          _controllers[index + i].text = digits[i];
        }
        final nextIndex = (index + digits.length).clamp(0, 5);
        _focusNodes[nextIndex].requestFocus();
      }
    } else if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    final code = _currentCode;
    widget.controller.text = code;
    setState(() {});

    if (code.length == 6) {
      widget.onSubmit(code);
    }
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  Future<void> _collerDepuisPressePapier() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 6) {
      for (var i = 0; i < 6; i++) {
        _controllers[i].text = digits[i];
      }
      _focusNodes.last.unfocus();
      final code = digits.substring(0, 6);
      widget.controller.text = code;
      setState(() {});
      widget.onSubmit(code);
    } else if (digits.isNotEmpty) {
      for (var i = 0; i < digits.length && i < 6; i++) {
        _controllers[i].text = digits[i];
      }
      final next = digits.length.clamp(0, 5);
      _focusNodes[next].requestFocus();
      widget.controller.text = _currentCode;
      setState(() {});
    }
  }

  void _effacer() {
    for (final c in _controllers) {
      c.clear();
    }
    widget.controller.clear();
    _focusNodes.first.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isFull = _currentCode.length == 6;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Badge d'en-tête premium
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F3E99), Color(0xFF01226C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF01226C).withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.dialpad_rounded, size: 28, color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const Text(
            'Code PIN Collaborateur',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Saisissez le code à 6 chiffres communiqué par votre administrateur pour rejoindre l\'entreprise.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Les 6 cases de saisie du PIN : 100% responsives, jamais de débordement
          Row(
            children: [
              for (int index = 0; index < 6; index++) ...[
                if (index == 3)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 6,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF94A3B8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: SizedBox(
                      height: 56,
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (e) => _onKeyDown(index, e),
                        child: TextField(
                          key: Key('join-pin-$index'),
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF01226C),
                          ),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: _controllers[index].text.isNotEmpty
                                ? const Color(0xFF01226C).withValues(alpha: 0.05)
                                : const Color(0xFFF8FAFC),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _controllers[index].text.isNotEmpty
                                    ? const Color(0xFF01226C).withValues(alpha: 0.45)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF01226C), width: 2),
                            ),
                          ),
                          onChanged: (v) => _onDigitChanged(index, v),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Raccourci rapide Coller / Effacer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_currentCode.isNotEmpty)
                TextButton.icon(
                  onPressed: _effacer,
                  icon: const Icon(Icons.backspace_outlined, size: 15, color: Color(0xFF64748B)),
                  label: const Text('Effacer', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600)),
                )
              else
                TextButton.icon(
                  onPressed: _collerDepuisPressePapier,
                  icon: const Icon(Icons.content_paste_rounded, size: 15, color: Color(0xFF01226C)),
                  label: const Text('Coller le code', style: TextStyle(color: Color(0xFF01226C), fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Alerte expiration 5 minutes au design élégant
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le code PIN expire 5 minutes après sa création par l\'administrateur.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Bouton d'action principal
          FilledButton.icon(
            key: const Key('join-code-submit'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF01226C),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              disabledForegroundColor: const Color(0xFF94A3B8),
              elevation: isFull ? 2 : 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: isFull ? () => widget.onSubmit(_currentCode) : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text(
              'Vérifier et continuer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aperçu et confirmation de l'invitation validée
class _Apercu extends ConsumerWidget {
  const _Apercu({
    required this.token,
    required this.connecte,
    required this.enCours,
    required this.onAccepter,
    required this.onIgnorer,
  });

  final String token;
  final bool connecte;
  final bool enCours;
  final VoidCallback onAccepter;
  final VoidCallback onIgnorer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final apercu = ref.watch(apercuInvitationProvider(token));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AsyncValueView<InvitationApercu>(
        value: apercu,
        onRetry: () => ref.invalidate(apercuInvitationProvider(token)),
        data: (inv) {
          final isAcceptable = inv.acceptable;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isAcceptable
                        ? const Color(0xFFE8F5EE)
                        : const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAcceptable ? Icons.verified_rounded : Icons.cancel_outlined,
                    size: 40,
                    color: isAcceptable ? const Color(0xFF1E7E4E) : const Color(0xFFEF4444),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (!isAcceptable) ...[
                Text(
                  l10n.invitationRefus(inv.statut),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ce code PIN n\'est plus valide ou a déjà été utilisé. Demandez un nouveau code à votre administrateur.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: onIgnorer,
                  child: const Text('Saisir un autre code'),
                ),
              ] else ...[
                Text(
                  'Invitation trouvée !',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vous êtes invité(e) à rejoindre l\'équipe de :',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: AppSpacing.md),

                // Carte récapitulative
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.business_rounded, color: Color(0xFF01226C)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              inv.entrepriseNom ?? 'Entreprise DubaGest',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF01226C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Rôle attribué :', style: TextStyle(color: Color(0xFF64748B))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5EE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.role(inv.roleCode ?? ''),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E7E4E),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (inv.expiresAt != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Validité :', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            Text(
                              l10n.date(inv.expiresAt!),
                              style: const TextStyle(color: Color(0xFFDF9540), fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                if (connecte)
                  FilledButton.icon(
                    key: const Key('join-accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E7E4E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: enCours ? null : onAccepter,
                    icon: enCours
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(
                      enCours ? 'Rattachement en cours...' : 'Rejoindre l\'espace maintenant',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  )
                else ...[
                  const Text('Veuillez vous connecter pour accepter :', textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: () => context.go(Routes.login),
                    child: Text(l10n.authSignInLink),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: onIgnorer,
                  child: const Text('Annuler / Saisir un autre code'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
