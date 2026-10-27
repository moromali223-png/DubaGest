import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/permissions/permission_codes.dart';
import '../../../core/sync/sync_models.dart';
import '../../../shared/widgets/state_views.dart';
import '../../agenda/domain/entities/agenda.dart';
import '../../entreprise/presentation/providers/contexte_providers.dart';
import '../domain/fichiers.dart';
import 'fichiers_providers.dart';

/// Notes (hors-ligne) et pièces jointes (envoi en ligne) d'une fiche.
class SectionNotesPieces extends ConsumerStatefulWidget {
  const SectionNotesPieces({super.key, required this.type, required this.cibleId});
  final CibleType type;
  final String cibleId;

  @override
  ConsumerState<SectionNotesPieces> createState() => _SectionNotesPiecesState();
}

class _SectionNotesPiecesState extends ConsumerState<SectionNotesPieces> {
  final _note = TextEditingController();
  bool _envoi = false;

  Fiche get _fiche => (type: widget.type, id: widget.cibleId);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _action(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    }
  }

  Future<void> _ajouterNote() async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null || _note.text.trim().isEmpty) return;
    await _action(() async {
      await ref.read(gererFichiersProvider).ajouterNote(ctx, widget.type, widget.cibleId, _note.text);
      _note.clear();
    });
  }

  Future<void> _joindre(Future<FichierChoisi?> Function() choisir) async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final f = await choisir();
    if (f == null) return;
    setState(() => _envoi = true);
    await _action(() => ref.read(gererFichiersProvider).ajouterPiece(ctx, widget.type, widget.cibleId, f));
    if (mounted) setState(() => _envoi = false);
  }

  Future<FichierChoisi?> _photo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 75);
    if (x == null) return null;
    return FichierChoisi(nom: x.name, octets: await x.readAsBytes(), typeMime: x.mimeType ?? 'image/jpeg');
  }

  Future<FichierChoisi?> _fichier() async {
    final x = await openFile(acceptedTypeGroups: [
      XTypeGroup(
        label: context.l10n.attachFileTypes,
        extensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        mimeTypes: FichierChoisi.typesAcceptes.toList(),
      ),
    ]);
    if (x == null) return null;
    final type = x.mimeType ?? FichierChoisi.typeDepuisNom(x.name) ?? '';
    return FichierChoisi(nom: x.name, octets: await x.readAsBytes(), typeMime: type);
  }

  Future<void> _ouvrir(PieceJointe p) => _action(() async {
        final url = await ref.read(fichiersRepositoryProvider).lienTemporaire(p.chemin);
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsFicheProvider(widget.type));
    if (!droits.lecture) return const SizedBox.shrink();
    final ctx = ref.watch(contexteActifProvider);
    final admin = ctx?.permissionEngine.has(PermissionCodes.entrepriseManage) ?? false;
    final notes = ref.watch(notesFicheProvider(_fiche)).value ?? const <Note>[];
    final pieces = ref.watch(piecesFicheProvider(_fiche)).value ?? const <PieceJointe>[];
    final photoPossible = ImagePicker().supportsImageSource(ImageSource.camera);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.notesTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        if (droits.ajout)
          TextField(
            key: const Key('note-saisie'),
            controller: _note,
            maxLength: 2000,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: l10n.notesAddHint,
              counterText: '',
              suffixIcon: IconButton(
                key: const Key('note-ajouter'),
                tooltip: l10n.notesAdd,
                icon: const Icon(Icons.send),
                onPressed: _ajouterNote,
              ),
            ),
          ),
        for (final n in notes)
          ListTile(
            key: Key('note-${n.id}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sticky_note_2_outlined, color: AppColors.green),
            title: Text(n.texte),
            subtitle: Text([
              if (n.auteurNom != null) n.auteurNom!,
              l10n.dateTime(n.createdAt),
              if (n.syncStatus == RecordSyncStatus.syncError) l10n.financeRejectedShort,
            ].join(' · ')),
            trailing: !(n.createdBy == ctx?.userId || admin)
                ? null
                : PopupMenuButton<String>(
                    onSelected: (choix) => choix == 'modifier' ? _modifier(n) : _action(() => ref.read(gererFichiersProvider).retirerNote(ctx!, n)),
                    itemBuilder: (_) => [
                      if (n.createdBy == ctx?.userId) PopupMenuItem(value: 'modifier', child: Text(l10n.commonEdit)),
                      PopupMenuItem(value: 'retirer', child: Text(l10n.commonDelete)),
                    ],
                  ),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(l10n.attachmentsTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (_envoi) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        if (droits.ajout)
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (photoPossible)
                OutlinedButton.icon(
                  key: const Key('piece-photo'),
                  onPressed: _envoi ? null : () => _joindre(_photo),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.attachTakePhoto),
                ),
              OutlinedButton.icon(
                key: const Key('piece-fichier'),
                onPressed: _envoi ? null : () => _joindre(_fichier),
                icon: const Icon(Icons.attach_file),
                label: Text(l10n.attachChooseFile),
              ),
            ],
          ),
        if (droits.ajout)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.attachOnlineHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          ),
        for (final p in pieces)
          ListTile(
            key: Key('piece-${p.id}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(p.estImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined, color: AppColors.green),
            title: Text(p.nomFichier, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text([
              _taille(l10n, p.taille),
              if (p.auteurNom != null) p.auteurNom!,
              l10n.date(p.createdAt),
            ].join(' · ')),
            onTap: () => _ouvrir(p),
            trailing: !(p.createdBy == ctx?.userId || admin)
                ? null
                : IconButton(
                    tooltip: l10n.commonDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _action(() => ref.read(gererFichiersProvider).retirerPiece(ctx!, p)),
                  ),
          ),
      ],
    );
  }

  static String _taille(AppLocalizations l10n, int octets) => octets >= 1024 * 1024
      ? l10n.attachSizeMb((octets / (1024 * 1024)).toStringAsFixed(1))
      : l10n.attachSizeKb((octets / 1024).ceil());

  Future<void> _modifier(Note n) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    final c = TextEditingController(text: n.texte);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.commonEdit),
        content: TextField(controller: c, maxLength: 2000, maxLines: 4, minLines: 1),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l10n.commonSave)),
        ],
      ),
    );
    final texte = c.text;
    c.dispose();
    if (ok != true || ctx == null) return;
    await _action(() => ref.read(gererFichiersProvider).modifierNote(ctx, n, texte));
  }
}
