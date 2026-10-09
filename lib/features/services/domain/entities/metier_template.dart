import 'package:flutter/material.dart';

/// Unité de durée pour la planification et l'estimation des délais.
enum UniteDuree {
  heures('HEURES', 'Heure(s)', 1 / 24),
  jours('JOURS', 'Jour(s)', 1),
  semaines('SEMAINES', 'Semaine(s)', 7),
  mois('MOIS', 'Mois', 30);

  const UniteDuree(this.code, this.libelle, this.multiplicateurJours);
  final String code;
  final String libelle;
  final double multiplicateurJours;

  static UniteDuree parse(String? code) =>
      values.firstWhere((u) => u.code == code, orElse: () => jours);
}

/// Modèles métiers prédéfinis pour les prestations et ordres de travail.
enum MetierCode {
  generique('GENERIQUE', 'Générique / Prestation standard', Icons.handyman_outlined),
  incubation('INCUBATION', 'Incubation d\'œufs & Aviculture', Icons.egg_outlined),
  pressing('PRESSING', 'Pressing & Blanchisserie', Icons.local_laundry_service_outlined),
  couture('COUTURE', 'Couture, Confection & Retouches', Icons.content_cut_outlined),
  reparation('REPARATION', 'Réparation & SAV (Téléphone, Auto, PC)', Icons.phonelink_setup_outlined),
  menuiserie('MENUISERIE', 'Menuiserie & Fabrication sur commande', Icons.carpenter_outlined),
  entretien('ENTRETIEN', 'Entretien, Climatisation & Nettoyage', Icons.cleaning_services_outlined),
  surMesure('SUR_MESURE', 'Fabrication artisanale sur-mesure', Icons.design_services_outlined);

  const MetierCode(this.code, this.libelle, this.icone);
  final String code;
  final String libelle;
  final IconData icone;

  static MetierCode parse(String? code) =>
      values.firstWhere((m) => m.code == code, orElse: () => generique);
}

/// Définition d'un champ spécifique à un modèle métier.
class ChampMetierDefinition {
  const ChampMetierDefinition({
    required this.cle,
    required this.libelle,
    required this.hint,
    this.type = TextInputType.text,
    this.options = const [],
    this.requis = false,
  });

  final String cle;
  final String libelle;
  final String hint;
  final TextInputType type;
  final List<String> options;
  final bool requis;
}

/// Modèle métier complet avec champs spécifiques et valeurs par défaut.
class MetierTemplate {
  const MetierTemplate({
    required this.code,
    required this.titreParDefaut,
    required this.dureeParDefaut,
    required this.uniteParDefaut,
    required this.champs,
    required this.instructions,
  });

  final MetierCode code;
  final String titreParDefaut;
  final int dureeParDefaut;
  final UniteDuree uniteParDefaut;
  final List<ChampMetierDefinition> champs;
  final String instructions;

  static final Map<MetierCode, MetierTemplate> catalogue = {
    MetierCode.incubation: const MetierTemplate(
      code: MetierCode.incubation,
      titreParDefaut: 'Lot incubation d\'œufs',
      dureeParDefaut: 21,
      uniteParDefaut: UniteDuree.jours,
      instructions: 'Mirage recommandé au 7e et 14e jour. Date d\'éclosion estimée selon l\'espèce.',
      champs: [
        ChampMetierDefinition(
          cle: 'espece',
          libelle: 'Espèce / Type d\'œufs',
          hint: 'Poule, Caille, Dinde, Canard, Pintade...',
          options: ['Poule (21j)', 'Caille (17j)', 'Pintade (28j)', 'Canard (28j)', 'Dinde (28j)', 'Oie (30j)'],
          requis: true,
        ),
        ChampMetierDefinition(
          cle: 'nb_oeufs',
          libelle: 'Nombre d\'œufs déposés',
          hint: 'Ex. 150',
          type: TextInputType.number,
          requis: true,
        ),
        ChampMetierDefinition(
          cle: 'numero_lot',
          libelle: 'Numéro de lot / Plateau',
          hint: 'Ex. LOT-A3, Panier 12',
        ),
        ChampMetierDefinition(
          cle: 'etat_oeufs',
          libelle: 'Observations à la réception',
          hint: 'Propreté, calibres, fêlures éventuelles...',
        ),
      ],
    ),
    MetierCode.pressing: const MetierTemplate(
      code: MetierCode.pressing,
      titreParDefaut: 'Nettoyage & Repassage vêtements',
      dureeParDefaut: 2,
      uniteParDefaut: UniteDuree.jours,
      instructions: 'Vérifier les poches, boutons, fermetures et photographier les taches préexistantes.',
      champs: [
        ChampMetierDefinition(
          cle: 'type_vetement',
          libelle: 'Type de vêtements / Linge',
          hint: 'Costume, Robe de soirée, Couette, Chemises...',
          requis: true,
        ),
        ChampMetierDefinition(
          cle: 'nb_pieces',
          libelle: 'Nombre de pièces',
          hint: 'Ex. 3',
          type: TextInputType.number,
          requis: true,
        ),
        ChampMetierDefinition(
          cle: 'taches_constatees',
          libelle: 'Taches ou défauts constatés',
          hint: 'Tache de graisse col, accroc manche...',
        ),
        ChampMetierDefinition(
          cle: 'traitement_special',
          libelle: 'Traitement demandé',
          hint: 'Nettoyage à sec, Blanchiment, Repassage seul...',
        ),
      ],
    ),
    MetierCode.couture: const MetierTemplate(
      code: MetierCode.couture,
      titreParDefaut: 'Confection & Retouche couture',
      dureeParDefaut: 7,
      uniteParDefaut: UniteDuree.jours,
      instructions: 'Noter les mesures du client, les détails du modèle choisi et photographier le tissu fourni.',
      champs: [
        ChampMetierDefinition(
          cle: 'modele',
          libelle: 'Modèle / Style de vêtement',
          hint: 'Robe sirène, Boubou 3 pièces, Chemise sur-mesure...',
          requis: true,
        ),
        ChampMetierDefinition(
          cle: 'tissu_fourni',
          libelle: 'Tissu & Fournitures',
          hint: 'Pagne Bazin 6 yards, Soie, Tissu client...',
        ),
        ChampMetierDefinition(
          cle: 'mesures',
          libelle: 'Principales mesures (Poitrine / Tour de taille / Longueur)',
          hint: 'P: 95cm, T: 78cm, L: 140cm...',
        ),
        ChampMetierDefinition(
          cle: 'date_essayage',
          libelle: 'Date d\'essayage intermédiaire',
          hint: 'Ex. Dans 4 jours',
        ),
      ],
    ),
    MetierCode.reparation: const MetierTemplate(
      code: MetierCode.reparation,
      titreParDefaut: 'Réparation appareil & SAV',
      dureeParDefaut: 4,
      uniteParDefaut: UniteDuree.heures,
      instructions: 'Tester l\'état initial de l\'appareil, relever l\'état de la coque/écran et photographier l\'appareil.',
      champs: [
        ChampMetierDefinition(
          cle: 'appareil_marque',
          libelle: 'Marque & Modèle précis',
          hint: 'Ex. Samsung Galaxy A54, HP Pavilion 15...',
          requis: true,
        ),
        ChampMetierDefinition(
          cle: 'panne_declaree',
          libelle: 'Panne ou problème signalé',
          hint: 'Écran fissuré, ne s\'allume plus, port de charge...',
          requis: true,
        ),
        ChampMetierDefinition(
          cle: 'numero_serie',
          libelle: 'N° de série / IMEI / Plaque',
          hint: 'Recommandé pour la traçabilité',
        ),
        ChampMetierDefinition(
          cle: 'code_verrouillage',
          libelle: 'Schéma / Code de déverrouillage (si utile pour tests)',
          hint: 'Code PIN pour vérification technique',
        ),
        ChampMetierDefinition(
          cle: 'accessoires_laisses',
          libelle: 'Accessoires laissés par le client',
          hint: 'Chargeur, housse, carte SIM...',
        ),
      ],
    ),
    MetierCode.menuiserie: const MetierTemplate(
      code: MetierCode.menuiserie,
      titreParDefaut: 'Fabrication menuiserie / mobilier',
      dureeParDefaut: 14,
      uniteParDefaut: UniteDuree.jours,
      instructions: 'Préciser les dimensions exactes, l\'essence de bois et les finitions validées par le client.',
      champs: [
        ChampMetierDefinition(
          cle: 'type_meuble',
          libelle: 'Ouvrage / Meuble commandé',
          hint: 'Armoire dressing 3 battants, Table salle à manger...',
          requis: true,
        ),
        ChampMetierDefinition(
          cle: 'essence_bois',
          libelle: 'Essence de bois & Matériaux',
          hint: 'Iroko, Teck, Bois rouge, MDF mélaminé...',
        ),
        ChampMetierDefinition(
          cle: 'dimensions',
          libelle: 'Dimensions (H × L × P)',
          hint: '200cm × 180cm × 60cm',
        ),
        ChampMetierDefinition(
          cle: 'finition_vernis',
          libelle: 'Teinte & Finition vernis',
          hint: 'Vernis mat, laque blanche, teinte noyer...',
        ),
      ],
    ),
    MetierCode.entretien: const MetierTemplate(
      code: MetierCode.entretien,
      titreParDefaut: 'Entretien & Nettoyage d\'équipement',
      dureeParDefaut: 3,
      uniteParDefaut: UniteDuree.heures,
      instructions: 'Relever les paramètres avant et après intervention (température, pression, état d\'encrassement).',
      champs: [
        ChampMetierDefinition(
          cle: 'equipement',
          libelle: 'Équipement / Installation',
          hint: 'Split climatiseur 1.5CV, Groupe électrogène...',
          requis: true,
        ),
        ChampMetierDefinition(
          cle: 'emplacement',
          libelle: 'Emplacement / Pièce',
          hint: 'Bureau direction, Salon rez-de-chaussée...',
        ),
        ChampMetierDefinition(
          cle: 'type_intervention',
          libelle: 'Nature de l\'entretien',
          hint: 'Nettoyage filtres, recharge gaz, vidange...',
        ),
      ],
    ),
    MetierCode.surMesure: const MetierTemplate(
      code: MetierCode.surMesure,
      titreParDefaut: 'Création artisanale sur-mesure',
      dureeParDefaut: 10,
      uniteParDefaut: UniteDuree.jours,
      instructions: 'Détailler les spécifications du client et archiver les croquis ou photos de référence.',
      champs: [
        ChampMetierDefinition(
          cle: 'description_projet',
          libelle: 'Description détaillée du projet',
          hint: 'Spécifications demandées par le client...',
          requis: true,
        ),
        ChampMetierDefinition(
          cle: 'materiaux_utilises',
          libelle: 'Matières premières et fournitures',
          hint: 'Cuir, Métal forgé, Résine...',
        ),
      ],
    ),
    MetierCode.generique: const MetierTemplate(
      code: MetierCode.generique,
      titreParDefaut: 'Prestation de services',
      dureeParDefaut: 1,
      uniteParDefaut: UniteDuree.jours,
      instructions: 'Renseigner les informations nécessaires à l\'exécution du service.',
      champs: [],
    ),
  };

  static MetierTemplate templatePour(MetierCode code) =>
      catalogue[code] ?? catalogue[MetierCode.generique]!;
}
