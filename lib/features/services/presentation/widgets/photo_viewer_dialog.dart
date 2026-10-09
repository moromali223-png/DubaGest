import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/prestation.dart';

/// Visionneuse plein écran haute qualité pour les photos de prestation.
class PhotoViewerDialog extends StatelessWidget {
  const PhotoViewerDialog({
    super.key,
    required this.photo,
    this.onSupprimer,
  });

  final PhotoPrestation photo;
  final VoidCallback? onSupprimer;

  static Future<void> show(BuildContext context, {required PhotoPrestation photo, VoidCallback? onSupprimer}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => PhotoViewerDialog(photo: photo, onSupprimer: onSupprimer),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (photo.cheminLocal != null && !kIsWeb) {
      final file = File(photo.cheminLocal!);
      if (file.existsSync()) {
        imageWidget = Image.file(file, fit: BoxFit.contain);
      } else if (photo.cheminDistant != null) {
        imageWidget = Image.network(photo.cheminDistant!, fit: BoxFit.contain);
      } else {
        imageWidget = _placeholderErreur();
      }
    } else if (photo.cheminDistant != null) {
      imageWidget = Image.network(photo.cheminDistant!, fit: BoxFit.contain);
    } else {
      imageWidget = _placeholderErreur();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(photo.categorie.emoji),
                const SizedBox(width: 6),
                Text(
                  photo.categorie.libelle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            Text(
              'Ajoutée le ${DateFormat('dd/MM/yyyy à HH:mm').format(photo.createdAt)}${photo.auteurNom != null ? " par ${photo.auteurNom}" : ""}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (onSupprimer != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Supprimer la photo',
              onPressed: () {
                Navigator.of(context).pop();
                onSupprimer!();
              },
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: imageWidget,
                ),
              ),
            ),
            if (photo.legende != null && photo.legende!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: Colors.black87,
                child: Text(
                  photo.legende!,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderErreur() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 64, color: Colors.white54),
          SizedBox(height: 12),
          Text(
            'Image non disponible hors-ligne',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
