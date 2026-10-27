import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/immobilier/domain/entities/bien_immobilier.dart';
import 'package:dubagest/features/immobilier/domain/entities/location_immobilier.dart';

void main() {
  group('Étape 5 — Locations : Tests Unitaires', () {
    test('LocationImmobilier : Sérialisation et désérialisation JSON intègre', () {
      final location = LocationImmobilier(
        id: 'loc-001',
        entrepriseId: 'ent-1',
        bienId: 'bien-101',
        locataireId: 'locataire-202',
        contratId: 'ctr-303',
        dateDebut: DateTime(2026, 1, 1),
        dateFinPrevue: DateTime(2026, 12, 31),
        loyerMensuel: 350000,
        chargesMensuelles: 25000,
        depotGarantie: 700000,
        statut: StatutLocation.active,
        etatLieuxEntree: true,
        remarques: 'Caution versée en espèces et séquestrée',
        creeLe: DateTime(2026, 1, 1, 10, 0),
        misAJourLe: DateTime(2026, 1, 1, 12, 0),
        version: 1,
      );

      final json = location.toJson();
      final deserialise = LocationImmobilier.fromJson(json);

      expect(deserialise.id, 'loc-001');
      expect(deserialise.entrepriseId, 'ent-1');
      expect(deserialise.bienId, 'bien-101');
      expect(deserialise.locataireId, 'locataire-202');
      expect(deserialise.contratId, 'ctr-303');
      expect(deserialise.dateDebut, DateTime(2026, 1, 1));
      expect(deserialise.dateFinPrevue, DateTime(2026, 12, 31));
      expect(deserialise.loyerMensuel, 350000);
      expect(deserialise.chargesMensuelles, 25000);
      expect(deserialise.totalMensuel, 375000);
      expect(deserialise.depotGarantie, 700000);
      expect(deserialise.statut, StatutLocation.active);
      expect(deserialise.etatLieuxEntree, isTrue);
      expect(deserialise.estActive, isTrue);
      expect(deserialise.estCloturee, isFalse);
    });

    test('Règle anti-chevauchement : Détection précise des conflits temporels', () {
      final locationExistante = LocationImmobilier(
        id: 'loc-1',
        entrepriseId: 'ent-1',
        bienId: 'bien-1',
        locataireId: 'loc-A',
        dateDebut: DateTime(2026, 1, 1),
        dateFinPrevue: DateTime(2026, 6, 30),
        loyerMensuel: 200000,
        statut: StatutLocation.active,
      );

      // 1. Période entièrement à l'intérieur -> Chevauchement
      expect(
        locationExistante.chevauchePeriode(DateTime(2026, 2, 1), DateTime(2026, 4, 30)),
        isTrue,
      );

      // 2. Début avant, fin à l'intérieur -> Chevauchement
      expect(
        locationExistante.chevauchePeriode(DateTime(2025, 12, 1), DateTime(2026, 3, 1)),
        isTrue,
      );

      // 3. Début à l'intérieur, fin après -> Chevauchement
      expect(
        locationExistante.chevauchePeriode(DateTime(2026, 5, 1), DateTime(2026, 8, 1)),
        isTrue,
      );

      // 4. Période strictement après -> Pas de chevauchement
      expect(
        locationExistante.chevauchePeriode(DateTime(2026, 7, 1), DateTime(2026, 12, 31)),
        isFalse,
      );

      // 5. Période strictement avant -> Pas de chevauchement
      expect(
        locationExistante.chevauchePeriode(DateTime(2025, 6, 1), DateTime(2025, 12, 31)),
        isFalse,
      );

      // 6. Une location clôturée / terminée ne bloque pas les nouvelles périodes
      final locationTerminee = locationExistante.copyWith(
        statut: StatutLocation.terminee,
        dateFinReelle: DateTime(2026, 3, 31),
      );
      expect(
        locationTerminee.chevauchePeriode(DateTime(2026, 2, 1), DateTime(2026, 4, 30)),
        isFalse,
      );
    });

    test('Statistiques d\'occupation : Taux et montants consolidés', () {
      final biens = [
        const BienImmobilier(
          id: 'b-1',
          entrepriseId: 'ent-1',
          reference: 'B1',
          nom: 'Bien 1',
          type: TypeBien.appartement,
          statut: StatutBien.occupe,
          proprietaireId: 'p-1',
        ),
        const BienImmobilier(
          id: 'b-2',
          entrepriseId: 'ent-1',
          reference: 'B2',
          nom: 'Bien 2',
          type: TypeBien.maison,
          statut: StatutBien.occupe,
          proprietaireId: 'p-1',
        ),
        const BienImmobilier(
          id: 'b-3',
          entrepriseId: 'ent-1',
          reference: 'B3',
          nom: 'Bien 3',
          type: TypeBien.magasin,
          statut: StatutBien.disponible,
          proprietaireId: 'p-1',
        ),
        const BienImmobilier(
          id: 'b-4',
          entrepriseId: 'ent-1',
          reference: 'B4',
          nom: 'Bien 4',
          type: TypeBien.chambre,
          statut: StatutBien.enTravaux,
          proprietaireId: 'p-1',
        ),
      ];

      final totalActifs = biens.length;
      final occupes = biens.where((b) => b.statut == StatutBien.occupe).length;
      final vacants = biens.where((b) => b.statut == StatutBien.disponible).length;
      final taux = (occupes / totalActifs) * 100;

      expect(totalActifs, 4);
      expect(occupes, 2);
      expect(vacants, 1);
      expect(taux, 50.0);
    });

    test('Clôture de location : Transition vers libération du bien', () {
      final location = LocationImmobilier(
        id: 'loc-cloture',
        entrepriseId: 'ent-1',
        bienId: 'b-1',
        locataireId: 'loc-1',
        dateDebut: DateTime(2026, 1, 1),
        loyerMensuel: 150000,
        statut: StatutLocation.active,
      );

      expect(location.estActive, isTrue);

      final cloturee = location.copyWith(
        statut: StatutLocation.terminee,
        dateFinReelle: DateTime(2026, 4, 30),
        motifCloture: 'Déménagement locataire',
        etatLieuxSortie: true,
      );

      expect(cloturee.estActive, isFalse);
      expect(cloturee.estCloturee, isTrue);
      expect(cloturee.statut, StatutLocation.terminee);
      expect(cloturee.dateFinReelle, DateTime(2026, 4, 30));
      expect(cloturee.etatLieuxSortie, isTrue);
    });
  });
}
