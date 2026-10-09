import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/state_views.dart';
import '../../agenda/presentation/pages/agenda_page.dart';
import '../../agenda/presentation/providers/agenda_providers.dart';
import '../../documents/presentation/pages/documents_page.dart';
import '../../documents/presentation/providers/documents_providers.dart';
import '../../finances/domain/entities/finances.dart';
import '../../finances/presentation/providers/finances_providers.dart';
import '../../finances/presentation/widgets/finances_widgets.dart';
import '../domain/recherche_globale.dart';

class TexteRechercheNotifier extends Notifier<String> {
  @override
  String build() => '';
  void changer(String v) => state = v;
}

final texteRechercheProvider = NotifierProvider.autoDispose<TexteRechercheNotifier, String>(TexteRechercheNotifier.new);

/// Résultats sur les données de l'appareil, selon les droits de l'utilisateur.
final resultatsRechercheProvider = Provider.autoDispose<ResultatsRecherche>((ref) {
  final texte = ref.watch(texteRechercheProvider);
  if (texte.trim().length < 2) return const ResultatsRecherche();
  final droitsF = ref.watch(droitsFinancesProvider);
  final voitFinances = droitsF.voirCreances || droitsF.voirPaiements || droitsF.voirDepenses;
  return RechercheGlobale.chercher(
    texte,
    contacts: (ref.watch(contactsParIdProvider).value ?? const {}).values.toList(),
    finances: voitFinances ? ref.watch(etatFinancesProvider).value : null,
    sommesDues: droitsF.voirCreances,
    paiements: droitsF.voirPaiements,
    depenses: droitsF.voirDepenses,
    documents: ref.watch(documentsProvider).value ?? const [],
    echeances: ref.watch(echeancesProvider).value ?? const [],
  );
});

/// Champ d'accès à la recherche (accueil).
class ChampRechercheGlobale extends StatelessWidget {
  const ChampRechercheGlobale({super.key});

  @override
  Widget build(BuildContext context) {
    const hint = 'Produit, client, facture...';
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: InkWell(
        key: const Key('recherche-globale'),
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push(Routes.recherche),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.muted, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.muted, fontSize: 14, fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecherchePage extends ConsumerWidget {
  const RecherchePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final texte = ref.watch(texteRechercheProvider);
    final r = ref.watch(resultatsRechercheProvider);

    Widget section(String titre, List<Widget> lignes) => lignes.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.sm),
                child: Text(titre, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Card(child: Column(children: lignes)),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('recherche-champ'),
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: ref.read(texteRechercheProvider.notifier).changer,
        ),
      ),
      body: ResponsiveBody(
        child: texte.trim().length < 2
            ? EmptyView(icon: Icons.search, message: l10n.searchIntro)
            : r.vide
                ? EmptyView(icon: Icons.search_off, message: l10n.searchNoResult)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                    children: [
                      section(l10n.moduleCommunContacts, [
                        for (final x in r.contacts)
                          ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(x.contact.nomAffiche),
                            subtitle: x.contact.telephone == null ? null : Text(x.contact.telephone!),
                            onTap: () => context.push(Routes.contact(x.contact.id)),
                          ),
                      ]),
                      section(l10n.searchDebts, [
                        for (final x in r.sommesDues)
                          ListTile(
                            leading: Icon(x.suivi.engagement.sens == SensEngagement.aRecevoir
                                ? Icons.south_west
                                : Icons.north_east),
                            title: Text(x.contact?.nomAffiche ?? x.suivi.engagement.libelle),
                            subtitle: Text(x.suivi.engagement.libelle),
                            trailing: Montant(x.suivi.reste),
                            onTap: () => context.push(Routes.engagement(x.suivi.engagement.id)),
                          ),
                      ]),
                      section(l10n.moduleFinancesPaiements, [
                        for (final x in r.paiements)
                          ListTile(
                            leading: const Icon(Icons.payments_outlined),
                            title: Text(x.contact?.nomAffiche ?? l10n.modePaiement(x.paiement.mode)),
                            subtitle: Text(l10n.dateTime(x.paiement.datePaiement)),
                            trailing: Montant(x.paiement.montant,
                                signe: x.paiement.sens == SensPaiement.entree, barre: x.annule),
                            onTap: () => context.push(Routes.paiement(x.paiement.id)),
                          ),
                      ]),
                      section(l10n.moduleFinancesDepenses, [
                        for (final x in r.depenses)
                          ListTile(
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(x.depense.libelle),
                            subtitle: Text(l10n.date(x.depense.dateDepense)),
                            trailing: Montant(x.depense.montant, signe: false, barre: x.depense.annulee),
                            onTap: () => context.push(Routes.depense(x.depense.id)),
                          ),
                      ]),
                      section(l10n.moduleCommunDocuments, [
                        for (final x in r.documents)
                          ListTile(
                            leading: const Icon(Icons.receipt_outlined),
                            title: Text(x.document.numero),
                            subtitle: Text(l10n.typeDocument(x.document.type)),
                            trailing: Montant(x.document.montant),
                            onTap: () => context.push(Routes.document(x.document.id)),
                          ),
                      ]),
                      section(l10n.moduleCommunAgenda, [
                        for (final x in r.echeances)
                          ListTile(
                            leading: Icon(iconeEcheance(x.echeance.type)),
                            title: Text(x.echeance.titre),
                            subtitle: Text(l10n.date(x.echeance.dateHeure)),
                            onTap: () => context.push(Routes.echeance(x.echeance.id)),
                          ),
                      ]),
                    ],
                  ),
      ),
    );
  }
}
