import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../core/utils/media_picker_helper.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/prestation.dart';
import '../services_providers.dart';
import 'photo_viewer_dialog.dart';

/// Section compacte, moderne et fiable de gestion des photographies du dossier.
///
/// Fonctionnalités :
/// - Capture directe (caméra) ou sélection depuis la galerie / ordinateur.
/// - Petite fenêtre de dialogue compacte d'aperçu avant validation (jamais masquée par la Navbar).
/// - Suppression avec confirmation.
/// - Visionneuse plein écran avec parcours multi-photos et zoom.
/// - Compatibilité totale Mobile (Android / iOS / PWA) et Web Desktop.
class PrestationPhotosSection extends ConsumerStatefulWidget {
  const PrestationPhotosSection({
    super.key,
    required this.photos,
    required this.onPhotosChanged,
    this.prestationId,
    this.readOnly = false,
    this.modeDetail = false,
  });

  final List<PhotoPrestation> photos;
  final FutureOr<void> Function(List<PhotoPrestation>) onPhotosChanged;
  final String? prestationId;
  final bool readOnly;

  /// Active le libellé « Enregistrer » dans l'aperçu (page de détail d'un projet/contrat).
  final bool modeDetail;

  @override
  ConsumerState<PrestationPhotosSection> createState() => _PrestationPhotosSectionState();
}

class _PrestationPhotosSectionState extends ConsumerState<PrestationPhotosSection> {
  final _picker = ImagePicker();
  bool _enChargement = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _recupererPhotoPerdue();
    }
  }

  Future<void> _recupererPhotoPerdue() async {
    if (kIsWeb) return;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      if (!mounted) return;
      final octets = await response.file!.readAsBytes();
      await _validerEtAjouterPhoto(
        octets: octets,
        nomFichier: response.file!.name,
        cheminExistant: response.file!.path,
      );
    } catch (_) {}
  }

  Future<void> _capturerPhoto(ImageSource source) async {
    if (_enChargement) return;
    setState(() => _enChargement = true);

    try {
      final photoSelectionnee = await MediaPickerHelper.choisirPhotoDetail(
        context,
        forceSource: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );

      if (photoSelectionnee == null || !mounted) return;

      // Petite fenêtre de dialogue compacte d'aperçu avant enregistrement
      final confirme = await _afficherApercuAvantAjout(photoSelectionnee.octets);
      if (confirme != true || !mounted) return;

      await _validerEtAjouterPhoto(
        octets: photoSelectionnee.octets,
        nomFichier: photoSelectionnee.nom,
      );
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final msg = errStr.contains('MissingPluginException')
            ? "Impossible d'accéder au sélecteur d'image sur ce navigateur."
            : 'Impossible d\'ajouter la photo : $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.negative,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enChargement = false);
    }
  }

  Future<void> _validerEtAjouterPhoto({
    required Uint8List octets,
    required String nomFichier,
    String? cheminExistant,
  }) async {
    final storage = ref.read(prestationPhotosStorageProvider);
    final photoId = const Uuid().v4();

    String chemin;
    if (cheminExistant != null && cheminExistant.isNotEmpty) {
      chemin = cheminExistant;
    } else if (kIsWeb) {
      chemin = 'data:image/jpeg;base64,${base64Encode(octets)}';
    } else {
      // Sauvegarder dans le répertoire permanent (Application Documents) pour éviter la purge après 24h
      chemin = await storage.enregistrerFichierPermanent(nomFichier, octets);
    }

    final user = ref.read(contexteActifProvider);
    final nouvellePhoto = PhotoPrestation(
      id: photoId,
      prestationId: widget.prestationId ?? '',
      categorie: CategoriePhoto.reception,
      cheminLocal: chemin,
      legende: null,
      auteurNom: user?.nomComplet,
      createdBy: user?.userId,
      createdAt: DateTime.now(),
      taille: octets.length,
      syncStatus: RecordSyncStatus.pendingSync,
    );

    // Sauvegarde immédiate et inaltérable dans SQLite et cache mémoire
    await storage.sauvegarderOctets(
      photoId: nouvellePhoto.id,
      octets: octets,
      cheminLocal: chemin,
    );

    final miseAJour = List<PhotoPrestation>.from(widget.photos)..add(nouvellePhoto);
    await widget.onPhotosChanged(miseAJour);
  }

  /// Petite fenêtre de dialogue compacte pour prévisualiser la photo avant de l'enregistrer.
  /// Centrée sur le navigateur racine (`useRootNavigator: true`), jamais masquée par la Navbar.
  Future<bool?> _afficherApercuAvantAjout(Uint8List octets) {
    final labelValidation = widget.modeDetail ? 'Enregistrer' : 'Ajouter au dossier';

    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (dlgCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.greenSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.photo_camera_outlined, size: 18, color: AppColors.green),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Aperçu de la photo',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.ink),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(dlgCtx).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: Container(
                      color: AppColors.background,
                      child: Image.memory(octets, fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          foregroundColor: AppColors.negative,
                          side: BorderSide(color: AppColors.negative.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () => Navigator.of(dlgCtx).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(labelValidation, style: const TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () => Navigator.of(dlgCtx).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Petite fenêtre de dialogue compacte de choix de source (Caméra ou Galerie).
  Future<void> _ouvrirSelecteurSource(BuildContext context) async {
    final source = await showDialog<ImageSource>(
      context: context,
      useRootNavigator: true,
      builder: (dlgCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ajouter une photo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(dlgCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: const BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle),
                    child: const Icon(Icons.photo_camera_outlined, color: AppColors.green, size: 20),
                  ),
                  title: const Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Ouvrir l\'appareil photo', style: TextStyle(fontSize: 12)),
                  onTap: () => Navigator.of(dlgCtx).pop(ImageSource.camera),
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library_outlined, color: Color(0xFF4F46E5), size: 20),
                  ),
                  title: const Text('Choisir dans la galerie', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Importer une image existante', style: TextStyle(fontSize: 12)),
                  onTap: () => Navigator.of(dlgCtx).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (source != null && mounted) {
      await _capturerPhoto(source);
    }
  }

  Future<void> _demanderConfirmationSuppression(PhotoPrestation photo) async {
    final confirme = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette photo ?'),
        content: const Text('Cette photo sera retirée du dossier.'),
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

    if (confirme == true && mounted) {
      await _supprimerPhoto(photo);
    }
  }

  Future<void> _supprimerPhoto(PhotoPrestation photo) async {
    if (_enChargement) return;
    setState(() => _enChargement = true);
    try {
      final storage = ref.read(prestationPhotosStorageProvider);
      await storage.supprimerPhoto(photo);
      final miseAJour = widget.photos.where((p) => p.id != photo.id).toList();
      await widget.onPhotosChanged(miseAJour);
    } finally {
      if (mounted) setState(() => _enChargement = false);
    }
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
          // En-tête de section
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
                      'Photos du dossier (${widget.photos.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Text(
                      'Preuve visuelle et suivi du dossier',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (!widget.readOnly) ...[
                if (_enChargement)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 16),
                    label: const Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    onPressed: () => _ouvrirSelecteurSource(context),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // État vide : 2 boutons directs (Caméra & Galerie)
          if (widget.photos.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.muted),
                  const SizedBox(height: 6),
                  const Text(
                    'Aucune photo enregistrée',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Prenez une photo directement ou importez depuis votre galerie.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  if (!widget.readOnly) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.photo_camera_outlined, size: 16),
                          label: const Text('Prendre une photo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          onPressed: _enChargement ? null : () => _capturerPhoto(ImageSource.camera),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: const Text('Galerie', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          onPressed: _enChargement ? null : () => _capturerPhoto(ImageSource.gallery),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )
          else
            // Liste horizontale des miniatures avec aperçu plein écran et suppression confirmée
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.photos.length + (widget.readOnly ? 0 : 1),
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (ctx, idx) {
                  if (idx == widget.photos.length) {
                    return InkWell(
                      onTap: _enChargement ? null : () => _ouvrirSelecteurSource(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 96,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_a_photo_outlined, size: 19, color: AppColors.primary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '+ Photo',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final photo = widget.photos[idx];
                  return _PhotoThumbnailCard(
                    photo: photo,
                    onTap: () => PhotoViewerDialog.show(
                      context,
                      photo: photo,
                      allPhotos: widget.photos,
                      onSupprimerPhoto: widget.readOnly ? null : (p) => _supprimerPhoto(p),
                    ),
                    onSupprimer: widget.readOnly ? null : () => _demanderConfirmationSuppression(photo),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 104,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.border,
                border: Border.all(color: AppColors.border),
              ),
              child: PrestationPhotoImage(
                photo: photo,
                fit: BoxFit.cover,
                width: 104,
                height: 120,
              ),
            ),
          ),
          if (onSupprimer != null)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black.withValues(alpha: 0.65),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSupprimer,
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
