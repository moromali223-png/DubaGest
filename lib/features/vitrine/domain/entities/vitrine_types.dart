import 'package:flutter/material.dart';

/// Type d'activité professionnelle géré par la vitrine DubaGest V2
enum TypeActivite {
  commerceGeneral('COMMERCE_GENERAL', 'Commerce général', 'Boutiques, alimentations, quincailleries, grossistes et détaillants'),
  boutiqueSpecialisee('BOUTIQUE_SPECIALISEE', 'Boutique spécialisée', 'Cosmétiques, mode, téléphones, chaussures, accessoires'),
  salonCoiffure('SALON_COIFFURE', 'Salon de coiffure', 'Coiffure mixte, tresses, locks, coupes, brushing, perruques'),
  beauteEsthetique('BEAUTE_ESTHETIQUE', 'Beauté & Esthétique', 'Instituts, soins du visage, manucure, massage, épilation'),
  prestataireServices('PRESTATAIRE_SERVICES', 'Prestataire de services', 'Artisans, réparations, conseils, événements, prestations'),
  autre('AUTRE', 'Autre activité', 'Tout autre corps de métier');

  const TypeActivite(this.code, this.libelle, this.description);
  final String code;
  final String libelle;
  final String description;

  static TypeActivite fromCode(String? code) {
    return values.firstWhere(
      (e) => e.code == code,
      orElse: () => TypeActivite.commerceGeneral,
    );
  }
}

/// Modèle visuel de structure de site vitrine
enum ModeleVitrine {
  modeleA('MODELE_A', 'Modèle A — Commerce Général', 'Bannière, catégories, produits vedettes, promotions, populaires'),
  modeleB('MODELE_B', 'Modèle B — Boutique Spécialisée', 'Design moderne et contrasté, collections, nouveautés, galerie'),
  modeleC('MODELE_C', 'Modèle C — Salon de Coiffure', 'Prestations, tarifs clairs, galerie réalisations, équipe, rendez-vous WhatsApp'),
  modeleD('MODELE_D', 'Modèle D — Beauté & Esthétique', 'Soins, tarifs, galerie avant/après, équipe experte, rendez-vous'),
  modeleE('MODELE_E', 'Modèle E — Prestataire de Services', 'Présentation, services proposés, devis rapide, réalisations');

  const ModeleVitrine(this.code, this.titre, this.description);
  final String code;
  final String titre;
  final String description;

  static ModeleVitrine fromCode(String? code) {
    return values.firstWhere(
      (e) => e.code == code,
      orElse: () => ModeleVitrine.modeleA,
    );
  }

  /// Recommande le modèle idéal en fonction de l'activité
  static ModeleVitrine recommanderPour(TypeActivite activite) {
    switch (activite) {
      case TypeActivite.commerceGeneral:
        return ModeleVitrine.modeleA;
      case TypeActivite.boutiqueSpecialisee:
        return ModeleVitrine.modeleB;
      case TypeActivite.salonCoiffure:
        return ModeleVitrine.modeleC;
      case TypeActivite.beauteEsthetique:
        return ModeleVitrine.modeleD;
      case TypeActivite.prestataireServices:
      case TypeActivite.autre:
        return ModeleVitrine.modeleE;
    }
  }
}

/// Styles visuels et palettes de couleurs prédéfinies
enum ThemeStyle {
  luxeOr(
    'LUXE_OR',
    'Luxe Noir & Or',
    Color(0xFF111111),
    Color(0xFFD4AF37),
    Color(0xFF1A1A1A),
    Color(0xFFF9F6EE),
  ),
  elegantBeige(
    'ELEGANT_BEIGE',
    'Élégant Beige & Blanc',
    Color(0xFFFBF8F5),
    Color(0xFF8C7355),
    Color(0xFF2C241D),
    Color(0xFF1F1A17),
  ),
  moderneMinimal(
    'MODERNE_MINIMAL',
    'Moderne & Minimaliste',
    Color(0xFFFFFFFF),
    Color(0xFF2563EB),
    Color(0xFF0F172A),
    Color(0xFF334155),
  ),
  naturelChaud(
    'NATUREL_CHAUD',
    'Naturel & Chaleureux',
    Color(0xFFFDFBF7),
    Color(0xFF2D5A27),
    Color(0xFF1B3B17),
    Color(0xFF704214),
  ),
  commercialVert(
    'COMMERCIAL_VERT',
    'Vert Duba & Blanc',
    Color(0xFFFFFFFF),
    Color(0xFF1E7E4E),
    Color(0xFF0F3D24),
    Color(0xFF1A2522),
  ),
  sombrePro(
    'SOMBRE_PRO',
    'Sombre & Électrique',
    Color(0xFF0F172A),
    Color(0xFF6366F1),
    Color(0xFF1E293B),
    Color(0xFFF8FAFC),
  );

  const ThemeStyle(
    this.code,
    this.nom,
    this.fond,
    this.primaire,
    this.secondaire,
    this.texte,
  );

  final String code;
  final String nom;
  final Color fond;
  final Color primaire;
  final Color secondaire;
  final Color texte;

  static ThemeStyle fromCode(String? code) {
    return values.firstWhere(
      (e) => e.code == code,
      orElse: () => ThemeStyle.commercialVert,
    );
  }
}
