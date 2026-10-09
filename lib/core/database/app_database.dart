import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';
import 'app_database.steps.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Base locale unique. Le reste de l'application n'y accède qu'à travers les
/// LocalDataSource des features et les services de `core/sync`.
///
/// Évolution du schéma (jamais de perte de données) :
///   1. modifier les tables et incrémenter [schemaVersion] ;
///   2. `dart run drift_dev make-migrations` (fige la version, génère les tests) ;
///   3. écrire l'étape dans [migrerVers] — une étape publiée ne change plus.
/// Avant toute migration, une copie de la base est faite (hors web).
@DriftDatabase(tables: [
  JsonCache,
  SyncQueue,
  SyncCursors,
  SyncJournal,
  Perimetres,
  Contacts,
  Engagements,
  Paiements,
  TransfertsTresorerie,
  PaiementAffectations,
  Caisses,
  CaisseSessions,
  CaisseMouvements,
  DepenseCategories,
  Depenses,
  DepensesCourantes,
  NumeroBlocs,
  Documents,
  Echeances,
  Notifications,
  Notes,
  PiecesJointes,
  CategoriesProduits,
  Produits,
  Stocks,
  MouvementsStock,
  TransfertsStock,
  Achats,
  Receptions,
  Ventes,
  PhotosLocales,
  PostesVente,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Tables du noyau financier (étape 3), dans l'ordre de création.
  List<TableInfo> get tablesFinances => [
        engagements, paiements, paiementAffectations, caisses, caisseSessions, caisseMouvements,
        depenseCategories, depenses, depensesCourantes, transfertsTresorerie,
      ];

  /// Tables du Commerce (catalogue, stock, achats, ventes).
  List<TableInfo> get tablesCommerce => [
        categoriesProduits, produits, stocks, mouvementsStock, transfertsStock, achats, receptions, ventes,
      ];

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          await sauvegarder('v$from');
          await customStatement('PRAGMA foreign_keys = OFF');
          for (var version = from + 1; version <= to; version++) {
            AppLogger.info('Migration de la base locale vers v$version', tag: 'database');
            await migrerVers(m, version);
          }
          // Validation avant d'ouvrir l'application.
          final erreurs = await customSelect('PRAGMA foreign_key_check').get();
          if (erreurs.isNotEmpty) {
            throw StateError('Migration $from → $to : ${erreurs.length} référence(s) invalide(s)');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Étapes de migration, une par version (`case 2: …`). Jamais de
  /// suppression de données : ajouts de tables/colonnes, copies, conversions.
  @protected
  Future<void> migrerVers(Migrator m, int version) async {
    switch (version) {
      case 2: // Socle commun — Contacts.
        await m.createTable(contacts);
      case 3: // Socle commun — noyau financier (tables telles qu'en v3, figées).
        final v3 = Schema3(database: this);
        for (final table in <TableInfo>[
          v3.engagements, v3.paiements, v3.paiementAffectations, v3.caisses, v3.caisseSessions, v3.caisseMouvements,
        ]) {
          await m.createTable(table);
        }
      case 4: // Socle commun — dépenses (tables telles qu'en v4, figées).
        final v4 = Schema4(database: this);
        await m.createTable(v4.depenseCategories);
        await m.createTable(v4.depenses);
      case 5: // Socle commun — documents et numérotation.
        await m.createTable(numeroBlocs);
        await m.createTable(documents);
      case 6: // Socle commun — agenda et notifications.
        await m.createTable(echeances);
        await m.createTable(notifications);
      case 7: // Socle commun — notes et pièces jointes.
        await m.createTable(notes);
        await m.createTable(piecesJointes);
      case 8: // Commerce — catalogue, stock, achats, ventes, photos.
        // Tables telles qu'en v8 (figées) : les colonnes ajoutées ensuite
        // arrivent par leurs propres étapes.
        final v8 = Schema8(database: this);
        for (final table in <TableInfo>[
          v8.categoriesProduits, v8.produits, v8.stocks, v8.mouvementsStock, v8.transfertsStock, v8.achats,
          v8.receptions, v8.ventes,
        ]) {
          await m.createTable(table);
        }
        await m.createTable(v8.photosLocales);
        // Anciennes tables d'essai du stock (jamais synchronisées) : retirées.
        for (final ancienne in ['local_produits', 'local_produit_conditionnements', 'local_stocks',
          'local_mouvements_stock']) {
          await customStatement('DROP TABLE IF EXISTS $ancienne');
        }
      case 9: // Commerce — reçus de vente (numéro, acompte, annulation tracée).
        for (final colonne in [
          ventes.numero, ventes.dateCommerciale, ventes.poste, ventes.sequence, ventes.montantPaye,
          ventes.annuleeLe, ventes.annuleeParNom,
        ]) {
          await m.addColumn(ventes, colonne);
        }
        await m.createTable(postesVente);
        // Les ventes déjà reçues sont relues pour obtenir leur numéro.
        await customStatement("DELETE FROM sync_cursors WHERE entity_table = 'ventes'");
      case 10: // Dépenses — dépenses courantes, bénéficiaire.
        for (final colonne in [depenses.beneficiaire, depenses.couranteId, depenses.echeancePrevue]) {
          await m.addColumn(depenses, colonne);
        }
        await m.createTable(depensesCourantes);
      case 11: // Caisse — nature des paiements, transferts, motif d'écart.
        for (final colonne in [paiements.nature, paiements.transfertId]) {
          await m.addColumn(paiements, colonne);
        }
        await m.addColumn(caisseSessions, caisseSessions.motifEcart);
        await m.createTable(transfertsTresorerie);
        // Paiements déjà reçus : relus pour obtenir leur nature.
        await customStatement("DELETE FROM sync_cursors WHERE entity_table = 'paiements'");
      default:
        throw StateError('Aucune étape de migration définie pour la version $version');
    }
  }

  /// Copie cohérente de la base dans un fichier voisin (`…<etiquette>-<date>.bak`).
  /// Sans effet sur le web (IndexedDB/OPFS) et pour une base en mémoire :
  /// les données synchronisées restent récupérables depuis le serveur.
  Future<String?> sauvegarder(String etiquette) async {
    if (kIsWeb) return null;
    final bases = await customSelect('PRAGMA database_list').get();
    final fichier = bases.firstWhere((r) => r.read<String>('name') == 'main').read<String>('file');
    if (fichier.isEmpty) return null;
    final cible = '$fichier.$etiquette-${DateTime.now().millisecondsSinceEpoch}.bak';
    await customStatement('VACUUM INTO ?', [cible]);
    AppLogger.info('Sauvegarde locale avant migration : $cible', tag: 'database');
    return cible;
  }

  /// Efface les données métier en cache (changement d'utilisateur sur
  /// l'appareil). La file de synchronisation est conservée : chaque opération
  /// reste liée à son auteur et ne sera envoyée qu'avec sa session.
  Future<void> purgerDonneesUtilisateur() => transaction(() async {
        await delete(perimetres).go();
        await delete(contacts).go();
        for (final table in tablesFinances) {
          await delete(table).go();
        }
        // Les blocs de numéros restent : ils sont liés à leur utilisateur
        // (userId) et évitent de perdre des numéros déjà réservés.
        await delete(documents).go();
        await delete(echeances).go();
        await delete(notifications).go();
        await delete(notes).go();
        await delete(piecesJointes).go();
        for (final table in tablesCommerce) {
          await delete(table).go();
        }
        // Les photos à envoyer restent (fichiers liés à leurs fiches).
        await (delete(photosLocales)..where((p) => p.aEnvoyer.equals(false))).go();
        await delete(syncCursors).go();
        await delete(jsonCache).go();
      });
}
