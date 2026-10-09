import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

/// Dialogue modal professionnel pour l'Aide & Support DubaGest.
class AideSupportDialog extends StatefulWidget {
  const AideSupportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const AideSupportDialog(),
    );
  }

  @override
  State<AideSupportDialog> createState() => _AideSupportDialogState();
}

class _AideSupportDialogState extends State<AideSupportDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final dialogWidth = (screenWidth - 32).clamp(280.0, 600.0);
    final dialogHeight = (screenHeight * 0.85).clamp(360.0, 680.0);

    return Dialog(
      key: const Key('dialog-aide-support'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: const BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('❓', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Centre d\'Aide & Support',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'DubaGest · La gestion simple de votre activité',
                          style: TextStyle(color: AppColors.onInkMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.inkRaised,
                    ),
                  ),
                ],
              ),
            ),

            // TabBar
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.green,
                labelColor: AppColors.green,
                unselectedLabelColor: AppColors.muted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.support_agent_rounded, size: 20), text: 'Assistance'),
                  Tab(icon: Icon(Icons.menu_book_rounded, size: 20), text: 'Guides & FAQ'),
                  Tab(icon: Icon(Icons.offline_bolt_rounded, size: 20), text: 'Hors-ligne'),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabAssistance(theme),
                  _buildTabGuidesFAQ(theme),
                  _buildTabHorsLigne(theme),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Version 1.0.0 · DubaGest PME',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(minimumSize: const Size(80, 38)),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabAssistance(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CardAction(
          icon: Icons.chat_rounded,
          iconColor: Colors.green,
          title: 'Assistance WhatsApp Directe',
          subtitle: 'Discutez avec nos conseillers techniques 7j/7 pour un dépannage rapide.',
          actionLabel: '+223 70 00 00 00',
          badge: 'Recommandé',
        ),
        const SizedBox(height: 12),
        _CardAction(
          icon: Icons.alternate_email_rounded,
          iconColor: Colors.blue,
          title: 'Support par Email',
          subtitle: 'Envoyez vos questions détaillées ou demandes d\'assistance.',
          actionLabel: 'support@dubagest.com',
        ),
        const SizedBox(height: 12),
        _CardAction(
          icon: Icons.phone_in_talk_rounded,
          iconColor: Colors.orange,
          title: 'Service Client Téléphonique',
          subtitle: 'Du lundi au samedi, de 08h00 à 19h00 (Heure de Bamako / GMT).',
          actionLabel: '+223 20 00 00 00',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_rounded, color: AppColors.green, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nos équipes vous accompagnent lors de la configuration initiale de votre entreprise, de vos boutiques et de vos utilisateurs.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabGuidesFAQ(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _FaqAccordion(
          title: 'Comment enregistrer une vente au comptant ou à crédit ?',
          content:
              'Rendez-vous dans Ventes (ou le bouton « + » au centre). Sélectionnez vos articles et quantités. Choisissez le mode de règlement : Cash, Mobile Money ou À crédit. Si le client ne paie pas immédiatement ou paie partiellement, la dette est automatiquement générée dans le dossier du client.',
        ),
        SizedBox(height: 8),
        _FaqAccordion(
          title: 'Comment gérer les dépenses payées ou différées ?',
          content:
              'Dans le module Dépenses, vous pouvez enregistrer une dépense payée immédiatement ou une dépense non payée. Les dépenses non payées s\'inscrivent automatiquement dans la section « À payer » (Dettes) avec consolidation par fournisseur/contact.',
        ),
        SizedBox(height: 8),
        _FaqAccordion(
          title: 'Comment fonctionne la gestion multi-boutiques ?',
          content:
              'Une boutique physique réelle représente un lieu de vente précis. La « Vue consolidée » regroupe l\'activité de toutes vos boutiques pour le gérant. Vous pouvez affecter vos vendeurs spécifiquement à une boutique depuis le Menu ☰ > Administration > Boutiques & Périmètres.',
        ),
        SizedBox(height: 8),
        _FaqAccordion(
          title: 'Comment clôturer une caisse à la fin de la journée ?',
          content:
              'Dans Finances > Caisse, vous pouvez vérifier le solde théorique calculé à partir de tous les encaissements et décaissements de la journée, puis procéder à la clôture de session avec justification des écarts éventuels.',
        ),
      ],
    );
  }

  Widget _buildTabHorsLigne(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.inkRaised,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_done_rounded, color: AppColors.greenOnDark, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Fonctionnement 100% Hors-ligne',
                    style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'DubaGest a été spécialement conçu pour fonctionner sans interruption même en cas de coupure Internet. Toutes vos opérations (ventes, dépenses, paiements, fiches contacts) sont enregistrées localement sur votre téléphone ou tablette.',
                style: TextStyle(color: AppColors.onInkMuted, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _StepItem(
          stepNumber: '1',
          title: 'Enregistrement local immédiat',
          description: 'Vos ventes et écritures continuent de fonctionner instantanément et en toute sécurité.',
        ),
        const SizedBox(height: 10),
        const _StepItem(
          stepNumber: '2',
          title: 'Mise en file d\'attente chiffrée',
          description: 'Les transactions sont protégées localement et ordonnées chronologiquement.',
        ),
        const SizedBox(height: 10),
        const _StepItem(
          stepNumber: '3',
          title: 'Synchronisation Cloud automatique',
          description: 'Dès que le réseau mobile ou Wi-Fi revient, les données sont synchronisées avec le serveur sans aucune action requise.',
        ),
      ],
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.green),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.3),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.inkRaised,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greenOnDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqAccordion extends StatelessWidget {
  const _FaqAccordion({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.help_outline_rounded, color: AppColors.green, size: 20),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        children: [
          Text(
            content,
            style: const TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  final String stepNumber;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.green,
          child: Text(
            stepNumber,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
