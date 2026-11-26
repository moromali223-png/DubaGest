import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_types.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_config.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_prestation.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_galerie_item.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_membre_equipe.dart';
import 'package:dubagest/features/vitrine/domain/entities/vitrine_rendez_vous.dart';
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
      expect(sections.produits, isFalse); // Produits désactivés par défaut (salon sans stock)
    });

    test('2. Modèle A recommandé pour Commerce général avec produits activés', () {
      final act = TypeActivite.commerceGeneral;
      final modele = ModeleVitrine.recommanderPour(act);
      expect(modele, ModeleVitrine.modeleA);

      final sections = VitrineSections.parDefautPour(act);
      expect(sections.produits, isTrue);
      expect(sections.prestations, isFalse);
    });

    test('3. Modèle B pour Boutique spécialisée et Modèle D pour Beauté', () {
      expect(ModeleVitrine.recommanderPour(TypeActivite.boutiqueSpecialisee), ModeleVitrine.modeleB);
      expect(ModeleVitrine.recommanderPour(TypeActivite.beauteEsthetique), ModeleVitrine.modeleD);
      expect(ModeleVitrine.recommanderPour(TypeActivite.prestataireServices), ModeleVitrine.modeleE);
    });

    test('4. Sérialisation et désérialisation VitrineConfig', () {
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

    test('5. Sérialisation VitrinePrestation et formatage durée', () {
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
      const p2 = VitrinePrestation(
        id: 'p-2',
        vitrineId: 'v-1',
        entrepriseId: 'e-1',
        nom: 'Coupe',
        prix: 5000,
        dureeMinutes: 45,
      );
      expect(p2.dureeFormatee, '45 min');
      const p3 = VitrinePrestation(
        id: 'p-3',
        vitrineId: 'v-1',
        entrepriseId: 'e-1',
        nom: 'Coloration',
        prix: 20000,
        dureeMinutes: 135,
      );
      expect(p3.dureeFormatee, '2 h 15 min');

      final json = p.toJson();
      final parsed = VitrinePrestation.fromJson(json);
      expect(parsed.nom, 'Tresses Braids');
      expect(parsed.prix, 15000);
      expect(parsed.categorie, 'Tresses');
    });

    test('6. Sérialisation VitrineRendezVous et statut', () {
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

    test('7. Détection Cloudflare R2 vs Supabase Storage V1', () {
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

    test('8. VitrinePubliqueData JSON parsing unifié', () {
      final json = {
        'vitrine': {
          'id': 'v-1',
          'entreprise_id': 'e-1',
          'nom': 'Salon Kiff Coiffure',
          'slug': 'kiff-coiffure',
          'type_activite': 'SALON_COIFFURE',
          'modele_visuel': 'MODELE_C',
          'theme_style': 'LUXE_OR',
          'couleur_principale': '#111111',
          'couleur_secondaire': '#D4AF37',
          'sections_actives': {'prestations': true, 'galerie': true, 'rdv': true},
        },
        'prestations': [
          {'id': 'pr-1', 'nom': 'Coupe Dame', 'prix': 5000, 'ordre': 1},
        ],
        'galerie': [
          {'id': 'g-1', 'photo_url': 'r2:galerie/e-1/photo.jpg', 'titre': 'Braids Chic'},
        ],
        'equipe': [
          {'id': 'eq-1', 'nom': 'Awa', 'role_ou_specialite': 'Experte Tresses'},
        ],
        'produits': [],
        'collections': [],
        'nouveautes': [],
      };

      final data = VitrinePubliqueData.fromJson(json);
      expect(data.vitrine.slug, 'kiff-coiffure');
      expect(data.vitrine.modeleVisuel, ModeleVitrine.modeleC);
      expect(data.prestations.length, 1);
      expect(data.prestations.first.nom, 'Coupe Dame');
      expect(data.galerie.length, 1);
      expect(data.equipe.length, 1);
      expect(data.equipe.first.nom, 'Awa');
    });
  });
}
