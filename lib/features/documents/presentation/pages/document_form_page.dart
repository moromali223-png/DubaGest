import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/forms/unsaved_changes_scope.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../commerce/presentation/widgets/choix_contact.dart';
import '../../../commerce/presentation/widgets/choix_produit.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../entreprise/domain/entities/contexte_session.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart' hide choisirContact;
import '../../domain/entities/document.dart';
import '../providers/documents_providers.dart';
import '../widgets/apercu_document_feuille_a4.dart';
import '../../../services/presentation/widgets/devis_contact_widgets.dart';

final _fmtDate = DateFormat('dd/MM/yyyy');
final _fmtMonnaie = NumberFormat.decimalPattern('fr');

class _LigneDocumentForm {
  _LigneDocumentForm({
    required this.id,
    this.produitId,
    String libelle = '',
    String unite = 'U',
    double quantite = 1,
    this.prixReference,
    this.prixPropose,
    int prixUnitaire = 0,
  })  : libelleCtrl = TextEditingController(text: libelle),
        uniteCtrl = TextEditingController(text: unite),
        quantiteCtrl = TextEditingController(
          text: quantite == quantite.roundToDouble() ? quantite.toInt().toString() : quantite.toString(),
        ),
        prixUnitaireCtrl = TextEditingController(text: prixUnitaire == 0 ? '' : prixUnitaire.toString());

  final String id;
  String? produitId;
  final TextEditingController libelleCtrl;
  final TextEditingController uniteCtrl;
  final TextEditingController quantiteCtrl;
  final TextEditingController prixUnitaireCtrl;

  int? prixReference;
  int? prixPropose;
  int? prixContreProposition;

  String get libelle => libelleCtrl.text.trim();
  set libelle(String val) => libelleCtrl.text = val;

  String get unite => uniteCtrl.text.trim().isEmpty ? 'U' : uniteCtrl.text.trim();
  set unite(String val) => uniteCtrl.text = val;

  double get quantite => double.tryParse(quantiteCtrl.text.trim()) ?? 1.0;
  set quantite(double val) =>
      quantiteCtrl.text = val == val.roundToDouble() ? val.toInt().toString() : val.toString();

  int get prixUnitaire => int.tryParse(prixUnitaireCtrl.text.trim()) ?? 0;
  set prixUnitaire(int val) => prixUnitaireCtrl.text = val == 0 ? '' : val.toString();

  int get montantTotal => (quantite * prixUnitaire).round();
  int get montantReference => ((prixReference ?? prixUnitaire) * quantite).round();
  int get economie => (montantReference - montantTotal).clamp(0, 1000000000);

  void dispose() {
    libelleCtrl.dispose();
    uniteCtrl.dispose();
    quantiteCtrl.dispose();
    prixUnitaireCtrl.dispose();
  }
}


/// Parcours par étapes (Wizard) moderne et épuré pour la création de documents :
/// Devis, Facture client, Bon de commande, Avoir / Note de crédit, Reçu de paiement.
class DocumentFormPage extends ConsumerStatefulWidget {
  const DocumentFormPage({
    super.key,
    this.initialType,
    this.initialContactId,
  });

  final TypeDocument? initialType;
  final String? initialContactId;

  @override
  ConsumerState<DocumentFormPage> createState() => _DocumentFormPageState();
}

class _DocumentFormPageState extends ConsumerState<DocumentFormPage> {
  final _pageController = PageController();
  int _etapeCourante = 0;
  int _modeApercu = 0; // 0 = Fiche récapitulative, 1 = Feuille A4 officielle

  late TypeDocument _typeSelectionne;
  String? _contactId;

  final _titreCtrl = TextEditingController();
  final _referenceMetierCtrl = TextEditingController();
  final _lieuLivraisonCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _remiseCtrl = TextEditingController(text: '0');
  final _acompteCtrl = TextEditingController(text: '0');

  String _statutCommercial = 'a_negocier';

  DateTime _dateDocument = DateTime.now();
  DateTime? _dateEcheance;

  final List<_LigneDocumentForm> _lignes = [];
  bool _enSauvegarde = false;
  bool _aEteModifie = false;

  Color get _couleurTheme => switch (_typeSelectionne) {
        TypeDocument.devis => const Color(0xFF2563EB), // Bleu Cobalt Pro
        TypeDocument.facture => AppColors.green, // Vert Émeraude
        TypeDocument.bonCommande => const Color(0xFFEA580C), // Orange Négociation
        TypeDocument.avoir => const Color(0xFFE11D48), // Rose / Rouge comptable
        TypeDocument.recu => const Color(0xFF10B981), // Menthe Caisse
        TypeDocument.bonTravail => const Color(0xFF0D9488), // Teal
        _ => const Color(0xFF01226C),
      };

  IconData get _iconeTheme => switch (_typeSelectionne) {
        TypeDocument.devis => Icons.request_quote_outlined,
        TypeDocument.facture => Icons.receipt_long_outlined,
        TypeDocument.bonCommande => Icons.shopping_cart_checkout,
        TypeDocument.avoir => Icons.assignment_return_outlined,
        TypeDocument.recu => Icons.receipt_outlined,
        TypeDocument.bonTravail => Icons.build_circle_outlined,
        _ => Icons.description_outlined,
      };

  @override
  void initState() {
    super.initState();
    _typeSelectionne = widget.initialType ?? TypeDocument.facture;
    _contactId = widget.initialContactId;

    // Ligne initiale par défaut
    _lignes.add(_LigneDocumentForm(id: const Uuid().v4(), libelle: '', quantite: 1, prixUnitaire: 0));

    // Valeurs par défaut selon le type
    _initialiserValeursParDefaut(_typeSelectionne);

    for (final c in [_titreCtrl, _referenceMetierCtrl, _lieuLivraisonCtrl, _conditionsCtrl, _notesCtrl, _remiseCtrl, _acompteCtrl]) {
      c.addListener(() {
        if (!_aEteModifie) setState(() => _aEteModifie = true);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titreCtrl.dispose();
    _referenceMetierCtrl.dispose();
    _lieuLivraisonCtrl.dispose();
    _conditionsCtrl.dispose();
    _notesCtrl.dispose();
    _remiseCtrl.dispose();
    _acompteCtrl.dispose();
    for (final l in _lignes) {
      l.dispose();
    }
    super.dispose();
  }

  void _initialiserValeursParDefaut(TypeDocument type) {
    switch (type) {
      case TypeDocument.facture:
        _titreCtrl.text = 'Facture de vente';
        _conditionsCtrl.text = 'Paiement à réception.';
        _dateEcheance = DateTime.now().add(const Duration(days: 30));
      case TypeDocument.devis:
        _titreCtrl.text = 'Proposition commerciale';
        _conditionsCtrl.text = 'Offre valable 30 jours. Acompte de 30% à la commande.';
        _dateEcheance = DateTime.now().add(const Duration(days: 30));
      case TypeDocument.bonCommande:
        _titreCtrl.text = 'Bon de commande fournisseur';
        _conditionsCtrl.text = 'Règlement à réception après contrôle de conformité.';
        _dateEcheance = DateTime.now().add(const Duration(days: 7));
      case TypeDocument.bonTravail:
        _titreCtrl.text = 'Ordre de travail / intervention';
        _conditionsCtrl.text = 'Validation technique des travaux.';
      case TypeDocument.avoir:
        _titreCtrl.text = 'Avoir / Note de crédit';
        _conditionsCtrl.text = 'À déduire de votre prochaine facture.';
        _dateEcheance = null;
      case TypeDocument.recu:
        _titreCtrl.text = 'Reçu de paiement';
        _conditionsCtrl.text = 'Règlement perçu et validé.';
        _dateEcheance = null;
      default:
        break;
    }
  }

  int get _sousTotalBrut => _lignes.fold(0, (total, l) => total + l.montantTotal);
  int get _totalReference => _lignes.fold(0, (total, l) => total + l.montantReference);
  int get _economieTotale => _lignes.fold(0, (total, l) => total + l.economie);
  int get _remise => int.tryParse(_remiseCtrl.text.trim()) ?? 0;
  int get _acompte => int.tryParse(_acompteCtrl.text.trim()) ?? 0;
  int get _totalNet => (_sousTotalBrut - _remise).clamp(0, 10000000000);
  int get _soldePrevisionnel => (_totalNet - _acompte).clamp(0, 10000000000);

  void _ajouterLigne() {
    setState(() {
      _lignes.add(_LigneDocumentForm(id: const Uuid().v4(), libelle: '', quantite: 1, prixUnitaire: 0));
      _aEteModifie = true;
    });
  }

  void _supprimerLigne(int index) {
    if (_lignes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le document doit comporter au moins un article.')),
      );
      return;
    }
    setState(() {
      final supprimee = _lignes.removeAt(index);
      supprimee.dispose();
      _aEteModifie = true;
    });
  }

  Future<void> _selectionnerContact(BuildContext context) async {
    final relation = _typeSelectionne == TypeDocument.bonCommande
        ? RelationContact.fournisseur
        : RelationContact.client;
    final c = await choisirContact(context, relation);
    if (c != null && mounted) {
      setState(() {
        _contactId = c.id;
        _aEteModifie = true;
      });
    }
  }

  Future<void> _associerProduitALigne(int index) async {
    final produit = await choisirProduit(
      context,
      titre: _typeSelectionne == TypeDocument.bonCommande
          ? 'Choisir le produit pour l\'article #${index + 1}'
          : 'Choisir le produit / prestation #${index + 1}',
    );
    if (produit != null && mounted) {
      final prix = _typeSelectionne == TypeDocument.bonCommande
          ? (produit.prixAchat ?? produit.prixDetail)
          : produit.prixDetail;
      setState(() {
        _lignes[index]
          ..produitId = produit.id
          ..libelle = produit.nom
          ..unite = produit.uniteBase
          ..prixReference = prix
          ..prixPropose = prix
          ..prixUnitaire = prix;
        _aEteModifie = true;
      });
    }
  }

  Future<void> _choisirDuCatalogue(BuildContext context) async {
    final produit = await choisirProduit(
      context,
      titre: _typeSelectionne == TypeDocument.bonCommande
          ? 'Choisir un produit à commander'
          : 'Choisir un produit / prestation',
    );
    if (produit != null && mounted) {
      setState(() {
        final prix = _typeSelectionne == TypeDocument.bonCommande
            ? (produit.prixAchat ?? produit.prixDetail)
            : produit.prixDetail;

        // Si la seule ligne existante est vide, on la remplace
        if (_lignes.length == 1 && _lignes.first.libelle.isEmpty && _lignes.first.prixUnitaire == 0) {
          _lignes.first
            ..produitId = produit.id
            ..libelle = produit.nom
            ..unite = produit.uniteBase
            ..quantite = 1
            ..prixReference = prix
            ..prixPropose = prix
            ..prixUnitaire = prix;
        } else {
          _lignes.add(_LigneDocumentForm(
            id: const Uuid().v4(),
            produitId: produit.id,
            libelle: produit.nom,
            unite: produit.uniteBase,
            quantite: 1,
            prixReference: prix,
            prixPropose: prix,
            prixUnitaire: prix,
          ));
        }
        _aEteModifie = true;
      });
    }
  }

  void _avancerEtape() {
    if (_etapeCourante == 0) {
      // Validation étape 0 : Contact requis
      if (_contactId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.negative,
            content: Text(
              _typeSelectionne == TypeDocument.bonCommande
                  ? 'Veuillez sélectionner un fournisseur avant de continuer.'
                  : 'Veuillez sélectionner un client / destinataire avant de continuer.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
        return;
      }
      if (_titreCtrl.text.trim().isEmpty) {
        _titreCtrl.text = _libelleType(_typeSelectionne);
      }
    } else if (_etapeCourante == 1) {
      // Validation étape 1 : Au moins un article valide
      final aArticleValide = _lignes.any((l) => l.libelle.trim().isNotEmpty && l.quantite > 0);
      if (!aArticleValide) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.negative,
            content: Text(
              'Veuillez renseigner au moins un article avec sa désignation et sa quantité.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
        return;
      }
    }

    if (_etapeCourante < 3) {
      _pageController.animateToPage(
        _etapeCourante + 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _reculerEtape() {
    if (_etapeCourante > 0) {
      _pageController.animateToPage(
        _etapeCourante - 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  String _nomEtape(int etape) => switch (etape) {
        0 => 'Destinataire',
        1 => 'Articles',
        2 => 'Règlement',
        3 => 'Aperçu',
        _ => '',
      };

  String _titreBoutonSuivant() => switch (_etapeCourante) {
        0 => 'Suivant : Articles',
        1 => 'Suivant : Règlement',
        2 => 'Suivant : Aperçu',
        _ => 'Valider',
      };

  Future<void> _emettreDocument({required bool estBrouillon}) async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;

    final contacts = ref.read(contactsParIdProvider).value ?? const {};
    final contact = _contactId != null ? contacts[_contactId] : null;

    final lignesValides = _lignes.where((l) => l.libelle.trim().isNotEmpty && l.quantite > 0).toList();
    if (lignesValides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le document doit comporter au moins un article.')),
      );
      return;
    }

    setState(() => _enSauvegarde = true);
    try {
      final profil = await ref.read(profilEntrepriseProvider.future).catchError((_) => null);
      final appareilId = ref.read(appareilIdProvider);
      final devise = profil?.devise ?? ctx.entreprise?.devise ?? 'XOF';

      final contenu = <String, dynamic>{
        'entreprise': {
          'nom': profil?.nom ?? ctx.entreprise!.nom,
          'telephone': profil?.telephone,
          'adresse': profil?.adresse,
          'ville': profil?.ville,
          'identifiant_fiscal': profil?.identifiantFiscal,
          'registre_commerce': profil?.registreCommerce,
          'devise': devise,
        },
        'contact': contact == null
            ? null
            : {
                'nom': contact.nomAffiche,
                'telephone': contact.telephone,
                'email': contact.email,
                'adresse': contact.adresse,
              },
        'titre': _titreCtrl.text.trim().isEmpty ? _typeSelectionne.code : _titreCtrl.text.trim(),
        'reference_metier': _referenceMetierCtrl.text.trim().isEmpty ? null : _referenceMetierCtrl.text.trim(),
        'lieu_livraison': _lieuLivraisonCtrl.text.trim().isEmpty ? null : _lieuLivraisonCtrl.text.trim(),
        'date_document': _dateDocument.toUtc().toIso8601String(),
        'date_echeance': _dateEcheance?.toUtc().toIso8601String(),
        'date_validite': _typeSelectionne == TypeDocument.devis ? _dateEcheance?.toUtc().toIso8601String() : null,
        'statut': estBrouillon
            ? 'BROUILLON'
            : (_typeSelectionne == TypeDocument.bonCommande
                ? (_statutCommercial == 'confirme' ? 'CONFIRME' : 'EMIS')
                : (_soldePrevisionnel == 0 ? 'PAYE' : 'EMIS')),
        'statut_commercial': _typeSelectionne == TypeDocument.bonCommande ? _statutCommercial : null,
        'sous_total': _sousTotalBrut,
        'total_reference': _typeSelectionne == TypeDocument.bonCommande ? _totalReference : null,
        'economie_totale': _typeSelectionne == TypeDocument.bonCommande ? _economieTotale : null,
        'remise': _remise,
        'total': _totalNet,
        'acompte': _acompte,
        'reste': _soldePrevisionnel,
        'conditions': _conditionsCtrl.text.trim().isEmpty ? null : _conditionsCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'lignes': [
          for (final l in lignesValides)
            {
              if (l.produitId != null) 'produit_id': l.produitId,
              'libelle': l.libelle.trim(),
              'unite': l.unite.trim().isEmpty ? 'U' : l.unite.trim(),
              'quantite': l.quantite,
              if (l.prixReference != null) 'prix_reference': l.prixReference,
              if (l.prixPropose != null) 'prix_propose': l.prixPropose,
              if (l.prixContreProposition != null) 'prix_contre_proposition': l.prixContreProposition,
              'prix_unitaire': l.prixUnitaire,
              'montant': l.montantTotal,
              if (l.economie > 0) 'economie': l.economie,
            }
        ],
      };

      final doc = await ref.read(emettreDocumentProvider).call(
            ctx,
            type: _typeSelectionne,
            origineType: 'MANUEL',
            contactId: _contactId,
            montant: _totalNet,
            contenu: contenu,
            appareilId: appareilId,
            langue: profil?.langueDocuments ?? 'fr',
          );

      if (mounted) {
        _aEteModifie = false;
        ref.invalidate(documentsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _couleurTheme,
            content: Text(
              estBrouillon ? 'Brouillon enregistré avec succès.' : 'Document ${doc.numero} émis avec succès !',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
        context.pushReplacement(Routes.document(doc.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enSauvegarde = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contexteActifProvider);
    final contacts = ref.watch(contactsParIdProvider).value ?? const {};
    final contactActuel = _contactId != null ? contacts[_contactId] : null;

    final activites = ctx?.activites ?? const [];
    final hasCommerce = activites.any((a) => a.activite == ActiviteCode.commerce && a.estActive);
    final hasServices = activites.any((a) => a.activite == ActiviteCode.services && a.estActive);

    final typesDisponibles = [
      if (hasCommerce || hasServices) TypeDocument.facture,
      if (hasServices || hasCommerce) TypeDocument.devis,
      if (hasCommerce) TypeDocument.bonCommande,
      if (hasCommerce || hasServices) TypeDocument.avoir,
      TypeDocument.recu,
      if (hasServices) TypeDocument.bonTravail,
    ];

    return UnsavedChangesScope(
      hasUnsavedChanges: _aEteModifie && !_enSauvegarde,
      child: PopScope(
        canPop: _etapeCourante == 0 && !_aEteModifie,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_etapeCourante > 0) {
            _reculerEtape();
          } else {
            Navigator.of(context).maybePop();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            elevation: 0,
            leading: IconButton(
              icon: Icon(_etapeCourante > 0 ? Icons.arrow_back_rounded : Icons.close_rounded),
              tooltip: _etapeCourante > 0 ? 'Étape précédente' : 'Quitter',
              onPressed: _reculerEtape,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nouveau ${_libelleType(_typeSelectionne)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                Text(
                  'Étape ${_etapeCourante + 1}/4 : ${_nomEtape(_etapeCourante)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _couleurTheme.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconeTheme, size: 14, color: _couleurTheme),
                    const SizedBox(width: 6),
                    Text(
                      _libelleType(_typeSelectionne).toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _couleurTheme, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _buildStepperBar(),
            ),
          ),
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _etapeCourante = i),
            children: [
              // ÉTAPE 0 : DESTINATAIRE & INFORMATIONS GÉNÉRALES
              _buildEtape0Infos(contactActuel, typesDisponibles),

              // ÉTAPE 1 : ARTICLES & PRESTATIONS
              _buildEtape1Articles(),

              // ÉTAPE 2 : RÈGLEMENT & CONDITIONS
              _buildEtape2Reglement(),

              // ÉTAPE 3 : RÉCAPITULATIF & APERÇU OFFICIEL
              _buildEtape3Recapitulatif(ctx, contactActuel),
            ],
          ),
          bottomNavigationBar: _buildDockedFooter(),
        ),
      ),
    );
  }

  /// Barre de progression du Stepper en haut de l'écran (anti-overflow horizontal)
  Widget _buildStepperBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 4; i++) ...[
                InkWell(
                  onTap: i < _etapeCourante ? () => _pageController.jumpToPage(i) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: i == _etapeCourante
                              ? _couleurTheme
                              : (i < _etapeCourante ? AppColors.green : const Color(0xFFE2E8F0)),
                          child: i < _etapeCourante
                              ? const Icon(Icons.check, size: 12, color: Colors.white)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: i == _etapeCourante ? Colors.white : AppColors.muted,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _nomEtape(i),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: i == _etapeCourante ? FontWeight.bold : FontWeight.w500,
                            color: i == _etapeCourante
                                ? AppColors.ink
                                : (i < _etapeCourante ? AppColors.ink : AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < 3)
                  Container(
                    width: 14,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: i < _etapeCourante ? AppColors.green : const Color(0xFFE2E8F0),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Footer fixé au bas de l'écran (Docked Action Bar)
  Widget _buildDockedFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_etapeCourante > 0)
              OutlinedButton.icon(
                onPressed: _reculerEtape,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(_etapeCourante == 3 ? 'Retour' : 'Précédent'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: _etapeCourante == 3 ? 10 : 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                label: const Text('Annuler', style: TextStyle(color: AppColors.muted)),
              ),
            const SizedBox(width: 8),
            if (_etapeCourante < 3) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _avancerEtape,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    _titreBoutonSuivant(),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _couleurTheme,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              OutlinedButton(
                onPressed: _enSauvegarde ? null : () => _emettreDocument(estBrouillon: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Brouillon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _enSauvegarde ? null : () => _emettreDocument(estBrouillon: false),
                  icon: _enSauvegarde
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    _enSauvegarde ? 'Émission...' : 'Émettre',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _couleurTheme,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ÉTAPE 0 : INFORMATIONS & DESTINATAIRE
  // ===========================================================================
  Widget _buildEtape0Infos(Contact? contactActuel, List<TypeDocument> typesDisponibles) {
    final estBonCommande = _typeSelectionne == TypeDocument.bonCommande;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ResponsiveBody(
        maxWidth: 800,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sélecteur de type rapide
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in typesDisponibles) ...[
                    ChoiceChip(
                      avatar: Icon(
                        _iconeType(t),
                        size: 16,
                        color: _typeSelectionne == t ? Colors.white : AppColors.muted,
                      ),
                      label: Text(_libelleType(t)),
                      selected: _typeSelectionne == t,
                      selectedColor: _couleurTheme,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _typeSelectionne == t ? Colors.white : AppColors.ink,
                      ),
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _typeSelectionne = t;
                            _initialiserValeursParDefaut(t);
                            _aEteModifie = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bannière explicative
            _construireBanniereContexte(),
            const SizedBox(height: 16),

            // CARTE DESTINATAIRE / CLIENT OU FOURNISSEUR
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          estBonCommande ? Icons.storefront_outlined : Icons.person_outline,
                          size: 18,
                          color: _couleurTheme,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          estBonCommande ? 'FOURNISSEUR CONCERNÉ *' : 'CLIENT / DESTINATAIRE *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: _couleurTheme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (contactActuel != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _couleurTheme.withValues(alpha: 0.12),
                              foregroundColor: _couleurTheme,
                              child: Text(
                                contactActuel.nomAffiche.isNotEmpty
                                    ? contactActuel.nomAffiche[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contactActuel.nomAffiche,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                  if (contactActuel.telephone != null && contactActuel.telephone!.isNotEmpty)
                                    Text(
                                      contactActuel.telephone!,
                                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                                    ),
                                  if (contactActuel.adresse != null && contactActuel.adresse!.isNotEmpty)
                                    Text(
                                      contactActuel.adresse!,
                                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                    ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _selectionnerContact(context),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              child: const Text('Changer'),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectionnerContact(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.person_search_rounded, size: 30, color: _couleurTheme),
                                      const SizedBox(height: 6),
                                      Text(
                                        estBonCommande
                                            ? 'Choisir fournisseur'
                                            : 'Choisir un client',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Rechercher existant',
                                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final relation = estBonCommande ? RelationContact.fournisseur : RelationContact.client;
                                final nouveau = await DialogueNouveauContactDevis.afficher(
                                  context,
                                  relation: relation,
                                );
                                if (nouveau != null && mounted) {
                                  setState(() {
                                    _contactId = nouveau.id;
                                    _aEteModifie = true;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.greenSoft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.person_add_rounded, size: 30, color: AppColors.green),
                                      const SizedBox(height: 6),
                                      Text(
                                        estBonCommande ? '+ Nouveau fournisseur' : '+ Nouveau client',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.green),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Création immédiate',
                                        style: TextStyle(fontSize: 11, color: AppColors.green),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CARTE OBJET & RÉFÉRENCES
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IDENTIFICATION DU DOCUMENT',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.muted, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titreCtrl,
                      decoration: InputDecoration(
                        labelText: 'Objet / Intitulé du document *',
                        hintText: 'Ex: Vente matériel bureau, Réfection toiture...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _referenceMetierCtrl,
                      decoration: InputDecoration(
                        labelText: 'Référence externe / N° Devis lié (facultatif)',
                        hintText: 'Ex: DEV-2026-0042, BC-FOURN-09',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    if (estBonCommande) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lieuLivraisonCtrl,
                        decoration: InputDecoration(
                          labelText: 'Lieu de livraison prévu',
                          hintText: 'Ex: Dépôt principal, Boutique centrale...',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CARTE DATES CLÉS
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CALENDRIER ET ÉCHÉANCES',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.muted, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _dateDocument,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (d != null) setState(() => _dateDocument = d);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Date d\'émission', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.muted),
                                      const SizedBox(width: 6),
                                      Text(_fmtDate.format(_dateDocument), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _dateEcheance ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (d != null) setState(() => _dateEcheance = d);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _typeSelectionne == TypeDocument.devis ? 'Validité de l\'offre' : 'Date d\'échéance',
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.event_available_outlined, size: 14, color: AppColors.muted),
                                      const SizedBox(width: 6),
                                      Text(
                                        _dateEcheance != null ? _fmtDate.format(_dateEcheance!) : 'Aucune',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (estBonCommande) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STATUT DE LA NÉGOCIATION FOURNISSEUR',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFEA580C), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final st in ['a_negocier', 'envoye', 'confirme'])
                            ChoiceChip(
                              label: Text(_statutLabel(st)),
                              selected: _statutCommercial == st,
                              selectedColor: const Color(0xFFEA580C),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _statutCommercial == st ? Colors.white : AppColors.ink,
                              ),
                              onSelected: (sel) {
                                if (sel) setState(() => _statutCommercial = st);
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ÉTAPE 1 : ARTICLES & PRESTATIONS
  // ===========================================================================
  Widget _buildEtape1Articles() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ResponsiveBody(
        maxWidth: 800,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre récapitulative haute
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 18, color: _couleurTheme),
                      const SizedBox(width: 8),
                      Text(
                        '${_lignes.length} article${_lignes.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Total HT : ', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      Text(
                        '${_fmtMonnaie.format(_sousTotalBrut)} FCFA',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _couleurTheme),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Boutons d'ajout
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _choisirDuCatalogue(context),
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('Catalogue produits'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _ajouterLigne,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Ligne libre'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cartes d'articles
            for (int i = 0; i < _lignes.length; i++) ...[
              _construireLigneItem(i),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ÉTAPE 2 : RÈGLEMENT, REMISES & CONDITIONS
  // ===========================================================================
  Widget _buildEtape2Reglement() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ResponsiveBody(
        maxWidth: 800,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CARTE REMISE & ACOMPTE
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AJUSTEMENTS FINANCIERS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.muted, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _remiseCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: 'Remise commerciale',
                              suffixText: 'FCFA',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _acompteCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: 'Acompte déjà perçu',
                              suffixText: 'FCFA',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Synthèse financière en grille
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Sous-total brut :', style: TextStyle(color: AppColors.muted)),
                              Text('${_fmtMonnaie.format(_sousTotalBrut)} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (_remise > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Remise déduite :', style: TextStyle(color: Color(0xFFE11D48))),
                                Text('- ${_fmtMonnaie.format(_remise)} FCFA', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFE11D48))),
                              ],
                            ),
                          ],
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL NET :', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                              Text(
                                '${_fmtMonnaie.format(_totalNet)} FCFA',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _couleurTheme),
                              ),
                            ],
                          ),
                          if (_acompte > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Acompte versé :', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
                                Text('${_fmtMonnaie.format(_acompte)} FCFA', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Reste à régler :', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                                Text(
                                  '${_fmtMonnaie.format(_soldePrevisionnel)} FCFA',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEA580C)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CARTE CONDITIONS DE RÈGLEMENT
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CONDITIONS DE PAIEMENT',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.muted, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final condition in [
                          'Paiement à réception',
                          '30 jours net',
                          'Acompte 30% à la commande',
                          'Paiement comptant',
                        ])
                          ActionChip(
                            label: Text(condition, style: const TextStyle(fontSize: 12)),
                            onPressed: () => setState(() => _conditionsCtrl.text = condition),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _conditionsCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Conditions applicables',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CARTE NOTES COMPLÉMENTAIRES
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NOTES & MENTIONS LÉGALES',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.muted, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notes visibles sur le document (coordonnées bancaires, merci...)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
    );
  }

  // ===========================================================================
  // ÉTAPE 3 : RÉCAPITULATIF & APERÇU OFFICIEL
  // ===========================================================================
  Widget _buildEtape3Recapitulatif(ContexteSession? ctx, Contact? contactActuel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ResponsiveBody(
        maxWidth: 850,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sélecteur Vue Résumé vs Aperçu A4
            Center(
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.receipt_long_outlined),
                    label: Text('Fiche récapitulative'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.print_outlined),
                    label: Text('Aperçu feuille A4'),
                  ),
                ],
                selected: {_modeApercu},
                onSelectionChanged: (s) => setState(() => _modeApercu = s.first),
              ),
            ),
            const SizedBox(height: 16),

            if (_modeApercu == 1) ...[
              // VUE 1 : APERÇU A4 DIRECT
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(16),
                child: _construireApercu(ctx, contactActuel),
              ),
            ] else ...[
              // VUE 0 : FICHE RÉCAPITULATIVE ÉLÉGANTE
              Card(
                elevation: 0,
                color: _couleurTheme.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _couleurTheme.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _libelleType(_typeSelectionne).toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                    color: _couleurTheme,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _titreCtrl.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _dateEcheance != null ? 'Échéance : ${_fmtDate.format(_dateEcheance!)}' : 'Sans échéance',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'MONTANT TOTAL NET :',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.muted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_fmtMonnaie.format(_totalNet)} FCFA',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _couleurTheme),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // DESTINATAIRE RÉCAPITULATIF
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DESTINATAIRE DU DOCUMENT',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.muted, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        contactActuel?.nomAffiche ?? 'Non spécifié',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      if (contactActuel?.telephone != null && contactActuel!.telephone!.isNotEmpty)
                        Text(contactActuel.telephone!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      if (contactActuel?.adresse != null && contactActuel!.adresse!.isNotEmpty)
                        Text(contactActuel.adresse!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // LISTE DES ARTICLES RÉCAPITULATIVE
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ARTICLES & DÉSIGNATIONS (${_lignes.length})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.muted, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),
                      for (int i = 0; i < _lignes.length; i++) ...[
                        Row(
                          children: [
                            Text('${i + 1}. ', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                _lignes[i].libelle.isNotEmpty ? _lignes[i].libelle : 'Article sans nom',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              '${_lignes[i].quantite} ${_lignes[i].unite} × ${_fmtMonnaie.format(_lignes[i].prixUnitaire)} F',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${_fmtMonnaie.format(_lignes[i].montantTotal)} F',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        if (i < _lignes.length - 1) const Divider(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // BILAN FINANCIER
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sous-total brut'),
                          Text('${_fmtMonnaie.format(_sousTotalBrut)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (_remise > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Remise'),
                            Text('- ${_fmtMonnaie.format(_remise)} FCFA', style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Net à payer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          Text(
                            '${_fmtMonnaie.format(_totalNet)} FCFA',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _couleurTheme),
                          ),
                        ],
                      ),
                      if (_acompte > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Acompte versé', style: TextStyle(color: AppColors.green)),
                            Text('${_fmtMonnaie.format(_acompte)} FCFA', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Reste dû', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                            Text(
                              '${_fmtMonnaie.format(_soldePrevisionnel)} FCFA',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEA580C)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _construireApercu(ContexteSession? ctx, Contact? contact) {
    if (ctx == null) return const SizedBox.shrink();

    final logo = ref.watch(logoEntrepriseProvider).value;
    final profil = ref.watch(profilEntrepriseProvider).value;
    final lignesValides = _lignes.where((l) => l.libelle.trim().isNotEmpty && l.quantite > 0).toList();

    // Création d'un document factice pour l'aperçu temps réel
    final documentSimule = Document(
      id: 'preview',
      entrepriseId: ctx.entreprise!.id,
      type: _typeSelectionne,
      numero: 'PREVIEW-000',
      blocId: 'preview',
      sequence: 0,
      langue: 'fr',
      date: _dateDocument,
      montant: _totalNet,
      origineType: 'MANUEL',
      contenu: {
        'entreprise': {
          'nom': profil?.nom ?? ctx.entreprise!.nom,
          'telephone': profil?.telephone,
          'adresse': profil?.adresse,
          'ville': profil?.ville,
          'identifiant_fiscal': profil?.identifiantFiscal,
          'registre_commerce': profil?.registreCommerce,
          'devise': profil?.devise ?? ctx.entreprise?.devise ?? 'XOF',
        },
        'contact': contact == null
            ? null
            : {
                'nom': contact.nomAffiche,
                'telephone': contact.telephone,
                'adresse': contact.adresse,
              },
        'titre': _titreCtrl.text,
        'reference_metier': _referenceMetierCtrl.text,
        'date_echeance': _dateEcheance?.toIso8601String(),
        'sous_total': _sousTotalBrut,
        'remise': _remise,
        'acompte': _acompte,
        'reste': _soldePrevisionnel,
        'conditions': _conditionsCtrl.text,
        'notes': _notesCtrl.text,
        'lignes': [
          for (final l in lignesValides)
            {
              'libelle': l.libelle,
              'quantite': l.quantite,
              'prix_unitaire': l.prixUnitaire,
              'montant': l.montantTotal,
            }
        ],
      },
    );

    return ApercuDocumentFeuilleA4(
      document: documentSimule,
      logo: logo,
      padding: EdgeInsets.zero,
    );
  }

  Widget _construireBanniereContexte() {
    return switch (_typeSelectionne) {
      TypeDocument.bonCommande => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDBA74)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Color(0xFFEA580C), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bon de commande fournisseur : ce document commercial officiel sert à proposer vos tarifs et négocier. Il ne modifie pas votre stock et ne génère aucune dette avant la réception physique dans le module Achats.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF9A3412), height: 1.3),
                ),
              ),
            ],
          ),
        ),
      TypeDocument.devis => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.request_quote_outlined, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Devis & Offre de prix : chiffrage sans engagement comptable. Dès accord du client, convertissez-le en un clic en facture officielle.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF), height: 1.3),
                ),
              ),
            ],
          ),
        ),
      TypeDocument.avoir => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECDD3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.assignment_return_outlined, color: Color(0xFFE11D48), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Avoir / Note de crédit : document officiel rectificatif annulant partiellement ou totalement une facture client suite à un retour ou geste commercial.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF9F1239), height: 1.3),
                ),
              ),
            ],
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _construireLigneItem(int index) {
    final ligne = _lignes[index];
    final estBonCommande = _typeSelectionne == TypeDocument.bonCommande;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. En-tête : Badge Article, Bouton Catalogue et Bouton Supprimer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _couleurTheme.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 14, color: _couleurTheme),
                    const SizedBox(width: 6),
                    Text(
                      'Article #${index + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _couleurTheme),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _associerProduitALigne(index),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                    label: const Text('Catalogue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: _couleurTheme,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 22, color: AppColors.negative),
                    tooltip: 'Supprimer cet article',
                    onPressed: () => _supprimerLigne(index),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Désignation / Description complète et spacieuse
          TextFormField(
            controller: ligne.libelleCtrl,
            minLines: 1,
            maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            decoration: InputDecoration(
              labelText: estBonCommande ? 'Marchandise commandée *' : 'Désignation / Article *',
              hintText: estBonCommande ? 'Ex: Riz brisé 50kg...' : 'Nom ou description du produit / service',
              prefixIcon: Icon(Icons.edit_note_rounded, color: _couleurTheme),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded, size: 20),
                tooltip: 'Choisir depuis le catalogue',
                onPressed: () => _associerProduitALigne(index),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _couleurTheme, width: 1.8),
              ),
            ),
            onChanged: (v) {
              if (!_aEteModifie) setState(() => _aEteModifie = true);
            },
          ),
          const SizedBox(height: 12),

          // 3. Rangée Quantité et Unité
          Row(
            children: [
              // Quantité avec Stepper tactile
              Expanded(
                flex: 5,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.muted),
                        onPressed: () {
                          if (ligne.quantite > 1) {
                            setState(() {
                              ligne.quantite -= 1;
                              _aEteModifie = true;
                            });
                          }
                        },
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: ligne.quantiteCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Qté',
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (v) {
                            setState(() {
                              _aEteModifie = true;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.muted),
                        onPressed: () {
                          setState(() {
                            ligne.quantite += 1;
                            _aEteModifie = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Unité
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: ligne.uniteCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Unité',
                    hintText: 'U, kg...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _couleurTheme, width: 1.8),
                    ),
                  ),
                  onChanged: (v) {
                    if (!_aEteModifie) setState(() => _aEteModifie = true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Prix Unitaire
          TextFormField(
            controller: ligne.prixUnitaireCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            decoration: InputDecoration(
              labelText: estBonCommande ? 'Prix unitaire proposé' : 'Prix unitaire',
              hintText: '0',
              suffixText: 'FCFA',
              prefixIcon: const Icon(Icons.payments_outlined, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _couleurTheme, width: 1.8),
              ),
            ),
            onChanged: (v) {
              setState(() {
                final pu = int.tryParse(v.trim()) ?? 0;
                ligne.prixPropose ??= pu;
                _aEteModifie = true;
              });
            },
          ),

          if (estBonCommande) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: (ligne.prixReference ?? ligne.prixUnitaire).toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Prix catalogue référence',
                      suffixText: 'FCFA',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {
                        ligne.prixReference = int.tryParse(v.trim());
                        _aEteModifie = true;
                      });
                    },
                  ),
                ),
                if (ligne.economie > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '-${_fmtMonnaie.format(ligne.economie)} F économisés',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.green),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),

          // 5. Total de la ligne mis en valeur
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _couleurTheme.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total de la ligne :',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
                Text(
                  ligne.prixUnitaire == 0 && estBonCommande
                      ? 'À déterminer'
                      : '${_fmtMonnaie.format(ligne.montantTotal)} FCFA',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: ligne.prixUnitaire == 0 && estBonCommande ? const Color(0xFFEA580C) : _couleurTheme,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconeType(TypeDocument t) => switch (t) {
        TypeDocument.devis => Icons.request_quote_outlined,
        TypeDocument.facture => Icons.receipt_long_outlined,
        TypeDocument.bonCommande => Icons.shopping_cart_checkout,
        TypeDocument.avoir => Icons.assignment_return_outlined,
        TypeDocument.recu => Icons.receipt_outlined,
        TypeDocument.bonTravail => Icons.build_circle_outlined,
        TypeDocument.quittance => Icons.home_work_outlined,
        TypeDocument.contrat => Icons.handshake_outlined,
      };

  String _statutLabel(String code) => switch (code) {
        'brouillon' => 'Brouillon',
        'a_negocier' => 'À négocier',
        'envoye' => 'Envoyé',
        'contre_proposition' => 'Contre-prop.',
        'confirme' => 'Confirmé',
        _ => code,
      };

  String _libelleType(TypeDocument t) => switch (t) {
        TypeDocument.facture => 'Facture',
        TypeDocument.devis => 'Devis',
        TypeDocument.bonCommande => 'Bon de commande',
        TypeDocument.bonTravail => 'Ordre de travail',
        TypeDocument.quittance => 'Quittance',
        TypeDocument.contrat => 'Contrat',
        TypeDocument.avoir => 'Avoir',
        TypeDocument.recu => 'Reçu',
      };
}
