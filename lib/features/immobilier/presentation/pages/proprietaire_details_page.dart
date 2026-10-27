import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/immobilier_widgets.dart';

class ProprietaireDetailsPage extends ConsumerWidget {
  const ProprietaireDetailsPage({super.key, required this.proprietaireId});
  final String proprietaireId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactAsync = ref.watch(contactProvider(proprietaireId));
    final biensAsync = ref.watch(biensParProprietaireProvider(proprietaireId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche Propriétaire'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier les coordonnées',
            onPressed: () => context.push(Routes.contactEdit(proprietaireId)),
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
            onPressed: () => ref.invalidate(contactProvider(proprietaireId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ),
        data: (contact) {
          if (contact == null) {
            return const MessageView(
              icon: Icons.search_off_rounded,
              title: 'Propriétaire introuvable',
              message: 'Ce contact n\'existe pas ou a été archivé.',
            );
          }

          final biens = biensAsync.value ?? const [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Carte Coordonnées Propriétaire
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
                      Text(
                        contact.nomAffiche,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.adresse != null && contact.ville != null
                            ? '${contact.adresse}, ${contact.ville}'
                            : (contact.ville ?? 'Adresse non précisée'),
                        style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),

                      // Boutons d'action rapide (Appel, WhatsApp)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (contact.telephone != null && contact.telephone!.isNotEmpty) ...[
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.greenSoft,
                                foregroundColor: AppColors.green,
                              ),
                              icon: const Icon(Icons.phone_rounded, size: 18),
                              label: const Text('Appeler'),
                              onPressed: () => launchUrl(Uri.parse('tel:${contact.telephone}')),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (contact.whatsapp != null && contact.whatsapp!.isNotEmpty) ...[
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
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Section : Biens de ce propriétaire
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Biens en gestion (${biens.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Ajouter un bien'),
                    onPressed: () => context.push(Routes.bienNouveau),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (biens.isEmpty) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                  ),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.home_work_outlined, size: 40, color: AppColors.muted),
                        const SizedBox(height: 8),
                        const Text(
                          'Aucun bien rattaché à ce propriétaire',
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enregistrez le premier bien appartenant à ce propriétaire.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF01226C),
                          ),
                          icon: const Icon(Icons.add_home_work_rounded, size: 18),
                          label: const Text('Créer un bien pour ce propriétaire'),
                          onPressed: () => context.push(Routes.bienNouveau),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                for (final bien in biens)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BienCard(bien: bien),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
