import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../entreprise/domain/entities/profil_entreprise.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart';

/// Paramètres d'encaissement de l'entreprise : modes de paiement proposés
/// et mention en bas des reçus. En ligne, `entreprise.manage`.
class ParametresPaiementsPage extends ConsumerWidget {
  const ParametresPaiementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilEntrepriseProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsPayments)),
      body: switch (profil) {
        AsyncData(value: final p?) => _Formulaire(profil: p),
        AsyncError(:final error) =>
          ErrorView(error: error, onRetry: () => ref.invalidate(profilEntrepriseProvider)),
        _ => const LoadingView(),
      },
    );
  }
}

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({required this.profil});
  final ProfilEntreprise profil;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  late final Set<String> _modes = {...widget.profil.modesPaiement};
  late final _pied = TextEditingController(text: widget.profil.piedRecu ?? '');
  bool _enCours = false;

  @override
  void dispose() {
    _pied.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    setState(() => _enCours = true);
    try {
      await ref.read(modifierParametresEntrepriseProvider).call(ctx, modesPaiement: _modes, piedRecu: _pied.text);
      ref.invalidate(profilEntrepriseProvider);
      if (mounted) showMessageSnackBar(context, context.l10n.settingsSaved);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(l10n.settingsPaymentModes, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.settingsPaymentModesHint, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                for (final m in ModePaiement.values)
                  SwitchListTile(
                    key: Key('parametre-mode-${m.code}'),
                    title: Text(l10n.modePaiement(m)),
                    subtitle: m.passeParCaisse ? Text(l10n.settingsPaymentModeCash) : null,
                    value: _modes.contains(m.code),
                    // Au moins un mode reste proposé.
                    onChanged: _modes.contains(m.code) && _modes.length == 1
                        ? null
                        : (v) => setState(() => v ? _modes.add(m.code) : _modes.remove(m.code)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.settingsReceiptFooter, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('parametre-pied-recu'),
            controller: _pied,
            maxLength: ProfilEntreprise.piedRecuMax,
            maxLines: 3,
            decoration: InputDecoration(hintText: l10n.settingsReceiptFooterHint),
          ),
          Text(l10n.settingsReceiptFooterNote, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('parametres-enregistrer'),
            onPressed: _enCours ? null : _enregistrer,
            icon: _enCours
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
