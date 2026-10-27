import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../documents/presentation/providers/documents_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/locataire_immobilier.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/locataire_widgets.dart';

class LocataireDetailsPage extends ConsumerWidget {
  const LocataireDetailsPage({super.key, required this.locataireId});
  final String locataireId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactAsync = ref.watch(contactProvider(locataireId));
    final profilAsync = ref.watch(profilLocataireProvider(locataireId));
    final situation = ref.watch(situationFinanciereLocataireProvider(locataireId));

    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final l10n = context.l10n;

    // Documents liés à ce locataire (quittances, reçus, contrats)
    final tousLesDocs = ref.watch(documentsProvider).value ?? const [];
    final docsLocataire = tousLesDocs.where((d) => d.contactId == locataireId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche Locataire'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier les coordonnées',
            onPressed: () => context.push(Routes.contactEdit(locataireId)),
          ),
        ],
      ),
      body: contactAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => MessageView(
          icon: Icons.error_outline,
          title: 'Erreur',
          message: err.toString(),
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(contactProvider(locataireId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ),
        data: (contact) {
          if (contact == null) {
            return const MessageView(
              icon: Icons.search_off_rounded,
              title: 'Locataire introuvable',
              message: 'Ce contact n\'existe pas ou a été archivé.',
            );
          }

          final profil = profilAsync.value;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Carte Identité & Coordonnées principales
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.border, width: 1.2),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ContactAvatar(contact: contact, radius: 36),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              contact.nomAffiche,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (contact.typePersonne == TypePersonne.organisation) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF01226C).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Société',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF01226C),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.adresse != null && contact.ville != null
                            ? '${contact.adresse}, ${contact.ville}'
                            : (contact.ville ?? 'Adresse non précisée'),
                        style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
                      ),
                      if (contact.email != null && contact.email!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          contact.email!,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Boutons d'action directe (Appel, WhatsApp, Email)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          if (contact.telephone != null && contact.telephone!.isNotEmpty)
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.greenSoft,
                                foregroundColor: AppColors.green,
                              ),
                              icon: const Icon(Icons.phone_rounded, size: 18),
                              label: const Text('Appeler'),
                              onPressed: () => launchUrl(Uri.parse('tel:${contact.telephone}')),
                            ),
                          if (contact.whatsapp != null && contact.whatsapp!.isNotEmpty)
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                                foregroundColor: const Color(0xFF128C7E),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              label: const Text('WhatsApp'),
                              onPressed: () {
                                final clean = contact.whatsapp!.replaceAll(RegExp(r'[^0-9]'), '');
                                launchUrl(
                                  Uri.parse('https://wa.me/$clean'),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                            ),
                          if (contact.email != null && contact.email!.isNotEmpty)
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF01226C).withValues(alpha: 0.08),
                                foregroundColor: const Color(0xFF01226C),
                              ),
                              icon: const Icon(Icons.email_outlined, size: 18),
                              label: const Text('Email'),
                              onPressed: () => launchUrl(Uri.parse('mailto:${contact.email}')),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Situation financière & Impayés
              SituationFinanciereCard(situation: situation, devise: devise),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add_card_rounded, size: 20),
                  label: const Text('Recevoir un loyer', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                  onPressed: () => context.push(Routes.loyerRecevoirAvec(locataireId: locataireId)),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Dossier locatif (Pièce d'identité, Profession, Garant, Urgence)
              DossierLocataireCard(
                profil: profil,
                onEdit: () => _ouvrirModalDossier(context, ref, contact, profil),
              ),
              const SizedBox(height: 16),

              // 4. Section : Baux & Contrats de location
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.border, width: 1.2),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.description_outlined, size: 20, color: Color(0xFF01226C)),
                              SizedBox(width: 8),
                              Text(
                                'Contrats & Locations',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Nouveau bail'),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Le module Contrats de bail sera activé à l\'Étape 6.'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: AppColors.border),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(Icons.home_work_outlined, size: 36, color: AppColors.muted),
                              SizedBox(height: 8),
                              Text(
                                'Aucun contrat actif pour ce locataire',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Les baux et logements assignés apparaîtront automatiquement ici.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Section : Documents & Quittances de loyer
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.border, width: 1.2),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 20, color: Color(0xFF01226C)),
                              const SizedBox(width: 8),
                              Text(
                                'Quittances & Reçus (${docsLocataire.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: AppColors.border),
                      if (docsLocataire.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.receipt_outlined, size: 36, color: AppColors.muted),
                                SizedBox(height: 8),
                                Text(
                                  'Aucun document ou quittance émise',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Les quittances de loyer et reçus d\'acompte validés apparaîtront ici.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docsLocataire.length,
                          separatorBuilder: (_, _) => const Divider(height: 12, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final doc = docsLocataire[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF01226C).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.description_outlined, color: Color(0xFF01226C)),
                              ),
                              title: Text(
                                doc.numero,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${doc.type.code} · ${doc.date.day.toString().padLeft(2, '0')}/${doc.date.month.toString().padLeft(2, '0')}/${doc.date.year}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                              trailing: Text(
                                l10n.montant(doc.montant, devise),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF01226C),
                                ),
                              ),
                              onTap: () => context.push(Routes.document(doc.id)),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  void _ouvrirModalDossier(
    BuildContext context,
    WidgetRef ref,
    Contact contact,
    ProfilLocataire? profilActuel,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _EditerDossierLocataireSheet(
          contact: contact,
          profilActuel: profilActuel,
        ),
      ),
    );
  }
}

class _EditerDossierLocataireSheet extends ConsumerStatefulWidget {
  const _EditerDossierLocataireSheet({
    required this.contact,
    required this.profilActuel,
  });

  final Contact contact;
  final ProfilLocataire? profilActuel;

  @override
  ConsumerState<_EditerDossierLocataireSheet> createState() => _EditerDossierLocataireSheetState();
}

class _EditerDossierLocataireSheetState extends ConsumerState<_EditerDossierLocataireSheet> {
  final _formKey = GlobalKey<FormState>();

  late TypePieceIdentite _typePiece = widget.profilActuel?.typePiece ?? TypePieceIdentite.cni;
  late final _numeroPieceCtrl = TextEditingController(text: widget.profilActuel?.numeroPiece ?? '');
  late final _professionCtrl = TextEditingController(text: widget.profilActuel?.profession ?? '');
  late final _employeurCtrl = TextEditingController(text: widget.profilActuel?.employeur ?? '');
  late final _revenuCtrl = TextEditingController(
    text: widget.profilActuel?.revenuMensuelEstime != null
        ? widget.profilActuel!.revenuMensuelEstime!.toStringAsFixed(0)
        : '',
  );

  // Garant
  late final _nomGarantCtrl = TextEditingController(text: widget.profilActuel?.nomGarant ?? '');
  late final _telGarantCtrl = TextEditingController(text: widget.profilActuel?.telephoneGarant ?? '');
  late final _lienGarantCtrl = TextEditingController(text: widget.profilActuel?.lienGarant ?? '');
  late final _adresseGarantCtrl = TextEditingController(text: widget.profilActuel?.adresseGarant ?? '');

  // Urgence
  late final _nomUrgenceCtrl = TextEditingController(text: widget.profilActuel?.nomUrgence ?? '');
  late final _telUrgenceCtrl = TextEditingController(text: widget.profilActuel?.telephoneUrgence ?? '');
  late final _lienUrgenceCtrl = TextEditingController(text: widget.profilActuel?.lienUrgence ?? '');

  // Notes
  late final _notesCtrl = TextEditingController(text: widget.profilActuel?.notesLocatives ?? '');
  late StatutFinancierLocataire _statutFinancier =
      widget.profilActuel?.statutFinancier ?? StatutFinancierLocataire.aJour;

  bool _chargement = false;

  @override
  void dispose() {
    _numeroPieceCtrl.dispose();
    _professionCtrl.dispose();
    _employeurCtrl.dispose();
    _revenuCtrl.dispose();
    _nomGarantCtrl.dispose();
    _telGarantCtrl.dispose();
    _lienGarantCtrl.dispose();
    _adresseGarantCtrl.dispose();
    _nomUrgenceCtrl.dispose();
    _telUrgenceCtrl.dispose();
    _lienUrgenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _sauvegarder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _chargement = true);

    try {
      final ctx = ref.read(contexteActifProvider);
      if (ctx == null || ctx.entreprise == null) return;

      final profil = ProfilLocataire(
        contactId: widget.contact.id,
        entrepriseId: ctx.entreprise!.id,
        typePiece: _typePiece,
        numeroPiece: _numeroPieceCtrl.text.trim().isEmpty ? null : _numeroPieceCtrl.text.trim(),
        profession: _professionCtrl.text.trim().isEmpty ? null : _professionCtrl.text.trim(),
        employeur: _employeurCtrl.text.trim().isEmpty ? null : _employeurCtrl.text.trim(),
        revenuMensuelEstime: double.tryParse(_revenuCtrl.text.replaceAll(' ', '')),
        nomGarant: _nomGarantCtrl.text.trim().isEmpty ? null : _nomGarantCtrl.text.trim(),
        telephoneGarant: _telGarantCtrl.text.trim().isEmpty ? null : _telGarantCtrl.text.trim(),
        lienGarant: _lienGarantCtrl.text.trim().isEmpty ? null : _lienGarantCtrl.text.trim(),
        adresseGarant: _adresseGarantCtrl.text.trim().isEmpty ? null : _adresseGarantCtrl.text.trim(),
        nomUrgence: _nomUrgenceCtrl.text.trim().isEmpty ? null : _nomUrgenceCtrl.text.trim(),
        telephoneUrgence: _telUrgenceCtrl.text.trim().isEmpty ? null : _telUrgenceCtrl.text.trim(),
        lienUrgence: _lienUrgenceCtrl.text.trim().isEmpty ? null : _lienUrgenceCtrl.text.trim(),
        notesLocatives: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        statutFinancier: _statutFinancier,
        updatedAt: DateTime.now(),
      );

      await ref.read(immobilierRepositoryProvider).sauvegarderProfilLocataire(profil);
      ref.invalidate(profilLocataireProvider(widget.contact.id));
      ref.invalidate(profilsLocatairesProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dossier locataire mis à jour avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Compléter le dossier locatif',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- PIÈCE D'IDENTITÉ ---
                  const Text(
                    'PIÈCE D\'IDENTITÉ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF01226C)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TypePieceIdentite>(
                    initialValue: _typePiece,
                    decoration: const InputDecoration(
                      labelText: 'Type de pièce officielle',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: [
                      for (final t in TypePieceIdentite.values)
                        DropdownMenuItem(value: t, child: Text(t.libelle)),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _typePiece = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _numeroPieceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de la pièce d\'identité',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- PROFESSION ET REVENUS ---
                  const Text(
                    'SITUATION PROFESSIONNELLE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF01226C)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _professionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Profession / Activité',
                      prefixIcon: Icon(Icons.work_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _employeurCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Employeur / Société / Établissement',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _revenuCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Revenu mensuel moyen estimé',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- CONTACT D'URGENCE ---
                  const Text(
                    'PERSONNE À CONTACTER EN CAS D\'URGENCE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF01226C)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nomUrgenceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom et prénom du contact d\'urgence',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telUrgenceCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de téléphone d\'urgence',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lienUrgenceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lien de parenté / Relation (ex: Frère, Épouse...)',
                      prefixIcon: Icon(Icons.family_restroom_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- GARANT / CAUTIONNAIRE ---
                  const Text(
                    'GARANT OU CAUTIONNAIRE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF01226C)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nomGarantCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom et prénom du garant',
                      prefixIcon: Icon(Icons.shield_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telGarantCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de téléphone du garant',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lienGarantCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lien / Relation avec le garant',
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _adresseGarantCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Adresse du garant',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- STATUT ET NOTES ---
                  const Text(
                    'STATUT ET OBSERVATIONS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF01226C)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<StatutFinancierLocataire>(
                    initialValue: _statutFinancier,
                    decoration: const InputDecoration(
                      labelText: 'Statut du locataire',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: [
                      for (final s in StatutFinancierLocataire.values)
                        DropdownMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              Icon(s.icone, size: 16, color: s.couleur),
                              const SizedBox(width: 8),
                              Text(s.libelle),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _statutFinancier = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes ou clauses particulières',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF01226C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _chargement ? null : _sauvegarder,
                  child: _chargement
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Enregistrer le dossier',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
