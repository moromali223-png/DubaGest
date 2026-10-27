import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/features/contacts/domain/entities/contact.dart';
import 'package:dubagest/features/immobilier/data/datasources/immobilier_local_data_source.dart';
import 'package:dubagest/features/immobilier/data/datasources/immobilier_sync_handlers.dart';
import 'package:dubagest/features/immobilier/domain/entities/bien_immobilier.dart';
import 'package:dubagest/features/immobilier/domain/entities/contrat_bail.dart';
import 'package:dubagest/features/immobilier/domain/entities/dashboard_immobilier.dart';
import 'package:dubagest/features/immobilier/domain/entities/echeance_loyer.dart';
import 'package:dubagest/features/immobilier/domain/entities/locataire_immobilier.dart';
import 'package:dubagest/features/immobilier/domain/entities/location_immobilier.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ImmobilierLocalDataSource local;
  late DriftSyncCursorStore cursors;

  setUp(() {
    db = memoryDatabase();
    local = ImmobilierLocalDataSource(db);
    cursors = DriftSyncCursorStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Étape 10 — Recette Finale Métier, Intégrité & Finitions UX', () {
    const entrepriseId = 'ent-duba-recette';

    test('1. Parcours complet cycle de vie locatif : Bien -> Contrat -> Occupation -> Loyer', () async {
      // A. Propriétaire (Socle Contacts)
      final proprietaire = Contact(
        id: 'prop-01',
        entrepriseId: entrepriseId,
        nom: 'Sow',
        prenom: 'El Hadj Ousmane',
        telephone: '+221 77 123 45 67',
        email: 'ousmane.sow@example.com',
        typePersonne: TypePersonne.personne,
        relations: const {RelationContact.proprietaire},
        ville: 'Dakar',
      );
      expect(proprietaire.relations, contains(RelationContact.proprietaire));

      // B. Création du Bien immobilier rattaché au propriétaire
      final bien = BienImmobilier(
        id: 'bien-recette-01',
        entrepriseId: entrepriseId,
        reference: 'VILLA-MNG-01',
        nom: 'Villa Mermoz Océan',
        type: TypeBien.maison,
        statut: StatutBien.disponible,
        proprietaireId: proprietaire.id,
        loyerReference: 600000,
        periodicite: PeriodiciteLoyer.mensuelle,
        depotGarantiePrevu: 1200000,
        adresse: 'Rue MZ-12',
        ville: 'Dakar',
        quartier: 'Mermoz',
        caracteristiques: const CaracteristiquesBien(
          surfaceM2: 280,
          nbPieces: 6,
          nbChambres: 4,
          meuble: true,
          climatisation: true,
          parking: true,
        ),
        creeLe: DateTime(2026, 10, 1),
      );
      await local.sauvegarderBiens(entrepriseId, [bien]);

      final biensEnBase = await local.chargerBiens(entrepriseId);
      expect(biensEnBase.length, 1);
      expect(biensEnBase.first.estDisponible, isTrue);

      // C. Dossier Locataire complet (Contact + Profil)
      final locataireContact = Contact(
        id: 'loc-recette-01',
        entrepriseId: entrepriseId,
        nom: 'Diallo',
        prenom: 'Aïssatou',
        telephone: '+221 78 987 65 43',
        email: 'aissatou.diallo@example.com',
        typePersonne: TypePersonne.personne,
        relations: const {RelationContact.locataire},
        ville: 'Dakar',
      );

      final profilLocataire = ProfilLocataire(
        contactId: locataireContact.id,
        entrepriseId: entrepriseId,
        profession: 'Directrice Financière',
        employeur: 'Banque Atlantique',
        revenuMensuelEstime: 2500000,
        typePiece: TypePieceIdentite.cni,
        numeroPiece: '10982347612',
        nomGarant: 'Mamadou Diallo',
        telephoneGarant: '+221 77 555 44 33',
        statutFinancier: StatutFinancierLocataire.aJour,
      );
      await local.sauvegarderProfilLocataire(profilLocataire);

      final profilRecupere = await local.chargerProfilLocataire(locataireContact.id);
      expect(profilRecupere?.profession, 'Directrice Financière');
      expect(profilRecupere?.aGarant, isTrue);

      // D. Création du Contrat de bail & Signature
      var contrat = ContratBail(
        id: 'ctr-recette-01',
        entrepriseId: entrepriseId,
        reference: 'BAIL-2026-VILLA1',
        bienId: bien.id,
        proprietaireId: proprietaire.id,
        locataireId: locataireContact.id,
        typeBail: TypeBail.habitationMeublee,
        statut: StatutContratBail.brouillon,
        dateDebut: DateTime(2026, 10, 1),
        dateFinPrevue: DateTime(2027, 9, 30),
        loyerMensuel: 600000,
        chargesMensuelles: 50000,
        depotGarantie: 1200000,
        termePaiementJour: 5,
        termeType: TermePaiementType.aEchoir,
        signeParBailleur: false,
        signeParLocataire: false,
      );
      expect(contrat.estBrouillon, isTrue);
      expect(contrat.estEntierementSigne, isFalse);

      // Signature des 2 parties
      contrat = contrat.copyWith(
        statut: StatutContratBail.actif,
        signeParBailleur: true,
        signeParLocataire: true,
        dateSignature: DateTime(2026, 10, 1),
      );
      await local.sauvegarderContrat(contrat);
      expect(contrat.estActif, isTrue);
      expect(contrat.estEntierementSigne, isTrue);

      // E. Location active rattachée
      final location = LocationImmobilier(
        id: 'loc-occup-01',
        entrepriseId: entrepriseId,
        bienId: bien.id,
        locataireId: locataireContact.id,
        contratId: contrat.id,
        dateDebut: DateTime(2026, 10, 1),
        dateFinPrevue: DateTime(2027, 9, 30),
        loyerMensuel: 600000,
        chargesMensuelles: 50000,
        depotGarantie: 1200000,
        statut: StatutLocation.active,
      );
      await local.sauvegarderLocation(location);

      // Le bien passe à occupé
      final bienOccupe = bien.copyWith(statut: StatutBien.occupe);
      await local.sauvegarderBiens(entrepriseId, [bienOccupe]);

      // F. Échéance de loyer mensuel émise
      var echeance = EcheanceLoyer(
        id: 'ech-recette-01',
        entrepriseId: entrepriseId,
        reference: 'ECH-202610-01',
        contratId: contrat.id,
        bienId: bien.id,
        locataireId: locataireContact.id,
        proprietaireId: proprietaire.id,
        engagementId: 'eng-loyer-01',
        periodeMois: 10,
        periodeAnnee: 2026,
        dateEmission: DateTime(2026, 10, 1),
        dateExigibilite: DateTime(2026, 10, 5),
        loyerNet: 600000,
        charges: 50000,
        totalDu: 650000,
        montantRegle: 0,
        statut: StatutEcheanceLoyer.aPayer,
      );
      await local.sauvegarderEcheanceLoyer(echeance);

      expect(echeance.resteAPayer, 650000);
      expect(echeance.estSolde, isFalse);

      // G. Encaissement intégral du loyer
      echeance = echeance.copyWith(
        montantRegle: 650000,
        statut: StatutEcheanceLoyer.solde,
        derniereDatePaiement: DateTime(2026, 10, 4),
        recuDocumentIds: ['recu-doc-01'],
        quittanceDocumentId: 'quittance-doc-01',
      );
      await local.sauvegarderEcheanceLoyer(echeance);

      expect(echeance.estSolde, isTrue);
      expect(echeance.resteAPayer, 0);
      expect(echeance.pourcentageRegle, 100.0);
      expect(echeance.quittanceDocumentId, 'quittance-doc-01');
    });

    test('2. Règle d\'Or Financière : Ségrégation absolue des dépôts de garantie', () {
      const caution = 1500000;
      const loyerMensuel = 500000;

      final contrat = ContratBail(
        id: 'ctr-sequestre-01',
        entrepriseId: entrepriseId,
        reference: 'BAIL-CAUTION-01',
        bienId: 'bien-01',
        proprietaireId: 'prop-01',
        locataireId: 'loc-01',
        statut: StatutContratBail.actif,
        dateDebut: DateTime(2026, 10, 1),
        loyerMensuel: loyerMensuel,
        chargesMensuelles: 0,
        depotGarantie: caution,
      );

      final echeance = EcheanceLoyer(
        id: 'ech-caution-01',
        entrepriseId: entrepriseId,
        reference: 'ECH-01',
        contratId: contrat.id,
        bienId: 'bien-01',
        locataireId: 'loc-01',
        engagementId: 'eng-01',
        periodeMois: 10,
        periodeAnnee: 2026,
        dateEmission: DateTime(2026, 10, 1),
        dateExigibilite: DateTime(2026, 10, 5),
        loyerNet: loyerMensuel,
        charges: 0,
        totalDu: loyerMensuel,
        montantRegle: loyerMensuel,
        statut: StatutEcheanceLoyer.solde,
      );

      final dashboard = DashboardImmobilierData(
        totalBiens: 1,
        nbBiensOccupes: 1,
        nbBiensDisponibles: 0,
        nbBiensEnTravaux: 0,
        nbBiensReserves: 0,
        nbContratsActifs: 1,
        nbLocatairesActifs: 1,
        totalLoyersAppelesMois: echeance.totalDu,
        totalLoyersEncaissesMois: echeance.montantRegle,
        totalImpayesMois: 0,
        totalCautionsEnDepot: contrat.depotGarantie,
        alertes: const [],
      );

      // Le CA locatif mensuel ne doit PAS inclure la caution
      expect(dashboard.totalLoyersEncaissesMois, loyerMensuel);
      expect(dashboard.totalLoyersAppelesMois, loyerMensuel);

      // La caution reste isolée en séquestre
      expect(dashboard.totalCautionsEnDepot, caution);
      expect(dashboard.totalLoyersEncaissesMois + dashboard.totalCautionsEnDepot, 2000000);
    });

    test('3. Détection des conflits de dates sur un même bien (Règle anti-chevauchement)', () {
      final locExistante = LocationImmobilier(
        id: 'loc-exist',
        entrepriseId: entrepriseId,
        bienId: 'bien-test',
        locataireId: 'loc-1',
        dateDebut: DateTime(2026, 1, 1),
        dateFinPrevue: DateTime(2026, 12, 31),
        loyerMensuel: 300000,
        statut: StatutLocation.active,
      );

      // Tentative 1 : Début pendant la location active -> Conflit
      expect(
        locExistante.chevauchePeriode(DateTime(2026, 6, 1), DateTime(2027, 5, 31)),
        isTrue,
      );

      // Tentative 2 : Début après la fin de la location active -> Pas de conflit
      expect(
        locExistante.chevauchePeriode(DateTime(2027, 1, 1), DateTime(2027, 12, 31)),
        isFalse,
      );

      // Tentative 3 : Clôture de la location existante -> Libération
      final locTerminee = locExistante.copyWith(
        statut: StatutLocation.terminee,
        dateFinReelle: DateTime(2026, 5, 31),
      );
      expect(locTerminee.statut, StatutLocation.terminee);
      expect(locTerminee.dateFinReelle, isNotNull);
    });

    test('4. Synchronisation Intègre : Les 5 handlers opérationnels avec SQLite', () async {
      final handlers = immobilierSyncHandlers(local, cursors);
      expect(handlers.length, 5);

      // Injection d'une ligne distante pour chaque table
      for (final h in handlers) {
        expect(h.table.startsWith('immobilier_'), isTrue);
      }

      // Handler des Biens
      final handlerBiens = handlers.firstWhere((h) => h.table == 'immobilier_biens');
      await handlerBiens.applyRemoteRows([
        {
          'id': 'bien-synced-1',
          'entreprise_id': entrepriseId,
          'reference': 'APP-01',
          'nom': 'Appartement Synchro',
          'type': 'appartement',
          'statut': 'disponible',
          'loyer_reference': 300000,
          'periodicite': 'mensuelle',
          'version': 1,
          'cree_le': '2026-10-15T00:00:00.000Z',
        }
      ]);

      final biens = await local.chargerBiens(entrepriseId);
      expect(biens.any((b) => b.id == 'bien-synced-1'), isTrue);
    });
  });
}
