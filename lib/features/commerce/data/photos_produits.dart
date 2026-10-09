import 'dart:async';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_logger.dart';
import '../../fichiers/data/fichiers_repository_impl.dart' show bucketFichiers;

/// Photos des produits : gardées sur l'appareil (affichage immédiat, même
/// hors-ligne), envoyées dans le stockage privé dès que le réseau est là.
/// Chemin : `{entreprise}/produits/{produit}/{photo}.jpg` (règle serveur).
class PhotosProduits {
  PhotosProduits(this._db, this._client);

  final AppDatabase _db;
  final SupabaseClient? Function() _client;
  final _enCours = <String, Future<Uint8List?>>{};

  static String chemin(String entrepriseId, String produitId) =>
      '$entrepriseId/produits/$produitId/${const Uuid().v4()}.jpg';

  /// Enregistre une photo prise ou choisie ; elle partira au prochain envoi.
  Future<String> ajouter({required String entrepriseId, required String produitId, required Uint8List octets}) async {
    final c = chemin(entrepriseId, produitId);
    await _db.into(_db.photosLocales).insertOnConflictUpdate(PhotosLocalesCompanion.insert(
          chemin: c,
          octets: octets,
          aEnvoyer: const Value(true),
          majLe: DateTime.now(),
        ));
    unawaited(envoyerEnAttente());
    return c;
  }

  /// Octets d'une photo : copie locale, sinon téléchargée puis gardée.
  Future<Uint8List?> octets(String chemin) => _enCours[chemin] ??= _charger(chemin).whenComplete(() {
        _enCours.remove(chemin);
      });

  Future<Uint8List?> _charger(String chemin) async {
    final local = await (_db.select(_db.photosLocales)..where((p) => p.chemin.equals(chemin))).getSingleOrNull();
    if (local != null) return local.octets;
    final client = _client();
    if (client == null) return null;
    try {
      final octets = await client.storage.from(bucketFichiers).download(chemin);
      await _db.into(_db.photosLocales).insertOnConflictUpdate(PhotosLocalesCompanion.insert(
            chemin: chemin,
            octets: octets,
            majLe: DateTime.now(),
          ));
      return octets;
    } catch (e) {
      // Hors-ligne ou photo pas encore envoyée depuis un autre appareil.
      AppLogger.info('Photo indisponible ($chemin) : $e', tag: 'photos');
      return null;
    }
  }

  bool _envoiEnCours = false;

  /// Envoie les photos en attente (sans effet hors-ligne : nouvel essai plus tard).
  Future<void> envoyerEnAttente() async {
    if (_envoiEnCours) return;
    final client = _client();
    if (client == null) return;
    _envoiEnCours = true;
    try {
      final attente = await (_db.select(_db.photosLocales)..where((p) => p.aEnvoyer.equals(true))).get();
      for (final p in attente) {
        try {
          await client.storage.from(bucketFichiers).uploadBinary(
                p.chemin,
                p.octets,
                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
              );
          await (_db.update(_db.photosLocales)..where((x) => x.chemin.equals(p.chemin)))
              .write(const PhotosLocalesCompanion(aEnvoyer: Value(false)));
        } catch (e) {
          AppLogger.info('Envoi de photo reporté (${p.chemin}) : $e', tag: 'photos');
          break;
        }
      }
    } finally {
      _envoiEnCours = false;
    }
  }
}
