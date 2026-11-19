import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

import 'app_logger.dart';

/// Sélecteur de photo web direct via FileReader HTML5 natif.
///
/// Résout définitivement les problèmes de sélection/prise de photo sur iOS Safari et PWA :
/// - Ne fait AUCUN appel HTTP ni URL blob (compatible Service Worker et isolation cross-origin).
/// - Élément <input type="file" accept="image/*"> attaché au DOM pour garantir le déclenchement
///   de la feuille native iOS (Appareil photo / Photothèque / Fichiers).
/// - Écouteurs d'événements attachés rigoureusement avant la lecture du buffer.
Future<Uint8List?> pickImageBytesWeb() async {
  final completer = Completer<Uint8List?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..style.display = 'none'
    ..style.position = 'fixed'
    ..style.top = '-1000px'
    ..style.left = '-1000px';

  void cleanup() {
    try {
      input.remove();
    } catch (_) {}
  }

  // 1. Écouteur de changement (l'utilisateur a choisi ou pris une photo)
  input.addEventListener(
    'change',
    (web.Event event) {
      try {
        final files = input.files;
        if (files == null || files.length == 0) {
          cleanup();
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final file = files.item(0);
        if (file == null) {
          cleanup();
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final reader = web.FileReader();

        // Les écouteurs DOIVENT impérativement être déclarés AVANT readAsArrayBuffer
        reader.addEventListener(
          'loadend',
          (web.Event e) {
            cleanup();
            try {
              final result = reader.result;
              if (result != null && result.isA<JSArrayBuffer>()) {
                final buffer = (result as JSArrayBuffer).toDart.asUint8List();
                if (!completer.isCompleted) completer.complete(buffer);
              } else {
                if (!completer.isCompleted) completer.complete(null);
              }
            } catch (err) {
              AppLogger.error('Erreur conversion buffer photo web: $err', tag: 'media');
              if (!completer.isCompleted) completer.completeError(err);
            }
          }.toJS,
        );

        reader.addEventListener(
          'error',
          (web.Event e) {
            cleanup();
            AppLogger.error('Erreur FileReader photo web', tag: 'media');
            if (!completer.isCompleted) completer.completeError('Erreur de lecture du fichier');
          }.toJS,
        );

        reader.readAsArrayBuffer(file);
      } catch (err) {
        cleanup();
        AppLogger.error('Erreur traitement sélection photo web: $err', tag: 'media');
        if (!completer.isCompleted) completer.completeError(err);
      }
    }.toJS,
  );

  // 2. Écouteur d'annulation (l'utilisateur a fermé le sélecteur sans choisir)
  input.addEventListener(
    'cancel',
    (web.Event event) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    }.toJS,
  );

  // 3. Attacher au DOM et déclencher
  final body = web.document.body;
  if (body != null) {
    body.append(input);
  } else {
    web.document.documentElement?.append(input);
  }

  try {
    input.click();
  } catch (err) {
    cleanup();
    AppLogger.error('Erreur déclenchement click() input photo: $err', tag: 'media');
    if (!completer.isCompleted) completer.completeError(err);
  }

  return completer.future;
}
