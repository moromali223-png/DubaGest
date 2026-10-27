import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/forms/forms.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../finances/domain/entities/finances.dart' as fin;
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../utilisateurs/domain/entities/membre.dart';
import '../../../utilisateurs/presentation/providers/membres_providers.dart';
import '../../domain/entities/prestation.dart';
import '../../domain/entities/service_catalogue.dart';
import '../services_providers.dart';
import '../widgets/devis_contact_widgets.dart';
import '../widgets/prestation_photos_section.dart';

enum _TypeLieuIntervention {
  surSite('Sur site client / À domicile', Icons.home_repair_service_outlined),
  atelier('En atelier / Nos locaux', Icons.storefront_outlined);

  const _TypeLieuIntervention(this.libelle, this.icone);
  final String libelle;
  final IconData icone;
}

/// Formulaire dédié de planification d'intervention rapide pour l'agenda/planning.
///
/// Contrairement à PrestationFormPage (qui est un dossier technique complet avec chiffrage
/// comptable, pièces et gabarit métier), cet écran se concentre sur :
/// 1. La date et le créneau horaire (heure début + durée estimée -> heure fin calculée)
/// 2. Le client et le lieu d'intervention (sur site ou atelier)
/// 3. L'objet / motif d'intervention avec suggestions instantanées
/// 4. L'attribution au technicien et l'urgence
/// 5. Les consignes d'accès / notes terrain
class PlanningInterventionFormPage extends ConsumerStatefulWidget {
  const PlanningInterventionFormPage({
    super.key,
    this.initialDate,
    this.initialContactId,
  });

  final String? initialDate;
  final String? initialContactId;

  @override
  ConsumerState<PlanningInterventionFormPage> createState() => _PlanningInterventionFormPageState();
}

class _PlanningInterventionFormPageState extends ConsumerState<PlanningInterventionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _smartFormController = SmartFormController();

  // Champs de saisie
  final _titreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _adresseLieuCtrl = TextEditingController();
  final _consignesAccesCtrl = TextEditingController();
  final _montantCtrl = TextEditingController(text: '0');

  // État temporel
  late DateTime _dateIntervention;
  TimeOfDay _heureDebut = const TimeOfDay(hour: 9, minute: 0);
  int _dureeMinutes = 60; // 1 heure par défaut

  // Paramètres métier & finances
  String? _contactId;
  String? _responsableId;
  _TypeLieuIntervention _typeLieu = _TypeLieuIntervention.surSite;
  PrioritePrestation _priorite = PrioritePrestation.normale;
  ServiceCatalogue? _serviceCatalogueAssocie;
  bool _encaisserImmediat = false;
  fin.ModePaiement _modePaiement = fin.ModePaiement.especes;
  final List<PhotoPrestation> _photos = [];

  int _etape = 1; // 1 = Créneau & Client, 2 = Détails & Intervenant
  bool _envoi = false;

  static const _motifsFrequents = [
    '🔍 Diagnostic / Panne',
    '⚡ Dépannage urgent',
    '🛠️ Installation / Pose',
    '🔧 Entretien / Révision',
    '📏 Prise de mesures',
    '📦 Livraison / Pose',
    '✨ Nettoyage / Finition',
  ];

  static const _dureesRapides = [
    (label: '30 min', minutes: 30),
    (label: '45 min', minutes: 45),
    (label: '1 h', minutes: 60),
    (label: '1h 30', minutes: 90),
    (label: '2 h', minutes: 120),
    (label: '3 h', minutes: 180),
    (label: '4 h (1/2 j)', minutes: 240),
    (label: '8 h (1 j)', minutes: 480),
    (label: '12 h', minutes: 720),
    (label: '24 h (1 j+)', minutes: 1440),
  ];

  @override
  void initState() {
    super.initState();
    _contactId = widget.initialContactId;
    _titreCtrl.text = 'Intervention';

    if (widget.initialDate != null) {
      final parsed = DateTime.tryParse(widget.initialDate!);
      _dateIntervention = parsed ?? DateTime.now();
    } else {
      _dateIntervention = DateTime.now();
    }

    // Heure par défaut intelligente (prochaine heure pleine ou 9h)
    final now = DateTime.now();
    if (DateUtils.isSameDay(_dateIntervention, now)) {
      final prochaineHeure = now.minute > 30 ? (now.hour + 1) % 24 : now.hour;
      final minute = now.minute > 30 ? 0 : 30;
      _heureDebut = TimeOfDay(hour: prochaineHeure.clamp(7, 20), minute: minute);
    }
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _descCtrl.dispose();
    _adresseLieuCtrl.dispose();
    _consignesAccesCtrl.dispose();
    _montantCtrl.dispose();
    _smartFormController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Calculs
  TimeOfDay get _heureFin {
    final totalMinutes = _heureDebut.hour * 60 + _heureDebut.minute + _dureeMinutes;
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formaterDate(DateTime d) {
    const jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const mois = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]} ${d.year}';
  }

  String _formaterDuree(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) {
      if (h >= 24 && h % 24 == 0) {
        return '${h}h (${h ~/ 24} j)';
      }
      return '${h}h';
    }
    return '${h}h ${m}min';
  }

  String _formaterHeure(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool get _aModifications =>
      _titreCtrl.text.trim().isNotEmpty ||
      _descCtrl.text.trim().isNotEmpty ||
      _contactId != widget.initialContactId ||
      _adresseLieuCtrl.text.trim().isNotEmpty ||
      _consignesAccesCtrl.text.trim().isNotEmpty ||
      _photos.isNotEmpty;

  // ---------------------------------------------------------------- Actions de sélection
  Future<void> _choisirDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dateIntervention,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (d != null) {
      setState(() => _dateIntervention = d);
    }
  }

  Future<void> _choisirHeureDebut() async {
    final h = await showTimePicker(
      context: context,
      initialTime: _heureDebut,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (h != null) {
      setState(() => _heureDebut = h);
    }
  }

  Future<void> _choisirHeureFin() async {
    final h = await showTimePicker(
      context: context,
      initialTime: _heureFin,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (h != null) {
      final debutMin = _heureDebut.hour * 60 + _heureDebut.minute;
      final finMin = h.hour * 60 + h.minute;
      int delta;
      if (finMin > debutMin) {
        delta = finMin - debutMin;
      } else if (finMin == debutMin) {
        delta = 24 * 60; // 24h complètes
      } else {
        delta = (24 * 60 - debutMin) + finMin;
      }
      setState(() => _dureeMinutes = delta);
    }
  }

  Future<void> _ouvrirDialogueDureePersonnalisee() async {
    final heuresCtrl = TextEditingController(text: (_dureeMinutes ~/ 60).toString());
    final minutesCtrl = TextEditingController(text: (_dureeMinutes % 60).toString());

    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Durée personnalisée', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Définissez la durée estimée de l\'intervention :',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: heuresCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Heures',
                      suffixText: 'h',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: minutesCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Minutes',
                      suffixText: 'min',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final h = int.tryParse(heuresCtrl.text) ?? 0;
              final m = int.tryParse(minutesCtrl.text) ?? 0;
              final total = h * 60 + m;
              if (total > 0) {
                Navigator.pop(ctx, total);
              }
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
    if (res != null && res > 0) {
      setState(() => _dureeMinutes = res);
    }
  }

  Future<void> _ouvrirSelecteurContact(List<Contact> contacts) async {
    final selection = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ModalChoixContactDevis(
        contacts: contacts,
        contactActuelId: _contactId,
        onCreerRapide: (nom) async {
          Navigator.pop(context);
          await _ouvrirCreationContactRapide(nom);
        },
      ),
    );

    if (!mounted || selection == null) return;

    if (selection == 'AUCUN') {
      setState(() => _contactId = null);
    } else if (selection is Contact) {
      setState(() {
        _contactId = selection.id;
        // Si adresse renseignée et champ adresse vide, pré-remplir
        if (_typeLieu == _TypeLieuIntervention.surSite && _adresseLieuCtrl.text.trim().isEmpty) {
          final adr = [
            if (selection.adresse != null && selection.adresse!.isNotEmpty) selection.adresse,
            if (selection.ville != null && selection.ville!.isNotEmpty) selection.ville,
          ].join(', ');
          if (adr.isNotEmpty) {
            _adresseLieuCtrl.text = adr;
          }
        }
      });
    }
  }

  Future<void> _ouvrirCreationContactRapide([String? nomInitial]) async {
    final nouveau = await showDialog<Contact?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogueNouveauContactDevis(nomInitial: nomInitial),
    );
    if (!mounted || nouveau == null) return;
    setState(() {
      _contactId = nouveau.id;
      if (_typeLieu == _TypeLieuIntervention.surSite && _adresseLieuCtrl.text.trim().isEmpty) {
        if (nouveau.adresse != null && nouveau.adresse!.isNotEmpty) {
          _adresseLieuCtrl.text = nouveau.adresse!;
        }
      }
    });
    showMessageSnackBar(context, 'Contact « ${nouveau.nomAffiche} » créé et sélectionné');
  }

  // ---------------------------------------------------------------- Enregistrement
  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    if (_envoi) return;

    final titreSaisi = _titreCtrl.text.trim();
    if (!_formKey.currentState!.validate() || titreSaisi.isEmpty) {
      if (_etape != 2) {
        setState(() => _etape = 2);
      }
      if (_smartFormController.scrollController.hasClients) {
        unawaited(_smartFormController.scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner un intitulé pour l\'intervention.'),
          backgroundColor: AppColors.negative,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ctx = ref.read(contexteActifProvider);
    final espace = ref.read(espaceCourantProvider);
    final entrepriseId = ctx?.entreprise?.id;
    if (entrepriseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entreprise non connectée. Impossible d\'enregistrer.'),
          backgroundColor: AppColors.negative,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _envoi = true);

    try {
      final gerer = ref.read(gererServicesProvider);

      // Calcul date/heure début et échéance
      final debutPrevu = DateTime(
        _dateIntervention.year,
        _dateIntervention.month,
        _dateIntervention.day,
        _heureDebut.hour,
        _heureDebut.minute,
      );

      final finPrevue = debutPrevu.add(Duration(minutes: _dureeMinutes));
      final echeanceJourFinal = DateTime(finPrevue.year, finPrevue.month, finPrevue.day);
      final echeanceHeureStr = _formaterHeure(_heureFin);

      // Lieu formaté
      final String? lieuFinal;
      if (_typeLieu == _TypeLieuIntervention.atelier) {
        lieuFinal = 'En atelier (Nos locaux)';
      } else {
        lieuFinal = _adresseLieuCtrl.text.trim().isNotEmpty
            ? _adresseLieuCtrl.text.trim()
            : 'Sur site client';
      }

      // Notes & consignes d'accès
      final List<String> notesParts = [];
      if (_consignesAccesCtrl.text.trim().isNotEmpty) {
        notesParts.add('🔑 Consignes d\'accès : ${_consignesAccesCtrl.text.trim()}');
      }
      final String? noteComplete = notesParts.isNotEmpty ? notesParts.join('\n\n') : null;

      final titreFinal = titreSaisi.isNotEmpty ? titreSaisi : 'Intervention';

      final montantFacture = int.tryParse(_montantCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final prestationId = const Uuid().v4();

      // Photos associées à l'intervention
      final photosAssociees = _photos.map((p) => p.copyWith(prestationId: prestationId)).toList();

      // Lignes de prestation (service associé ou ligne par défaut)
      final List<LignePrestation> lignes = [];
      if (_serviceCatalogueAssocie != null) {
        lignes.add(LignePrestation(
          id: const Uuid().v4(),
          serviceId: _serviceCatalogueAssocie!.id,
          libelle: _serviceCatalogueAssocie!.nom,
          quantite: 1.0,
          prixUnitaire: montantFacture > 0 ? montantFacture : _serviceCatalogueAssocie!.prix,
        ));
      } else {
        lignes.add(LignePrestation(
          id: const Uuid().v4(),
          libelle: titreFinal,
          quantite: 1.0,
          prixUnitaire: montantFacture,
        ));
      }

      // 1. Création de l'intervention de terrain
      await gerer.creerPrestation(
        id: prestationId,
        entrepriseId: entrepriseId,
        perimetreId: espace.perimetreId,
        contactId: _contactId,
        responsableId: _responsableId,
        titre: titreFinal,
        description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        lignes: lignes,
        remise: 0,
        priorite: _priorite,
        debutPrevu: debutPrevu,
        echeanceJour: echeanceJourFinal,
        echeanceHeure: echeanceHeureStr,
        dureeMinutes: _dureeMinutes,
        livraisonRequise: false,
        lieu: lieuFinal,
        note: noteComplete,
        montantRegle: _encaisserImmediat && montantFacture > 0 ? montantFacture : 0,
        photos: photosAssociees,
        champsMetier: {
          'type_dossier': 'INTERVENTION',
          if (_serviceCatalogueAssocie != null) 'service_catalogue_id': _serviceCatalogueAssocie!.id,
        },
      );

      // 2. Lien Financier Direct : Encaissement & Caisse Finance
      if (montantFacture > 0) {
        final finRepo = ref.read(financesRepositoryProvider);
        final maintenant = DateTime.now();

        // Créance / Engagement à recevoir
        final engagement = fin.Engagement(
          id: prestationId,
          entrepriseId: entrepriseId,
          activite: ActiviteCode.services,
          perimetreId: espace.perimetreId,
          sens: fin.SensEngagement.aRecevoir,
          contactId: _contactId,
          libelle: 'Intervention - $titreFinal',
          montantTotal: montantFacture,
          dateEngagement: DateTime(_dateIntervention.year, _dateIntervention.month, _dateIntervention.day),
          origineType: 'INTERVENTION',
        );
        await finRepo.creerEngagement(engagement);

        // Encaissement immédiat dans la caisse ou mode choisi
        if (_encaisserImmediat) {
          final etatFinances = ref.read(etatFinancesProvider).value;
          fin.SessionCaisse? session;
          if (_modePaiement.passeParCaisse && etatFinances != null) {
            for (final c in etatFinances.caisses.where((c) => c.perimetreId == espace.perimetreId && c.estActive)) {
              session = etatFinances.sessionOuverte(c.id);
              if (session != null) break;
            }
          }

          final paiementId = const Uuid().v4();
          final paiement = fin.Paiement(
            id: paiementId,
            entrepriseId: entrepriseId,
            activite: ActiviteCode.services,
            perimetreId: espace.perimetreId,
            sens: fin.SensPaiement.entree,
            montant: montantFacture,
            mode: _modePaiement,
            datePaiement: maintenant,
            contactId: _contactId,
            note: 'Règlement intervention - $titreFinal',
            sessionId: session?.id,
            affectations: [fin.Affectation(id: paiementId, engagementId: prestationId, montant: montantFacture)],
          );

          fin.MouvementCaisse? mouvementCaisse;
          if (session != null) {
            mouvementCaisse = fin.MouvementCaisse(
              id: paiementId,
              sessionId: session.id,
              caisseId: session.caisseId,
              type: fin.TypeMouvement.encaissement,
              montant: montantFacture,
              paiementId: paiementId,
              createdAt: maintenant,
            );
          }

          await finRepo.enregistrerPaiement(paiement, mouvement: mouvementCaisse);
        }

        ref.invalidate(etatFinancesProvider);
      }

      if (mounted) {
        ref.invalidate(prestationsProvider);
        final confirmationMsg = montantFacture > 0
            ? (_encaisserImmediat
                ? 'Intervention planifiée & $montantFacture FCFA encaissés en caisse !'
                : 'Intervention planifiée & créance de $montantFacture FCFA enregistrée !')
            : 'Intervention planifiée pour le ${_formaterDate(_dateIntervention)} à ${_formaterHeure(_heureDebut)}';

        showMessageSnackBar(context, confirmationMsg);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        if (e is Failure) {
          showFailureSnackBar(context, e);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: AppColors.negative,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  void _changerEtape(int nouvelleEtape) {
    if (_etape == nouvelleEtape) return;
    setState(() => _etape = nouvelleEtape);
    if (_smartFormController.scrollController.hasClients) {
      _smartFormController.scrollController.jumpTo(0);
    }
  }

  // ---------------------------------------------------------------- Construction UI
  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    final membres = ref.watch(membresProvider).value ?? const <Membre>[];
    final catalogue = ref.watch(servicesCatalogueProvider).value ?? const <ServiceCatalogue>[];

    final Contact? contactSelectionne = _contactId == null
        ? null
        : contacts.where((c) => c.id == _contactId).firstOrNull ??
            ref.watch(contactProvider(_contactId!)).value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _envoi) return;
        if (_etape == 2) {
          _changerEtape(1);
          return;
        }
        final nav = Navigator.of(context);
        if (!_aModifications) {
          nav.pop();
          return;
        }
        final abandon = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Abandonner la planification ?'),
            content: const Text('Les informations renseignées pour ce créneau seront perdues.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuer la saisie'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Abandonner'),
              ),
            ],
          ),
        );
        if (abandon == true && mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_etape == 1 ? 'Planifier une intervention (1/2)' : 'Planifier une intervention (2/2)'),
          ),
          centerTitle: false,
          actions: [
            if (_envoi)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _enregistrer,
                  child: const Text(
                    'ENREGISTRER',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SmartFormContainer(
            controller: _smartFormController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // ─── STEPPER DE PROGRESSION MODERNE ───
              _PlanningStepIndicator(
                currentStep: _etape,
                onStepTap: _changerEtape,
              ),

              // ======================================
              // ÉTAPE 1 : CRÉNEAU, DATE & CLIENT
              // ======================================
              if (_etape == 1) ...[
                // ─── HERO RECAPITULATIF CRÉNEAU DYNAMIQUE ───
                _buildHeroResume(contactSelectionne),
                const SizedBox(height: 16),

              // ─── SECTION 1 : CRÉNEAU & DATE ───
              _buildSectionCard(
                numero: 1,
                titre: 'Créneau & Programmation',
                sousTitre: 'Date, heure de début et durée estimée',
                icone: Icons.schedule_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sélecteur rapide de dates
                    Text(
                      'Date d\'intervention',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRaccourcisDates(),
                    const SizedBox(height: 16),

                    // Ligne Heure Début + Heure Fin
                    Row(
                      children: [
                        // Heure de début
                        Expanded(
                          child: InkWell(
                            onTap: _choisirHeureDebut,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'Heure début',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(Icons.edit_outlined, size: 13, color: AppColors.muted),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formaterHeure(_heureDebut),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Heure de fin interactive
                        Expanded(
                          child: InkWell(
                            onTap: _choisirHeureFin,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.flag_outlined, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'Heure fin',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        _formaterHeure(_heureFin),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      if ((_heureDebut.hour * 60 + _heureDebut.minute + _dureeMinutes) >= 1440) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.gold, width: 0.8),
                                          ),
                                          child: Text(
                                            '+${((_heureDebut.hour * 60 + _heureDebut.minute + _dureeMinutes) ~/ 1440)} j',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Durée estimée en chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Durée estimée',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Total : ${_formaterDuree(_dureeMinutes)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in _dureesRapides)
                          ChoiceChip(
                            label: Text(d.label),
                            selected: _dureeMinutes == d.minutes,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: _dureeMinutes == d.minutes ? Colors.white : AppColors.ink,
                              fontWeight: _dureeMinutes == d.minutes ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12.5,
                            ),
                            backgroundColor: AppColors.surface,
                            side: BorderSide(
                              color: _dureeMinutes == d.minutes ? AppColors.primary : AppColors.border,
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _dureeMinutes = d.minutes);
                            },
                          ),
                        // Si durée personnalisée active
                        if (!_dureesRapides.any((d) => d.minutes == _dureeMinutes))
                          ChoiceChip(
                            label: Text('Perso (${_formaterDuree(_dureeMinutes)})'),
                            selected: true,
                            selectedColor: AppColors.primary,
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                            backgroundColor: AppColors.surface,
                            side: const BorderSide(color: AppColors.primary),
                            onSelected: (_) => _ouvrirDialogueDureePersonnalisee(),
                          ),
                        // Bouton Personnaliser
                        ActionChip(
                          avatar: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                          label: const Text('Personnaliser'),
                          labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                          backgroundColor: AppColors.primarySoft.withValues(alpha: 0.3),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                          onPressed: _ouvrirDialogueDureePersonnalisee,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── SECTION 2 : CLIENT & LIEU ───
              _buildSectionCard(
                numero: 2,
                titre: 'Client & Localisation',
                sousTitre: 'Destinataire et adresse de l\'intervention',
                icone: Icons.person_pin_circle_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sélection du client
                    SectionClientProspect(
                      selectedContact: contactSelectionne,
                      onChoisir: () => _ouvrirSelecteurContact(contacts),
                      onCreerNouveau: () => _ouvrirCreationContactRapide(),
                      onRetirer: () => setState(() => _contactId = null),
                    ),
                    const SizedBox(height: 16),

                    // Choix du lieu : Sur site vs Atelier
                    Text(
                      'Lieu de l\'intervention',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final type in _TypeLieuIntervention.values)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: type == _TypeLieuIntervention.surSite ? 8 : 0,
                                left: type == _TypeLieuIntervention.atelier ? 8 : 0,
                              ),
                              child: InkWell(
                                onTap: () => setState(() => _typeLieu = type),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _typeLieu == type
                                        ? AppColors.primarySoft
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _typeLieu == type
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: _typeLieu == type ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        type.icone,
                                        size: 22,
                                        color: _typeLieu == type
                                            ? AppColors.primary
                                            : AppColors.muted,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        type == _TypeLieuIntervention.surSite ? 'Sur site client' : 'En atelier',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: _typeLieu == type ? FontWeight.w700 : FontWeight.w600,
                                          fontSize: 12.5,
                                          color: _typeLieu == type ? AppColors.primary : AppColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (_typeLieu == _TypeLieuIntervention.surSite) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _adresseLieuCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Adresse ou repères terrain',
                          hintText: 'Ex: Quartier Faladié, Rue 24, près de la pharmacie',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ],

              // ======================================
              // ÉTAPE 2 : DÉTAILS, MOTIF & ATTRIBUTION
              // ======================================
              if (_etape == 2) ...[
                // Résumé interactif de l'étape 1 cliquable pour modifier
                _Etape1ResumeCard(
                  dateTexte: _formaterDate(_dateIntervention),
                  creneauTexte: '${_formaterHeure(_heureDebut)} – ${_formaterHeure(_heureFin)} (${_formaterDuree(_dureeMinutes)})',
                  lieuTexte: _typeLieu == _TypeLieuIntervention.atelier
                      ? 'En atelier (Nos locaux)'
                      : (_adresseLieuCtrl.text.trim().isNotEmpty ? _adresseLieuCtrl.text.trim() : 'Sur site client'),
                  clientNom: contactSelectionne?.nomAffiche,
                  onModifier: () => _changerEtape(1),
                ),

              // ─── SECTION 3 : OBJET & MOTIF D'INTERVENTION ───
              _buildSectionCard(
                numero: 3,
                titre: 'Objet de l\'intervention',
                sousTitre: 'Motif du rendez-vous et description du besoin',
                icone: Icons.handyman_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Suggestions rapides de motifs
                    Text(
                      'Motifs fréquents',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (final motif in _motifsFrequents)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(motif),
                                backgroundColor: AppColors.surface,
                                side: BorderSide(color: AppColors.border),
                                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                onPressed: () {
                                  // Retire l'émoji au début pour remplir le titre proprement
                                  final titreNettoye = motif.replaceFirst(RegExp(r'^[^\w\s]+\s*'), '');
                                  setState(() {
                                    _titreCtrl.text = titreNettoye;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Champ Titre (Requis)
                    TextFormField(
                      controller: _titreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Titre de l\'intervention *',
                        hintText: 'Ex: Révision groupe électrogène / Dépannage clim',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Veuillez saisir un intitulé pour l\'intervention'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Champ Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Détails ou problème signalé (optionnel)',
                        hintText: 'Symptômes observés, remarques du client...',
                        prefixIcon: Icon(Icons.notes_rounded),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── SECTION 4 : ATTRIBUTION & URGENCE ───
              _buildSectionCard(
                numero: 4,
                titre: 'Attribution & Urgence',
                sousTitre: 'Technicien assigné et niveau de priorité',
                icone: Icons.engineering_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sélection du technicien assigné
                    DropdownButtonFormField<String?>(
                      initialValue: _responsableId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Technicien / Intervenant assigné',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            'Non assigné (à dispatcher plus tard)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final m in membres)
                          DropdownMenuItem(
                            value: m.userId,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppColors.primarySoft,
                                  child: Text(
                                    m.nomAffiche.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(m.nomAffiche, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _responsableId = v),
                    ),
                    const SizedBox(height: 16),

                    // Sélecteur de priorité (Normale vs Haute)
                    Text(
                      'Niveau de priorité',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _priorite = PrioritePrestation.normale),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _priorite == PrioritePrestation.normale
                                    ? AppColors.surface
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _priorite == PrioritePrestation.normale
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: _priorite == PrioritePrestation.normale ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: _priorite == PrioritePrestation.normale
                                        ? AppColors.primary
                                        : AppColors.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Normale',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: _priorite == PrioritePrestation.normale
                                            ? AppColors.primary
                                            : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _priorite = PrioritePrestation.haute),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _priorite == PrioritePrestation.haute
                                    ? AppColors.negativeSoft
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _priorite == PrioritePrestation.haute
                                      ? AppColors.negative
                                      : AppColors.border,
                                  width: _priorite == PrioritePrestation.haute ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 18,
                                    color: _priorite == PrioritePrestation.haute
                                        ? AppColors.negative
                                        : AppColors.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Urgente',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: _priorite == PrioritePrestation.haute
                                            ? AppColors.negative
                                            : AppColors.ink,
                                      ),
                                    ),
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
              const SizedBox(height: 16),

              // ─── SECTION 5 : CONSIGNES ACCÈS & NOTES ───
              _buildSectionCard(
                numero: 5,
                titre: 'Consignes d\'accès & Notes terrain',
                sousTitre: 'Digicode, étage, contact sur place, consignes spéciales',
                icone: Icons.lock_open_rounded,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _consignesAccesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Consignes pour le technicien sur place',
                        hintText: 'Ex: Portail vert au fond, sonner chez M. Diallo, digicode 1234',
                        prefixIcon: Icon(Icons.info_outline_rounded),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── SECTION 6 : PHOTOS & CONSTAT TERRAIN ───
              _buildSectionCard(
                numero: 6,
                titre: 'Photos & Constat terrain (Facultatif)',
                sousTitre: 'Capturer ou ajouter des photos du constat / équipement',
                icone: Icons.camera_alt_outlined,
                child: PrestationPhotosSection(
                  photos: _photos,
                  onPhotosChanged: (maj) => setState(() {
                    _photos
                      ..clear()
                      ..addAll(maj);
                  }),
                ),
              ),

              // ─── SECTION OPTIONNELLE : SERVICE CATALOGUE ───
              if (catalogue.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  numero: 7,
                  titre: 'Associer un service du catalogue (Facultatif)',
                  sousTitre: 'Pré-remplit les tarifs ou la nature de prestation',
                  icone: Icons.category_outlined,
                  child: DropdownButtonFormField<ServiceCatalogue?>(
                    initialValue: _serviceCatalogueAssocie,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Prestation prédéfinie',
                      prefixIcon: Icon(Icons.library_books_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          'Aucun (intervention sur-mesure)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final s in catalogue)
                        DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s.nom} (${s.prix} FCFA)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (s) {
                      setState(() {
                        _serviceCatalogueAssocie = s;
                        if (s != null && _titreCtrl.text.trim().isEmpty) {
                          _titreCtrl.text = s.nom;
                        }
                        if (s != null) {
                          _montantCtrl.text = s.prix.toString();
                        }
                        if (s?.dureeMinutes != null && s!.dureeMinutes! > 0) {
                          _dureeMinutes = s.dureeMinutes!;
                        }
                      });
                    },
                  ),
                ),
              ],

              // ─── SECTION 8 : CHIFFRAGE & ENCAISSEMENT CAISSE DIRECT ───
              const SizedBox(height: 16),
              _buildSectionCard(
                numero: 8,
                titre: 'Chiffrage & Encaissement Caisse',
                sousTitre: 'Montant facturé et impact direct sur la trésorerie',
                icone: Icons.payments_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Saisie du montant
                    TextFormField(
                      controller: _montantCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Montant facturé (FCFA) *',
                        hintText: '0',
                        prefixIcon: Icon(Icons.monetization_on_outlined),
                        suffixText: 'FCFA',
                        suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    // Option d'encaissement direct
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _encaisserImmediat
                            ? const Color(0xFF10B981).withValues(alpha: 0.08)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _encaisserImmediat
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                _encaisserImmediat ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                color: _encaisserImmediat ? const Color(0xFF10B981) : AppColors.muted,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _encaisserImmediat
                                          ? 'Encaisser immédiatement (Caisse)'
                                          : 'Règlement ultérieur (Créance)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: _encaisserImmediat ? const Color(0xFF065F46) : AppColors.ink,
                                      ),
                                    ),
                                    Text(
                                      _encaisserImmediat
                                          ? 'Impact direct sur la caisse et le CA en temps réel'
                                          : 'Enregistré dans le suivi des créances clients',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: _encaisserImmediat ? const Color(0xFF047857) : AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _encaisserImmediat,
                                activeThumbColor: const Color(0xFF10B981),
                                onChanged: (val) => setState(() => _encaisserImmediat = val),
                              ),
                            ],
                          ),
                          if (_encaisserImmediat) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            // Choix du mode de règlement
                            const Row(
                              children: [
                                Text(
                                  'Mode de règlement :',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final mode in [
                                  (fin.ModePaiement.especes, '💵 Espèces (Caisse)'),
                                  (fin.ModePaiement.mobileMoney, '📱 Mobile Money / Wave'),
                                  (fin.ModePaiement.virement, '🏦 Virement'),
                                  (fin.ModePaiement.cheque, '📑 Chèque'),
                                ])
                                  ChoiceChip(
                                    label: Text(mode.$2),
                                    selected: _modePaiement == mode.$1,
                                    selectedColor: const Color(0xFF01226C),
                                    labelStyle: TextStyle(
                                      color: _modePaiement == mode.$1 ? Colors.white : AppColors.ink,
                                      fontWeight: _modePaiement == mode.$1 ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                      color: _modePaiement == mode.$1 ? const Color(0xFF01226C) : AppColors.border,
                                    ),
                                    onSelected: (sel) {
                                      if (sel) setState(() => _modePaiement = mode.$1);
                                    },
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
            ],
            const SizedBox(height: 32),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: FilledButton.icon(
                  onPressed: _envoi ? null : (_etape == 1 ? () => _changerEtape(2) : _enregistrer),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(_etape == 1 ? Icons.arrow_forward_rounded : Icons.check_rounded),
                  label: Text(
                    _envoi
                        ? 'Enregistrement...'
                        : (_etape == 1
                            ? 'Étape 2 : Détails'
                            : (_encaisserImmediat ? 'Valider & Encaisser' : 'Inscrire au planning')),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Composants d'aide
  Widget _buildHeroResume(Contact? contact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formaterDate(_dateIntervention),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${_formaterHeure(_heureDebut)} ➔ ${_formaterHeure(_heureFin)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formaterDuree(_dureeMinutes),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_priorite == PrioritePrestation.haute)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.negativeSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.negative.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.negative),
                      SizedBox(width: 4),
                      Text(
                        'Urgent',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.negative,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (contact != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Client : ${contact.nomAffiche}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (contact.telephone != null && contact.telephone!.isNotEmpty)
                  Text(
                    contact.telephone!,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRaccourcisDates() {
    final now = DateTime.now();
    final aujourdhui = DateTime(now.year, now.month, now.day);
    final demain = aujourdhui.add(const Duration(days: 1));
    final apresDemain = aujourdhui.add(const Duration(days: 2));

    final estAujourdhui = DateUtils.isSameDay(_dateIntervention, aujourdhui);
    final estDemain = DateUtils.isSameDay(_dateIntervention, demain);
    final estApresDemain = DateUtils.isSameDay(_dateIntervention, apresDemain);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Aujourd\'hui'),
            selected: estAujourdhui,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: estAujourdhui ? Colors.white : AppColors.ink,
              fontWeight: estAujourdhui ? FontWeight.w700 : FontWeight.w500,
            ),
            backgroundColor: AppColors.surface,
            side: BorderSide(color: estAujourdhui ? AppColors.primary : AppColors.border),
            onSelected: (s) {
              if (s) setState(() => _dateIntervention = aujourdhui);
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Demain'),
            selected: estDemain,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: estDemain ? Colors.white : AppColors.ink,
              fontWeight: estDemain ? FontWeight.w700 : FontWeight.w500,
            ),
            backgroundColor: AppColors.surface,
            side: BorderSide(color: estDemain ? AppColors.primary : AppColors.border),
            onSelected: (s) {
              if (s) setState(() => _dateIntervention = demain);
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Après-demain'),
            selected: estApresDemain,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: estApresDemain ? Colors.white : AppColors.ink,
              fontWeight: estApresDemain ? FontWeight.w700 : FontWeight.w500,
            ),
            backgroundColor: AppColors.surface,
            side: BorderSide(color: estApresDemain ? AppColors.primary : AppColors.border),
            onSelected: (s) {
              if (s) setState(() => _dateIntervention = apresDemain);
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.primary),
            label: const Text('Autre date...'),
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            onPressed: _choisirDate,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required int numero,
    required String titre,
    required String sousTitre,
    required IconData icone,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$numero',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        sousTitre,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }


}

/// Stepper visuel moderne pour la planification en 2 étapes
class _PlanningStepIndicator extends StatelessWidget {
  const _PlanningStepIndicator({
    required this.currentStep,
    required this.onStepTap,
  });

  final int currentStep;
  final ValueChanged<int> onStepTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Étape 1 : Date & Client
          Expanded(
            child: InkWell(
              onTap: () => onStepTap(1),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: currentStep >= 1 ? AppColors.primary : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: currentStep > 1
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                            : const Text('1', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '1. Date & Client',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: currentStep == 1 ? FontWeight.w800 : FontWeight.w600,
                          color: currentStep == 1 ? AppColors.ink : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.border, size: 20),
          // Étape 2 : Détails & Assignation
          Expanded(
            child: InkWell(
              onTap: () => onStepTap(2),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: currentStep == 2 ? AppColors.primary : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '2',
                          style: TextStyle(
                            color: currentStep == 2 ? Colors.white : AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '2. Détails & Assignation',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: currentStep == 2 ? FontWeight.w800 : FontWeight.w600,
                          color: currentStep == 2 ? AppColors.ink : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte récapitulative cliquable affichée en Étape 2
class _Etape1ResumeCard extends StatelessWidget {
  const _Etape1ResumeCard({
    required this.dateTexte,
    required this.creneauTexte,
    required this.lieuTexte,
    required this.clientNom,
    required this.onModifier,
  });

  final String dateTexte;
  final String creneauTexte;
  final String lieuTexte;
  final String? clientNom;
  final VoidCallback onModifier;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateTexte • $creneauTexte',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        lieuTexte,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (clientNom != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          clientNom!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: onModifier,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Modifier', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
