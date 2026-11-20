import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../app/localization/l10n.dart';
import '../../app/theme/app_theme.dart';
import 'app_logger.dart';
import 'web_file_picker_helper.dart';

/// Données complètes d'une photo sélectionnée ou capturée.
class PhotoSelectionnee {
  const PhotoSelectionnee({
    required this.octets,
    required this.nom,
    required this.typeMime,
  });

  final Uint8List octets;
  final String nom;
  final String typeMime;
}

/// Helper universel et résilient pour la prise de photo et la sélection de galerie.
///
/// Fonctionne de manière native et sécurisée sur :
/// - Android : Chrome, Samsung Internet et PWA installée.
/// - iPhone : Safari et PWA installée sur l'écran d'accueil.
/// - Ordinateur : Chrome, Edge, Firefox, etc.
class MediaPickerHelper {
  MediaPickerHelper._();

  static bool get isMobile =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) ||
      kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Sélectionne ou prend une photo et renvoie ses détails complets (octets, nom, type).
  static Future<PhotoSelectionnee?> choisirPhotoDetail(
    BuildContext context, {
    double? maxWidth = 1024,
    double? maxHeight,
    int? imageQuality = 80,
    ImageSource? forceSource,
  }) async {
    final octets = await choisirPhoto(
      context,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      forceSource: forceSource,
    );
    if (octets == null || octets.isEmpty) return null;
    return PhotoSelectionnee(
      octets: octets,
      nom: 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      typeMime: 'image/jpeg',
    );
  }

  /// Sélectionne ou prend une photo et renvoie directement les octets (`Uint8List`).
  ///
  /// Présente sur mobile la feuille native (Prendre une photo / Galerie).
  /// Déclenche le sélecteur immédiatement dans l'événement tactile direct sans perte d'activation navigateur.
  static Future<Uint8List?> choisirPhoto(
    BuildContext context, {
    double? maxWidth = 1024,
    double? maxHeight,
    int? imageQuality = 80,
    ImageSource? forceSource,
  }) async {
    try {
      if (kIsWeb) {
        return await _choisirPhotoWeb(
          context,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          imageQuality: imageQuality,
          forceSource: forceSource,
        );
      } else {
        return await _choisirPhotoNatif(
          context,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          imageQuality: imageQuality,
          forceSource: forceSource,
        );
      }
    } catch (e, stack) {
      debugPrint('[PHOTO_DIAGNOSTIC] Échec choisirPhoto: $e\n$stack');
      AppLogger.error('Échec sélection photo: $e', error: e, stackTrace: stack, tag: 'photos');
      rethrow;
    }
  }

  // --- Implémentation Web / PWA -----------------------------------------------

  static Future<Uint8List?> _choisirPhotoWeb(
    BuildContext context, {
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    ImageSource? forceSource,
  }) async {
    // Si la source est imposée (ex: caméra demandée explicitement)
    if (forceSource != null) {
      final webSource = forceSource == ImageSource.camera ? WebImageSource.camera : WebImageSource.gallery;
      final rawBytes = await pickImageBytesWeb(source: webSource);
      if (rawBytes == null || rawBytes.isEmpty) return null;
      return compresserImage(rawBytes, maxWidth: maxWidth?.toInt() ?? 1024, quality: imageQuality ?? 80);
    }

    // Sur ordinateur (Desktop Web) : ouvrir directement la boîte de dialogue de fichiers
    if (!isMobile) {
      final rawBytes = await pickImageBytesWeb(source: WebImageSource.gallery);
      if (rawBytes == null || rawBytes.isEmpty) return null;
      return compresserImage(rawBytes, maxWidth: maxWidth?.toInt() ?? 1024, quality: imageQuality ?? 80);
    }

    // Sur téléphone mobile (Safari / Chrome / PWA) : afficher le choix utilisateur
    await HapticFeedback.lightImpact();
    final l10n = context.l10n;

    final futureBytes = await showModalBottomSheet<Future<Uint8List?>>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(sheetContext).bottom + 16,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.comTakePhoto,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 16),
              // Option 1 : Prendre une photo (Appareil photo direct)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_camera_outlined, color: AppColors.green),
                ),
                title: Text(l10n.comTakePhoto, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Prendre une nouvelle photo avec la caméra arrière'),
                onTap: () {
                  // DÉCLENCHEMENT 100% SYNCHRONE DANS LE GESTE TACTILE
                  final pending = pickImageBytesWeb(source: WebImageSource.camera);
                  Navigator.pop(sheetContext, pending);
                },
              ),
              // Option 2 : Galerie de photos
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_outlined, color: Color(0xFF4F46E5)),
                ),
                title: Text(l10n.comChooseFromGallery, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Choisir une photo existante dans la galerie'),
                onTap: () {
                  // DÉCLENCHEMENT 100% SYNCHRONE DANS LE GESTE TACTILE
                  final pending = pickImageBytesWeb(source: WebImageSource.gallery);
                  Navigator.pop(sheetContext, pending);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (futureBytes == null) return null;
    final rawBytes = await futureBytes;
    if (rawBytes == null || rawBytes.isEmpty) return null;
    return compresserImage(rawBytes, maxWidth: maxWidth?.toInt() ?? 1024, quality: imageQuality ?? 80);
  }

  // --- Implémentation Mobile Natif (Android / iOS APK) -------------------------

  static Future<Uint8List?> _choisirPhotoNatif(
    BuildContext context, {
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    ImageSource? forceSource,
  }) async {
    final picker = ImagePicker();
    ImageSource? source = forceSource;

    if (source == null) {
      if (!picker.supportsImageSource(ImageSource.camera)) {
        source = ImageSource.gallery;
      } else {
        await HapticFeedback.mediumImpact();
        final l10n = context.l10n;
        source = await showModalBottomSheet<ImageSource>(
          context: context,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (sheetContext) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(sheetContext).bottom + 16,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.comTakePhoto,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle),
                      child: const Icon(Icons.photo_camera_outlined, color: AppColors.green),
                    ),
                    title: Text(l10n.comTakePhoto, style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                      child: const Icon(Icons.photo_library_outlined, color: Color(0xFF4F46E5)),
                    ),
                    title: Text(l10n.comChooseFromGallery, style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      }
    }
    if (source == null) return null;

    final x = await picker.pickImage(
      source: source,
      maxWidth: maxWidth ?? 1024,
      maxHeight: maxHeight,
      imageQuality: imageQuality ?? 80,
    );
    if (x == null) return null;
    final octets = await x.readAsBytes();
    if (octets.isEmpty) return null;
    return compresserImage(octets, maxWidth: maxWidth?.toInt() ?? 1024, quality: imageQuality ?? 80);
  }

  // --- Compression et redimensionnement pur Dart ------------------------------

  /// Compresse et redimensionne une image en pur Dart pour éviter tout dépassement mémoire.
  /// Gère automatiquement les images JPEG, PNG, WebP et les formats convertis d'iPhone.
  static Uint8List compresserImage(Uint8List rawBytes, {int maxWidth = 1024, int quality = 80}) {
    // Sur le Web ou si déjà compressé sous 400 Ko, le moteur matériel HTML5 a déjà opéré.
    // Ne jamais exécuter img.decodeImage sur le Web pour préserver le thread UI et éviter les crashs mémoire.
    if (kIsWeb || rawBytes.length < 400 * 1024) {
      return rawBytes;
    }
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;
      if (decoded.width <= maxWidth && decoded.height <= maxWidth) {
        if (rawBytes.length < 350 * 1024) return rawBytes;
        return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
      }
      final resized = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? maxWidth : null,
        height: decoded.height >= decoded.width ? maxWidth : null,
      );
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    } catch (e) {
      debugPrint('[PHOTO_DIAGNOSTIC] Compression image ignorée: $e');
      return rawBytes;
    }
  }
}
