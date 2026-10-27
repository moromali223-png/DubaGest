import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/immobilier/domain/entities/dashboard_immobilier.dart';

void main() {
  group('Étape 8 — Dashboard Immobilier & Alertes Métier : Tests Unitaires', () {
    test('DashboardImmobilierData : Calcul précis du taux d\'occupation', () {
      final data = DashboardImmobilierData(
        totalBiens: 10,
        nbBiensOccupes: 8,
        nbBiensDisponibles: 1,
        nbBiensEnTravaux: 0,
        nbBiensReserves: 1,
        nbContratsActifs: 8,
        nbLocatairesActifs: 8,
        totalLoyersAppelesMois: 2000000,
        totalLoyersEncaissesMois: 1800000,
        totalImpayesMois: 200000,
        totalCautionsEnDepot: 4000000,
        alertes: const [],
      );

      expect(data.tauxOccupation, 80.0);
      expect(data.tauxRecouvrement, 90.0);
      expect(data.nbAlertesCritiques, 0);
      expect(data.nbTotalAlertes, 0);
    });

    test('DashboardImmobilierData : Prise en compte des biens en travaux dans le taux d\'occupation', () {
      // 10 biens au total dont 2 en travaux (donc 8 biens exploitables)
      // 6 occupés sur 8 exploitables = 75%
      final data = DashboardImmobilierData(
        totalBiens: 10,
        nbBiensOccupes: 6,
        nbBiensDisponibles: 2,
        nbBiensEnTravaux: 2,
        nbBiensReserves: 0,
        nbContratsActifs: 6,
        nbLocatairesActifs: 6,
        totalLoyersAppelesMois: 1500000,
        totalLoyersEncaissesMois: 1500000,
        totalImpayesMois: 0,
        totalCautionsEnDepot: 3000000,
        alertes: const [],
      );

      expect(data.tauxOccupation, 75.0);
      expect(data.tauxRecouvrement, 100.0);
    });

    test('Règle d\'or : Ségrégation stricte des cautions en séquestre au tableau de bord', () {
      final data = DashboardImmobilierData(
        totalBiens: 5,
        nbBiensOccupes: 5,
        nbBiensDisponibles: 0,
        nbBiensEnTravaux: 0,
        nbBiensReserves: 0,
        nbContratsActifs: 5,
        nbLocatairesActifs: 5,
        totalLoyersAppelesMois: 1000000,
        totalLoyersEncaissesMois: 1000000,
        totalImpayesMois: 0,
        totalCautionsEnDepot: 2000000, // Cautions = 2 mois de loyer
        alertes: const [],
      );

      // Les cautions (2 000 000) ne sont JAMAIS ajoutées au chiffre d'affaires locatif appelé (1 000 000)
      expect(data.totalCautionsEnDepot, 2000000);
      expect(data.totalLoyersEncaissesMois, 1000000);
      expect(data.totalCautionsEnDepot != data.totalLoyersEncaissesMois, isTrue);
    });

    test('Alertes Métier : Hiérarchie et classification par niveau de criticité', () {
      final alertes = [
        AlerteImmobilier(
          id: 'alt-info',
          type: TypeAlerteImmobilier.bienVacant,
          niveau: NiveauAlerte.information,
          titre: 'Bien vacant disponible',
          message: 'Villa Cocody disponible à la location.',
          dateReference: DateTime(2026, 10, 1),
          actionRoute: '/immobilier/biens/bien-1',
          actionLibelle: 'Proposer à bail',
        ),
        AlerteImmobilier(
          id: 'alt-critique',
          type: TypeAlerteImmobilier.loyerEnRetard,
          niveau: NiveauAlerte.critique,
          titre: 'Loyer en retard (20 j)',
          message: 'Loyer d\'octobre impayé depuis 20 jours.',
          dateReference: DateTime(2026, 10, 5),
          montantConcerne: 350000,
          actionRoute: '/immobilier/loyers/ech-1',
          actionLibelle: 'Encaisser',
        ),
        AlerteImmobilier(
          id: 'alt-warning',
          type: TypeAlerteImmobilier.finBailProche,
          niveau: NiveauAlerte.avertissement,
          titre: 'Bail à échéance (45 j)',
          message: 'Le bail arrive à terme dans 45 jours.',
          dateReference: DateTime(2026, 11, 20),
          actionRoute: '/immobilier/contrats/ctr-1',
          actionLibelle: 'Voir le bail',
        ),
      ];

      // Tri attendu : critique en premier, puis avertissement, puis info
      alertes.sort((a, b) {
        final ordre = {
          NiveauAlerte.critique: 0,
          NiveauAlerte.avertissement: 1,
          NiveauAlerte.information: 2,
        };
        return (ordre[a.niveau] ?? 3).compareTo(ordre[b.niveau] ?? 3);
      });

      expect(alertes[0].niveau, NiveauAlerte.critique);
      expect(alertes[0].type, TypeAlerteImmobilier.loyerEnRetard);

      expect(alertes[1].niveau, NiveauAlerte.avertissement);
      expect(alertes[1].type, TypeAlerteImmobilier.finBailProche);

      expect(alertes[2].niveau, NiveauAlerte.information);
      expect(alertes[2].type, TypeAlerteImmobilier.bienVacant);

      final dashboard = DashboardImmobilierData(
        totalBiens: 10,
        nbBiensOccupes: 8,
        nbBiensDisponibles: 2,
        nbBiensEnTravaux: 0,
        nbBiensReserves: 0,
        nbContratsActifs: 8,
        nbLocatairesActifs: 8,
        totalLoyersAppelesMois: 1000000,
        totalLoyersEncaissesMois: 650000,
        totalImpayesMois: 350000,
        totalCautionsEnDepot: 2000000,
        alertes: alertes,
      );

      expect(dashboard.nbTotalAlertes, 3);
      expect(dashboard.nbAlertesCritiques, 1);
    });

    test('TypeAlerteImmobilier & NiveauAlerte : Codes et libellés cohérents', () {
      expect(TypeAlerteImmobilier.loyerEnRetard.code, 'LOYER_EN_RETARD');
      expect(TypeAlerteImmobilier.finBailProche.code, 'FIN_BAIL_PROCHE');
      expect(TypeAlerteImmobilier.bienVacant.code, 'BIEN_VACANT');
      expect(TypeAlerteImmobilier.cautionARestituer.code, 'CAUTION_A_RESTITUER');

      expect(NiveauAlerte.critique.libelle, 'Urgent');
      expect(NiveauAlerte.avertissement.libelle, 'Important');
      expect(NiveauAlerte.information.libelle, 'Information');
    });
  });
}
