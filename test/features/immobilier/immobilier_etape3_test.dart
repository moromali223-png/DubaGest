import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/immobilier/data/models/bien_mappers.dart';
import 'package:dubagest/features/immobilier/domain/entities/bien_immobilier.dart';

void main() {
  group('Étape 3 — Biens et Propriétaires : Tests Unitaires', () {
    test('BienImmobilier : Sérialisation et désérialisation JSON intègre', () {
      final bien = BienImmobilier(
        id: 'bien-123',
        entrepriseId: 'ent-1',
        reference: 'VILLA-001',
        nom: 'Villa Océan Almadies',
        type: TypeBien.maison,
        statut: StatutBien.disponible,
        proprietaireId: 'contact-proprio-1',
        loyerReference: 500000,
        periodicite: PeriodiciteLoyer.mensuelle,
        depotGarantiePrevu: 1000000,
        description: 'Superbe villa avec jardin et piscine',
        adresse: 'Route des Almadies',
        ville: 'Dakar',
        quartier: 'Almadies',
        complementAdresse: 'Lot 45',
        photos: ['https://example.com/photo1.jpg', 'https://example.com/photo2.jpg'],
        caracteristiques: const CaracteristiquesBien(
          surfaceM2: 250.5,
          nbPieces: 5,
          nbChambres: 4,
          nbSallesDeBain: 3,
          etage: 1,
          meuble: true,
          climatisation: true,
          parking: true,
          compteurEauIndependant: true,
          compteurElectriciteIndependant: true,
        ),
        notes: 'Clés chez le gardien',
        creeLe: DateTime(2026, 10, 14, 10, 0),
        misAJourLe: DateTime(2026, 10, 14, 12, 0),
        version: 1,
      );

      final json = BienMappers.bienToJson(bien);
      final deserialise = BienMappers.bienFromJson(json);

      expect(deserialise.id, 'bien-123');
      expect(deserialise.reference, 'VILLA-001');
      expect(deserialise.nom, 'Villa Océan Almadies');
      expect(deserialise.type, TypeBien.maison);
      expect(deserialise.statut, StatutBien.disponible);
      expect(deserialise.proprietaireId, 'contact-proprio-1');
      expect(deserialise.loyerReference, 500000);
      expect(deserialise.periodicite, PeriodiciteLoyer.mensuelle);
      expect(deserialise.depotGarantiePrevu, 1000000);
      expect(deserialise.photos.length, 2);
      expect(deserialise.caracteristiques.surfaceM2, 250.5);
      expect(deserialise.caracteristiques.nbChambres, 4);
      expect(deserialise.caracteristiques.meuble, isTrue);
      expect(deserialise.caracteristiques.climatisation, isTrue);
      expect(deserialise.estDisponible, isTrue);
      expect(deserialise.estOccupe, isFalse);
    });

    test('BienImmobilier : Changement de statut et copyWith', () {
      final bien = BienImmobilier(
        id: 'bien-456',
        entrepriseId: 'ent-1',
        reference: 'APT-101',
        nom: 'Studio Plateau',
        type: TypeBien.chambre,
        statut: StatutBien.disponible,
        proprietaireId: 'contact-proprio-2',
        loyerReference: 120000,
      );

      expect(bien.estDisponible, isTrue);

      final occupe = bien.copyWith(statut: StatutBien.occupe);
      expect(occupe.estOccupe, isTrue);
      expect(occupe.estDisponible, isFalse);
      expect(occupe.id, 'bien-456');
      expect(occupe.nom, 'Studio Plateau');

      final archive = bien.copyWith(statut: StatutBien.archive);
      expect(archive.estArchive, isTrue);
    });

    test('Relation : Un propriétaire peut posséder plusieurs biens', () {
      const proprietaireId = 'proprio-moussa-ba';
      final biens = [
        BienImmobilier(
          id: 'bien-1',
          entrepriseId: 'ent-1',
          reference: 'APT-1',
          nom: 'Appartement 1',
          type: TypeBien.appartement,
          proprietaireId: proprietaireId,
        ),
        BienImmobilier(
          id: 'bien-2',
          entrepriseId: 'ent-1',
          reference: 'APT-2',
          nom: 'Appartement 2',
          type: TypeBien.appartement,
          proprietaireId: proprietaireId,
        ),
        BienImmobilier(
          id: 'bien-3',
          entrepriseId: 'ent-1',
          reference: 'MAG-1',
          nom: 'Magasin Central',
          type: TypeBien.magasin,
          proprietaireId: 'autre-proprio',
        ),
      ];

      final biensDeMoussa = biens.where((b) => b.proprietaireId == proprietaireId).toList();
      expect(biensDeMoussa.length, 2);
      expect(biensDeMoussa.map((b) => b.reference), containsAll(['APT-1', 'APT-2']));
    });

    test('TypeBien : Terrains et formulaires adaptés', () {
      final terrain = BienImmobilier(
        id: 'terrain-01',
        entrepriseId: 'ent-1',
        reference: 'TER-01',
        nom: 'Parcelle Diamniadio',
        type: TypeBien.terrain,
        proprietaireId: 'proprio-1',
        loyerReference: 50000,
        caracteristiques: const CaracteristiquesBien(surfaceM2: 500),
      );

      expect(terrain.type, TypeBien.terrain);
      expect(terrain.caracteristiques.surfaceM2, 500);
      expect(terrain.caracteristiques.nbPieces, isNull);
      expect(terrain.caracteristiques.etage, isNull);
    });
  });
}
