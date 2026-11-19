import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../app/localization/l10n.dart';
import '../../app/theme/app_theme.dart';
import 'app_logger.dart';
import 'web_file_picker_helper.dart';

/// Données d'une photo sélectionnée ou capturée.
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

/// Helper universel et résilient pour la prise et la sélection de photos.
///
/// Résout définitivement le problème de prise de photo sur iPhone (Safari & PWA standalone) :
/// - Sur Web (iOS Safari & PWA) : utilise `openFile` avec types MIME JPEG/PNG/WebP explicites,
///   ce qui force iOS Safari à convertir automatiquement les prises de vue caméra et photos HEIC
///   en JPEG standard, sans passer par le canvas HTML5 qui gèle ou crashe sur les appareils Apple.
/// - Présente la feuille native iOS (Prendre une photo / Photothèque / Fichiers).
/// - Sur Mobile natif (Android / iOS) : conserve la boîte de dialogue stylée et la compression native.
class MediaPickerHelper {
  MediaPickerHelper._();

  /// Sélectionne ou prend une photo et renvoie ses détails complets (octets, nom, type).
  static Future<PhotoSelectionnee?> choisirPhotoDetail(
    BuildContext context, {
    double? maxWidth = 1024,
    double? maxHeight,
    int? imageQuality = 80,
    ImageSource? forceSource,
  }) async {
    if (kIsWeb) {
      try {
        final rawBytes = await pickImageBytesWeb();
        if (rawBytes == null || rawBytes.isEmpty) return null;
        final compressed = compresserImage(
          rawBytes,
          maxWidth: maxWidth?.toInt() ?? 1024,
          quality: imageQuality ?? 80,
        );
        return PhotoSelectionnee(
          octets: compressed,
          nom: 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
          typeMime: 'image/jpeg',
        );
      } catch (e) {
        AppLogger.error('Échec sélection photo Web: $e', tag: 'media');
        rethrow;
      }
    }

    // Plateformes natives (Android / iOS app installée)
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
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (x == null) return null;
    final octets = await x.readAsBytes();
    if (octets.isEmpty) return null;
    return PhotoSelectionnee(
      octets: octets,
      nom: x.name.isNotEmpty ? x.name : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      typeMime: x.mimeType ?? 'image/jpeg',
    );
  }

  /// Sélectionne ou prend une photo et renvoie directement les octets (`Uint8List`).
  static Future<Uint8List?> choisirPhoto(
    BuildContext context, {
    double? maxWidth = 1024,
    double? maxHeight,
    int? imageQuality = 80,
    ImageSource? forceSource,
  }) async {
    final photo = await choisirPhotoDetail(
      context,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      forceSource: forceSource,
    );
    return photo?.octets;
  }

  /// Compresse et redimensionne une image en pur Dart pour éviter tout dépassement mémoire.
  static Uint8List compresserImage(Uint8List rawBytes, {int maxWidth = 1024, int quality = 80}) {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;
      if (decoded.width <= maxWidth && decoded.height <= maxWidth) {
        if (rawBytes.length < 400 * 1024) return rawBytes;
        return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
      }
      final resized = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? maxWidth : null,
        height: decoded.height >= decoded.width ? maxWidth : null,
      );
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    } catch (e) {
      AppLogger.warning('Compression image ignorée: $e', tag: 'media');
      return rawBytes;
    }
  }
}
