import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/forms/forms.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/documents_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/domain/entities/finances.dart' as fin;
import '../../../finances/domain/usecases/gerer_finances.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../finances/presentation/widgets/caisse_labels.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart' hide choisirContact;
import '../../domain/entities/commerce.dart';
import '../../domain/services/etat_commerce.dart';
import '../../domain/usecases/gerer_commerce.dart';
import '../commerce_providers.dart';
import '../widgets/champ_quantite.dart';
import '../widgets/choix_contact.dart';
import '../widgets/choix_produit.dart';
import '../widgets/commerce_widgets.dart';

enum _ModeReglement {
  credit('À crédit', 'Aucun paiement immédiat (Dette)', Icons.pending_actions_outlined, AppColors.warning),
  acompte('Acompte', 'Versement partiel immédiat', Icons.pie_chart_outline, AppColors.gold),
  comptant('Comptant', 'Paiement intégral immédiat (100%)', Icons.check_circle_outline, AppColors.green);

  const _ModeReglement(this.titre, this.description, this.icone, this.couleur);
  final String titre;
  final String description;
  final IconData icone;
  final Color couleur;
}

/// Achat chez un fournisseur : plusieurs produits, prix d'achat proposés,
/// produits habituels du fournisseur en premier.
class AchatFormPage extends ConsumerWidget {
  const AchatFormPage({super.key, this.achatId, this.fournisseurId, this.produitId, this.bonCommandeId});
  final String? achatId;
  final String? fournisseurId;
  final String? produitId;
  final String? bonCommandeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(etatCommerceProvider);
    return switch (etat) {
      AsyncData(value: final e) when achatId == null =>
        _Formulaire(etat: e, fournisseurId: fournisseurId, produitId: produitId, bonCommandeId: bonCommandeId),
      AsyncData(value: final e) when e.achat(achatId!) != null => _Formulaire(etat: e, initial: e.achat(achatId!)),
      AsyncData() => Scaffold(appBar: AppBar(), body: EmptyView(message: context.l10n.errorNotFound)),
      _ => Scaffold(appBar: AppBar(), body: const LoadingView()),
    };
  }
}

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({required this.etat, this.initial, this.fournisseurId, this.produitId, this.bonCommandeId});
  final EtatCommerce etat;
  final Achat? initial;
  final String? fournisseurId;
  final String? produitId;
  final String? bonCommandeId;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  final _formController = SmartFormController(initialOpenIndex: 0);

  late String? _fournisseurId = widget.initial?.fournisseurId ?? widget.fournisseurId;
  String? _boutique;
  late DateTime _date = widget.initial?.dateAchat ?? DateTime.now();
  late final _reference = TextEditingController(text: widget.initial?.reference);
  late final _note = TextEditingController(text: widget.initial?.note);
  late final List<LigneOperation> _lignes = [...?widget.initial?.lignes];
  bool _enCours = false;
  bool _aEteModifie = false;

  _ModeReglement _modeReglement = _ModeReglement.credit;
  fin.ModePaiement _modePaiement = fin.ModePaiement.especes;
  late final _acompteCtrl = TextEditingController(text: '0');
  String? _bonCommandeId;

  bool get _creation => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final autorisees = ref.read(droitsCommerceProvider).boutiquesAchat;
    final courante = ref.read(boutiqueCouranteProvider);
    _boutique = widget.initial?.perimetreId ?? (autorisees.contains(courante) ? courante : autorisees.firstOrNull);
    if (widget.produitId case final id?) {
      if (widget.etat.produit(id) case final p?) _lignes.add(_nouvelleLigne(p));
    }

    if (widget.bonCommandeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final docs = ref.read(documentsProvider).value ?? const [];
        final doc = docs.where((d) => d.id == widget.bonCommandeId).firstOrNull;
        if (doc != null) _importerBonCommande(doc);
      });
    }

    for (final c in [_reference, _note, _acompteCtrl]) {
      c.addListener(() {
        if (!_aEteModifie) setState(() => _aEteModifie = true);
      });
    }
  }

  @override
  void dispose() {
    _formController.dispose();
    _reference.dispose();
    _note.dispose();
    _acompteCtrl.dispose();
    super.dispose();
  }

  /// Ligne proposée : la plus grande unité, au dernier prix d'achat connu.
  LigneOperation _nouvelleLigne(Produit p, {UniteVente? unite}) {
    final memo = ref.read(unitesMemoriseesProvider.notifier).pour('achat', p.id);
    final u = unite ?? p.unite(memo ?? p.plusGrandeUnite.id);
    final prix = widget.etat.dernierPrixAchat(p.id, u.nom) ?? u.prixAchat ?? 0;
    return LigneOperation(
      id: const Uuid().v4(),
      produitId: p.id,
      unite: u.nom,
      facteur: u.facteur,
      quantite: Qte.un,
      prixUnitaire: prix,
    );
  }

  Future<void> _ajouter() async {
    final etat = ref.read(etatCommerceProvider).value ?? widget.etat;
    final suggestions = _fournisseurId == null ? const <Produit>[] : etat.produitsDuFournisseur(_fournisseurId!);
    final p = await choisirProduit(
      context,
      suggestions: suggestions,
      onCreer: ref.read(droitsCommerceProvider).creerProduits ? () => context.push(Routes.produitNouveau()) : null,
    );
    if (p == null || !mounted) return;
    final ligne = await _editerLigne(p, _nouvelleLigne(p));
    if (ligne != null) {
      setState(() {
        _lignes.add(ligne);
        _aEteModifie = true;
      });
    }
  }

  Future<LigneOperation?> _editerLigne(Produit p, LigneOperation ligne) =>
      showModalBottomSheet<LigneOperation>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _EditeurLigne(produit: p, ligne: ligne, etat: widget.etat),
      );

  Future<void> _choisirBonCommande(BuildContext context) async {
    final docs = ref.read(documentsProvider).value ?? const [];
    final bcs = docs.where((d) => d.type == TypeDocument.bonCommande).toList();

    if (bcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun bon de commande disponible dans Documents.')),
      );
      return;
    }

    final docChoisi = await showModalBottomSheet<Document>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sélectionner un bon de commande',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Les produits, quantités, prix négociés et le fournisseur seront importés automatiquement.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: bcs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = bcs[i];
                    final st = d.contenu['statut_commercial'] as String? ?? 'envoye';
                    final (statutLabel, statutCouleur) = switch (st) {
                      'brouillon' => ('Brouillon', const Color(0xFF6B7280)),
                      'a_negocier' => ('À négocier', const Color(0xFFD97706)),
                      'envoye' => ('Envoyé', const Color(0xFF2563EB)),
                      'contre_proposition' => ('Contre-prop.', const Color(0xFF7C3AED)),
                      'confirme' => ('Confirmé', const Color(0xFF16A34A)),
                      _ => ('Bon de commande', const Color(0xFF2563EB)),
                    };
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: statutCouleur.withValues(alpha: 0.12),
                        child: Icon(Icons.shopping_bag_outlined, color: statutCouleur, size: 20),
                      ),
                      title: Row(
                        children: [
                          Text(d.numero, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statutCouleur.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(statutLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statutCouleur)),
                          ),
                        ],
                      ),
                      subtitle: Text('${d.contactNom ?? 'Fournisseur inconnu'} • ${montant(context, ref, d.montant)}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => Navigator.pop(ctx, d),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (docChoisi != null && mounted) {
      _importerBonCommande(docChoisi);
    }
  }

  void _importerBonCommande(Document d) {
    final contenu = d.contenu;
    final lignesDoc = (contenu['lignes'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final nouvellesLignes = <LigneOperation>[];

    for (final l in lignesDoc) {
      final libelle = (l['libelle'] ?? l['designation'] ?? l['produit'] ?? '').toString();
      final qteNum = (l['quantite'] as num?)?.toDouble() ?? 1.0;
      final prixNum = (l['prix_unitaire'] as num?)?.toInt() ?? 0;
      final remiseNum = (l['remise'] as num?)?.toInt() ?? 0;
      final uniteNom = (l['unite'] as String?)?.trim();
      final produitId = l['produit_id'] as String?;

      Produit? match;
      if (produitId != null) {
        match = widget.etat.produit(produitId);
      }
      if (match == null) {
        for (final p in widget.etat.produits) {
          if (p.nom.trim().toLowerCase() == libelle.trim().toLowerCase()) {
            match = p;
            break;
          }
        }
      }
      if (match == null) {
        for (final p in widget.etat.produits) {
          if (p.reference != null && p.reference!.isNotEmpty && libelle.contains(p.reference!)) {
            match = p;
            break;
          }
        }
      }

      if (match != null) {
        final UniteVente u = uniteNom != null ? match.uniteNommee(uniteNom) : match.plusGrandeUnite;

        nouvellesLignes.add(LigneOperation(
          id: const Uuid().v4(),
          produitId: match.id,
          unite: u.nom,
          facteur: u.facteur,
          quantite: Qte.depuis(qteNum),
          prixUnitaire: prixNum > 0 ? prixNum : (match.prixAchat ?? 0),
          remise: remiseNum,
        ));
      }
    }

    setState(() {
      if (d.contactId != null) _fournisseurId = d.contactId;
      _reference.text = d.numero;
      if (d.notes != null && d.notes!.isNotEmpty) {
        _note.text = d.notes!;
      }
      if (nouvellesLignes.isNotEmpty) {
        _lignes
          ..clear()
          ..addAll(nouvellesLignes);
      }
      _bonCommandeId = d.id;
      _aEteModifie = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nouvellesLignes.length == lignesDoc.length
              ? 'Bon de commande ${d.numero} importé (${nouvellesLignes.length} article(s)).'
              : 'Bon de commande ${d.numero} importé : ${nouvellesLignes.length}/${lignesDoc.length} article(s) lié(s) au catalogue.',
        ),
      ),
    );
  }

  // --- Statuts et Résumés dynamiques des sections ---
  FormSectionStatus get _fournisseurStatus {
    if (_fournisseurId != null || _boutique != null) return FormSectionStatus.complete;
    return FormSectionStatus.emptyOptional;
  }

  String _fournisseurSummary(AppLocalizations l10n) {
    final elements = [
      nomContact(ref, _fournisseurId) ?? 'Fournisseur non sélectionné',
      l10n.date(_date),
      if (_bonCommandeId != null) 'Lié au BC' else if (_reference.text.trim().isNotEmpty) 'Réf: ${_reference.text.trim()}',
    ];
    return elements.join(' • ');
  }

  FormSectionStatus get _lignesStatus {
    if (_lignes.isEmpty) return FormSectionStatus.emptyRequired;
    return FormSectionStatus.complete;
  }

  String _lignesSummary(AppLocalizations l10n) {
    if (_lignes.isEmpty) return 'Aucun article ajouté (Requis)';
    final count = _lignes.length;
    final total = totalLignes(_lignes);
    return '$count article${count > 1 ? 's' : ''} • ${montant(context, ref, total)}';
  }

  FormSectionStatus get _reglementStatus => FormSectionStatus.complete;

  String _reglementSummary(AppLocalizations l10n) {
    final total = totalLignes(_lignes);
    return switch (_modeReglement) {
      _ModeReglement.credit => 'À crédit • Solde dû: ${montant(context, ref, total)}',
      _ModeReglement.comptant => 'Comptant (${l10n.modePaiement(_modePaiement)}) • 100% payé',
      _ModeReglement.acompte => () {
        final a = (int.tryParse(_acompteCtrl.text.trim()) ?? 0).clamp(0, total);
        final r = (total - a).clamp(0, total);
        return 'Acompte: ${montant(context, ref, a)} • Reste dû: ${montant(context, ref, r)}';
      }(),
    };
  }

  FormSectionStatus get _noteStatus {
    if (_note.text.trim().isNotEmpty) return FormSectionStatus.complete;
    return FormSectionStatus.emptyOptional;
  }

  Future<void> _enregistrer({required bool recevoir}) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    final etat = ref.read(etatCommerceProvider).value;
    if (ctx == null || etat == null || _boutique == null) return;
    if (_lignes.isEmpty) {
      _formController.scrollToSection(1);
      return;
    }
    setState(() => _enCours = true);
    final saisie = SaisieAchat(
      perimetreId: _boutique!,
      fournisseurId: _fournisseurId,
      reference: _reference.text,
      date: _date,
      lignes: _lignes,
      note: _note.text,
    );
    final gerer = ref.read(gererCommerceProvider);
    try {
      if (_lignes.any((l) => l.prixUnitaire <= 0)) {
        throw 'Le prix d\'achat doit être supérieur à 0 pour chaque article réceptionné.';
      }
      for (final l in _lignes) {
        ref.read(unitesMemoriseesProvider.notifier).retenir('achat', l.produitId, etat.produit(l.produitId)!.uniteNommee(l.unite).id);
      }
      if (_creation) {
        final achat = await gerer.creerAchat(ctx, etat, saisie, recevoirTout: recevoir);

        // Enregistrement immédiat du paiement si Comptant ou Acompte
        if (_modeReglement != _ModeReglement.credit) {
          final int montantPayer = _modeReglement == _ModeReglement.comptant
              ? achat.total
              : (int.tryParse(_acompteCtrl.text.trim()) ?? 0).clamp(0, achat.total);

          if (montantPayer > 0) {
            final etatFin = ref.read(etatFinancesProvider).value;
            if (etatFin != null) {
              final activeSession = etatFin.sessions
                  .where((s) => s.fermeeLe == null && s.perimetreId == _boutique)
                  .firstOrNull;
              try {
                await ref.read(enregistrerPaiementProvider).call(
                  ctx,
                  etatFin,
                  SaisiePaiement(
                    sens: fin.SensPaiement.sortie,
                    montant: montantPayer,
                    mode: _modePaiement,
                    date: _date,
                    contactId: achat.fournisseurId,
                    perimetreId: achat.perimetreId,
                    sessionId: _modePaiement == fin.ModePaiement.especes ? activeSession?.id : null,
                    reference: 'Achat ${achat.reference ?? ''}'.trim(),
                    affectations: {achat.id: montantPayer},
                  ),
                );
              } catch (_) {}
            }
          }
        }

        if (!mounted) return;
        _aEteModifie = false;
        confirmer(context, recevoir ? l10n.comReceptionDone : l10n.comPurchaseSaved);
        context.pushReplacement(Routes.achat(achat.id));
      } else {
        await gerer.modifierAchat(ctx, etat, widget.initial!, saisie);
        if (!mounted) return;
        _aEteModifie = false;
        confirmer(context, l10n.comPurchaseSaved);
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enCours = false);
      signalerErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etat = ref.watch(etatCommerceProvider).value ?? widget.etat;
    final droits = ref.watch(droitsCommerceProvider);
    final total = totalLignes(_lignes);
    final habituels = _fournisseurId == null
        ? const <Produit>[]
        : etat.produitsDuFournisseur(_fournisseurId!).where((p) => !_lignes.any((l) => l.produitId == p.id)).toList();
    final peutRecevoir = _creation && _boutique != null && droits.boutiquesReception.contains(_boutique);
    final valide = _lignes.isNotEmpty && _boutique != null && !_enCours;

    return UnsavedChangesScope(
      hasUnsavedChanges: _aEteModifie && !_enCours,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_creation ? 'Réception d\'achat' : 'Modifier la réception'),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF123B6D).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF123B6D)),
                  SizedBox(width: 4),
                  Text(
                    'STOCK & FINANCE',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF123B6D), letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            if (_enCours)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              TextButton(
                key: const Key('achat-enregistrer-appbar'),
                onPressed: valide ? () => _enregistrer(recevoir: false) : null,
                child: Text(l10n.comSave, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: SmartFormContainer(
            controller: _formController,
            children: [
                    // Section 1 : Fournisseur & Contexte
                    CollapsibleFormSection(
                      key: _formController.registerSectionKey(0),
                      title: 'Origine & Destination du stock',
                      icon: Icons.local_shipping_rounded,
                      summary: _fournisseurSummary(l10n),
                      status: _fournisseurStatus,
                      isExpanded: _formController.isSectionOpen(0),
                      onToggle: () => setState(() => _formController.toggleSection(0)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_bonCommandeId != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.shopping_bag_outlined, color: Color(0xFF1D4ED8), size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Importé depuis le Bon de commande',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                        ),
                                        Text(
                                          _reference.text.isNotEmpty ? _reference.text : 'BC lié',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _choisirBonCommande(context),
                                    child: const Text('Changer', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ] else if (_creation) ...[
                            OutlinedButton.icon(
                              onPressed: () => _choisirBonCommande(context),
                              icon: const Icon(Icons.file_download_outlined),
                              label: const Text('Importer depuis un Bon de commande'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF123B6D),
                                side: const BorderSide(color: Color(0xFF123B6D)),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          Card(
                            elevation: 0,
                            color: AppColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: ListTile(
                              key: const Key('achat-fournisseur'),
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.greenSoft,
                                child: Icon(Icons.business_rounded, color: AppColors.green, size: 20),
                              ),
                              title: Text(l10n.comSupplier, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                              subtitle: Text(
                                nomContact(ref, _fournisseurId) ?? l10n.comNoSupplierChosen,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                              onTap: () async {
                                final c = await choisirContact(context, RelationContact.fournisseur);
                                if (c != null) {
                                  setState(() {
                                    _fournisseurId = c.id;
                                    _aEteModifie = true;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (droits.boutiquesAchat.length > 1 && _creation) ...[
                            ChampBoutique(
                              valeur: _boutique,
                              autorisees: droits.boutiquesAchat,
                              onChanged: (v) => setState(() {
                                _boutique = v;
                                _aEteModifie = true;
                              }),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: _date,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(const Duration(days: 1)),
                                    );
                                    if (d != null) {
                                      setState(() {
                                        _date = d;
                                        _aEteModifie = true;
                                      });
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: l10n.comPurchaseDate,
                                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                                    ),
                                    child: Text(l10n.date(_date)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: TextField(
                                  controller: _reference,
                                  decoration: const InputDecoration(
                                    labelText: 'N° Facture / BL fournisseur',
                                    hintText: 'Ex: FAC-2026-001',
                                    prefixIcon: Icon(Icons.tag_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Section 2 : Articles & Produits commandés
                    CollapsibleFormSection(
                      key: _formController.registerSectionKey(1),
                      title: 'Articles à réceptionner en stock',
                      icon: Icons.inventory_2_rounded,
                      summary: _lignesSummary(l10n),
                      status: _lignesStatus,
                      isRequired: true,
                      isExpanded: _formController.isSectionOpen(1),
                      onToggle: () => setState(() => _formController.toggleSection(1)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (habituels.isNotEmpty) ...[
                            Text(
                              l10n.comUsualProducts,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.muted),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              height: 104,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final p in habituels)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () async {
                                          final l = await _editerLigne(p, _nouvelleLigne(p));
                                          if (l != null) {
                                            setState(() {
                                              _lignes.add(l);
                                              _aEteModifie = true;
                                            });
                                          }
                                        },
                                        child: SizedBox(
                                          width: 76,
                                          child: Column(
                                            children: [
                                              ProduitImage(produit: p, taille: 64),
                                              const SizedBox(height: 4),
                                              Text(
                                                p.nom,
                                                maxLines: 2,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          for (final (i, l) in _lignes.indexed)
                            if (etat.produit(l.produitId) case final p?)
                              Card(
                                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: ListTile(
                                  key: Key('ligne-$i'),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  leading: ProduitImage(produit: p, taille: 48),
                                  title: Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    '${qteUnite(context, l.quantite, l.unite)} × ${montant(context, ref, l.prixUnitaire)}'
                                    '${l.facteur == Qte.un ? '' : '\n${equivalentBase(context, p, l.quantiteBase) ?? ''}'}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        montant(context, ref, l.montant),
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.muted),
                                        onPressed: () => setState(() {
                                          _lignes.removeAt(i);
                                          _aEteModifie = true;
                                        }),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    final r = await _editerLigne(p, l);
                                    if (r != null) {
                                      setState(() {
                                        _lignes[i] = r;
                                        _aEteModifie = true;
                                      });
                                    }
                                  },
                                ),
                              ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  key: const Key('achat-ajouter-ligne'),
                                  onPressed: _ajouter,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Ajouter manuellement'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    // Simuler scan Code-barres
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Ouverture du scanner de code-barres / QR Code...')),
                                    );
                                  },
                                  icon: const Icon(Icons.qr_code_scanner_rounded),
                                  label: const Text('Scanner'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Section 3 : Paiement & Règlement (si création)
                    if (_creation)
                      CollapsibleFormSection(
                        key: _formController.registerSectionKey(2),
                        title: 'Paiement & Modalités de règlement',
                        icon: Icons.payments_rounded,
                        summary: _reglementSummary(l10n),
                        status: _reglementStatus,
                        isExpanded: _formController.isSectionOpen(2),
                        onToggle: () => setState(() => _formController.toggleSection(2)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final m in _ModeReglement.values)
                                  ChoiceChip(
                                    label: Text(m.titre),
                                    avatar: Icon(m.icone, size: 18),
                                    selected: _modeReglement == m,
                                    selectedColor: m.couleur.withValues(alpha: 0.15),
                                    onSelected: (sel) {
                                      if (sel) {
                                        setState(() {
                                          _modeReglement = m;
                                          _aEteModifie = true;
                                        });
                                      }
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _modeReglement.description,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _modeReglement.couleur,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (_modeReglement == _ModeReglement.acompte) ...[
                              TextField(
                                controller: _acompteCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  labelText: 'Montant de l\'acompte immédiat (FCFA) *',
                                  helperText: 'Reste à payer : ${montant(context, ref, (total - (int.tryParse(_acompteCtrl.text.trim()) ?? 0)).clamp(0, total))}',
                                  prefixIcon: const Icon(Icons.price_change_outlined),
                                ),
                                onChanged: (_) => setState(() => _aEteModifie = true),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (_modeReglement != _ModeReglement.credit) ...[
                              DropdownButtonFormField<fin.ModePaiement>(
                                initialValue: _modePaiement,
                                decoration: const InputDecoration(
                                  labelText: 'Mode de décaissement *',
                                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                                ),
                                items: [
                                  for (final m in [
                                    fin.ModePaiement.especes,
                                    fin.ModePaiement.mobileMoney,
                                    fin.ModePaiement.virement,
                                    fin.ModePaiement.carte,
                                    fin.ModePaiement.cheque,
                                  ])
                                    DropdownMenuItem(
                                      value: m,
                                      child: Row(
                                        children: [
                                          Icon(iconeMode(m), size: 18, color: couleurMode(m)),
                                          const SizedBox(width: 8),
                                          Text(l10n.modePaiement(m)),
                                        ],
                                      ),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      _modePaiement = v;
                                      _aEteModifie = true;
                                    });
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Section Note interne (Facultatif)
                    CollapsibleFormSection(
                      key: _formController.registerSectionKey(_creation ? 3 : 2),
                      title: 'Note & Observations',
                      icon: Icons.note_alt_rounded,
                      summary: _note.text.trim().isEmpty ? 'Aucune observation (Facultatif)' : _note.text.trim(),
                      status: _noteStatus,
                      isExpanded: _formController.isSectionOpen(_creation ? 3 : 2),
                      onToggle: () => setState(() => _formController.toggleSection(_creation ? 3 : 2)),
                      child: TextField(
                        controller: _note,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: l10n.comNoteOptional,
                          hintText: 'Instructions de livraison, remarques...',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildRecapitulatif(context, total, peutRecevoir, valide),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRecapitulatif(BuildContext context, int total, bool peutRecevoir, bool valide) {
    final l10n = context.l10n;
    final acompteVal = (int.tryParse(_acompteCtrl.text.trim()) ?? 0).clamp(0, total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_lignes.length} article${_lignes.length > 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted, fontSize: 14),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Total à régler', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted, fontSize: 12)),
                Text(
                  montant(context, ref, total),
                  key: const Key('achat-total-recap'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF01226C)),
                ),
              ],
            ),
          ],
        ),
        if (_creation && _modeReglement != _ModeReglement.credit) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.greenSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _modeReglement == _ModeReglement.comptant ? 'Payé comptant (100%)' : 'Acompte versé',
                      style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      montant(context, ref, _modeReglement == _ModeReglement.comptant ? total : acompteVal),
                      style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (_modeReglement == _ModeReglement.acompte) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reste à payer', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
                      Text(
                        montant(context, ref, (total - acompteVal).clamp(0, total)),
                        style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_enCours)
          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
        else ...[
          if (peutRecevoir)
            FilledButton.icon(
              key: const Key('achat-enregistrer-recevoir'),
              onPressed: valide ? () => _enregistrer(recevoir: true) : null,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Confirmer la réception en stock', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )
          else
            FilledButton.icon(
              key: const Key('achat-enregistrer-bottom'),
              onPressed: valide ? () => _enregistrer(recevoir: false) : null,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_creation ? l10n.comSave : 'Enregistrer les modifications', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

/// Quantité, unité et prix d'achat d'une ligne.
class _EditeurLigne extends ConsumerStatefulWidget {
  const _EditeurLigne({required this.produit, required this.ligne, required this.etat});
  final Produit produit;
  final LigneOperation ligne;
  final EtatCommerce etat;

  @override
  ConsumerState<_EditeurLigne> createState() => _EditeurLigneState();
}

class _EditeurLigneState extends ConsumerState<_EditeurLigne> {
  late Qte? _quantite = widget.ligne.quantite;
  late UniteVente _unite = widget.produit.uniteNommee(widget.ligne.unite);
  late final _prixAchat = TextEditingController(text: '${widget.ligne.prixUnitaire}');
  late final _prixVente = TextEditingController(text: '${widget.produit.prixDetail}');
  late final _remise = TextEditingController(text: widget.ligne.remise > 0 ? '${widget.ligne.remise}' : '');

  @override
  void dispose() {
    _prixAchat.dispose();
    _prixVente.dispose();
    _remise.dispose();
    super.dispose();
  }

  void _changerUnite(UniteVente u) {
    if (u.id == _unite.id) return;
    final dernier = widget.etat.dernierPrixAchat(widget.produit.id, u.nom) ?? u.prixAchat;
    setState(() {
      _unite = u;
      if (dernier != null) _prixAchat.text = '$dernier';
      _prixVente.text = '${u.prixDetail}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = widget.produit;
    final prixA = int.tryParse(_prixAchat.text) ?? 0;
    final prixV = int.tryParse(_prixVente.text) ?? 0;
    final remise = int.tryParse(_remise.text.trim()) ?? 0;
    final q = _quantite;
    final dernier = widget.etat.dernierPrixAchat(p.id, _unite.nom);
    final valide = q != null && q.estPositif && (p.venteFractionnee || q.fois(_unite.facteur).estEntier);
    final totalLigne = (q != null && q.estPositif) ? (q.montant(prixA) - remise).clamp(0, 10000000000) : 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProduitImage(produit: p, taille: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nom, style: Theme.of(context).textTheme.titleMedium),
                      if (p.categorieId != null)
                        Text(
                          'Catégorie : ${widget.etat.categories.where((c) => c.id == p.categorieId).firstOrNull?.nom ?? "Inconnue"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ChampQuantite(
              champKey: const Key('ligne-quantite'),
              produit: p,
              uniteInitiale: _unite,
              quantiteInitiale: widget.ligne.quantite,
              autofocus: true,
              onChanged: (q, u) {
                _changerUnite(u);
                setState(() => _quantite = q);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _prixAchat,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Prix d\'ACHAT réel (${_unite.nom})',
                      prefixIcon: const Icon(Icons.download_rounded, color: AppColors.negative),
                      helperText: dernier == null ? 'Jamais acheté' : 'Dernier : ${montant(context, ref, dernier)}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _prixVente,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Prix de VENTE désiré',
                      prefixIcon: const Icon(Icons.upload_rounded, color: AppColors.positive),
                      helperText: 'Actuel : ${montant(context, ref, _unite.prixDetail)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (prixV > 0 && prixA > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (prixV - prixA) > 0 ? AppColors.greenSoft : AppColors.negativeSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      (prixV - prixA) > 0 ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: (prixV - prixA) > 0 ? AppColors.green : AppColors.negative,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Marge brute estimée : ${montant(context, ref, prixV - prixA)} / ${_unite.nom}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: (prixV - prixA) > 0 ? AppColors.green : AppColors.negative,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('ligne-remise'),
              controller: _remise,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Remise obtenue du fournisseur (optionnel)',
                prefixIcon: Icon(Icons.discount_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: valide
                  ? () => Navigator.pop(
                        context,
                        widget.ligne.copyWith(
                          quantite: q,
                          prixUnitaire: prixA,
                          remise: remise,
                          unite: _unite.nom,
                          facteur: _unite.facteur,
                        ),
                      )
                  : null,
              label: const Text('Valider la réception de cet article'),
            ),
          ],
        ),
      ),
    );
  }
}
