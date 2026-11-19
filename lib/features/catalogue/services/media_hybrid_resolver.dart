import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/app_logger.dart';

/// Origine physique d'un fichier média dans DubaGest.
enum MediaOrigin {
  /// Anciennes photos et pièces jointes stockées sur Supabase Storage (bucket « fichiers »).
  supabaseV1,

  /// Nouveaux médias V2 stockés sur Cloudflare R2 / CDN public.
  cloudflareR2,

  /// Lien externe direct (ex: URL CDN absolue https://...).
  directHttp,
}

/// Résolveur hybride de médias : unifie la lecture, la génération d'URLs publiques
/// et le téléchargement transparent des anciennes photos Supabase V1 et des nouveaux
/// médias V2 Cloudflare R2 (photos, vocaux 60s, vidéos courtes 30s).
abstract final class MediaHybridResolver {
  /// Domaine CDN Cloudflare R2 par défaut pour DubaGest V2.
  static const String defaultR2CdnBase = 'https://media.dubagest.com';

  /// Bucket Supabase Storage historique de la V1.
  static const String bucketSupabaseFichiers = 'fichiers';

  /// Détecte l'origine d'un chemin ou d'une URL de média.
  static MediaOrigin detectOrigin(String pathOrUrl) {
    final lower = pathOrUrl.trim().toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      if (lower.contains('r2.dev') || lower.contains('media.dubagest.com')) {
        return MediaOrigin.cloudflareR2;
      }
      return MediaOrigin.directHttp;
    }
    if (lower.startsWith('r2:')) {
      return MediaOrigin.cloudflareR2;
    }
    // Tout chemin relatif (ex: "{eid}/produits/{pid}/{uuid}.jpg") ou préfixé "supabase:"
    // correspond aux fichiers historiques Supabase Storage V1.
    return MediaOrigin.supabaseV1;
  }

  /// Génère l'URL publique ou de streaming accessible aux clients web et mobiles.
  static String resolvePublicUrl(
    String pathOrUrl, {
    String? supabaseStorageBaseUrl,
    String? r2CdnBaseUrl,
  }) {
    final p = pathOrUrl.trim();
    if (p.isEmpty) return '';

    final origin = detectOrigin(p);
    switch (origin) {
      case MediaOrigin.directHttp:
        return p;

      case MediaOrigin.cloudflareR2:
        final cleanPath = p.startsWith('r2:') ? p.substring(3).replaceFirst(RegExp(r'^/+'), '') : p;
        if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
          return cleanPath;
        }
        final base = (r2CdnBaseUrl ?? defaultR2CdnBase).replaceAll(RegExp(r'/+$'), '');
        return '$base/$cleanPath';

      case MediaOrigin.supabaseV1:
        final cleanPath = p.startsWith('supabase:') ? p.substring(9).replaceFirst(RegExp(r'^/+'), '') : p;
        if (supabaseStorageBaseUrl != null && supabaseStorageBaseUrl.isNotEmpty) {
          final base = supabaseStorageBaseUrl.replaceAll(RegExp(r'/+$'), '');
          return '$base/storage/v1/object/public/$bucketSupabaseFichiers/$cleanPath';
        }
        // Repli standard si aucune URL de stockage personnalisée n'est injectée
        return 'https://app.dubagest.com/storage/v1/object/public/$bucketSupabaseFichiers/$cleanPath';
    }
  }

  /// Télécharge les octets bruts d'un média (que ce soit depuis Cloudflare R2 via HTTP
  /// ou depuis Supabase Storage avec authentification si nécessaire).
  static Future<Uint8List?> downloadBytes(
    String pathOrUrl, {
    SupabaseClient? Function()? supabaseClientProvider,
    http.Client? httpClient,
  }) async {
    final p = pathOrUrl.trim();
    if (p.isEmpty) return null;

    final origin = detectOrigin(p);

    if (origin == MediaOrigin.cloudflareR2 || origin == MediaOrigin.directHttp) {
      final publicUrl = resolvePublicUrl(p);
      final client = httpClient ?? http.Client();
      try {
        final res = await client.get(Uri.parse(publicUrl));
        if (res.statusCode == 200) {
          return res.bodyBytes;
        }
        AppLogger.warning('Erreur HTTP ${res.statusCode} lors du téléchargement de $publicUrl', tag: 'media_hybrid');
      } catch (e) {
        AppLogger.warning('Échec téléchargement R2/HTTP ($publicUrl): $e', tag: 'media_hybrid');
      }
      return null;
    }

    // Origine Supabase V1
    final client = supabaseClientProvider?.call();
    if (client == null) return null;

    final cleanPath = p.startsWith('supabase:') ? p.substring(9) : p;
    try {
      return await client.storage.from(bucketSupabaseFichiers).download(cleanPath);
    } catch (e) {
      AppLogger.info('Supabase Storage download ($cleanPath) : $e', tag: 'media_hybrid');
      return null;
    }
  }

  /// Génère un chemin de stockage V2 pour une photo produit Cloudflare R2.
  static String createR2PhotoPath({
    required String entrepriseId,
    required String produitId,
    String extension = 'jpg',
  }) {
    final uuid = const Uuid().v4();
    return 'r2:photos/$entrepriseId/$produitId/$uuid.$extension';
  }

  /// Génère un chemin de stockage V2 pour un enregistrement vocal (60s max) Cloudflare R2.
  static String createR2AudioPath({
    required String entrepriseId,
    required String produitId,
    String extension = 'm4a',
  }) {
    final uuid = const Uuid().v4();
    return 'r2:audios/$entrepriseId/$produitId/$uuid.$extension';
  }

  /// Génère un chemin de stockage V2 pour une vidéo commerciale courte (30s max) Cloudflare R2.
  static String createR2VideoPath({
    required String entrepriseId,
    required String produitId,
    String extension = 'mp4',
  }) {
    final uuid = const Uuid().v4();
    return 'r2:videos/$entrepriseId/$produitId/$uuid.$extension';
  }

  /// Vérifie si le fichier est un enregistrement audio
  static bool isAudio(String? pathOrUrl) {
    if (pathOrUrl == null) return false;
    final lower = pathOrUrl.toLowerCase();
    return lower.contains('.m4a') || lower.contains('.mp3') || lower.contains('.aac') || lower.contains('.ogg') || lower.contains('/audios/');
  }

  /// Vérifie si le fichier est une vidéo
  static bool isVideo(String? pathOrUrl) {
    if (pathOrUrl == null) return false;
    final lower = pathOrUrl.toLowerCase();
    return lower.contains('.mp4') || lower.contains('.webm') || lower.contains('.mov') || lower.contains('/videos/');
  }

  /// Vérifie si le fichier est une image
  static bool isImage(String? pathOrUrl) {
    if (pathOrUrl == null) return false;
    final lower = pathOrUrl.toLowerCase();
    return lower.contains('.jpg') || lower.contains('.jpeg') || lower.contains('.png') || lower.contains('.webp') || lower.contains('/photos/');
  }
}
