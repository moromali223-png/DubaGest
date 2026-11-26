import 'vitrine_types.dart';

/// Horaires d'ouverture par jour
class HoraireJour {
  const HoraireJour({
    required this.jour,
    required this.ouvert,
    this.ouverture = '08:30',
    this.fermeture = '19:00',
  });

  final String jour;
  final bool ouvert;
  final String ouverture;
  final String fermeture;

  Map<String, dynamic> toJson() => {
        'jour': jour,
        'ouvert': ouvert,
        'ouverture': ouverture,
        'fermeture': fermeture,
      };

  factory HoraireJour.fromJson(Map<String, dynamic> j) => HoraireJour(
        jour: j['jour'] as String? ?? '',
        ouvert: j['ouvert'] as bool? ?? true,
        ouverture: j['ouverture'] as String? ?? '08:30',
        fermeture: j['fermeture'] as String? ?? '19:00',
      );

  HoraireJour copyWith({
    String? jour,
    bool? ouvert,
    String? ouverture,
    String? fermeture,
  }) =>
      HoraireJour(
        jour: jour ?? this.jour,
        ouvert: ouvert ?? this.ouvert,
        ouverture: ouverture ?? this.ouverture,
        fermeture: fermeture ?? this.fermeture,
      );
}

/// Sections activables ou désactivables selon l'activité
class VitrineSections {
  const VitrineSections({
    this.accueil = true,
    this.aPropos = true,
    this.produits = true,
    this.prestations = false,
    this.tarifs = false,
    this.galerie = false,
    this.equipe = false,
    this.rdv = false,
    this.horaires = true,
    this.contact = true,
    this.temoignages = false,
  });

  final bool accueil;
  final bool aPropos;
  final bool produits;
  final bool prestations;
  final bool tarifs;
  final bool galerie;
  final bool equipe;
  final bool rdv;
  final bool horaires;
  final bool contact;
  final bool temoignages;

  Map<String, dynamic> toJson() => {
        'accueil': accueil,
        'a_propos': aPropos,
        'produits': produits,
        'prestations': prestations,
        'tarifs': tarifs,
        'galerie': galerie,
        'equipe': equipe,
        'rdv': rdv,
        'horaires': horaires,
        'contact': contact,
        'temoignages': temoignages,
      };

  factory VitrineSections.fromJson(Map<String, dynamic> j) => VitrineSections(
        accueil: j['accueil'] as bool? ?? true,
        aPropos: j['a_propos'] as bool? ?? true,
        produits: j['produits'] as bool? ?? true,
        prestations: j['prestations'] as bool? ?? false,
        tarifs: j['tarifs'] as bool? ?? false,
        galerie: j['galerie'] as bool? ?? false,
        equipe: j['equipe'] as bool? ?? false,
        rdv: j['rdv'] as bool? ?? false,
        horaires: j['horaires'] as bool? ?? true,
        contact: j['contact'] as bool? ?? true,
        temoignages: j['temoignages'] as bool? ?? false,
      );

  VitrineSections copyWith({
    bool? accueil,
    bool? aPropos,
    bool? produits,
    bool? prestations,
    bool? tarifs,
    bool? galerie,
    bool? equipe,
    bool? rdv,
    bool? horaires,
    bool? contact,
    bool? temoignages,
  }) =>
      VitrineSections(
        accueil: accueil ?? this.accueil,
        aPropos: aPropos ?? this.aPropos,
        produits: produits ?? this.produits,
        prestations: prestations ?? this.prestations,
        tarifs: tarifs ?? this.tarifs,
        galerie: galerie ?? this.galerie,
        equipe: equipe ?? this.equipe,
        rdv: rdv ?? this.rdv,
        horaires: horaires ?? this.horaires,
        contact: contact ?? this.contact,
        temoignages: temoignages ?? this.temoignages,
      );

  /// Sections par défaut adaptées à chaque activité
  static VitrineSections parDefautPour(TypeActivite activite) {
    switch (activite) {
      case TypeActivite.commerceGeneral:
        return const VitrineSections(
          accueil: true,
          aPropos: true,
          produits: true,
          prestations: false,
          tarifs: false,
          galerie: false,
          equipe: false,
          rdv: false,
          horaires: true,
          contact: true,
        );
      case TypeActivite.boutiqueSpecialisee:
        return const VitrineSections(
          accueil: true,
          aPropos: true,
          produits: true,
          prestations: false,
          tarifs: false,
          galerie: true,
          equipe: false,
          rdv: false,
          horaires: true,
          contact: true,
        );
      case TypeActivite.salonCoiffure:
        return const VitrineSections(
          accueil: true,
          aPropos: true,
          produits: false, // Peut être activé si vente de mèches/produits
          prestations: true,
          tarifs: true,
          galerie: true,
          equipe: true,
          rdv: true,
          horaires: true,
          contact: true,
        );
      case TypeActivite.beauteEsthetique:
        return const VitrineSections(
          accueil: true,
          aPropos: true,
          produits: false,
          prestations: true,
          tarifs: true,
          galerie: true,
          equipe: true,
          rdv: true,
          horaires: true,
          contact: true,
        );
      case TypeActivite.prestataireServices:
      case TypeActivite.autre:
        return const VitrineSections(
          accueil: true,
          aPropos: true,
          produits: false,
          prestations: true,
          tarifs: true,
          galerie: true,
          equipe: true,
          rdv: true,
          horaires: true,
          contact: true,
          temoignages: true,
        );
    }
  }
}

/// Configuration globale d'une vitrine V2 personnalisée
class VitrineConfig {
  const VitrineConfig({
    required this.id,
    required this.entrepriseId,
    required this.slug,
    this.typeActivite = TypeActivite.commerceGeneral,
    this.modeleVisuel = ModeleVitrine.modeleA,
    this.themeStyle = ThemeStyle.commercialVert,
    this.couleurPrincipale = '#1E7E4E',
    this.couleurSecondaire = '#10B981',
    this.titreHero,
    this.slogan,
    this.description,
    this.logoUrl,
    this.banniereUrl,
    this.photoPresentationUrl,
    this.audioPresentationUrl,
    this.sections = const VitrineSections(),
    this.horaires = const [],
    this.adresse,
    this.ville,
    this.pays = 'Mali',
    this.telephone,
    this.whatsapp,
    this.email,
    this.reseauxSociaux = const {},
    this.estPublie = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String entrepriseId;
  final String slug;
  final TypeActivite typeActivite;
  final ModeleVitrine modeleVisuel;
  final ThemeStyle themeStyle;
  final String couleurPrincipale;
  final String couleurSecondaire;
  final String? titreHero;
  final String? slogan;
  final String? description;
  final String? logoUrl;
  final String? banniereUrl;
  final String? photoPresentationUrl;
  final String? audioPresentationUrl;
  final VitrineSections sections;
  final List<HoraireJour> horaires;
  final String? adresse;
  final String? ville;
  final String pays;
  final String? telephone;
  final String? whatsapp;
  final String? email;
  final Map<String, dynamic> reseauxSociaux;
  final bool estPublie;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get whatsappContact => (whatsapp != null && whatsapp!.trim().isNotEmpty)
      ? whatsapp!.trim()
      : (telephone ?? '').trim();

  String get urlPublique => 'https://dubagest.com/v/$slug';

  Map<String, dynamic> toJson() => {
        'id': id,
        'entreprise_id': entrepriseId,
        'slug': slug,
        'type_activite': typeActivite.code,
        'modele_visuel': modeleVisuel.code,
        'theme_style': themeStyle.code,
        'couleur_principale': couleurPrincipale,
        'couleur_secondaire': couleurSecondaire,
        'titre_hero': titreHero,
        'slogan': slogan,
        'description': description,
        'logo_url': logoUrl,
        'banniere_url': banniereUrl,
        'photo_presentation_url': photoPresentationUrl,
        'audio_presentation_url': audioPresentationUrl,
        'sections_actives': sections.toJson(),
        'horaires': horaires.map((h) => h.toJson()).toList(),
        'adresse': adresse,
        'ville': ville,
        'pays': pays,
        'telephone': telephone,
        'whatsapp': whatsapp,
        'email': email,
        'reseaux_sociaux': reseauxSociaux,
        'est_publie': estPublie,
      };

  factory VitrineConfig.fromJson(Map<String, dynamic> j) {
    final secs = j['sections_actives'] is Map
        ? VitrineSections.fromJson((j['sections_actives'] as Map).cast<String, dynamic>())
        : const VitrineSections();

    final hrs = [
      for (final h in (j['horaires'] as List?) ?? const [])
        if (h is Map) HoraireJour.fromJson(h.cast<String, dynamic>()),
    ];

    return VitrineConfig(
      id: j['id'] as String? ?? '',
      entrepriseId: j['entreprise_id'] as String? ?? '',
      slug: j['slug'] as String? ?? '',
      typeActivite: TypeActivite.fromCode(j['type_activite'] as String?),
      modeleVisuel: ModeleVitrine.fromCode(j['modele_visuel'] as String?),
      themeStyle: ThemeStyle.fromCode(j['theme_style'] as String?),
      couleurPrincipale: j['couleur_principale'] as String? ?? '#1E7E4E',
      couleurSecondaire: j['couleur_secondaire'] as String? ?? '#10B981',
      titreHero: j['titre_hero'] as String?,
      slogan: j['slogan'] as String?,
      description: j['description'] as String?,
      logoUrl: j['logo_url'] as String?,
      banniereUrl: j['banniere_url'] as String?,
      photoPresentationUrl: j['photo_presentation_url'] as String?,
      audioPresentationUrl: j['audio_presentation_url'] as String?,
      sections: secs,
      horaires: hrs.isNotEmpty
          ? hrs
          : const [
              HoraireJour(jour: 'Lundi', ouvert: true),
              HoraireJour(jour: 'Mardi', ouvert: true),
              HoraireJour(jour: 'Mercredi', ouvert: true),
              HoraireJour(jour: 'Jeudi', ouvert: true),
              HoraireJour(jour: 'Vendredi', ouvert: true),
              HoraireJour(jour: 'Samedi', ouvert: true, ouverture: '09:00', fermeture: '20:00'),
              HoraireJour(jour: 'Dimanche', ouvert: false),
            ],
      adresse: j['adresse'] as String?,
      ville: j['ville'] as String?,
      pays: j['pays'] as String? ?? 'Mali',
      telephone: j['telephone'] as String?,
      whatsapp: j['whatsapp'] as String?,
      email: j['email'] as String?,
      reseauxSociaux: (j['reseaux_sociaux'] as Map?)?.cast<String, dynamic>() ?? const {},
      estPublie: j['est_publie'] as bool? ?? true,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
      updatedAt: j['updated_at'] != null ? DateTime.tryParse(j['updated_at'].toString()) : null,
    );
  }

  VitrineConfig copyWith({
    String? id,
    String? entrepriseId,
    String? slug,
    TypeActivite? typeActivite,
    ModeleVitrine? modeleVisuel,
    ThemeStyle? themeStyle,
    String? couleurPrincipale,
    String? couleurSecondaire,
    String? titreHero,
    String? slogan,
    String? description,
    String? logoUrl,
    String? banniereUrl,
    String? photoPresentationUrl,
    String? audioPresentationUrl,
    VitrineSections? sections,
    List<HoraireJour>? horaires,
    String? adresse,
    String? ville,
    String? pays,
    String? telephone,
    String? whatsapp,
    String? email,
    Map<String, dynamic>? reseauxSociaux,
    bool? estPublie,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      VitrineConfig(
        id: id ?? this.id,
        entrepriseId: entrepriseId ?? this.entrepriseId,
        slug: slug ?? this.slug,
        typeActivite: typeActivite ?? this.typeActivite,
        modeleVisuel: modeleVisuel ?? this.modeleVisuel,
        themeStyle: themeStyle ?? this.themeStyle,
        couleurPrincipale: couleurPrincipale ?? this.couleurPrincipale,
        couleurSecondaire: couleurSecondaire ?? this.couleurSecondaire,
        titreHero: titreHero ?? this.titreHero,
        slogan: slogan ?? this.slogan,
        description: description ?? this.description,
        logoUrl: logoUrl ?? this.logoUrl,
        banniereUrl: banniereUrl ?? this.banniereUrl,
        photoPresentationUrl: photoPresentationUrl ?? this.photoPresentationUrl,
        audioPresentationUrl: audioPresentationUrl ?? this.audioPresentationUrl,
        sections: sections ?? this.sections,
        horaires: horaires ?? this.horaires,
        adresse: adresse ?? this.adresse,
        ville: ville ?? this.ville,
        pays: pays ?? this.pays,
        telephone: telephone ?? this.telephone,
        whatsapp: whatsapp ?? this.whatsapp,
        email: email ?? this.email,
        reseauxSociaux: reseauxSociaux ?? this.reseauxSociaux,
        estPublie: estPublie ?? this.estPublie,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
