import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../features/catalogue/domain/entities/catalogue_public_data.dart';
import '../../../../features/catalogue/presentation/widgets/vocal_player_badge.dart';
import '../../../../features/catalogue/services/media_hybrid_resolver.dart';
import '../providers/vitrine_providers.dart';
import '../../domain/entities/vitrine_config.dart';
import '../../domain/entities/vitrine_galerie_item.dart';
import '../../domain/entities/vitrine_membre_equipe.dart';
import '../../domain/entities/vitrine_prestation.dart';
import '../../domain/entities/vitrine_publique_data.dart';
import '../../domain/entities/vitrine_rendez_vous.dart';
import '../../domain/entities/vitrine_types.dart';

/// Page web et mobile publique d'une vitrine DubaGest V2.
/// Accessible sans compte (clients, prospects, réseaux sociaux) via `/v/:slug` ou `/boutique/:slug`.
class VitrinePubliquePage extends ConsumerStatefulWidget {
  const VitrinePubliquePage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<VitrinePubliquePage> createState() => _VitrinePubliquePageState();
}

class _VitrinePubliquePageState extends ConsumerState<VitrinePubliquePage> {
  // Panier de commande pour les produits (si activés)
  final Map<String, int> _panier = {};

  // Clés de scroll pour navigation fluide
  final _keyPrestations = GlobalKey();
  final _keyRdv = GlobalKey();
  final _keyGalerie = GlobalKey();
  final _keyProduits = GlobalKey();
  final _keyContact = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  void _ajouterAuPanier(String produitId) {
    HapticFeedback.lightImpact();
    setState(() {
      _panier[produitId] = (_panier[produitId] ?? 0) + 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Article ajouté à la commande WhatsApp'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _retirerDuPanier(String produitId) {
    HapticFeedback.lightImpact();
    setState(() {
      final qte = _panier[produitId] ?? 0;
      if (qte <= 1) {
        _panier.remove(produitId);
      } else {
        _panier[produitId] = qte - 1;
      }
    });
  }

  int get _totalArticlesPanier => _panier.values.fold(0, (a, b) => a + b);

  Future<void> _commanderWhatsAppPanier({
    required VitrineConfig vitrine,
    required List<ProduitCataloguePublic> produits,
  }) async {
    final contact = vitrine.whatsappContact;
    if (contact.isEmpty) return;
    final clean = contact.replaceAll(RegExp(r'[^0-9]'), '');

    final sb = StringBuffer();
    sb.writeln('Bonjour *${vitrine.titreHero ?? "DubaGest"}*, je souhaite commander les articles suivants depuis votre vitrine :');
    sb.writeln('');

    var total = 0;
    for (final entry in _panier.entries) {
      final prod = produits.where((p) => p.id == entry.key).firstOrNull;
      if (prod != null) {
        final st = prod.prix * entry.value;
        total += st;
        sb.writeln('• ${entry.value}x *${prod.nom}* (${prod.prix} FCFA) = $st FCFA');
      }
    }
    sb.writeln('');
    sb.writeln('*Total commande : $total FCFA*');
    sb.writeln('Site : ${vitrine.urlPublique}');

    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(sb.toString())}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(vitrinePubliqueDataProvider(widget.slug));

    return Scaffold(
      backgroundColor: Colors.white,
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_outlined, size: 54, color: Color(0xFF94A3B8)),
                const SizedBox(height: 14),
                const Text('Vitrine introuvable ou indisponible', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 6),
                Text('$err', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (data) => _buildVitrineComplete(data),
      ),
    );
  }

  Widget _buildVitrineComplete(VitrinePubliqueData data) {
    final vitrine = data.vitrine;
    final style = vitrine.themeStyle;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    return Theme(
      data: ThemeData(
        fontFamily: 'Plus Jakarta Sans',
        primaryColor: style.primaire,
        scaffoldBackgroundColor: style.fond,
        colorScheme: ColorScheme.fromSeed(seedColor: style.primaire),
      ),
      child: Container(
        color: style.fond,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Barre de navigation sticky
              _buildNavBar(vitrine, style, isDesktop),

              // 2. Bannière Hero d'accueil adaptée au modèle
              _buildHeroSection(vitrine, style, isDesktop),

              // 3. Audio vocal de présentation (Cloudflare R2 max 60s)
              if (vitrine.audioPresentationUrl != null && vitrine.audioPresentationUrl!.isNotEmpty)
                _buildAudioPresentation(vitrine, style),

              // 4. Section À propos
              if (vitrine.sections.aPropos && vitrine.description != null && vitrine.description!.isNotEmpty)
                _buildSectionAPropos(vitrine, style),

              // 5. Section Prestations & Tarifs (Modèle C, D, E)
              if (vitrine.sections.prestations && data.prestations.isNotEmpty)
                _buildSectionPrestations(data.prestations, vitrine, style, key: _keyPrestations),

              // 6. Section Prise de Rendez-vous (Salon de coiffure, Beauté)
              if (vitrine.sections.rdv)
                _buildSectionRendezVous(vitrine, data.prestations, style, key: _keyRdv),

              // 7. Galerie de réalisations (Photos coiffures, avant/après)
              if (vitrine.sections.galerie && data.galerie.isNotEmpty)
                _buildSectionGalerie(data.galerie, style, key: _keyGalerie),

              // 8. Équipe professionnelle
              if (vitrine.sections.equipe && data.equipe.isNotEmpty)
                _buildSectionEquipe(data.equipe, style),

              // 9. Produits en vitrine & Panier WhatsApp (Modèle A, B, ou mixte)
              if (vitrine.sections.produits && data.produits.isNotEmpty)
                _buildSectionProduits(data.produits, vitrine, style, key: _keyProduits),

              // 10. Horaires & Contact
              _buildSectionContact(vitrine, style, key: _keyContact),

              // 11. Footer professionnel
              _buildFooter(vitrine, style),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. NAVIGATION BAR ---
  Widget _buildNavBar(VitrineConfig vitrine, ThemeStyle style, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: style.fond,
        border: Border(bottom: BorderSide(color: style.secondaire.withValues(alpha: 0.15))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            children: [
              if (vitrine.logoUrl != null && vitrine.logoUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    MediaHybridResolver.resolvePublicUrl(vitrine.logoUrl!),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.spa_rounded),
                  ),
                )
              else
                Icon(Icons.storefront_rounded, color: style.primaire, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  vitrine.titreHero ?? 'DubaGest',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: style.texte),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDesktop) ...[
                if (vitrine.sections.prestations)
                  TextButton(onPressed: () => _scrollTo(_keyPrestations), child: Text('Prestations', style: TextStyle(color: style.texte, fontWeight: FontWeight.w700))),
                if (vitrine.sections.galerie)
                  TextButton(onPressed: () => _scrollTo(_keyGalerie), child: Text('Réalisations', style: TextStyle(color: style.texte, fontWeight: FontWeight.w700))),
                if (vitrine.sections.produits)
                  TextButton(onPressed: () => _scrollTo(_keyProduits), child: Text('Produits', style: TextStyle(color: style.texte, fontWeight: FontWeight.w700))),
                TextButton(onPressed: () => _scrollTo(_keyContact), child: Text('Contact', style: TextStyle(color: style.texte, fontWeight: FontWeight.w700))),
              ],
              if (vitrine.sections.rdv) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: style.primaire, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                  icon: const Icon(Icons.calendar_today_rounded, size: 14),
                  label: const Text('Rendez-vous', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: () => _scrollTo(_keyRdv),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. HERO BANNER ---
  Widget _buildHeroSection(VitrineConfig vitrine, ThemeStyle style, bool isDesktop) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        color: style.fond,
        image: vitrine.banniereUrl != null && vitrine.banniereUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(MediaHybridResolver.resolvePublicUrl(vitrine.banniereUrl!)),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.55), BlendMode.darken),
              )
            : null,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: style.primaire.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: style.primaire.withValues(alpha: 0.5)),
                ),
                child: Text(
                  vitrine.typeActivite.libelle.toUpperCase(),
                  style: TextStyle(color: vitrine.banniereUrl != null ? Colors.white : style.primaire, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                vitrine.titreHero ?? 'Bienvenue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 36 : 28,
                  fontWeight: FontWeight.w900,
                  color: vitrine.banniereUrl != null ? Colors.white : style.texte,
                  height: 1.2,
                ),
              ),
              if (vitrine.slogan != null && vitrine.slogan!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  vitrine.slogan!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: vitrine.banniereUrl != null ? Colors.white.withValues(alpha: 0.9) : style.texte.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (vitrine.sections.prestations)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: style.primaire,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _scrollTo(_keyPrestations),
                      child: const Text('Découvrir nos prestations', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  if (vitrine.sections.rdv)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: vitrine.banniereUrl != null ? Colors.white : style.texte,
                        side: BorderSide(color: vitrine.banniereUrl != null ? Colors.white : style.primaire, width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _scrollTo(_keyRdv),
                      child: const Text('Prendre rendez-vous', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 3. AUDIO VOCAL DE PRÉSENTATION (R2) ---
  Widget _buildAudioPresentation(VitrineConfig vitrine, ThemeStyle style) {
    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: style.primaire.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: style.primaire.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.mic_rounded, color: style.primaire, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Écoutez notre mot de bienvenue', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: style.texte)),
                  const Text('Message vocal direct de l\'établissement (max 60s)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            VocalPlayerBadge(audioUrl: vitrine.audioPresentationUrl!, compact: true),
          ],
        ),
      ),
    );
  }

  // --- 4. À PROPOS ---
  Widget _buildSectionAPropos(VitrineConfig vitrine, ThemeStyle style) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: style.secondaire.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: style.primaire, size: 22),
                const SizedBox(width: 8),
                Text('À PROPOS DE NOUS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: style.primaire, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              vitrine.description!,
              style: TextStyle(fontSize: 14, height: 1.6, color: style.texte.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }

  // --- 5. PRESTATIONS & TARIFS ---
  Widget _buildSectionPrestations(List<VitrinePrestation> prestations, VitrineConfig vitrine, ThemeStyle style, {required Key key}) {
    return Center(
      child: Container(
        key: key,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('NOS PRESTATIONS & TARIFS', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text('Des soins d\'exception pour sublimer votre style', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: style.texte), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              itemCount: prestations.length,
              itemBuilder: (ctx, i) {
                final p = prestations[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: style.secondaire.withValues(alpha: 0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(p.nom, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: style.texte), maxLines: 1)),
                              if (p.dureeFormatee != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                  child: Text(p.dureeFormatee!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                ),
                            ],
                          ),
                          if (p.description != null) ...[
                            const SizedBox(height: 4),
                            Text(p.description!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          Text('${p.prix} FCFA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: style.primaire)),
                          const Spacer(),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: style.primaire.withValues(alpha: 0.1),
                              foregroundColor: style.primaire,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            child: const Text('Réserver', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            onPressed: () => _scrollTo(_keyRdv),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. PRISE DE RENDEZ-VOUS ---
  Widget _buildSectionRendezVous(VitrineConfig vitrine, List<VitrinePrestation> prestations, ThemeStyle style, {required Key key}) {
    return Center(
      child: Container(
        key: key,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: style.primaire.withValues(alpha: 0.25), width: 2),
          boxShadow: [BoxShadow(color: style.primaire.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: _FormulaireRdv(vitrine: vitrine, prestations: prestations, style: style),
      ),
    );
  }

  // --- 7. GALERIE RÉALISATIONS (AVANT / APRÈS) ---
  Widget _buildSectionGalerie(List<VitrineGalerieItem> galerie, ThemeStyle style, {required Key key}) {
    return Center(
      child: Container(
        key: key,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            Text('GALERIE DE RÉALISATIONS', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text('Découvrez notre savoir-faire en images', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: style.texte)),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: galerie.length,
              itemBuilder: (ctx, i) {
                final g = galerie[i];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        MediaHybridResolver.resolvePublicUrl(g.photoUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: const Color(0xFFE2E8F0), child: const Icon(Icons.image_not_supported_rounded)),
                      ),
                      if (g.titre != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.black.withValues(alpha: 0.6),
                            child: Text(g.titre!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 8. ÉQUIPE ---
  Widget _buildSectionEquipe(List<VitrineMembreEquipe> equipe, ThemeStyle style) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            Text('NOTRE ÉQUIPE D\'EXPERTS', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text('Des professionnels dévoués à votre satisfaction', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: style.texte)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                for (final m in equipe)
                  Container(
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: style.secondaire.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: style.primaire.withValues(alpha: 0.15),
                          child: Text(m.nom.characters.first.toUpperCase(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: style.primaire)),
                        ),
                        const SizedBox(height: 12),
                        Text(m.nom, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: style.texte), textAlign: TextAlign.center),
                        if (m.roleSpecialite != null) ...[
                          const SizedBox(height: 4),
                          Text(m.roleSpecialite!, style: TextStyle(color: style.primaire, fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 9. PRODUITS & PANIER WHATSAPP ---
  Widget _buildSectionProduits(List<ProduitCataloguePublic> produits, VitrineConfig vitrine, ThemeStyle style, {required Key key}) {
    return Center(
      child: Container(
        key: key,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            Text('NOS PRODUITS', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text('Commandez directement via WhatsApp', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: style.texte)),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.78,
              ),
              itemCount: produits.length,
              itemBuilder: (ctx, i) {
                final p = produits[i];
                final qte = _panier[p.id] ?? 0;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: style.secondaire.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                          child: p.photoPrincipale != null
                              ? Image.network(MediaHybridResolver.resolvePublicUrl(p.photoPrincipale!), fit: BoxFit.cover, width: double.infinity)
                              : Container(color: const Color(0xFFF1F5F9), child: const Icon(Icons.shopping_bag_outlined)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nom, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: style.texte), maxLines: 1),
                            const SizedBox(height: 4),
                            Text('${p.prix} FCFA', style: TextStyle(fontWeight: FontWeight.w900, color: style.primaire, fontSize: 15)),
                            const SizedBox(height: 8),
                            if (qte == 0)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(backgroundColor: style.primaire.withValues(alpha: 0.1), foregroundColor: style.primaire),
                                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                                  label: const Text('Commander'),
                                  onPressed: () => _ajouterAuPanier(p.id),
                                ),
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _retirerDuPanier(p.id)),
                                  Text('$qte', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _ajouterAuPanier(p.id)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (_totalArticlesPanier > 0) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                icon: const Icon(Icons.shopping_cart_checkout_rounded),
                label: Text('Valider ma commande WhatsApp ($_totalArticlesPanier articles)'),
                onPressed: () => _commanderWhatsAppPanier(vitrine: vitrine, produits: produits),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 10. HORAIRES & CONTACT ---
  Widget _buildSectionContact(VitrineConfig vitrine, ThemeStyle style, {required Key key}) {
    return Center(
      child: Container(
        key: key,
        margin: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: style.secondaire.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HORAIRES & CONTACT', style: TextStyle(color: style.primaire, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 14),
            if (vitrine.adresse != null && vitrine.adresse!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_rounded, color: Colors.red),
                title: Text(vitrine.adresse!, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${vitrine.ville ?? ""}, ${vitrine.pays}'),
              ),
            if (vitrine.whatsapp != null && vitrine.whatsapp!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                title: Text('WhatsApp : ${vitrine.whatsapp}'),
                onTap: () => launchUrl(Uri.parse('https://wa.me/${vitrine.whatsapp!.replaceAll(RegExp(r"[^0-9]"), "")}'), mode: LaunchMode.externalApplication),
              ),
            const Divider(height: 24),
            const Text('Horaires d\'ouverture :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 8),
            for (final h in vitrine.horaires)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(width: 100, child: Text(h.jour, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text(h.ouvert ? '${h.ouverture} — ${h.fermeture}' : 'Fermé', style: TextStyle(color: h.ouvert ? const Color(0xFF16A34A) : Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- 11. FOOTER ---
  Widget _buildFooter(VitrineConfig vitrine, ThemeStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          children: [
            Text(vitrine.titreHero ?? 'DubaGest', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('Propulsé par DubaGest V2 — Solution de gestion & vitrines professionnelles', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// COMPOSANT FORMULAIRE PRISE DE RENDEZ-VOUS SALON
// =============================================================================

class _FormulaireRdv extends StatefulWidget {
  const _FormulaireRdv({
    required this.vitrine,
    required this.prestations,
    required this.style,
  });

  final VitrineConfig vitrine;
  final List<VitrinePrestation> prestations;
  final ThemeStyle style;

  @override
  State<_FormulaireRdv> createState() => _FormulaireRdvState();
}

class _FormulaireRdvState extends State<_FormulaireRdv> {
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String? _prestationNom;
  DateTime _dateSelectionnee = DateTime.now().add(const Duration(days: 1));
  String _heureSelectionnee = '10:00';
  bool _envoiEnCours = false;
  bool _succes = false;

  @override
  void initState() {
    super.initState();
    if (widget.prestations.isNotEmpty) {
      _prestationNom = widget.prestations.first.nom;
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyerDemande() async {
    if (_nomCtrl.text.trim().isEmpty || _telCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez renseigner votre nom et votre numéro de téléphone')));
      return;
    }

    setState(() => _envoiEnCours = true);

    try {
      final rdv = VitrineRendezVous(
        id: '',
        vitrineId: widget.vitrine.id,
        entrepriseId: widget.vitrine.entrepriseId,
        nomPrestation: _prestationNom ?? 'Prestation salon',
        dateSouhaitee: _dateSelectionnee,
        heureSouhaitee: _heureSelectionnee,
        nomClient: _nomCtrl.text.trim(),
        telephoneClient: _telCtrl.text.trim(),
        messageClient: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
        statut: StatutRendezVous.enAttente,
      );

      // 1. Envoyer aussi directement le message de demande par WhatsApp au salon
      final contact = widget.vitrine.whatsappContact;
      if (contact.isNotEmpty) {
        final clean = contact.replaceAll(RegExp(r'[^0-9]'), '');
        final dStr = '${_dateSelectionnee.day}/${_dateSelectionnee.month}/${_dateSelectionnee.year}';
        final txt = 'Bonjour *${widget.vitrine.titreHero ?? "le salon"}*, je souhaite prendre rendez-vous pour : *${rdv.nomPrestation}*\nDate : *$dStr* à *$_heureSelectionnee*\nNom : *${rdv.nomClient}*\nTél : *${rdv.telephoneClient}*';
        unawaited(launchUrl(Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(txt)}'), mode: LaunchMode.externalApplication));
      }

      setState(() {
        _envoiEnCours = false;
        _succes = true;
      });
    } catch (_) {
      setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_succes) {
      return Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
          const SizedBox(height: 12),
          const Text('Demande de rendez-vous envoyée !', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          const Text('Notre salon vous confirmera le créneau par SMS ou WhatsApp dans les plus brefs délais.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: widget.style.primaire),
            const SizedBox(width: 8),
            Text('PRENDRE RENDEZ-VOUS', style: TextStyle(color: widget.style.primaire, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 6),
        Text('Réservez votre créneau en 1 minute', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: widget.style.texte)),
        const SizedBox(height: 18),
        if (widget.prestations.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _prestationNom,
            decoration: const InputDecoration(labelText: 'Prestation souhaitée *', border: OutlineInputBorder()),
            items: widget.prestations.map((p) => DropdownMenuItem(value: p.nom, child: Text('${p.nom} (${p.prix} FCFA)'))).toList(),
            onChanged: (v) => setState(() => _prestationNom = v),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text('${_dateSelectionnee.day}/${_dateSelectionnee.month}/${_dateSelectionnee.year}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dateSelectionnee,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null) setState(() => _dateSelectionnee = d);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _heureSelectionnee,
                decoration: const InputDecoration(labelText: 'Heure', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: '09:00', child: Text('09:00')),
                  DropdownMenuItem(value: '10:00', child: Text('10:00')),
                  DropdownMenuItem(value: '11:00', child: Text('11:00')),
                  DropdownMenuItem(value: '14:00', child: Text('14:00')),
                  DropdownMenuItem(value: '15:00', child: Text('15:00')),
                  DropdownMenuItem(value: '16:00', child: Text('16:00')),
                  DropdownMenuItem(value: '17:00', child: Text('17:00')),
                  DropdownMenuItem(value: '18:00', child: Text('18:00')),
                ],
                onChanged: (v) => setState(() => _heureSelectionnee = v ?? '10:00'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(controller: _nomCtrl, decoration: const InputDecoration(labelText: 'Votre nom complet *', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        TextField(controller: _telCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Votre numéro WhatsApp ou mobile *', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        TextField(controller: _msgCtrl, decoration: const InputDecoration(labelText: 'Message ou précision (facultatif)', border: OutlineInputBorder())),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: widget.style.primaire,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(_envoiEnCours ? 'Envoi en cours...' : 'Envoyer la demande de rendez-vous', style: const TextStyle(fontWeight: FontWeight.w800)),
            onPressed: _envoiEnCours ? null : _envoyerDemande,
          ),
        ),
      ],
    );
  }
}
