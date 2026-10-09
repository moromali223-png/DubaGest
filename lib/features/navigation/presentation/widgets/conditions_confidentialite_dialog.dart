import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

/// Dialogue modal complet pour les Conditions Générales d'Utilisation,
/// la Politique de Confidentialité et les Mentions Légales de DubaGest.
class ConditionsConfidentialiteDialog extends StatefulWidget {
  const ConditionsConfidentialiteDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const ConditionsConfidentialiteDialog(),
    );
  }

  @override
  State<ConditionsConfidentialiteDialog> createState() => _ConditionsConfidentialiteDialogState();
}

class _ConditionsConfidentialiteDialogState extends State<ConditionsConfidentialiteDialog>
    with SingleTickerProviderStateMixin {
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final dialogWidth = (screenWidth - 32).clamp(280.0, 600.0);
    final dialogHeight = (screenHeight * 0.85).clamp(360.0, 680.0);

    return Dialog(
      key: const Key('dialog-conditions-confidentialite'),
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
                      child: Text('📜', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conditions & Confidentialité',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'DubaGest · Engagements légaux & protection des données',
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
                  Tab(icon: Icon(Icons.description_outlined, size: 20), text: 'CGU'),
                  Tab(icon: Icon(Icons.shield_outlined, size: 20), text: 'Confidentialité'),
                  Tab(icon: Icon(Icons.business_outlined, size: 20), text: 'Mentions légales'),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabCGU(),
                  _buildTabConfidentialite(),
                  _buildTabMentionsLegales(),
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
                  const Icon(Icons.verified_outlined, size: 16, color: AppColors.green),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Données 100% sécurisées et chiffrées',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(minimumSize: const Size(80, 38)),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('J\'ai compris'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabCGU() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _LegalSection(
          articleNumber: 'Article 1',
          title: 'Objet et portée du service',
          body:
              'DubaGest est une solution logicielle tout-en-un de gestion d\'entreprise destinée aux petites et moyennes entreprises (PME), commerces, prestataires de services et gestionnaires immobiliers. L\'application offre des fonctionnalités de vente, facturation, suivi de stock, trésorerie, caisse et gestion de dettes.',
        ),
        SizedBox(height: 12),
        _LegalSection(
          articleNumber: 'Article 2',
          title: 'Propriété intégrale des données',
          body:
              'Toutes les données renseignées sur DubaGest (chiffre d\'affaires, écritures comptables, fichiers contacts, stocks, tarifs, baux et contrats) demeurent la propriété exclusive, entière et inaliénable de l\'entreprise cliente. DubaGest n\'acquiert aucun droit de propriété sur votre contenu.',
        ),
        SizedBox(height: 12),
        _LegalSection(
          articleNumber: 'Article 3',
          title: 'Responsabilité & Sécurité des accès',
          body:
              'Chaque utilisateur enregistré s\'engage à préserver la stricte confidentialité de ses identifiants de connexion. L\'administrateur de l\'entreprise gère l\'attribution des rôles et des périmètres (boutiques) accordés à ses collaborateurs.',
        ),
        SizedBox(height: 12),
        _LegalSection(
          articleNumber: 'Article 4',
          title: 'Disponibilité du service et sauvegardes',
          body:
              'DubaGest intègre une architecture hybride offline-first permettant la poursuite ininterrompue des opérations même en l\'absence de connexion Internet. Les données sont automatiquement sauvegardées et répliquées dès rétablissement du réseau.',
        ),
      ],
    );
  }

  Widget _buildTabConfidentialite() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
              Icon(Icons.lock_rounded, color: AppColors.green, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vos données financières et commerciales sont strictement confidentielles. Aucune donnée n\'est vendue, louée ou partagée à des tiers publicitaires.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w700, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _LegalSection(
          articleNumber: 'Confidentialité 1',
          title: 'Nature des données traitées',
          body:
              'Nous traitons uniquement les informations indispensables au bon fonctionnement de votre gestion : identité du compte utilisateur, coordonnées professionnelles, données d\'inventaire, transactions financières et journaux d\'audit.',
        ),
        const SizedBox(height: 12),
        const _LegalSection(
          articleNumber: 'Confidentialité 2',
          title: 'Chiffrement et protection des échanges',
          body:
              'Tous les transferts entre votre appareil et nos serveurs sécurisés sont chiffrés selon les normes industrielles (protocole TLS/HTTPS). La base de données locale stockée sur votre appareil est également protégée.',
        ),
        const SizedBox(height: 12),
        const _LegalSection(
          articleNumber: 'Confidentialité 3',
          title: 'Droit d\'accès, rectification et suppression',
          body:
              'Conformément aux réglementations de protection des données personnelles et d\'entreprise, le gérant peut à tout moment exporter l\'intégralité des écritures ou demander la clôture et l\'effacement définitif de son compte.',
        ),
      ],
    );
  }

  Widget _buildTabMentionsLegales() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DubaGest Technologies',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              SizedBox(height: 4),
              Text(
                'Application professionnelle de gestion d\'entreprise',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              Divider(height: 24, color: AppColors.border),
              _InfoRow(label: 'Signature', value: 'DUBAGEST — La gestion simple de votre activité'),
              SizedBox(height: 8),
              _InfoRow(label: 'Version', value: '1.0.0 (Release PME Francophone)'),
              SizedBox(height: 8),
              _InfoRow(label: 'Zone d\'opération', value: 'Mali & Espace UEMOA / Francophone'),
              SizedBox(height: 8),
              _InfoRow(label: 'Contact Légal', value: 'legal@dubagest.com'),
              SizedBox(height: 8),
              _InfoRow(label: 'Support Technique', value: 'support@dubagest.com'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '© 2026 DubaGest Technologies. Tous droits réservés.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({
    required this.articleNumber,
    required this.title,
    required this.body,
  });

  final String articleNumber;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.inkRaised,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  articleNumber,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.greenOnDark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
