import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/immobilier/domain/entities/echeance_loyer.dart';
import 'package:dubagest/features/immobilier/domain/services/montant_en_lettres.dart';

void main() {
  group('MontantEnLettres Tests', () {
    test('Convertit 0 en zéro francs CFA', () {
      expect(MontantEnLettres.convertir(0), equals('Zéro francs CFA'));
    });

    test('Convertit 150 000 FCFA conformément aux spécifications', () {
      final res = MontantEnLettres.convertir(150000, devise: 'FCFA');
      expect(res.toLowerCase(), contains('cent cinquante mille francs cfa'));
    });

    test('Convertit les cas particuliers français (71, 80, 95)', () {
      expect(MontantEnLettres.convertir(71, devise: 'FCFA').toLowerCase(), contains('soixante et onze'));
      expect(MontantEnLettres.convertir(80, devise: 'FCFA').toLowerCase(), contains('quatre-vingts'));
      expect(MontantEnLettres.convertir(95, devise: 'FCFA').toLowerCase(), contains('quatre-vingt-quinze'));
    });

    test('Convertit les grands nombres (millions)', () {
      final res = MontantEnLettres.convertir(2500000, devise: 'FCFA');
      expect(res.toLowerCase(), contains('deux millions cinq cent mille'));
    });

    test('Gère différentes devises', () {
      expect(MontantEnLettres.convertir(100, devise: 'EUR').toLowerCase(), contains('cent euros'));
      expect(MontantEnLettres.convertir(1, devise: 'USD').toLowerCase(), contains('un dollar'));
    });
  });

  group('EcheanceLoyer Statut Dynamique & Jours de Retard', () {
    final echeanceBase = EcheanceLoyer(
      id: 'ech-1',
      entrepriseId: 'ent-1',
      reference: 'ECH-2026-10-001',
      contratId: 'contrat-1',
      bienId: 'bien-1',
      locataireId: 'loc-1',
      engagementId: 'eng-1',
      periodeMois: 10,
      periodeAnnee: 2026,
      dateEmission: DateTime(2026, 10, 1),
      dateExigibilite: DateTime(2026, 10, 5),
      loyerNet: 100000,
      charges: 10000,
      totalDu: 110000,
      montantRegle: 0,
    );

    test('Échéance future sans versement = enAttente', () {
      final maintenantAvant = DateTime(2026, 10, 3);
      expect(echeanceBase.statutDynamique(maintenantAvant), equals(StatutReglementLoyer.enAttente));
      expect(echeanceBase.joursDeRetard(maintenantAvant), equals(0));
      expect(echeanceBase.estEnRetardCalcule(maintenantAvant), isFalse);
    });

    test('Échéance future avec versement partiel = partiel', () {
      final echPartiel = echeanceBase.copyWith(montantRegle: 50000);
      final maintenantAvant = DateTime(2026, 10, 3);
      expect(echPartiel.statutDynamique(maintenantAvant), equals(StatutReglementLoyer.partiel));
      expect(echPartiel.resteAPayer, equals(60000));
    });

    test('Date dépassée avec 0 FCFA = impaye avec jours de retard', () {
      final maintenantApres = DateTime(2026, 10, 15);
      expect(echeanceBase.statutDynamique(maintenantApres), equals(StatutReglementLoyer.impaye));
      expect(echeanceBase.estEnRetardCalcule(maintenantApres), isTrue);
      expect(echeanceBase.joursDeRetard(maintenantApres), equals(10));
      expect(echeanceBase.retardLibelle(maintenantApres), equals('10 j de retard'));
    });

    test('Date dépassée avec versement partiel = enRetard', () {
      final echPartielRetard = echeanceBase.copyWith(montantRegle: 40000);
      final maintenantApres = DateTime(2026, 10, 20);
      expect(echPartielRetard.statutDynamique(maintenantApres), equals(StatutReglementLoyer.enRetard));
      expect(echPartielRetard.estEnRetardCalcule(maintenantApres), isTrue);
      expect(echPartielRetard.joursDeRetard(maintenantApres), equals(15));
      expect(echPartielRetard.resteAPayer, equals(70000));
    });

    test('Loyer intégralement réglé = paye même après échéance', () {
      final echPaye = echeanceBase.copyWith(montantRegle: 110000);
      final maintenantApres = DateTime(2026, 10, 25);
      expect(echPaye.statutDynamique(maintenantApres), equals(StatutReglementLoyer.paye));
      expect(echPaye.estSolde, isTrue);
      expect(echPaye.resteAPayer, equals(0));
      expect(echPaye.estEnRetardCalcule(maintenantApres), isFalse);
      expect(echPaye.joursDeRetard(maintenantApres), equals(0));
    });
  });

  group('RecouvrementStatistiques KPIs', () {
    test('Calcul des totaux et du taux de recouvrement', () {
      const stats = RecouvrementStatistiques(
        totalAppele: 1000000,
        totalEncaisse: 750000,
        totalImpayes: 250000,
        nbEcheances: 10,
        nbSoldes: 6,
        nbEnRetard: 2,
        nbPartiels: 1,
        nbImpayes: 1,
        nbEnAttente: 0,
      );

      expect(stats.totalAttendu, equals(1000000));
      expect(stats.totalEncaisse, equals(750000));
      expect(stats.totalRestant, equals(250000));
      expect(stats.tauxRecouvrement, equals(75.0));
      expect(stats.nbPayes, equals(6));
      expect(stats.nbEnRetard, equals(2));
      expect(stats.nbPartiels, equals(1));
      expect(stats.nbImpayes, equals(1));
    });
  });
}

