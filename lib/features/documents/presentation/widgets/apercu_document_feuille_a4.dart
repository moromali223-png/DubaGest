import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/document.dart';

/// Rendu visuel officiel haute définition d'un document DubaGest (Feuille A4).
///
/// Conception responsive d'excellence :
/// - 100% adaptatif : s'ajuste parfaitement aux écrans mobiles (<600px), tablettes et ordinateurs.
/// - Zéro dépassement (Zero overflow) : utilisation de LayoutBuilder, Expanded et FittedBox.
/// - 100% hors-ligne : ne requiert aucun appel réseau ni script externe.
/// - Esthétique haut de gamme : couleurs DubaGest (Bleu Marine #01226C, Or #DF9540, Vert #16A34A).
class ApercuDocumentFeuilleA4 extends StatelessWidget {
  const ApercuDocumentFeuilleA4({
    super.key,
    required this.document,
    this.annule = false,
    this.logo,
    this.padding,
  });

  final Document document;
  final bool annule;
  final Uint8List? logo;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final d = document;
    final c = d.contenu;
    final entreprise = (c['entreprise'] as Map?)?.cast<String, dynamic>() ?? const {};
    final contact = (c['contact'] as Map?)?.cast<String, dynamic>();
    final lignes = ((c['lignes'] as List?) ?? const []).cast<Map>();

    final devise = (entreprise['devise'] as String?) ?? 'FCFA';
    final uniteDevise = devise == 'XOF' ? 'FCFA' : devise;
    final fmt = NumberFormat.decimalPattern('fr');

    String fmtMontant(Object? v) {
      final num? val = v is num ? v : (v != null ? num.tryParse(v.toString()) : null);
      return '${fmt.format(val ?? 0)} $uniteDevise';
    }

    final dateDoc = DateFormat('dd/MM/yyyy').format(d.date.toLocal());
    final dateEcheanceRaw = c['date_echeance'] as String?;
    final dateEcheance = dateEcheanceRaw != null ? DateTime.tryParse(dateEcheanceRaw)?.toLocal() : null;

    final sousTotal = (c['sous_total'] as num?) ?? d.montant;
    final remise = (c['remise'] as num?) ?? 0;
    final acompte = (c['acompte'] as num?) ?? 0;
    final reste = (c['reste'] as num?) ?? (d.montant - acompte.toInt());

    // Palette DubaGest : Vert Émeraude (#1E7E4E) + Ardoise Sombre (#1A2522) + Menthe douce (#E8F5EE)
    const vert = AppColors.green;
    const ardoise = AppColors.ink;
    const menthe = AppColors.greenSoft;
    const orAccent = AppColors.gold;
    const rouge = AppColors.negative;
    const grisFond = AppColors.background;
    const grisBordure = AppColors.border;
    const texteMuted = AppColors.muted;

    final (String libelleType, Color couleurBadge, Color fondBadge) = switch (d.type) {
      TypeDocument.bonCommande => ('BON DE COMMANDE', vert, menthe),
      TypeDocument.facture => ('FACTURE COMMERCIALE', vert, menthe),
      TypeDocument.devis => ('DEVIS PROFORMA', orAccent, const Color(0xFFFFF7ED)),
      TypeDocument.recu => ('REÇU DE RÈGLEMENT', vert, menthe),
      TypeDocument.avoir => ('AVOIR / NOTE DE CRÉDIT', rouge, const Color(0xFFFEF2F2)),
      TypeDocument.bonTravail => ('ORDRE DE TRAVAIL / INTERVENTION', ardoise, menthe),
      TypeDocument.quittance => ('QUITTANCE DE LOYER', vert, menthe),
      TypeDocument.contrat => ('CONTRAT DE BAIL', ardoise, menthe),
    };

    final estPaye = (c['statut'] == 'PAYE' || reste == 0) &&
        d.type != TypeDocument.devis &&
        d.type != TypeDocument.bonCommande;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 620;
        final responsivePadding = padding ?? EdgeInsets.all(isMobile ? 14 : 24);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: grisBordure, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: responsivePadding,
              child: Stack(
                children: [
                  // 1. FILIGRANE TAMPON OFFICIEL
                  if (annule || d.refuse)
                    Positioned.fill(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.28,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: rouge.withValues(alpha: 0.8), width: 3.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'DOCUMENT ANNULÉ',
                              style: TextStyle(
                                fontSize: isMobile ? 22 : 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: rouge.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (d.type == TypeDocument.devis)
                    Positioned.fill(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.25,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: orAccent.withValues(alpha: 0.6), width: 3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PROFORMA',
                              style: TextStyle(
                                fontSize: isMobile ? 24 : 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: orAccent.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (estPaye && (d.type == TypeDocument.facture || d.type == TypeDocument.quittance))
                    Positioned.fill(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.28,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: vert.withValues(alpha: 0.7), width: 3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ACQUITTÉ / RÉGLÉ',
                              style: TextStyle(
                                fontSize: isMobile ? 22 : 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: vert.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 2. CONTENU DU DOCUMENT
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // En-tête : Entreprise + Badge Numéro
                      if (isMobile) ...[
                        // Version Mobile empilée et soignée
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (logo != null && logo!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Image.memory(logo!, height: 36, fit: BoxFit.contain),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entreprise['nom'] as String? ?? 'DUBAGEST',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: ardoise,
                                    ),
                                  ),
                                  if (entreprise['telephone'] case final String tel)
                                    Text('Tél : $tel', style: const TextStyle(fontSize: 10.5, color: texteMuted)),
                                  if ([entreprise['adresse'], entreprise['ville']].whereType<String>().isNotEmpty)
                                    Text(
                                      [entreprise['adresse'], entreprise['ville']].whereType<String>().join(', '),
                                      style: const TextStyle(fontSize: 10, color: texteMuted),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: fondBadge,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: couleurBadge.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      libelleType,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        color: couleurBadge,
                                      ),
                                    ),
                                    Text(
                                      'N° ${d.numero}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        color: ardoise,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Émis le : $dateDoc',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10.5, color: texteMuted),
                                    ),
                                    if (dateEcheance != null)
                                      Text(
                                        'Éch : ${DateFormat('dd/MM/yyyy').format(dateEcheance)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: orAccent),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Version Tablette & Desktop côte-à-côte
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (logo != null && logo!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Image.memory(logo!, height: 44, fit: BoxFit.contain),
                                    ),
                                  Text(
                                    entreprise['nom'] as String? ?? 'DUBAGEST',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: ardoise,
                                    ),
                                  ),
                                  if ([entreprise['adresse'], entreprise['ville']].whereType<String>().isNotEmpty)
                                    Text(
                                      [entreprise['adresse'], entreprise['ville']].whereType<String>().join(', '),
                                      style: const TextStyle(fontSize: 11, color: texteMuted),
                                    ),
                                  if (entreprise['telephone'] case final String tel)
                                    Text('Tél : $tel', style: const TextStyle(fontSize: 11, color: texteMuted)),
                                  if (entreprise['identifiant_fiscal'] case final String nif)
                                    Text('NIF : $nif', style: const TextStyle(fontSize: 10, color: texteMuted)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: fondBadge,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: couleurBadge.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      libelleType,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        color: couleurBadge,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'N° ${d.numero}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        color: ardoise,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Date d\'émission : $dateDoc', style: const TextStyle(fontSize: 11, color: texteMuted)),
                                    if (dateEcheance != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          d.type == TypeDocument.bonCommande
                                              ? 'Livraison : ${DateFormat('dd/MM/yyyy').format(dateEcheance)}'
                                              : 'Échéance : ${DateFormat('dd/MM/yyyy').format(dateEcheance)}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: orAccent),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Destinataire / Partenaire & Objet
                      Container(
                        padding: EdgeInsets.all(isMobile ? 10 : 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: grisBordure),
                        ),
                        child: isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.type == TypeDocument.bonCommande
                                        ? 'FOURNISSEUR / PRESTATAIRE :'
                                        : 'DESTINATAIRE / CLIENT :',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: texteMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    contact?['nom'] as String? ?? d.contactNom ?? 'Partenaire / Client',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  if ((contact?['telephone'] as String?) ?? d.contactTelephone case final String tel when tel.isNotEmpty)
                                    Text('Tél : $tel', style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                                  if ((contact?['adresse'] as String?) ?? '' case final String adr when adr.isNotEmpty)
                                    Text('Adresse : $adr', style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155))),
                                  if (d.titre != null || c['reference_metier'] != null) ...[
                                    const Divider(height: 14, color: grisBordure),
                                    if (d.titre case final String t when t.isNotEmpty)
                                      Text('Objet : $t', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                    if (c['reference_metier'] case final String ref when ref.isNotEmpty)
                                      Text('Réf. externe : $ref', style: const TextStyle(fontSize: 10.5, color: texteMuted)),
                                  ],
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.type == TypeDocument.bonCommande
                                              ? 'FOURNISSEUR / PRESTATAIRE :'
                                              : 'DESTINATAIRE / CLIENT :',
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                            color: texteMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          contact?['nom'] as String? ?? d.contactNom ?? 'Partenaire / Client',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if ((contact?['telephone'] as String?) ?? d.contactTelephone case final String tel when tel.isNotEmpty)
                                          Text('Tél : $tel', style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                                        if (contact?['adresse'] case final String adr when adr.isNotEmpty)
                                          Text('Adresse : $adr', style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                                      ],
                                    ),
                                  ),
                                  if (d.titre != null || c['reference_metier'] != null) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                        const Text(
                                            'OBJET / RÉFÉRENCE :',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.5,
                                              color: texteMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          if (d.titre case final String t when t.isNotEmpty)
                                            Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                          if (c['reference_metier'] case final String ref when ref.isNotEmpty)
                                            Text('Réf. externe : $ref', style: const TextStyle(fontSize: 11, color: texteMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),

                      // Tableau des Lignes (Adapté mobile avec FittedBox et distribution optimale)
                      if (lignes.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: grisBordure),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              // En-tête de table
                              Container(
                                color: fondBadge,
                                padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 7),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: isMobile ? 5 : 6,
                                      child: const Text(
                                        'Désignation',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                          color: ardoise,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 32,
                                      child: Text(
                                        'Qté',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                          color: ardoise,
                                        ),
                                      ),
                                    ),
                                    if (!isMobile)
                                      const Expanded(
                                        flex: 3,
                                        child: Text(
                                          'Prix unit.',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                            color: ardoise,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      flex: isMobile ? 4 : 3,
                                      child: const Text(
                                        'Total',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                          color: ardoise,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: grisBordure),

                              // Lignes de contenu
                              for (int i = 0; i < lignes.length; i++) ...[
                                Container(
                                  color: i.isEven ? Colors.white : const Color(0xFFF8FAFC),
                                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: isMobile ? 5 : 6,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (lignes[i]['libelle'] ?? lignes[i]['designation'] ?? 'Article ${i + 1}').toString(),
                                              style: TextStyle(fontSize: isMobile ? 11.5 : 12, fontWeight: FontWeight.w600),
                                            ),
                                            if (isMobile && (lignes[i]['prix_unitaire'] ?? 0) != 0)
                                              Text(
                                                'PU : ${fmtMontant(lignes[i]['prix_unitaire'])}',
                                                style: const TextStyle(fontSize: 9.5, color: texteMuted),
                                              ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 32,
                                        child: Text(
                                          (lignes[i]['quantite'] ?? 1).toString(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: isMobile ? 11 : 12),
                                        ),
                                      ),
                                      if (!isMobile)
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            fmtMontant(lignes[i]['prix_unitaire'] ?? 0),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      Expanded(
                                        flex: isMobile ? 4 : 3,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            fmtMontant(lignes[i]['montant'] ?? 0),
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: isMobile ? 12 : 12.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.5,
                                              color: vert,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (i < lignes.length - 1) const Divider(height: 1, color: grisBordure),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Totaux & Conditions
                      if (isMobile) ...[
                        // Version Mobile empilée : Totaux en premier, puis conditions
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: grisFond,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: grisBordure),
                          ),
                          child: Column(
                            children: [
                              if (sousTotal != d.montant) ...[
                                _ligneSynthese('Sous-total brut', fmtMontant(sousTotal)),
                                if (remise > 0)
                                  _ligneSynthese('Remise commerciale', '- ${fmtMontant(remise)}', couleur: rouge),
                                const Divider(height: 10, color: grisBordure),
                              ],
                              _ligneSynthese(
                                'TOTAL NET :',
                                fmtMontant(d.montant),
                                gras: true,
                                taille: 14,
                                couleur: vert,
                              ),
                              if (acompte > 0) ...[
                                const SizedBox(height: 4),
                                _ligneSynthese('Acompte / Réglé', fmtMontant(acompte)),
                              ],
                              if (reste > 0) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: d.type == TypeDocument.bonCommande
                                        ? AppColors.detteSoft
                                        : (d.type == TypeDocument.avoir ? AppColors.avoirSoft : AppColors.greenSoft),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: (d.type == TypeDocument.bonCommande
                                              ? AppColors.dette
                                              : (d.type == TypeDocument.avoir ? AppColors.avoir : AppColors.green))
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: _ligneSynthese(
                                    d.type == TypeDocument.bonCommande
                                        ? 'Reste à payer'
                                        : (d.type == TypeDocument.avoir ? 'Avoir restant' : 'Reste à recevoir'),
                                    fmtMontant(reste),
                                    gras: true,
                                    couleur: d.type == TypeDocument.bonCommande
                                        ? AppColors.dette
                                        : (d.type == TypeDocument.avoir ? AppColors.avoir : AppColors.green),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if ((c['conditions'] != null && c['conditions'].toString().isNotEmpty) ||
                            (c['notes'] != null && c['notes'].toString().isNotEmpty)) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: grisBordure),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (c['conditions'] case final String cond when cond.isNotEmpty) ...[
                                  const Text(
                                    'CONDITIONS :',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: texteMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(cond, style: const TextStyle(fontSize: 10.5)),
                                  if (c['notes'] != null && c['notes'].toString().isNotEmpty) const SizedBox(height: 6),
                                ],
                                if (c['notes'] case final String notes when notes.isNotEmpty) ...[
                                  const Text(
                                    'NOTES :',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: texteMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(notes, style: const TextStyle(fontSize: 10.5)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        // Version Desktop côte-à-côte
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (c['conditions'] case final String cond when cond.isNotEmpty) ...[
                                    const Text(
                                      'CONDITIONS & MODALITÉS :',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        color: texteMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(cond, style: const TextStyle(fontSize: 11)),
                                    const SizedBox(height: 8),
                                  ],
                                  if (c['notes'] case final String notes when notes.isNotEmpty) ...[
                                    const Text(
                                      'NOTES :',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        color: texteMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(notes, style: const TextStyle(fontSize: 11)),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: grisFond,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: grisBordure),
                                ),
                                child: Column(
                                  children: [
                                    if (sousTotal != d.montant) ...[
                                      _ligneSynthese('Sous-total brut', fmtMontant(sousTotal)),
                                      if (remise > 0)
                                        _ligneSynthese('Remise commerciale', '- ${fmtMontant(remise)}', couleur: rouge),
                                      const Divider(height: 12, color: grisBordure),
                                    ],
                                    _ligneSynthese(
                                      'TOTAL NET :',
                                      fmtMontant(d.montant),
                                      gras: true,
                                      taille: 14,
                                      couleur: vert,
                                    ),
                                    if (acompte > 0) ...[
                                      const SizedBox(height: 4),
                                      _ligneSynthese('Acompte / Réglé', fmtMontant(acompte)),
                                    ],
                                    if (reste > 0) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: d.type == TypeDocument.bonCommande
                                              ? AppColors.detteSoft
                                              : (d.type == TypeDocument.avoir ? AppColors.avoirSoft : AppColors.greenSoft),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: (d.type == TypeDocument.bonCommande
                                                    ? AppColors.dette
                                                    : (d.type == TypeDocument.avoir ? AppColors.avoir : AppColors.green))
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: _ligneSynthese(
                                          d.type == TypeDocument.bonCommande
                                              ? 'Reste à payer'
                                              : (d.type == TypeDocument.avoir ? 'Avoir restant' : 'Reste à recevoir'),
                                          fmtMontant(reste),
                                          gras: true,
                                          couleur: d.type == TypeDocument.bonCommande
                                              ? AppColors.dette
                                              : (d.type == TypeDocument.avoir ? AppColors.avoir : AppColors.green),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Cadres Signatures (Utilisant Expanded pour éliminer tout overflow)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.type == TypeDocument.bonCommande
                                      ? 'Pour le Commanditaire :'
                                      : 'Pour l\'entreprise :',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: texteMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: isMobile ? 44 : 52,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: grisBordure),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.type == TypeDocument.devis
                                      ? 'Bon pour accord Client :'
                                      : (d.type == TypeDocument.bonCommande
                                          ? 'Pour le Fournisseur :'
                                          : 'Pour réception / Accord :'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: texteMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: isMobile ? 44 : 52,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: grisBordure),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Pied de page
                      Center(
                        child: Text(
                          'Document officiel généré par DubaGest — Système offline-first.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9, color: texteMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ligneSynthese(String libelle, String valeur, {bool gras = false, double taille = 12, Color? couleur}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              libelle,
              style: TextStyle(
                fontSize: taille,
                fontWeight: gras ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: gras ? -0.5 : null,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                valeur,
                style: TextStyle(
                  fontSize: taille,
                  fontWeight: gras ? FontWeight.w900 : FontWeight.w600,
                  letterSpacing: gras ? -0.5 : null,
                  color: couleur ?? (gras ? AppColors.green : const Color(0xFF0F172A)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
