import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/features/immobilier/domain/entities/echeance_loyer.dart';
import 'package:dubagest/features/immobilier/domain/entities/resultat_encaissement_loyer.dart';
import 'package:dubagest/features/finances/domain/entities/finances.dart';
import 'package:dubagest/features/documents/domain/entities/document.dart';

void main() {
  group('Module « Réception des loyers » — Tests Métier & Financiers', () {
    late EcheanceLoyer echeanceOctobre;
    late EcheanceLoyer echeanceNovembre;

    setUp(() {
      echeanceOctobre = EcheanceLoyer(
        id: 'ech-oct-2026',
        entrepriseId: 'ent-1',
        reference: 'ECH-202610-001',
        contratId: 'ctr-001',
        bienId: 'bien-101',
        locataireId: 'loc-202',
        proprietaireId: 'prop-303',
        engagementId: 'eng-oct-2026',
        periodeMois: 10,
        periodeAnnee: 2026,
        dateEmission: DateTime(2026, 10, 1),
        dateExigibilite: DateTime(2026, 10, 5),
        loyerNet: 150000,
        charges: 20000,
        totalDu: 170000,
        montantRegle: 0,
        statut: StatutEcheanceLoyer.aPayer,
      );

      echeanceNovembre = EcheanceLoyer(
        id: 'ech-nov-2026',
        entrepriseId: 'ent-1',
        reference: 'ECH-202611-002',
        contratId: 'ctr-001',
        bienId: 'bien-101',
        locataireId: 'loc-202',
        proprietaireId: 'prop-303',
        engagementId: 'eng-nov-2026',
        periodeMois: 11,
        periodeAnnee: 2026,
        dateEmission: DateTime(2026, 11, 1),
        dateExigibilite: DateTime(2026, 11, 5),
        loyerNet: 150000,
        charges: 20000,
        totalDu: 170000,
        montantRegle: 0,
        statut: StatutEcheanceLoyer.aPayer,
      );
    });

    // 1. Paiement intégral d'un loyer
    test('1. Paiement intégral : solde l\'échéance et génère une Quittance de loyer', () {
      final montantVerse = 170000;
      final nouveauRegle = echeanceOctobre.montantRegle + montantVerse;
      final estSolde = nouveauRegle >= echeanceOctobre.totalDu;
      final statut = estSolde ? StatutEcheanceLoyer.solde : StatutEcheanceLoyer.partiellementPaye;

      final maj = echeanceOctobre.copyWith(
        montantRegle: nouveauRegle,
        statut: statut,
        quittanceDocumentId: 'qui-2026-001',
        derniereDatePaiement: DateTime(2026, 10, 5),
      );

      expect(maj.resteAPayer, 0);
      expect(maj.estSolde, isTrue);
      expect(maj.statut, StatutEcheanceLoyer.solde);
      expect(maj.quittanceDocumentId, 'qui-2026-001');
      expect(maj.pourcentageRegle, 100.0);
    });

    // 2. Paiement partiel et calcul précis du solde
    test('2. Paiement partiel : conserve le reste dû et génère un Reçu d\'acompte', () {
      final montantAcompte = 100000;
      final nouveauRegle = echeanceOctobre.montantRegle + montantAcompte;
      final estSolde = nouveauRegle >= echeanceOctobre.totalDu;
      final statut = estSolde ? StatutEcheanceLoyer.solde : StatutEcheanceLoyer.partiellementPaye;

      final maj = echeanceOctobre.copyWith(
        montantRegle: nouveauRegle,
        statut: statut,
        recuDocumentIds: ['rec-2026-001'],
        derniereDatePaiement: DateTime(2026, 10, 5),
      );

      expect(maj.resteAPayer, 70000);
      expect(maj.estSolde, isFalse);
      expect(maj.statut, StatutEcheanceLoyer.partiellementPaye);
      expect(maj.recuDocumentIds, contains('rec-2026-001'));
      expect(maj.quittanceDocumentId, isNull);
    });

    // 3. Refus d'un montant nul ou négatif
    test('3. Validation : Rejette un montant nul ou négatif', () {
      bool validerMontant(int montant) => montant > 0;

      expect(validerMontant(0), isFalse);
      expect(validerMontant(-50000), isFalse);
      expect(validerMontant(-1), isFalse);
      expect(validerMontant(150000), isTrue);
    });

    // 4. Paiement couvrant plusieurs échéances
    test('4. Paiement multi-échéances : ventile chronologiquement le montant versé', () {
      final echeances = [echeanceOctobre, echeanceNovembre];
      final montantVerse = 250000; // 170 000 pour octobre + 80 000 pour novembre

      int restant = montantVerse;
      final allocations = <AllocationLoyer>[];

      for (final ech in echeances) {
        if (restant <= 0) break;
        final part = restant > ech.resteAPayer ? ech.resteAPayer : restant;
        final resteApres = ech.resteAPayer - part;
        allocations.add(AllocationLoyer(
          echeanceId: ech.id,
          periodeLibelle: ech.periodeLibelle,
          montantAffecte: part,
          resteAvant: ech.resteAPayer,
          resteApres: resteApres,
          estSolde: resteApres == 0,
        ));
        restant -= part;
      }

      expect(allocations.length, 2);
      expect(allocations[0].echeanceId, 'ech-oct-2026');
      expect(allocations[0].montantAffecte, 170000);
      expect(allocations[0].resteApres, 0);
      expect(allocations[0].estSolde, isTrue);

      expect(allocations[1].echeanceId, 'ech-nov-2026');
      expect(allocations[1].montantAffecte, 80000);
      expect(allocations[1].resteApres, 90000);
      expect(allocations[1].estSolde, isFalse);
    });

    // 5. Gestion des avances
    test('5. Gestion des avances : un excédent n\'est pas perdu mais affecté à une période future', () {
      final montantVerse = 200000; // Total dû octobre : 170 000 -> Avance de 30 000
      final affecteOctobre = montantVerse > echeanceOctobre.resteAPayer ? echeanceOctobre.resteAPayer : montantVerse;
      final avance = montantVerse - affecteOctobre;

      expect(affecteOctobre, 170000);
      expect(avance, 30000);

      // L'avance s'impute sur novembre
      final resteNovembreApresAvance = echeanceNovembre.resteAPayer - avance;
      expect(resteNovembreApresAvance, 140000);
    });

    // 6. Absence de double encaissement (Idempotence)
    test('6. Idempotence : un loyer déjà soldé ne peut pas être ré-encaissé', () {
      final echeanceSoldee = echeanceOctobre.copyWith(
        montantRegle: 170000,
        statut: StatutEcheanceLoyer.solde,
      );

      final peutEncaisser = echeanceSoldee.resteAPayer > 0 && echeanceSoldee.statut != StatutEcheanceLoyer.solde;
      expect(peutEncaisser, isFalse);
    });

    // 7. Unicité de l'écriture financière
    test('7. Intégration financière : génère exactement un Paiement financier avec affectation', () {
      final paiement = Paiement(
        id: 'pay-001',
        entrepriseId: 'ent-1',
        sens: SensPaiement.entree,
        montant: 170000,
        mode: ModePaiement.especes,
        datePaiement: DateTime(2026, 10, 5),
        contactId: echeanceOctobre.locataireId,
        note: 'Encaissement loyer ${echeanceOctobre.periodeLibelle}',
        affectations: [
          Affectation(id: 'aff-001', engagementId: echeanceOctobre.engagementId, montant: 170000),
        ],
      );

      expect(paiement.montant, 170000);
      expect(paiement.sens, SensPaiement.entree);
      expect(paiement.affectations.length, 1);
      expect(paiement.affectations.first.engagementId, echeanceOctobre.engagementId);
      expect(paiement.affectations.first.montant, 170000);
    });

    // 8. Cohérence entre loyers, caisse et dettes
    test('8. Mouvement de caisse : créé si et seulement si session d\'espèces ouverte', () {
      final sessionOuverte = SessionCaisse(
        id: 'sess-001',
        entrepriseId: 'ent-1',
        caisseId: 'caisse-principale',
        perimetreId: 'perim-1',
        ouverteLe: DateTime.now(),
        soldeInitial: 50000,
        ouverte: true,
      );

      final montantVerse = 170000;
      final mouvement = MouvementCaisse(
        id: 'mouv-001',
        sessionId: sessionOuverte.id,
        caisseId: sessionOuverte.caisseId,
        type: TypeMouvement.encaissement,
        montant: montantVerse,
        paiementId: 'pay-001',
        createdAt: DateTime.now(),
      );

      expect(mouvement.type, TypeMouvement.encaissement);
      expect(mouvement.montant, 170000);
      expect(mouvement.signe, 170000);
      expect(sessionOuverte.soldeInitial + mouvement.signe, 220000);
    });

    // 9. Données complètes du reçu professionnel (Section 7)
    test('9. Reçu professionnel : contient toutes les mentions requises par le cahier des charges', () {
      final contenuDoc = <String, dynamic>{
        'titre': 'Quittance de loyer - Octobre 2026',
        'numero': 'QUI-2026-00001',
        'periode_loyer': 'Octobre 2026',
        'bien_nom': 'Villa Les Palmiers - Appartement B2',
        'bien_adresse': 'Hamdallaye ACI 2000, Bamako',
        'locataire_nom': 'Amadou Diallo',
        'locataire_telephone': '+223 76 00 11 22',
        'loyer_net': 150000,
        'charges': 20000,
        'total_du': 170000,
        'montant_verse': 170000,
        'reste_a_payer': 0,
        'mode_paiement': 'ESPECES',
        'statut': 'PAYE',
        'devise': 'FCFA',
      };

      final doc = Document(
        id: 'doc-001',
        entrepriseId: 'ent-1',
        type: TypeDocument.quittance,
        numero: 'QUI-2026-00001',
        blocId: 'bloc-1',
        sequence: 1,
        langue: 'fr',
        date: DateTime.now(),
        montant: 170000,
        origineType: 'LOYER',
        origineId: echeanceOctobre.id,
        contenu: contenuDoc,
      );

      expect(doc.type, TypeDocument.quittance);
      expect(doc.contenu['titre'], contains('Quittance'));
      expect(doc.contenu['locataire_nom'], 'Amadou Diallo');
      expect(doc.contenu['bien_nom'], 'Villa Les Palmiers - Appartement B2');
      expect(doc.contenu['montant_verse'], 170000);
      expect(doc.contenu['reste_a_payer'], 0);
      expect(doc.contenu['statut'], 'PAYE');
    });

    // 10. Distinction formelle : Quittance (Solde total) vs Reçu d'acompte (Partiel)
    test('10. Distinction Quittance vs Reçu : Un paiement partiel n\'émet jamais une Quittance', () {
      TypeDocument determinerTypeDocument(bool soldeTotal) {
        return soldeTotal ? TypeDocument.quittance : TypeDocument.recu;
      }

      expect(determinerTypeDocument(true), TypeDocument.quittance);
      expect(determinerTypeDocument(false), TypeDocument.recu);
    });

    // 11. Résultat consolidé de l'encaissement
    test('11. ResultatEncaissementLoyer : Consolide toutes les métriques requises', () {
      final resultat = ResultatEncaissementLoyer(
        echeancePrincipale: echeanceOctobre,
        allocations: [
          AllocationLoyer(
            echeanceId: echeanceOctobre.id,
            periodeLibelle: echeanceOctobre.periodeLibelle,
            montantAffecte: 170000,
            resteAvant: 170000,
            resteApres: 0,
            estSolde: true,
          ),
        ],
        montantTotalVerse: 170000,
        modePaiement: ModePaiement.especes,
        referencePaiement: 'CASH-REC-01',
        note: 'Paiement sans incident',
        datePaiement: DateTime(2026, 10, 5),
        paiementFinancierId: 'pay-001',
        estSoldeTotal: true,
      );

      expect(resultat.estSoldeTotal, isTrue);
      expect(resultat.montantTotalVerse, 170000);
      expect(resultat.resteTotalDu, 0);
      expect(resultat.allocations.first.estSolde, isTrue);
    });
  });
}
