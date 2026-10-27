import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/immobilier/domain/entities/contrat_bail.dart';

void main() {
  group('Étape 6 — Contrats de bail : Tests Unitaires', () {
    test('ContratBail : Sérialisation et désérialisation JSON intègre', () {
      final contrat = ContratBail(
        id: 'ctr-001',
        entrepriseId: 'ent-1',
        reference: 'CTR-202610-1234',
        bienId: 'bien-101',
        proprietaireId: 'prop-202',
        locataireId: 'loc-303',
        locationId: 'locat-404',
        documentId: 'doc-505',
        typeBail: TypeBail.commercial,
        statut: StatutContratBail.actif,
        dateDebut: DateTime(2026, 1, 1),
        dateFinPrevue: DateTime(2028, 12, 31),
        reconductionTacite: true,
        preavisMois: 3,
        loyerMensuel: 450000,
        chargesMensuelles: 50000,
        termePaiementJour: 5,
        termeType: TermePaiementType.aEchoir,
        depotGarantie: 900000,
        penaliteRetardPourcent: 5.0,
        clausesParticulieres: 'Destination exclusive: commerce de détail',
        dateSignature: DateTime(2025, 12, 28),
        signeParBailleur: true,
        signeParLocataire: true,
        creeLe: DateTime(2025, 12, 20),
        misAJourLe: DateTime(2025, 12, 28),
        version: 2,
      );

      final json = contrat.toJson();
      final deserialise = ContratBail.fromJson(json);

      expect(deserialise.id, 'ctr-001');
      expect(deserialise.entrepriseId, 'ent-1');
      expect(deserialise.reference, 'CTR-202610-1234');
      expect(deserialise.bienId, 'bien-101');
      expect(deserialise.proprietaireId, 'prop-202');
      expect(deserialise.locataireId, 'loc-303');
      expect(deserialise.locationId, 'locat-404');
      expect(deserialise.documentId, 'doc-505');
      expect(deserialise.typeBail, TypeBail.commercial);
      expect(deserialise.statut, StatutContratBail.actif);
      expect(deserialise.dateDebut, DateTime(2026, 1, 1));
      expect(deserialise.dateFinPrevue, DateTime(2028, 12, 31));
      expect(deserialise.reconductionTacite, isTrue);
      expect(deserialise.preavisMois, 3);
      expect(deserialise.loyerMensuel, 450000);
      expect(deserialise.chargesMensuelles, 50000);
      expect(deserialise.totalMensuel, 500000);
      expect(deserialise.termePaiementJour, 5);
      expect(deserialise.termeType, TermePaiementType.aEchoir);
      expect(deserialise.depotGarantie, 900000);
      expect(deserialise.penaliteRetardPourcent, 5.0);
      expect(deserialise.clausesParticulieres, 'Destination exclusive: commerce de détail');
      expect(deserialise.signeParBailleur, isTrue);
      expect(deserialise.signeParLocataire, isTrue);
      expect(deserialise.estEntierementSigne, isTrue);
      expect(deserialise.estActif, isTrue);
      expect(deserialise.estCloture, isFalse);
    });

    test('ContratBail : Cycle de vie et gestion des statuts', () {
      final contrat = ContratBail(
        id: 'ctr-002',
        entrepriseId: 'ent-1',
        reference: 'CTR-202610-5678',
        bienId: 'bien-1',
        proprietaireId: 'prop-1',
        locataireId: 'loc-1',
        dateDebut: DateTime(2026, 2, 1),
        loyerMensuel: 150000,
        statut: StatutContratBail.brouillon,
      );

      expect(contrat.estBrouillon, isTrue);
      expect(contrat.estActif, isFalse);
      expect(contrat.estEntierementSigne, isFalse);

      // 1. Signature bailleur
      final apresBailleur = contrat.copyWith(signeParBailleur: true);
      expect(apresBailleur.signeParBailleur, isTrue);
      expect(apresBailleur.signeParLocataire, isFalse);
      expect(apresBailleur.estEntierementSigne, isFalse);

      // 2. Signature locataire
      final completementSigne = apresBailleur.copyWith(
        signeParLocataire: true,
        dateSignature: DateTime(2026, 1, 25),
        statut: StatutContratBail.actif,
      );
      expect(completementSigne.estEntierementSigne, isTrue);
      expect(completementSigne.estActif, isTrue);

      // 3. Préavis de congé
      final enPreavis = completementSigne.copyWith(
        statut: StatutContratBail.enPreavis,
      );
      expect(enPreavis.estEnPreavis, isTrue);
      expect(enPreavis.estCloture, isFalse);

      // 4. Clôture / Terminé
      final termine = enPreavis.copyWith(
        statut: StatutContratBail.termine,
        dateFinReelle: DateTime(2026, 5, 31),
      );
      expect(termine.estCloture, isTrue);
      expect(termine.statut, StatutContratBail.termine);

      // 5. Résiliation
      final resilie = enPreavis.copyWith(
        statut: StatutContratBail.resilie,
        dateFinReelle: DateTime(2026, 4, 15),
      );
      expect(resilie.estCloture, isTrue);
      expect(resilie.statut, StatutContratBail.resilie);
    });

    test('TypeBail et TermePaiementType : Fallback et parseur robuste', () {
      expect(TypeBail.parse('HABITATION_NUE'), TypeBail.habitationNue);
      expect(TypeBail.parse('HABITATION_MEUBLEE'), TypeBail.habitationMeublee);
      expect(TypeBail.parse('COMMERCIAL'), TypeBail.commercial);
      expect(TypeBail.parse('PROFESSIONNEL'), TypeBail.professionnel);
      expect(TypeBail.parse('SAISONNIER'), TypeBail.saisonnier);
      expect(TypeBail.parse('PRECAIRE'), TypeBail.precaire);
      expect(TypeBail.parse('INCONNU'), TypeBail.habitationNue);

      expect(TermePaiementType.parse('A_ECHOIR'), TermePaiementType.aEchoir);
      expect(TermePaiementType.parse('ECHU'), TermePaiementType.echu);
      expect(TermePaiementType.parse(null), TermePaiementType.aEchoir);

      expect(StatutContratBail.parse('BROUILLON'), StatutContratBail.brouillon);
      expect(StatutContratBail.parse('ACTIF'), StatutContratBail.actif);
      expect(StatutContratBail.parse('EN_PREAVIS'), StatutContratBail.enPreavis);
      expect(StatutContratBail.parse('TERMINE'), StatutContratBail.termine);
      expect(StatutContratBail.parse('RESILIE'), StatutContratBail.resilie);
      expect(StatutContratBail.parse('AUTRE'), StatutContratBail.brouillon);
    });
  });
}
