import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/prestation.dart';
import 'photo_viewer_dialog.dart';

/// Section interactive de gestion des photographies pour un dossier de prestation.
class PrestationPhotosSection extends ConsumerStatefulWidget {
  const PrestationPhotosSection({
    super.key,
    required this.photos,
    required this.onPhotosChanged,
    this.prestationId,
    this.readOnly = false,
  });

  final List<PhotoPrestation> photos;
  final ValueChanged<List<PhotoPrestation>> onPhotosChanged;
  final String? prestationId;
  final bool readOnly;

  @override
  ConsumerState<PrestationPhotosSection> createState() => _PrestationPhotosSectionState();
}

class _PrestationPhotosSectionState extends ConsumerState<PrestationPhotosSection> {
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _recupererPhotoPerdue();
  }

  Future<void> _recupererPhotoPerdue() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      if (!mounted) return;
      final taille = await response.file!.length();
      _ouvrirDialogueCategorie(response.file!.path, taille);
    } catch (_) {
      // Ignorer si pas de données perdues
    }
  }

  Future<void> _capturerPhoto(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (xFile == null || !mounted) return;

      final taille = await xFile.length();
      _ouvrirDialogueCategorie(xFile.path, taille);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'accéder à l\'image : $e'), backgroundColor: AppColors.negative),
        );
      }
    }
  }

  Future<void> _ouvrirDialogueCategorie(String localPath, int taille) async {
    CategoriePhoto categorieChoisie = CategoriePhoto.reception;
    final legendeCtrl = TextEditingController();

    final valide = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: AppColors.green),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enregistrer la photographie',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.ink),
                            ),
                            Text(
                              'Sélectionnez la catégorie du dossier',
                              style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Catégorie de la photo *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cat in CategoriePhoto.values)
                        ChoiceChip(
                          avatar: Text(cat.emoji),
                          label: Text(cat.libelle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          selected: categorieChoisie == cat,
                          selectedColor: AppColors.green,
                          labelStyle: TextStyle(color: categorieChoisie == cat ? Colors.white : AppColors.ink),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => categorieChoisie = cat);
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: legendeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Légende / Observation (facultative)',
                      hintText: 'Ex. Tache constatée sur le col, fissure écran...',
                      prefixIcon: Icon(Icons.comment_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Ajouter au dossier'),
                    onPressed: () => Navigator.of(modalCtx).pop(true),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (valide == true && mounted) {
      final user = ref.read(contexteActifProvider);
      final nouvellePhoto = PhotoPrestation(
        id: const Uuid().v4(),
        prestationId: widget.prestationId ?? '',
        categorie: categorieChoisie,
        cheminLocal: localPath,
        legende: legendeCtrl.text.trim().isNotEmpty ? legendeCtrl.text.trim() : null,
        auteurNom: user?.nomComplet,
        createdBy: user?.userId,
        createdAt: DateTime.now(),
        taille: taille,
        syncStatus: RecordSyncStatus.pendingSync,
      );

      final miseAJour = List<PhotoPrestation>.from(widget.photos)..add(nouvellePhoto);
      widget.onPhotosChanged(miseAJour);
    }
  }

  void _supprimerPhoto(PhotoPrestation photo) {
    final miseAJour = widget.photos.where((p) => p.id != photo.id).toList();
    widget.onPhotosChanged(miseAJour);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library_outlined, size: 18, color: AppColors.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Photographies du dossier (${widget.photos.length})',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: AppColors.ink, letterSpacing: -0.2),
                    ),
                    const Text(
                      'État initial, progression, résultat & preuve de remise',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (!widget.readOnly) ...[
                PopupMenuButton<ImageSource>(
                  tooltip: 'Ajouter une photo',
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 15),
                        SizedBox(width: 4),
                        Text(
                          'Photo',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  onSelected: (source) => _capturerPhoto(source),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: ImageSource.camera,
                      child: Row(
                        children: [
                          Icon(Icons.camera_alt_outlined, color: AppColors.green),
                          SizedBox(width: 10),
                          Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: ImageSource.gallery,
                      child: Row(
                        children: [
                          Icon(Icons.photo_library_outlined, color: AppColors.green),
                          SizedBox(width: 10),
                          Text('Choisir dans la galerie', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (widget.photos.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.muted),
                  const SizedBox(height: 8),
                  const Text(
                    'Aucune photographie attachée',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Prenez une photo de l\'objet ou des pièces pour la traçabilité.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  if (!widget.readOnly) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Prendre une photo'),
                      onPressed: () => _capturerPhoto(ImageSource.camera),
                    ),
                  ],
                ],
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (ctx, idx) {
                  final photo = widget.photos[idx];
                  return _PhotoThumbnailCard(
                    photo: photo,
                    onTap: () => PhotoViewerDialog.show(
                      context,
                      photo: photo,
                      onSupprimer: widget.readOnly ? null : () => _supprimerPhoto(photo),
                    ),
                    onSupprimer: widget.readOnly ? null : () => _supprimerPhoto(photo),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoThumbnailCard extends StatelessWidget {
  const _PhotoThumbnailCard({
    required this.photo,
    required this.onTap,
    this.onSupprimer,
  });

  final PhotoPrestation photo;
  final VoidCallback onTap;
  final VoidCallback? onSupprimer;

  @override
  Widget build(BuildContext context) {
    Widget miniature;
    if (photo.cheminLocal != null && !kIsWeb) {
      final file = File(photo.cheminLocal!);
      if (file.existsSync()) {
        miniature = Image.file(file, fit: BoxFit.cover, width: 110, height: 120);
      } else if (photo.cheminDistant != null) {
        miniature = Image.network(photo.cheminDistant!, fit: BoxFit.cover, width: 110, height: 120);
      } else {
        miniature = _fallbackThumbnail();
      }
    } else if (photo.cheminDistant != null) {
      miniature = Image.network(photo.cheminDistant!, fit: BoxFit.cover, width: 110, height: 120);
    } else {
      miniature = _fallbackThumbnail();
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 110,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.border,
                border: Border.all(color: AppColors.border),
              ),
              child: miniature,
            ),
          ),
          // Badge catégorie
          Positioned(
            bottom: 6,
            left: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(photo.categorie.emoji, style: const TextStyle(fontSize: 10)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      photo.categorie.libelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Badge suppression
          if (onSupprimer != null)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSupprimer,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallbackThumbnail() {
    return Container(
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 28, color: AppColors.muted),
      ),
    );
  }
}
