import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../core/utils/recherche.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/domain/usecases/gerer_contacts.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import '../../../perimetres/presentation/providers/perimetres_providers.dart';
import '../../domain/entities/finances.dart';

/// Contacts actifs et archivés, par identifiant (noms affichés dans les
/// finances). Vide si l'utilisateur n'a pas accès aux contacts.
final contactsParIdProvider = StreamProvider.autoDispose<Map<String, Contact>>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null || !DroitsContacts.de(ctx).voir) return Stream.value(const {});
  return ref
      .watch(observerContactsProvider)
      .call(ctx, const FiltreContacts(inclureArchives: true))
      .map((list) => {for (final c in list) c.id: c});
});

/// Nom des boutiques / agences par identifiant.
final nomsPerimetresProvider = Provider.autoDispose<Map<String, String>>(
  (ref) => {for (final p in ref.watch(perimetresProvider).value ?? const <Perimetre>[]) p.id: p.nom},
);

/// Devise de l'entreprise (XOF par défaut).
final deviseProvider = Provider<String>((ref) => ref.watch(contexteActifProvider)?.entreprise?.devise ?? 'XOF');

extension FinancesLabels on AppLocalizations {
  String modePaiement(ModePaiement m) => switch (m) {
    ModePaiement.especes => paymentModeCash,
    ModePaiement.mobileMoney => paymentModeMobileMoney,
    ModePaiement.carte => paymentModeCard,
    ModePaiement.virement => paymentModeTransfer,
    ModePaiement.cheque => paymentModeCheque,
    ModePaiement.autre => paymentModeOther,
  };

  String etatReglement(EtatReglement e, SensEngagement sens) => switch (e) {
    EtatReglement.aRegler => sens == SensEngagement.aRecevoir ? debtStateUnpaid : debtStateToPay,
    EtatReglement.partiel => debtStatePartial,
    EtatReglement.enRetard => debtStateOverdue,
    EtatReglement.regle => debtStatePaid,
    EtatReglement.annule => debtStateCancelled,
  };

  /// Nom d'une catégorie : traduit pour les catégories fournies.
  String categorieDepense(CategorieDepense? c) =>
      c?.nom ??
      switch (c?.code) {
        'LOYER' => expenseCatRent,
        'ENERGIE' => expenseCatEnergy,
        'TRANSPORT' => expenseCatTransport,
        'SALAIRES' => expenseCatSalaries,
        'FOURNITURES' => expenseCatSupplies,
        'COMMUNICATION' => expenseCatCommunication,
        'ENTRETIEN' => expenseCatMaintenance,
        'TAXES' => expenseCatTaxes,
        'CARBURANT' => expenseCatFuel,
        'EAU' => expenseCatWater,
        'INTERNET' => expenseCatInternet,
        'REPARATION' => expenseCatRepair,
        'NETTOYAGE' => expenseCatCleaning,
        'GARDIENNAGE' => expenseCatSecurity,
        'LIVRAISON' => expenseCatDelivery,
        'FRAIS_BANCAIRES' => expenseCatBankFees,
        'ASSURANCE' => expenseCatInsurance,
        _ => expenseCatOther,
      };

  String naturePaiement(NaturePaiement n) => switch (n) {
    NaturePaiement.apport => cashNatureContribution,
    NaturePaiement.retrait => cashNatureWithdrawal,
    NaturePaiement.transfert => cashNatureTransfer,
    NaturePaiement.remboursement => cashNatureRefund,
    NaturePaiement.ajustement => cashNatureAdjustment,
    NaturePaiement.soldeInitial => cashNatureOpeningBalance,
    NaturePaiement.autre => cashNatureOther,
  };

  String motifEcart(MotifEcart m) => switch (m) {
    MotifEcart.renduMonnaie => cashGapReasonChange,
    MotifEcart.depenseNonEnregistree => cashGapReasonUnrecorded,
    MotifEcart.erreurComptage => cashGapReasonCounting,
    MotifEcart.autre => cashGapReasonOther,
  };

  String typeMouvement(TypeMouvement t) => switch (t) {
    TypeMouvement.encaissement => cashMoveCollection,
    TypeMouvement.decaissement => cashMoveDisbursement,
    TypeMouvement.depot => cashMoveDeposit,
    TypeMouvement.retrait => cashMoveWithdrawal,
  };
}

IconData iconeCategorie(CategorieDepense? c) => switch (c?.code) {
  'LOYER' => Icons.home_work_outlined,
  'ENERGIE' => Icons.bolt_outlined,
  'TRANSPORT' => Icons.local_shipping_outlined,
  'SALAIRES' => Icons.badge_outlined,
  'FOURNITURES' => Icons.inventory_2_outlined,
  'COMMUNICATION' => Icons.campaign_outlined,
  'ENTRETIEN' => Icons.build_outlined,
  'TAXES' => Icons.account_balance_outlined,
  'CARBURANT' => Icons.local_gas_station_outlined,
  'EAU' => Icons.water_drop_outlined,
  'INTERNET' => Icons.phone_android_outlined,
  'REPARATION' => Icons.handyman_outlined,
  'NETTOYAGE' => Icons.cleaning_services_outlined,
  'GARDIENNAGE' => Icons.shield_outlined,
  'LIVRAISON' => Icons.delivery_dining_outlined,
  'FRAIS_BANCAIRES' => Icons.account_balance_wallet_outlined,
  'ASSURANCE' => Icons.verified_user_outlined,
  null when c?.nom != null => Icons.label_outline,
  _ => Icons.more_horiz,
};

/// Montant formaté dans la devise ; signe et couleur selon le sens.
class Montant extends ConsumerWidget {
  const Montant(this.valeur, {super.key, this.signe, this.style, this.barre = false});
  final int valeur;

  /// `true` entrée (+, vert), `false` sortie (−, rouge), `null` neutre.
  final bool? signe;
  final TextStyle? style;
  final bool barre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texte = context.l10n.montant(valeur, ref.watch(deviseProvider));
    final couleur = switch (signe) {
      true => AppColors.positive,
      false => AppColors.negative,
      null => null,
    };
    return Text(
      signe == null ? texte : '${signe! ? '+' : '−'} $texte',
      style: (style ?? const TextStyle(fontWeight: FontWeight.w700)).copyWith(
        color: barre ? AppColors.muted : couleur,
        decoration: barre ? TextDecoration.lineThrough : null,
      ),
    );
  }
}

class EtatReglementChip extends StatelessWidget {
  const EtatReglementChip({super.key, required this.etat, required this.sens});
  final EtatReglement etat;
  final SensEngagement sens;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (etat) {
      EtatReglement.regle => (AppColors.positiveSoft, AppColors.positive),
      EtatReglement.enRetard => (AppColors.negativeSoft, AppColors.negative),
      EtatReglement.partiel => (AppColors.warningSoft, AppColors.warning),
      EtatReglement.aRegler => (AppColors.greenSoft, AppColors.ink),
      EtatReglement.annule => (AppColors.border, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        context.l10n.etatReglement(etat, sens),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Écriture refusée par le serveur : motif et action « Retirer ».
class EcritureRefuseeBanniere extends StatelessWidget {
  const EcritureRefuseeBanniere({super.key, required this.status, required this.onRetirer});
  final RecordSyncStatus status;
  final VoidCallback? onRetirer;

  @override
  Widget build(BuildContext context) {
    if (status != RecordSyncStatus.syncError) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Card(
      color: AppColors.negativeSoft,
      child: ListTile(
        leading: const Icon(Icons.block, color: AppColors.negative),
        title: Text(l10n.financeRejectedTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(l10n.financeRejectedMessage),
        trailing: onRetirer == null
            ? null
            : TextButton(
                key: const Key('finance-retirer'),
                onPressed: onRetirer,
                child: Text(l10n.financeRejectedRemove),
              ),
      ),
    );
  }
}

/// Saisie d'un montant entier (chiffres uniquement, séparateurs ignorés).
class ChampMontant extends ConsumerWidget {
  const ChampMontant({
    super.key,
    required this.controller,
    required this.label,
    this.obligatoire = true,
    this.max,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final bool obligatoire;
  final int? max;
  final ValueChanged<int?>? onChanged;
  final bool autofocus;

  static int? lire(String texte) => int.tryParse(chiffresSeuls(texte));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
      decoration: InputDecoration(labelText: label, suffixText: devise == 'XOF' ? 'FCFA' : devise),
      onChanged: onChanged == null ? null : (v) => onChanged!(lire(v)),
      validator: (v) {
        final n = lire(v ?? '');
        if (n == null || n == 0) return obligatoire ? l10n.validationAmount : null;
        if (max != null && n > max!) return l10n.validationAmountMax(l10n.montant(max!, devise));
        return null;
      },
    );
  }
}

/// Choix d'un contact (recherche hors-ligne). Renvoie `null` si annulé ;
/// [aucun] permet de retirer le contact.
Future<({Contact? contact})?> choisirContact(
  BuildContext context, {
  bool aucun = true,
  RelationContact relation = RelationContact.fournisseur,
}) =>
    showModalBottomSheet<({Contact? contact})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ChoixContact(aucun: aucun, relation: relation),
    );

/// Modal de création rapide d'un contact sans quitter le formulaire.
class DialogNouveauContactRapide extends ConsumerStatefulWidget {
  const DialogNouveauContactRapide({
    super.key,
    this.relationInitiale = RelationContact.fournisseur,
    this.nomInitial,
  });

  final RelationContact relationInitiale;
  final String? nomInitial;

  static Future<Contact?> afficher(
    BuildContext context, {
    RelationContact relation = RelationContact.fournisseur,
    String? nomInitial,
  }) =>
      showDialog<Contact>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogNouveauContactRapide(
          relationInitiale: relation,
          nomInitial: nomInitial,
        ),
      );

  @override
  ConsumerState<DialogNouveauContactRapide> createState() => _DialogNouveauContactRapideState();
}

class _DialogNouveauContactRapideState extends ConsumerState<DialogNouveauContactRapide> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  final _prenomController = TextEditingController();
  final _telephoneController = TextEditingController();
  late TypePersonne _typePersonne;
  late Set<RelationContact> _relations;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.nomInitial ?? '');
    _typePersonne = TypePersonne.personne;
    _relations = {widget.relationInitiale};
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;

    setState(() => _enCours = true);
    try {
      final contact = await ref.read(creerContactProvider).call(
            ctx,
            SaisieContact(
              typePersonne: _typePersonne,
              nom: _nomController.text.trim(),
              prenom: _typePersonne == TypePersonne.personne && _prenomController.text.trim().isNotEmpty
                  ? _prenomController.text.trim()
                  : null,
              telephone: _telephoneController.text.trim().isNotEmpty ? _telephoneController.text.trim() : null,
              relations: _relations,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop(contact);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_add_rounded, color: AppColors.green, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Nouveau contact',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TypePersonne>(
                segments: const [
                  ButtonSegment(
                    value: TypePersonne.personne,
                    label: Text('Particulier'),
                    icon: Icon(Icons.person_outline),
                  ),
                  ButtonSegment(
                    value: TypePersonne.organisation,
                    label: Text('Entreprise'),
                    icon: Icon(Icons.business_outlined),
                  ),
                ],
                selected: {_typePersonne},
                onSelectionChanged: (s) => setState(() => _typePersonne = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nomController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _typePersonne == TypePersonne.personne ? 'Nom *' : 'Nom de l\'entreprise *',
                  prefixIcon: Icon(_typePersonne == TypePersonne.personne ? Icons.badge_outlined : Icons.store_outlined),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
              ),
              if (_typePersonne == TypePersonne.personne) ...[
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _prenomController,
                  decoration: const InputDecoration(
                    labelText: 'Prénom (facultatif)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _telephoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (facultatif)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enCours ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _enCours ? null : _creer,
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          child: _enCours
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Créer & Sélectionner'),
        ),
      ],
    );
  }
}

class _ChoixContact extends ConsumerStatefulWidget {
  const _ChoixContact({required this.aucun, this.relation = RelationContact.fournisseur});
  final bool aucun;
  final RelationContact relation;

  @override
  ConsumerState<_ChoixContact> createState() => _ChoixContactState();
}

class _ChoixContactState extends ConsumerState<_ChoixContact> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cle = normaliserRecherche(_recherche);
    final contacts =
        (ref.watch(contactsParIdProvider).value ?? const {}).values
            .where((c) => !c.estArchive)
            .where(
              (c) =>
                  cle.isEmpty ||
                  normaliserRecherche('${c.prenom ?? ''} ${c.nom}').contains(cle) ||
                  (chiffresSeuls(_recherche).length >= 3 &&
                      chiffresSeuls(c.telephone).contains(chiffresSeuls(_recherche))),
            )
            .toList()
          ..sort((a, b) => a.nomAffiche.compareTo(b.nomAffiche));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              key: const Key('choix-contact-recherche'),
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.contactsSearchHint, prefixIcon: const Icon(Icons.search)),
              onChanged: (v) => setState(() => _recherche = v),
            ),
          ),
          // Option 1 : Créer un nouveau contact directement
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.greenSoft,
              child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.green),
            ),
            title: const Text(
              'Créer un nouveau contact',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.green),
            ),
            subtitle: const Text('Ajout immédiat sans quitter le formulaire'),
            onTap: () async {
              final nouveau = await DialogNouveauContactRapide.afficher(
                context,
                relation: widget.relation,
                nomInitial: _recherche.trim().isNotEmpty ? _recherche.trim() : null,
              );
              if (nouveau != null && context.mounted) {
                Navigator.pop(context, (contact: nouveau));
              }
            },
          ),
          const Divider(height: 1),
          // Option 2 : Sans contact (Facultatif)
          if (widget.aucun)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.background,
                child: Icon(Icons.person_off_outlined, color: AppColors.muted),
              ),
              title: Text(l10n.financeNoContact),
              subtitle: const Text('Dépense ou créance sans bénéficiaire attitré'),
              onTap: () => Navigator.pop(context, (contact: null)),
            ),
          const Divider(height: 1),
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_search_outlined, size: 48, color: AppColors.muted),
                          const SizedBox(height: AppSpacing.sm),
                          Text(l10n.contactsNoResult, style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Créer ce contact'),
                            onPressed: () async {
                              final nouveau = await DialogNouveauContactRapide.afficher(
                                context,
                                relation: widget.relation,
                                nomInitial: _recherche.trim().isNotEmpty ? _recherche.trim() : null,
                              );
                              if (nouveau != null && context.mounted) {
                                Navigator.pop(context, (contact: nouveau));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    itemCount: contacts.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.background,
                        child: Text(
                          contacts[i].nomAffiche.characters.firstOrNull?.toUpperCase() ?? '?',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                      ),
                      title: Text(contacts[i].nomAffiche, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: contacts[i].telephone == null ? null : Text(contacts[i].telephone!),
                      onTap: () => Navigator.pop(context, (contact: contacts[i])),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Champ cliquable affichant le contact choisi (avec possibilité de le retirer en 1 clic).
class ChampContact extends ConsumerWidget {
  const ChampContact({
    super.key,
    required this.contactId,
    required this.onChanged,
    this.label,
    this.relation = RelationContact.fournisseur,
  });

  final String? contactId;
  final ValueChanged<String?> onChanged;
  final String? label;
  final RelationContact relation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contact = contactId == null ? null : ref.watch(contactsParIdProvider).value?[contactId];
    return InkWell(
      key: const Key('champ-contact'),
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final choix = await choisirContact(context, relation: relation);
        if (choix != null) onChanged(choix.contact?.id);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label ?? l10n.financeContact,
          prefixIcon: const Icon(Icons.person_outline),
          suffixIcon: contactId != null
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  tooltip: 'Retirer (Sans contact)',
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          contact?.nomAffiche ?? 'Sans contact (Facultatif)',
          style: TextStyle(
            color: contact == null ? AppColors.muted : AppColors.ink,
            fontWeight: contact == null ? FontWeight.normal : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
