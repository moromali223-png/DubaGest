import 'dart:typed_data';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dubagest/core/database/app_database.dart';
import 'package:dubagest/core/sync/sync_models.dart';
import 'package:dubagest/features/services/data/datasources/prestation_photos_storage.dart';
import 'package:dubagest/features/services/domain/entities/prestation.dart';

void main() {
  late AppDatabase db;
  late PrestationPhotosStorage storage;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    storage = PrestationPhotosStorage(db, () => null);
    prestationPhotoBytesCache.clear();
  });

  tearDown(() async {
    prestationPhotoBytesCache.clear();
    await db.close();
  });

  group('PrestationPhotosStorage Tests', () {
    test('Persiste les octets de photo dans SQLite et les restitue même si le cache RAM est vidé', () async {
      final photoId = 'test-photo-uuid-123';
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final photo = PhotoPrestation(
        id: photoId,
        prestationId: 'prest-1',
        categorie: CategoriePhoto.reception,
        cheminDistant: 'entreprise-1/prestations/prest-1/$photoId.jpg',
        createdAt: DateTime.now(),
        syncStatus: RecordSyncStatus.pendingSync,
      );

      // 1. Sauvegarde dans SQLite et mémoire
      await storage.sauvegarderOctets(
        photoId: photoId,
        octets: dummyBytes,
        cheminDistant: photo.cheminDistant,
      );

      expect(prestationPhotoBytesCache.containsKey(photoId), isTrue);

      // 2. Simulation de fermeture et réouverture de l'application (vidage complet du cache RAM)
      prestationPhotoBytesCache.clear();
      expect(prestationPhotoBytesCache.isEmpty, isTrue);

      // 3. Récupération des octets : doit être lu directement depuis SQLite
      final bytesRestitues = await storage.chargerOctets(photo);

      expect(bytesRestitues, isNotNull);
      expect(bytesRestitues, equals(dummyBytes));
      // Vérifie que le cache RAM a été réapprovisionné pour les accès suivants
      expect(prestationPhotoBytesCache.containsKey(photoId), isTrue);
    });

    test('Supprime correctement une photo de SQLite et de la RAM', () async {
      final photoId = 'test-photo-delete-999';
      final dummyBytes = Uint8List.fromList([42, 43, 44]);
      final photo = PhotoPrestation(
        id: photoId,
        prestationId: 'prest-1',
        categorie: CategoriePhoto.reception,
        cheminDistant: 'entreprise-1/prestations/prest-1/$photoId.jpg',
        createdAt: DateTime.now(),
        syncStatus: RecordSyncStatus.synced,
      );

      await storage.sauvegarderOctets(
        photoId: photoId,
        octets: dummyBytes,
        cheminDistant: photo.cheminDistant,
      );

      expect(await storage.chargerOctets(photo), isNotNull);

      // Suppression
      await storage.supprimerPhoto(photo);

      prestationPhotoBytesCache.clear();
      final apresSuppression = await storage.chargerOctets(photo);
      expect(apresSuppression, isNull);
    });
  });
}
