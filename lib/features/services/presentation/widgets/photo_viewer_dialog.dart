import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../fichiers/data/fichiers_repository_impl.dart' show bucketFichiers;
import '../../domain/entities/prestation.dart';

/// Cache mémoire partagé des octets de photos téléchargées depuis Supabase Storage
/// ou capturées localement afin d'assurer un affichage instantané et fluide sur mobile et Web.
final Map<String, Uint8List> prestationPhotoBytesCache = {};

/// Widget réutilisable qui affiche une [PhotoPrestation] qu'elle soit locale,
/// en base64, via URL HTTP ou stockée dans le bucket privé Supabase Storage « fichiers ».
class PrestationPhotoImage extends StatefulWidget {
  const PrestationPhotoImage({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final PhotoPrestation photo;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  State<PrestationPhotoImage> createState() => _PrestationPhotoImageState();
}

class _PrestationPhotoImageState extends State<PrestationPhotoImage> {
  Future<Uint8List?>? _remoteFuture;

  @override
  void initState() {
    super.initState();
    _initRemoteLoader();
  }

  @override
  void didUpdateWidget(covariant PrestationPhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.cheminDistant != widget.photo.cheminDistant ||
        oldWidget.photo.cheminLocal != widget.photo.cheminLocal) {
      _initRemoteLoader();
    }
  }

  void _initRemoteLoader() {
    final distant = widget.photo.cheminDistant;
    if (distant != null && distant.isNotEmpty && !distant.startsWith('http') && !distant.startsWith('data:')) {
      if (prestationPhotoBytesCache.containsKey(distant) || prestationPhotoBytesCache.containsKey(widget.photo.id)) {
        final cached = prestationPhotoBytesCache[distant] ?? prestationPhotoBytesCache[widget.photo.id];
        _remoteFuture = Future.value(cached);
      } else {
        _remoteFuture = _telechargerDepuisStorage(distant);
      }
    } else {
      _remoteFuture = null;
    }
  }

  Future<Uint8List?> _telechargerDepuisStorage(String path) async {
    try {
      final bytes = await Supabase.instance.client.storage.from(bucketFichiers).download(path);
      if (bytes.isNotEmpty) {
        prestationPhotoBytesCache[path] = bytes;
        prestationPhotoBytesCache[widget.photo.id] = bytes;
        return bytes;
      }
    } catch (_) {}
    return null;
  }

  Uint8List? _extraireOctetsDataUri(String uri) {
    try {
      final idx = uri.indexOf(',');
      if (idx != -1 && idx < uri.length - 1) {
        return base64Decode(uri.substring(idx + 1));
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photo;

    // 0. Cache mémoire direct par ID de photo ou chemin local
    if (prestationPhotoBytesCache.containsKey(p.id)) {
      return Image.memory(
        prestationPhotoBytesCache[p.id]!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (_, _, _) => _buildRemoteOrFallback(),
      );
    }
    if (p.cheminLocal != null && prestationPhotoBytesCache.containsKey(p.cheminLocal)) {
      return Image.memory(
        prestationPhotoBytesCache[p.cheminLocal]!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (_, _, _) => _buildRemoteOrFallback(),
      );
    }

    // 1. Fichier local sur appareil mobile (Android / iOS)
    if (p.cheminLocal != null && p.cheminLocal!.isNotEmpty && !kIsWeb && !p.cheminLocal!.startsWith('data:') && !p.cheminLocal!.startsWith('http')) {
      final file = File(p.cheminLocal!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          errorBuilder: (_, _, _) => _buildRemoteOrFallback(),
        );
      }
    }

    // 2. Data URI base64 décodée en mémoire pour rendu garanti universel
    if (p.cheminLocal != null && p.cheminLocal!.startsWith('data:')) {
      final octets = _extraireOctetsDataUri(p.cheminLocal!);
      if (octets != null && octets.isNotEmpty) {
        prestationPhotoBytesCache[p.id] = octets;
        prestationPhotoBytesCache[p.cheminLocal!] = octets;
        return Image.memory(
          octets,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          errorBuilder: (_, _, _) => _buildRemoteOrFallback(),
        );
      }
    }

    // 3. URL HTTP directe
    if (p.cheminLocal != null && p.cheminLocal!.startsWith('http')) {
      return Image.network(
        p.cheminLocal!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (_, _, _) => _buildRemoteOrFallback(),
      );
    }

    return _buildRemoteOrFallback();
  }

  Widget _buildRemoteOrFallback() {
    final distant = widget.photo.cheminDistant;
    if (distant == null || distant.isEmpty) return _placeholder();

    if (distant.startsWith('data:')) {
      final octets = _extraireOctetsDataUri(distant);
      if (octets != null && octets.isNotEmpty) {
        prestationPhotoBytesCache[widget.photo.id] = octets;
        return Image.memory(
          octets,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          errorBuilder: (_, _, _) => _placeholder(),
        );
      }
    }

    if (distant.startsWith('http')) {
      return Image.network(
        distant,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    // Chemin Supabase Storage privé
    if (prestationPhotoBytesCache.containsKey(distant)) {
      return Image.memory(
        prestationPhotoBytesCache[distant]!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _remoteFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            width: widget.width,
            height: widget.height,
            color: AppColors.background,
            child: const Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final data = snap.data;
        if (data != null && data.isNotEmpty) {
          return Image.memory(
            data,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (_, _, _) => _placeholder(),
          );
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 28, color: AppColors.muted),
      ),
    );
  }
}

/// Visionneuse plein écran moderne avec parcours (swipe + flèches), zoom et suppression confirmée.
class PhotoViewerDialog extends StatefulWidget {
  const PhotoViewerDialog({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.onSupprimer,
  });

  final List<PhotoPrestation> photos;
  final int initialIndex;
  final ValueChanged<PhotoPrestation>? onSupprimer;

  static Future<void> show(
    BuildContext context, {
    required PhotoPrestation photo,
    List<PhotoPrestation>? allPhotos,
    VoidCallback? onSupprimer,
    ValueChanged<PhotoPrestation>? onSupprimerPhoto,
  }) {
    final list = (allPhotos != null && allPhotos.isNotEmpty) ? allPhotos : [photo];
    final idx = list.indexWhere((p) => p.id == photo.id).clamp(0, list.length - 1);

    return showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (_) => PhotoViewerDialog(
        photos: list,
        initialIndex: idx,
        onSupprimer: onSupprimerPhoto ??
            (onSupprimer != null ? (_) => onSupprimer() : null),
      ),
    );
  }

  @override
  State<PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<PhotoViewerDialog> {
  late final PageController _pageController;
  late List<PhotoPrestation> _photos;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _photos = List<PhotoPrestation>.from(widget.photos);
    _currentIndex = widget.initialIndex.clamp(0, _photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _confirmerSuppression() async {
    if (widget.onSupprimer == null || _photos.isEmpty) return;
    final photo = _photos[_currentIndex];

    final confirme = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette photo ?'),
        content: const Text('Cette photo sera définitivement retirée du dossier.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirme != true || !mounted) return;
    widget.onSupprimer!(photo);

    if (_photos.length <= 1) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _photos.removeAt(_currentIndex);
      if (_currentIndex >= _photos.length) {
        _currentIndex = _photos.length - 1;
      }
    });
    _pageController.jumpToPage(_currentIndex);
  }

  void _allerA(int index) {
    if (index < 0 || index >= _photos.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) {
      return const SizedBox.shrink();
    }
    final photo = _photos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _photos.length > 1
                  ? 'Photo ${_currentIndex + 1} / ${_photos.length}'
                  : 'Photo du dossier',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              'Ajoutée le ${DateFormat('dd/MM/yyyy à HH:mm').format(photo.createdAt)}${photo.auteurNom != null ? " • ${photo.auteurNom}" : ""}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (widget.onSupprimer != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Supprimer la photo',
              onPressed: _confirmerSuppression,
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _photos.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, idx) => Center(
                child: InteractiveViewer(
                  minScale: 0.6,
                  maxScale: 4.0,
                  child: PrestationPhotoImage(
                    photo: _photos[idx],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            if (_photos.length > 1 && _currentIndex > 0)
              Positioned(
                left: 12,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                    onPressed: () => _allerA(_currentIndex - 1),
                  ),
                ),
              ),
            if (_photos.length > 1 && _currentIndex < _photos.length - 1)
              Positioned(
                right: 12,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                    onPressed: () => _allerA(_currentIndex + 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
