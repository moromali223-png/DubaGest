import 'package:flutter/material.dart';

/// Les 3 grands domaines fondamentaux de DubaGest V2
enum DomaineActivite {
  commerce('COMMERCE', 'Commerce', 'Boutiques, magasins, produits & stocks', Icons.storefront_rounded),
  services('SERVICES', 'Services', 'Salons de coiffure, beauté, soins, prestations', Icons.content_cut_rounded),
  immobilier('IMMOBILIER', 'Immobilier', 'Agences, locations, ventes de biens, villas, appartements', Icons.apartment_rounded);

  const DomaineActivite(this.code, this.libelle, this.description, this.icone);
  final String code;
  final String libelle;
  final String description;
  final IconData icone;

  static DomaineActivite fromCode(String? code) {
    return values.firstWhere(
      (e) => e.code == code,
      orElse: () => DomaineActivite.commerce,
    );
  }
}

/// Type d'activité professionnelle précise gérée par la vitrine DubaGest V2
enum TypeActivite {
  // DOMAINE : COMMERCE
  commerceGeneral(
    'COMMERCE_GENERAL',
    'Commerce général',
    'Boutiques, alimentations, quincailleries, grossistes et détaillants',
    DomaineActivite.commerce,
  ),
  boutiqueSpecialisee(
    'BOUTIQUE_SPECIALISEE',
    'Boutique de mode & Prêt-à-porter',
    'Vêtements, chaussures, maroquinerie, accessoires de mode',
    DomaineActivite.commerce,
  ),
  boutiqueTech(
    'BOUTIQUE_TECH',
    'High-Tech, Téléphonie & Gadgets',
    'Smartphones, écouteurs, accessoires tech, électronique',
    DomaineActivite.commerce,
  ),
  cosmetiqueBeaute(
    'COSMETIQUE_BEAUTE',
    'Cosmétique & Soins corps',
    'Crèmes, baumes de soin, produits capillaires, maquillage',
    DomaineActivite.commerce,
  ),

  // DOMAINE : SERVICES
  salonCoiffure(
    'SALON_COIFFURE',
    'Salon de coiffure & Perruques',
    'Coiffure mixte, tresses, locks, coupes, brushing, raw hair, pose de perruques',
    DomaineActivite.services,
  ),
  beauteEsthetique(
    'BEAUTE_ESTHETIQUE',
    'Institut de Beauté & Esthétique',
    'Soins du visage, manucure, cils, maquillage pro, bien-être',
    DomaineActivite.services,
  ),
  prestataireServices(
    'PRESTATAIRE_SERVICES',
    'Prestataire de services & Artisan',
    'Artisans, réparations, conseils, événements, maintenance',
    DomaineActivite.services,
  ),

  // DOMAINE : IMMOBILIER
  immobilierLocation(
    'IMMOBILIER_LOCATION',
    'Location Immobilière',
    'Villas, appartements, studios meublés et magasins à louer',
    DomaineActivite.immobilier,
  ),
  immobilierVente(
    'IMMOBILIER_VENTE',
    'Vente de Biens & Terrains',
    'Maisons, parcelles, terrains, immeubles neufs',
    DomaineActivite.immobilier,
  ),
  agenceImmobiliere(
    'AGENCE_IMMOBILIERE',
    'Agence Immobilière & Gestion',
    'Gestion locative, vente, location et conseils immobiliers',
    DomaineActivite.immobilier,
  ),

  // AUTRE
  autre(
    'AUTRE',
    'Autre activité professionnelle',
    'Tout autre corps de métier',
    DomaineActivite.services,
  );

  const TypeActivite(this.code, this.libelle, this.description, this.domaine);
  final String code;
  final String libelle;
  final String description;
  final DomaineActivite domaine;

  static TypeActivite fromCode(String? code) {
    return values.firstWhere(
      (e) => e.code == code,
      orElse: () => TypeActivite.commerceGeneral,
    );
  }

  static List<TypeActivite> parDomaine(DomaineActivite d) {
    return values.where((e) => e.domaine == d).toList();
  }
}

/// Modèle visuel de structure de site vitrine
enum ModeleVitrine {
  modeleA(
    'MODELE_A',
    'Modèle A — TechVerse (Commerce Tech & Général)',
    'Grande bannière promo, catégories rondes, trending products, livraison & newsletter',
    DomaineActivite.commerce,
  ),
  modeleB(
    'MODELE_B',
    'Modèle B — GizmoHub & TechNest (Sombre & Électrique)',
    'Design sombre et contrasté, top picks, badges promos, panier WhatsApp',
    DomaineActivite.commerce,
  ),
  modeleC(
    'MODELE_C',
    'Modèle C — The LUXE Studio (Salon Coiffure & Hair VIP)',
    'Noir & Or ou Beige, prestations, durées, tarifs clairs, galerie avant/après, réservation WhatsApp',
    DomaineActivite.services,
  ),
  modeleD(
    'MODELE_D',
    'Modèle D — Hollis Body Care (Cosmétiques & Soins)',
    'Minimaliste & raffiné, filtres latéraux, grille aérée de soins et produits avec commande rapide',
    DomaineActivite.commerce,
  ),
  modeleE(
    'MODELE_E',
    'Modèle E — Prestataire de Services & Artisan',
    'Présentation d\'expertise, services proposés, réalisations, devis express',
    DomaineActivite.services,
  ),
  modeleF(
    'MODELE_F',
    'Modèle F — Havenly (Agence & Biens Immobiliers)',
    'Moteur de recherche par ville et type, fiches villas/appartements, chambres, surface m², demande de visite',
    DomaineActivite.immobilier,
  );

  const ModeleVitrine(this.code, this.titre, this.description, this.domaine);
  final String code;
  final String titre;
  final String description;
  final DomaineActivite domaine;

  static ModeleVitrine fromCode(String? code) {
    return values.firstWhere(
      (e) => e.code == code,
      orElse: () => ModeleVitrine.modeleA,
    );
  }

  static List<ModeleVitrine> parDomaine(DomaineActivite d) {
    return values.where((e) => e.domaine == d).toList();
  }

  /// Recommande le modèle idéal en fonction de l'activité précise
  static ModeleVitrine recommanderPour(TypeActivite activite) {
    switch (activite) {
      case TypeActivite.commerceGeneral:
        return ModeleVitrine.modeleA;
      case TypeActivite.boutiqueSpecialisee:
      case TypeActivite.boutiqueTech:
        return ModeleVitrine.modeleB;
      case TypeActivite.cosmetiqueBeaute:
        return ModeleVitrine.modeleD;
      case TypeActivite.salonCoiffure:
        return ModeleVitrine.modeleC;
      case TypeActivite.beauteEsthetique:
        return ModeleVitrine.modeleC; // Ou modèle D
      case TypeActivite.prestataireServices:
      case TypeActivite.autre:
        return ModeleVitrine.modeleE;
      case TypeActivite.immobilierLocation:
      case TypeActivite.immobilierVente:
      case TypeActivite.agenceImmobiliere:
        return ModeleVitrine.modeleF;
    }
  }
}

/// Styles visuels et palettes de couleurs prédéfinies
enum ThemeStyle {
  luxeOr(
    'LUXE_OR',
    'Luxe Noir & Or (The LUXE Studio)',
    Color(0xFF0F0F11),
    Color(0xFFD4AF37),
    Color(0xFF23232A),
    Color(0xFFF9F6EE),
  ),
  elegantBeige(
    'ELEGANT_BEIGE',
    'Élégant Crème & Nude (Hollis / Salon VIP)',
    Color(0xFFF8F6F0),
    Color(0xFF8C7355),
    Color(0xFFE8E2D5),
    Color(0xFF221F1C),
  ),
  moderneMinimal(
    'MODERNE_MINIMAL',
    'TechVerse Blanc & Épuré',
    Color(0xFFFFFFFF),
    Color(0xFFDC2626), // Rouge vif TechVerse
    Color(0xFFF1F5F9),
    Color(0xFF0F172A),
  ),
  sombrePro(
    'SOMBRE_PRO',
    'GizmoHub Bleu Électrique & Sombre',
    Color(0xFF0A0E1A),
    Color(0xFF2563EB),
    Color(0xFF1E293B),
    Color(0xFFF8FAFC),
  ),
  naturelChaud(
    'NATUREL_CHAUD',
    'Havenly Vert Forêt & Terre (Immobilier)',
    Color(0xFFFAF8F5),
    Color(0xFF1B3B2B), // Vert prestige Havenly
    Color(0xFFEFE9DF),
    Color(0xFF1C241F),
  ),
  commercialVert(
    'COMMERCIAL_VERT',
    'Vert Duba & Blanc',
    Color(0xFFFFFFFF),
    Color(0xFF1E7E4E),
    Color(0xFFDCFCE7),
    Color(0xFF1A2522),
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
