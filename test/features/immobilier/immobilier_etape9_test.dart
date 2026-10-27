import 'package:flutter_test/flutter_test.dart';
import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/core/sync/local/drift_sync_stores.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/immobilier/data/datasources/immobilier_local_data_source.dart';
import 'package:dubagest/features/immobilier/data/datasources/immobilier_sync_handlers.dart';
import 'package:dubagest/features/immobilier/domain/entities/contrat_bail.dart';
import 'package:dubagest/features/immobilier/domain/entities/echeance_loyer.dart';
import 'package:dubagest/features/immobilier/domain/entities/locataire_immobilier.dart';
import 'package:dubagest/features/immobilier/domain/entities/location_immobilier.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ImmobilierLocalDataSource localDataSource;
  late DriftSyncCursorStore cursorStore;

  setUp(() {
    db = memoryDatabase();
    localDataSource = ImmobilierLocalDataSource(db);
    cursorStore = DriftSyncCursorStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Étape 9 — Synchronisation Offline-First & Supabase : Tests Unitaires', () {
    test('1. Enregistrement des 5 tables synchronisées avec les noms SQL exacts', () {
      final handlers = immobilierSyncHandlers(localDataSource, cursorStore);

      expect(handlers.length, 5);
      final tableNames = handlers.map((h) => h.table).toSet();

      expect(tableNames, contains('immobilier_biens'));
      expect(tableNames, contains('immobilier_locataires_profils'));
      expect(tableNames, contains('immobilier_locations'));
      expect(tableNames, contains('immobilier_contrats'));
      expect(tableNames, contains('immobilier_echeances_loyers'));
    });

    test('2. ImmobilierBiensSyncHandler : applyRemoteRows, onPushApplied, onConflict & onRejected', () async {
      final handler = ImmobilierBiensSyncHandler(localDataSource, cursorStore);
      const entId = 'ent-test-biens';

      // Remote rows application
      final remoteRow = {
        'id': 'bien-remote-1',
        'entreprise_id': entId,
        'reference': 'VILLA-SYNC-01',
        'nom': 'Villa Synchro',
        'type': 'villa',
        'statut': 'disponible',
        'proprietaire_id': 'prop-1',
        'loyer_reference': 750000,
        'periodicite': 'mensuelle',
        'depot_garantie_prevu': 1500000,
        'adresse': 'Route des Almadies',
        'ville': 'Dakar',
        'quartier': 'Almadies',
        'caracteristiques': {'surface_m2': 300, 'nb_chambres': 4},
        'photos': <String>[],
        'version': 1,
        'cree_le': '2026-10-15T10:00:00.000Z',
        'mis_a_jour_le': '2026-10-15T10:00:00.000Z',
      };

      final deletedRemoteRow = {
        'id': 'bien-deleted-1',
        'entreprise_id': entId,
        'reference': 'DEL-01',
        'nom': 'Bien Supprimé',
        'type': 'appartement',
        'statut': 'archive',
        'proprietaire_id': 'prop-1',
        'loyer_reference': 200000,
        'periodicite': 'mensuelle',
        'version': 2,
        'deleted_at': '2026-10-15T11:00:00.000Z',
      };

      await handler.applyRemoteRows([remoteRow, deletedRemoteRow]);

      final biens = await localDataSource.chargerBiens(entId);
      expect(biens.length, 1);
      expect(biens.first.id, 'bien-remote-1');
      expect(biens.first.nom, 'Villa Synchro');
      expect(biens.first.version, 1);

      // onPushApplied : mise à jour après confirmation serveur
      final updatedServerRow = Map<String, dynamic>.from(remoteRow);
      updatedServerRow['nom'] = 'Villa Synchro Mise à Jour';
      updatedServerRow['version'] = 2;

      final op = SyncOperation(
        id: 'op-bien-1',
        userId: 'user-1',
        entityTable: 'immobilier_biens',
        recordId: 'bien-remote-1',
        type: SyncOperationType.update,
        payload: updatedServerRow,
        baseVersion: 1,
        status: SyncOpStatus.syncing,
        attempts: 1,
        createdAt: DateTime.now(),
      );

      await handler.onPushApplied(op, updatedServerRow);
      final biensApresPush = await localDataSource.chargerBiens(entId);
      expect(biensApresPush.first.nom, 'Villa Synchro Mise à Jour');
      expect(biensApresPush.first.version, 2);

      // onConflict : le serveur a la priorité
      final conflictServerRow = Map<String, dynamic>.from(updatedServerRow);
      conflictServerRow['nom'] = 'Villa Version Serveur Arbitrée';
      conflictServerRow['version'] = 3;
      await handler.onConflict(op, conflictServerRow);
      final biensApresConflit = await localDataSource.chargerBiens(entId);
      expect(biensApresConflit.first.nom, 'Villa Version Serveur Arbitrée');
      expect(biensApresConflit.first.version, 3);

      // onRejected : réinitialisation du curseur
      await cursorStore.write('immobilier_biens', entId, '2026-10-15T12:00:00.000Z');
      expect(await cursorStore.read('immobilier_biens', entId), isNotNull);
      await handler.onRejected(op, const Failure(FailureKind.server));
      expect(await cursorStore.read('immobilier_biens', entId), isNull);
    });

    test('3. ImmobilierLocatairesProfilsSyncHandler : Synchronisation du profil locataire', () async {
      final handler = ImmobilierLocatairesProfilsSyncHandler(localDataSource, cursorStore);
      const entId = 'ent-test-locataires';

      final remoteRow = {
        'contact_id': 'contact-loc-1',
        'entreprise_id': entId,
        'profession': 'Ingénieur Logiciel',
        'employeur': 'Tech SARL',
        'revenu_mensuel_estime': 1500000.0,
        'type_piece': 'cni',
        'numero_piece': '123456789',
        'statut_financier': 'A_JOUR',
        'updated_at': '2026-10-15T10:00:00.000Z',
      };

      await handler.applyRemoteRows([remoteRow]);
      final profils = await localDataSource.chargerProfilsLocataires(entId);
      expect(profils.length, 1);
      expect(profils.first.contactId, 'contact-loc-1');
      expect(profils.first.profession, 'Ingénieur Logiciel');
      expect(profils.first.revenuMensuelEstime, 1500000.0);

      // onPushApplied
      final serverUpdated = Map<String, dynamic>.from(remoteRow);
      serverUpdated['revenu_mensuel_estime'] = 1800000.0;

      final op = SyncOperation(
        id: 'op-loc-1',
        userId: 'user-1',
        entityTable: 'immobilier_locataires_profils',
        recordId: 'contact-loc-1',
        type: SyncOperationType.update,
        payload: serverUpdated,
        baseVersion: 1,
        status: SyncOpStatus.syncing,
        attempts: 1,
        createdAt: DateTime.now(),
      );

      await handler.onPushApplied(op, serverUpdated);
      final profilApresPush = await localDataSource.chargerProfilLocataire('contact-loc-1');
      expect(profilApresPush?.revenuMensuelEstime, 1800000.0);

      // onConflict
      final conflictServer = Map<String, dynamic>.from(serverUpdated);
      conflictServer['statut_financier'] = 'CONTENTIEUX';
      await handler.onConflict(op, conflictServer);
      final profilApresConflit = await localDataSource.chargerProfilLocataire('contact-loc-1');
      expect(profilApresConflit?.statutFinancier, StatutFinancierLocataire.contentieux);
    });

    test('4. ImmobilierLocationsSyncHandler : Synchronisation des occupations', () async {
      final handler = ImmobilierLocationsSyncHandler(localDataSource, cursorStore);
      const entId = 'ent-test-locations';

      final remoteLocation = {
        'id': 'loc-101',
        'entreprise_id': entId,
        'bien_id': 'bien-001',
        'locataire_id': 'loc-001',
        'loyer_mensuel': 400000,
        'charges_mensuelles': 50000,
        'depot_garantie': 800000,
        'statut': 'ACTIVE',
        'date_debut': '2026-10-01T00:00:00.000Z',
        'version': 1,
        'cree_le': '2026-10-01T10:00:00.000Z',
        'mis_a_jour_le': '2026-10-01T10:00:00.000Z',
      };

      await handler.applyRemoteRows([remoteLocation]);
      final locations = await localDataSource.chargerLocations(entId);
      expect(locations.length, 1);
      expect(locations.first.id, 'loc-101');
      expect(locations.first.statut, StatutLocation.active);
      expect(locations.first.loyerMensuel, 400000);

      // onConflict : le serveur fait foi
      final conflictLoc = Map<String, dynamic>.from(remoteLocation);
      conflictLoc['statut'] = 'RESILIEE';
      conflictLoc['date_fin_reelle'] = '2026-10-15T00:00:00.000Z';
      final op = SyncOperation(
        id: 'op-loc-1',
        userId: 'user-1',
        entityTable: 'immobilier_locations',
        recordId: 'loc-101',
        type: SyncOperationType.update,
        payload: conflictLoc,
        baseVersion: 1,
        status: SyncOpStatus.syncing,
        attempts: 1,
        createdAt: DateTime.now(),
      );

      await handler.onConflict(op, conflictLoc);
      final locationsApres = await localDataSource.chargerLocations(entId);
      expect(locationsApres.first.statut, StatutLocation.resiliee);
      expect(locationsApres.first.dateFinReelle, isNotNull);
    });

    test('5. ImmobilierContratsSyncHandler : Synchronisation des contrats de bail', () async {
      final handler = ImmobilierContratsSyncHandler(localDataSource, cursorStore);
      const entId = 'ent-test-contrats';

      final remoteContrat = {
        'id': 'ctr-201',
        'entreprise_id': entId,
        'reference': 'BAIL-2026-201',
        'bien_id': 'bien-001',
        'locataire_id': 'loc-001',
        'proprietaire_id': 'prop-001',
        'type_bail': 'HABITATION_NUE',
        'statut': 'ACTIF',
        'terme_paiement_jour': 5,
        'terme_type': 'A_ECHOIR',
        'loyer_mensuel': 350000,
        'charges_mensuelles': 30000,
        'depot_garantie': 700000,
        'date_debut': '2026-10-01T00:00:00.000Z',
        'date_fin_prevue': '2027-09-30T00:00:00.000Z',
        'signe_par_bailleur': true,
        'signe_par_locataire': true,
        'version': 1,
        'cree_le': '2026-10-01T10:00:00.000Z',
        'mis_a_jour_le': '2026-10-01T10:00:00.000Z',
      };

      await handler.applyRemoteRows([remoteContrat]);
      final contrats = await localDataSource.chargerContrats(entId);
      expect(contrats.length, 1);
      expect(contrats.first.id, 'ctr-201');
      expect(contrats.first.statut, StatutContratBail.actif);
      expect(contrats.first.depotGarantie, 700000);
      expect(contrats.first.estEntierementSigne, isTrue);

      // onPushApplied
      final serverContrat = Map<String, dynamic>.from(remoteContrat);
      serverContrat['statut'] = 'RESILIE';
      serverContrat['clauses_particulieres'] = 'Départ anticipé';
      final op = SyncOperation(
        id: 'op-ctr-1',
        userId: 'user-1',
        entityTable: 'immobilier_contrats',
        recordId: 'ctr-201',
        type: SyncOperationType.update,
        payload: serverContrat,
        baseVersion: 1,
        status: SyncOpStatus.syncing,
        attempts: 1,
        createdAt: DateTime.now(),
      );

      await handler.onPushApplied(op, serverContrat);
      final contratsApres = await localDataSource.chargerContrats(entId);
      expect(contratsApres.first.statut, StatutContratBail.resilie);
      expect(contratsApres.first.clausesParticulieres, 'Départ anticipé');
    });

    test('6. ImmobilierEcheancesSyncHandler : Synchronisation des échéances de loyers', () async {
      final handler = ImmobilierEcheancesSyncHandler(localDataSource, cursorStore);
      const entId = 'ent-test-echeances';

      final remoteEcheance = {
        'id': 'ech-301',
        'entreprise_id': entId,
        'reference': 'ECH-202610-301',
        'contrat_id': 'ctr-201',
        'bien_id': 'bien-001',
        'locataire_id': 'loc-001',
        'proprietaire_id': 'prop-001',
        'engagement_id': 'eng-001',
        'periode_mois': 10,
        'periode_annee': 2026,
        'date_emission': '2026-10-01T00:00:00.000Z',
        'date_exigibilite': '2026-10-05T00:00:00.000Z',
        'loyer_net': 350000,
        'charges': 30000,
        'total_du': 380000,
        'montant_regle': 0,
        'statut': 'A_PAYER',
        'version': 1,
        'cree_le': '2026-10-01T00:00:00.000Z',
        'mis_a_jour_le': '2026-10-01T00:00:00.000Z',
      };

      await handler.applyRemoteRows([remoteEcheance]);
      final echeances = await localDataSource.chargerEcheancesLoyers(entId);
      expect(echeances.length, 1);
      expect(echeances.first.id, 'ech-301');
      expect(echeances.first.statut, StatutEcheanceLoyer.aPayer);
      expect(echeances.first.totalDu, 380000);
      expect(echeances.first.montantRegle, 0);

      // onPushApplied : paiement répercuté depuis le serveur
      final serverEcheance = Map<String, dynamic>.from(remoteEcheance);
      serverEcheance['montant_regle'] = 380000;
      serverEcheance['statut'] = 'SOLDE';
      serverEcheance['derniere_date_paiement'] = '2026-10-04T14:30:00.000Z';
      serverEcheance['version'] = 2;

      final op = SyncOperation(
        id: 'op-ech-1',
        userId: 'user-1',
        entityTable: 'immobilier_echeances_loyers',
        recordId: 'ech-301',
        type: SyncOperationType.update,
        payload: serverEcheance,
        baseVersion: 1,
        status: SyncOpStatus.syncing,
        attempts: 1,
        createdAt: DateTime.now(),
      );

      await handler.onPushApplied(op, serverEcheance);
      final echeancesApres = await localDataSource.chargerEcheancesLoyers(entId);
      expect(echeancesApres.first.estSolde, isTrue);
      expect(echeancesApres.first.montantRegle, 380000);
      expect(echeancesApres.first.version, 2);
    });

    test('7. Fonctionnement Hors-Ligne & File SyncQueue : Empilement sans réseau', () async {
      const entId = 'ent-offline';
      const userId = 'user-offline';

      // Empiler une création de bien hors-ligne
      await localDataSource.empilerOperationSync(
        operationId: 'op-off-1',
        userId: userId,
        entityTable: 'immobilier_biens',
        recordId: 'bien-offline-1',
        operation: 'INSERT',
        payload: {
          'id': 'bien-offline-1',
          'entreprise_id': entId,
          'nom': 'Bureau Plateau Hors-Ligne',
          'loyer_reference': 600000,
        },
        baseVersion: null,
      );

      // Vérifier la présence dans syncQueue de Drift
      final rows = await db.select(db.syncQueue).get();
      expect(rows.length, 1);
      final row = rows.first;
      expect(row.id, 'op-off-1');
      expect(row.userId, userId);
      expect(row.entityTable, 'immobilier_biens');
      expect(row.recordId, 'bien-offline-1');
      expect(row.operation, 'INSERT');
      expect(row.status, 'PENDING');
      expect(row.attempts, 0);
    });
  });
}
