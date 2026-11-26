import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_types.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_config.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_prestation.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_rendez_vous.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_bien_immobilier.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_demande_visite.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_produit_item.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_publique_data.dart';
import 'package:dubagest/features/catalogue/services/media_hybrid_resolver.dart';

void main() {
  group('Vitrine DubaGest V2 — Tests unitaires & de domaine', () {
    test('1. Modèle C recommandé pour un salon de coiffure avec sections adaptées', () {
      final act = TypeActivite.salonCoiffure;
      final modele = ModeleVitrine.recommanderPour(act);
      expect(modele, ModeleVitrine.modeleC);

      final sections = VitrineSections.parDefautPour(act);
      expect(sections.prestations, isTrue);
      expect(sections.tarifs, isTrue);
      expect(sections.galerie, isTrue);
      expect(sections.equipe, isTrue);
      expect(sections.rdv, isTrue);
      expect(sections.produits, isTrue); // Produits activés pour perruques & mèches
      expect(sections.biens, isFalse);
    });

    test('2. Modèle A recommandé pour Commerce général avec produits activés', () {
      final act = TypeActivite.commerceGeneral;
      final modele = ModeleVitrine.recommanderPour(act);
      expect(modele, ModeleVitrine.modeleA);

      final sections = VitrineSections.parDefautPour(act);
      expect(sections.produits, isTrue);
      expect(sections.prestations, isFalse);
      expect(sections.biens, isFalse);
    });

    test('3. Modèle B pour Boutique spécialisée, Modèle D pour Beauté et Modèle F pour Immobilier', () {
      expect(ModeleVitrine.recommanderPour(TypeActivite.boutiqueSpecialisee), ModeleVitrine.modeleB);
      expect(ModeleVitrine.recommanderPour(TypeActivite.boutiqueTech), ModeleVitrine.modeleB);
      expect(ModeleVitrine.recommanderPour(TypeActivite.cosmetiqueBeaute), ModeleVitrine.modeleD);
      expect(ModeleVitrine.recommanderPour(TypeActivite.prestataireServices), ModeleVitrine.modeleE);
      expect(ModeleVitrine.recommanderPour(TypeActivite.agenceImmobiliere), ModeleVitrine.modeleF);
      expect(ModeleVitrine.recommanderPour(TypeActivite.immobilierLocation), ModeleVitrine.modeleF);
      expect(ModeleVitrine.recommanderPour(TypeActivite.immobilierVente), ModeleVitrine.modeleF);
    });

    test('4. Sections par défaut Domaine Immobilier', () {
      final sections = VitrineSections.parDefautPour(TypeActivite.agenceImmobiliere);
      expect(sections.biens, isTrue);
      expect(sections.demandeVisite, isTrue);
      expect(sections.galerie, isTrue);
      expect(sections.equipe, isTrue);
      expect(sections.produits, isFalse);
      expect(sections.prestations, isFalse);
    });

    test('5. Sérialisation et désérialisation VitrineConfig', () {
      const config = VitrineConfig(
        id: 'vitrine-123',
        entrepriseId: 'ent-456',
        slug: 'salon-elegance-bamako',
        typeActivite: TypeActivite.salonCoiffure,
        modeleVisuel: ModeleVitrine.modeleC,
        themeStyle: ThemeStyle.luxeOr,
        titreHero: 'Salon Élégance Bamako',
        slogan: 'L\'art de sublimer votre beauté',
        telephone: '+22370000000',
        whatsapp: '+22370000000',
        sections: VitrineSections(prestations: true, rdv: true, produits: true),
      );

      final json = config.toJson();
      expect(json['slug'], 'salon-elegance-bamako');
      expect(json['type_activite'], 'SALON_COIFFURE');
      expect(json['modele_visuel'], 'MODELE_C');
      expect(json['theme_style'], 'LUXE_OR');

      final parsed = VitrineConfig.fromJson(json);
      expect(parsed.id, 'vitrine-123');
      expect(parsed.slug, 'salon-elegance-bamako');
      expect(parsed.typeActivite, TypeActivite.salonCoiffure);
      expect(parsed.modeleVisuel, ModeleVitrine.modeleC);
      expect(parsed.themeStyle, ThemeStyle.luxeOr);
      expect(parsed.sections.prestations, isTrue);
      expect(parsed.sections.rdv, isTrue);
      expect(parsed.sections.produits, isTrue);
    });

    test('6. Sérialisation VitrinePrestation et formatage durée et prix', () {
      const p = VitrinePrestation(
        id: 'p-1',
        vitrineId: 'v-1',
        entrepriseId: 'e-1',
        nom: 'Tresses Braids',
        prix: 15000,
        dureeMinutes: 120,
        categorie: 'Tresses',
      );

      expect(p.dureeFormatee, '2 h');
      expect(p.prixFormate, '15 000 FCFA');

      const p2 = VitrinePrestation(
        id: 'p-2',
        vitrineId: 'v-1',
        entrepriseId: 'e-1',
        nom: 'Coupe',
        prix: 5000,
        dureeMinutes: 45,
      );
      expect(p2.dureeFormatee, '45 min');
      expect(p2.prixFormate, '5 000 FCFA');

      final json = p.toJson();
      final parsed = VitrinePrestation.fromJson(json);
      expect(parsed.nom, 'Tresses Braids');
      expect(parsed.prix, 15000);
      expect(parsed.categorie, 'Tresses');
    });

    test('7. Sérialisation VitrineRendezVous et statut', () {
      final rdv = VitrineRendezVous(
        id: 'rdv-1',
        vitrineId: 'v-1',
        entrepriseId: 'e-1',
        nomPrestation: 'Brushing & Soin',
        dateSouhaitee: DateTime(2026, 12, 1),
        heureSouhaitee: '14:30',
        nomClient: 'Fatoumata Traoré',
        telephoneClient: '+22371234567',
        statut: StatutRendezVous.enAttente,
      );

      final json = rdv.toJson();
      expect(json['statut'], 'EN_ATTENTE');
      expect(json['nom_client'], 'Fatoumata Traoré');

      final parsed = VitrineRendezVous.fromJson(json);
      expect(parsed.statut, StatutRendezVous.enAttente);
      expect(parsed.telephoneClient, '+22371234567');
    });

    test('8. Sérialisation VitrineBienImmobilier et formatage prix/loyer', () {
      const bien = VitrineBienImmobilier(
        id: 'b-1',
        vitrineId: 'v-1',
        entrepriseId: 'e-1',
        titre: 'Villa Moderne F5 avec Piscine',
        typeBien: 'VILLA',
        typeOffre: 'LOCATION',
        prix: 750000,
        surfaceM2: 350,
        nbChambres: 4,
        nbSallesDeBain: 3,
        ville: 'Bamako',
        quartier: 'ACI 2000',
      );

      expect(bien.prixFormate, '750 000 FCFA / mois');

      final json = bien.toJson();
      expect(json['titre'], 'Villa Moderne F5 avec Piscine');
      expect(json['type_offre'], 'LOCATION');
      expect(json['prix'], 750000);

      final parsed = VitrineBienImmobilier.fromJson(json);
      expect(parsed.titre, 'Villa Moderne F5 avec Piscine');
      expect(parsed.nbChambres, 4);
      expect(parsed.nbSallesDeBain, 3);
      expect(parsed.surfaceM2, 350.0);
    });

    test('9. Sérialisation VitrineDemandeVisite', () {
      final visite = VitrineDemandeVisite(
        id: 'visite-1',
        vitrineId: 'v-1',
        entrepriseId: 'e-1',
        nomBien: 'Villa Moderne F5',
        nomClient: 'Amadou Coulibaly',
        telephoneClient: '+22370000000',
        dateSouhaitee: DateTime(2026, 12, 5),
        heureSouhaitee: '10:00',
        statut: StatutDemandeVisite.enAttente,
      );

      final json = visite.toJson();
      expect(json['nom_client'], 'Amadou Coulibaly');
      expect(json['statut'], 'EN_ATTENTE');

      final parsed = VitrineDemandeVisite.fromJson(json);
      expect(parsed.nomClient, 'Amadou Coulibaly');
      expect(parsed.statut, StatutDemandeVisite.enAttente);
    });

    test('10. Détection Cloudflare R2 vs Supabase Storage V1', () {
      expect(
        MediaHybridResolver.detectOrigin('r2:vitrines/ent-1/banniere/img.jpg'),
        MediaOrigin.cloudflareR2,
      );
      expect(
        MediaHybridResolver.detectOrigin('https://media.dubagest.com/r2:photos/img.jpg'),
        MediaOrigin.cloudflareR2,
      );
      expect(
        MediaHybridResolver.detectOrigin('ent-1/produits/prod-1/photo.jpg'),
        MediaOrigin.supabaseV1,
      );
      expect(
        MediaHybridResolver.detectOrigin('supabase:fichiers/ancien.jpg'),
        MediaOrigin.supabaseV1,
      );
    });

    test('11. VitrinePubliqueData JSON parsing unifié avec biens immobiliers', () {
      final json = {
        'vitrine': {
          'id': 'v-1',
          'entreprise_id': 'e-1',
          'nom': 'Agence Havenly Prestige',
          'slug': 'havenly-prestige',
          'type_activite': 'AGENCE_IMMOBILIERE',
          'modele_visuel': 'MODELE_F',
          'theme_style': 'NATUREL_CHAUD',
          'couleur_principale': '#1B3B2B',
          'couleur_secondaire': '#EFE9DF',
          'sections_actives': {'biens': true, 'demande_visite': true},
        },
        'prestations': [],
        'galerie': [
          {'id': 'g-1', 'photo_url': 'r2:galerie/e-1/photo.jpg', 'titre': 'Villa Havenly'},
        ],
        'equipe': [
          {'id': 'eq-1', 'nom': 'Sarah Mansouri', 'role_ou_specialite': 'Directrice Immobilière'},
        ],
        'produits': [],
        'collections': [],
        'nouveautes': [],
        'biens': [
          {
            'id': 'b-1',
            'titre': 'Modern Villa in Casablanca',
            'type_bien': 'VILLA',
            'type_offre': 'VENTE',
            'prix': 450000000,
            'photos': ['r2:biens/villa.jpg'],
            'nb_chambres': 4,
            'nb_salles_de_bain': 3,
            'surface_m2': 320,
          }
        ],
      };

      final data = VitrinePubliqueData.fromJson(json);
      expect(data.vitrine.slug, 'havenly-prestige');
      expect(data.vitrine.modeleVisuel, ModeleVitrine.modeleF);
      expect(data.biens.length, 1);
      expect(data.biens.first.titre, 'Modern Villa in Casablanca');
      expect(data.biens.first.nbChambres, 4);
      expect(data.biens.first.surfaceM2, 320.0);
      expect(data.equipe.length, 1);
    });

    test('12. Sérialisation et désérialisation VitrineProduitItem', () {
      const prod = VitrineProduitItem(
        id: 'p-100',
        nom: 'Écouteurs Pro Sans Fil',
        description: 'Réduction active du bruit et autonomie 30h',
        prix: 45000,
        prixBarre: 60000,
        photoUrl: 'https://images.unsplash.com/photo-example',
        estPublie: true,
      );

      final json = prod.toJson(entrepriseId: 'ent-123');
      expect(json['id'], 'p-100');
      expect(json['entreprise_id'], 'ent-123');
      expect(json['nom'], 'Écouteurs Pro Sans Fil');
      expect(json['prix_detail'], 45000);
      expect(json['prix_barre'], 60000);
      expect(json['est_publie_catalogue'], true);

      final decoded = VitrineProduitItem.fromJson(json);
      expect(decoded.id, prod.id);
      expect(decoded.nom, prod.nom);
      expect(decoded.prixFormate, '45 000 FCFA');
      expect(decoded.aPromotion, isTrue);
    });
  });
}
