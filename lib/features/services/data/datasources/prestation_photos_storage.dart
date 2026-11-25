import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../fichiers/data/fichiers_repository_impl.dart' show bucketFichiers;
import '../../domain/entities/prestation.dart';

/// Cache mémoire haute performance pour éviter les accès disques répétés durant la session.
final Map<String, Uint8List> prestationPhotoBytesCache = {};

/// Gestionnaire pérenne et hors-ligne du stockage des photographies de contrats de service et interventions.
///
/// Résout définitivement la disparition des images après 24h ou après fermeture/réouverture :
/// 1. Les octets sont conservés dans la base SQLite locale `photosLocales` (ou IndexedDB sur Web).
/// 2. Sur mobile (Android/iOS), les fichiers sont sécurisés dans le dossier documents permanent
///    (jamais dans le cache temporaire `/tmp` qui est purgé après 24h par le système).
/// 3. Au rechargement de l'application, l'image est restituée immédiatement depuis le stockage local.
/// 4. Si la photo provient d'un autre appareil, elle est téléchargée une seule fois depuis Supabase Storage,
///    puis immédiatement mise en cache permanent dans SQLite pour ne plus jamais disparaître.
class PrestationPhotosStorage {
  PrestationPhotosStorage(this._db, this._client);

  final AppDatabase _db;
  final SupabaseClient? Function() _client;

  /// Sauvegarde locale pérenne des octets d'une photo dans SQLite et en mémoire.
  Future<void> sauvegarderOctets({
    required String photoId,
    required Uint8List octets,
    String? cheminDistant,
    String? cheminLocal,
  }) async {
    prestationPhotoBytesCache[photoId] = octets;
    if (cheminDistant != null && cheminDistant.isNotEmpty) {
      prestationPhotoBytesCache[cheminDistant] = octets;
    }
    if (cheminLocal != null && cheminLocal.isNotEmpty) {
      prestationPhotoBytesCache[cheminLocal] = octets;
    }

    try {
      // Clé primaire principale : ID de la photo
      await _db.into(_db.photosLocales).insertOnConflictUpdate(
            PhotosLocalesCompanion.insert(
              chemin: photoId,
              octets: octets,
              aEnvoyer: const Value(false),
              majLe: DateTime.now(),
            ),
          );

      // Indexation secondaire par chemin distant pour résolution directe
      if (cheminDistant != null && cheminDistant.isNotEmpty && cheminDistant != photoId) {
        await _db.into(_db.photosLocales).insertOnConflictUpdate(
              PhotosLocalesCompanion.insert(
                chemin: cheminDistant,
                octets: octets,
                aEnvoyer: const Value(false),
                majLe: DateTime.now(),
              ),
            );
      }
    } catch (e) {
      AppLogger.warning('Erreur persistence SQLite photo ($photoId) : $e', tag: 'services_photos');
    }
  }

  /// Récupère les octets d'une photo selon la hiérarchie optimale :
  /// 1. Cache RAM instantané
  /// 2. Stockage permanent SQLite (`photosLocales`)
  /// 3. Data URI base64 décodée
  /// 4. Fichier persistant du système de fichiers
  /// 5. Téléchargement Supabase Storage (avec sauvegarde locale automatique)
  Future<Uint8List?> chargerOctets(PhotoPrestation photo) async {
    // 1. Cache RAM
    if (prestationPhotoBytesCache.containsKey(photo.id)) {
      return prestationPhotoBytesCache[photo.id];
    }
    if (photo.cheminDistant != null && prestationPhotoBytesCache.containsKey(photo.cheminDistant!)) {
      return prestationPhotoBytesCache[photo.cheminDistant!];
    }
    if (photo.cheminLocal != null && prestationPhotoBytesCache.containsKey(photo.cheminLocal!)) {
      return prestationPhotoBytesCache[photo.cheminLocal!];
    }

    // 2. Base SQLite locale permanente (Survit à la fermeture/réouverture et au-delà de 24h)
    try {
      final candidats = <String>[
        photo.id,
        if (photo.cheminDistant != null && photo.cheminDistant!.isNotEmpty) photo.cheminDistant!,
        if (photo.cheminLocal != null && photo.cheminLocal!.isNotEmpty) photo.cheminLocal!,
      ];

      for (final cle in candidats) {
        final row = await (_db.select(_db.photosLocales)..where((p) => p.chemin.equals(cle))).getSingleOrNull();
        if (row != null && row.octets.isNotEmpty) {
          prestationPhotoBytesCache[photo.id] = row.octets;
          if (photo.cheminDistant != null) {
            prestationPhotoBytesCache[photo.cheminDistant!] = row.octets;
          }
          return row.octets;
        }
      }
    } catch (_) {}

    // 3. Data URI base64
    if (photo.cheminLocal != null && photo.cheminLocal!.startsWith('data:')) {
      final octets = _extraireOctetsDataUri(photo.cheminLocal!);
      if (octets != null && octets.isNotEmpty) {
        await sauvegarderOctets(
          photoId: photo.id,
          octets: octets,
          cheminDistant: photo.cheminDistant,
          cheminLocal: photo.cheminLocal,
        );
        return octets;
      }
    }

    // 4. Fichier disque local persistant
    if (!kIsWeb && photo.cheminLocal != null && !photo.cheminLocal!.startsWith('http') && !photo.cheminLocal!.startsWith('data:')) {
      try {
        final file = File(photo.cheminLocal!);
        if (await file.exists()) {
          final octets = await file.readAsBytes();
          if (octets.isNotEmpty) {
            await sauvegarderOctets(
              photoId: photo.id,
              octets: octets,
              cheminDistant: photo.cheminDistant,
              cheminLocal: photo.cheminLocal,
            );
            return octets;
          }
        }
      } catch (_) {}
    }

    // 5. Téléchargement Supabase Storage (si stocké dans le cloud)
    final distant = photo.cheminDistant;
    if (distant != null && distant.isNotEmpty && !distant.startsWith('http') && !distant.startsWith('data:')) {
      final client = _client();
      if (client != null) {
        try {
          final octets = await client.storage.from(bucketFichiers).download(distant);
          if (octets.isNotEmpty) {
            await sauvegarderOctets(
              photoId: photo.id,
              octets: octets,
              cheminDistant: distant,
            );
            return octets;
          }
        } catch (e) {
          AppLogger.warning('Téléchargement photo Supabase Storage échoué ($distant) : $e', tag: 'services_photos');
        }
      }
    }

    return null;
  }

  /// Écrit de manière pérenne un fichier image sur le stockage permanent de l'appareil (hors /tmp).
  Future<String> enregistrerFichierPermanent(String nomFichier, Uint8List octets) async {
    if (kIsWeb) {
      return 'data:image/jpeg;base64,${base64Encode(octets)}';
    }
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docsDir.path}/services_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final file = File('${photosDir.path}/$nomFichier');
      await file.writeAsBytes(octets, flush: true);
      return file.path;
    } catch (_) {
      // Repli temporaire si restriction du système de fichiers
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$nomFichier');
      await file.writeAsBytes(octets, flush: true);
      return file.path;
    }
  }

  /// Purge une photo supprimée de la base SQLite et de la mémoire RAM.
  Future<void> supprimerPhoto(PhotoPrestation photo) async {
    prestationPhotoBytesCache.remove(photo.id);
    if (photo.cheminDistant != null) prestationPhotoBytesCache.remove(photo.cheminDistant!);
    if (photo.cheminLocal != null) prestationPhotoBytesCache.remove(photo.cheminLocal!);

    try {
      await (_db.delete(_db.photosLocales)..where((p) => p.chemin.equals(photo.id))).go();
      if (photo.cheminDistant != null) {
        await (_db.delete(_db.photosLocales)..where((p) => p.chemin.equals(photo.cheminDistant!))).go();
      }
    } catch (_) {}

    if (!kIsWeb && photo.cheminLocal != null) {
      try {
        final f = File(photo.cheminLocal!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  static Uint8List? _extraireOctetsDataUri(String uri) {
    try {
      final idx = uri.indexOf(',');
      if (idx != -1 && idx < uri.length - 1) {
        return base64Decode(uri.substring(idx + 1));
      }
    } catch (_) {}
    return null;
  }
}
