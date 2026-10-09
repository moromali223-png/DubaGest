import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../providers/finances_providers.dart';
import '../widgets/caisse_dashboard_view.dart';

/// Une caisse : tableau de bord complet de trésorerie et caisse pour ce site.
class CaissePage extends ConsumerWidget {
  const CaissePage({super.key, required this.caisseId});
  final String caisseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final etat = ref.watch(etatFinancesProvider);
    final nom = etat.value?.caisses.where((c) => c.id == caisseId).firstOrNull?.nom;
    return Scaffold(
      appBar: AppBar(title: Text(nom ?? l10n.moduleFinancesCaisse), actions: const [SyncStatusButton()]),
      body: ResponsiveBody(
        child: AsyncValueView(
          value: etat,
          onRetry: () => ref.invalidate(etatFinancesProvider),
          isEmpty: (e) => !e.caisses.any((c) => c.id == caisseId),
          emptyMessage: l10n.financeNotFound,
          data: (e) => CaisseDashboardView(
            etat: e,
            caisseIdSpecifique: caisseId,
            perimetreIdInitial: e.caisses.where((c) => c.id == caisseId).firstOrNull?.perimetreId,
          ),
        ),
      ),
    );
  }
}

/// Nouvelle caisse (administrateur) : une caisse par boutique / agence.
class CaisseFormPage extends ConsumerStatefulWidget {
  const CaisseFormPage({super.key});

  @override
  ConsumerState<CaisseFormPage> createState() => _CaisseFormPageState();
}

class _CaisseFormPageState extends ConsumerState<CaisseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  String? _perimetreId;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    try {
      final c = await ref.read(gererCaisseProvider).creer(ctx, perimetreId: _perimetreId!, nom: _nom.text);
      if (mounted) context.pushReplacement(Routes.caisse(c.id));
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sites = (ref.watch(perimetresProvider).value ?? const []).where((p) => p.estActif).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cashNew)),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              DropdownButtonFormField<String>(
                key: const Key('caisse-site'),
                initialValue: _perimetreId,
                decoration: InputDecoration(
                  labelText: l10n.financeSite,
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
                items: [for (final p in sites) DropdownMenuItem(value: p.id, child: Text(p.nom))],
                onChanged: (v) => setState(() {
                  _perimetreId = v;
                  if (_nom.text.trim().isEmpty && v != null) {
                    _nom.text = l10n.cashDefaultName(sites.firstWhere((p) => p.id == v).nom);
                  }
                }),
                validator: (v) => v == null ? l10n.validationRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('caisse-nom'),
                controller: _nom,
                maxLength: 80,
                decoration: InputDecoration(labelText: l10n.cashName, counterText: ''),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(key: const Key('caisse-enregistrer'), onPressed: _enregistrer, child: Text(l10n.commonSave)),
            ],
          ),
        ),
      ),
    );
  }
}
