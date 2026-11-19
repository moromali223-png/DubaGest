import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'app_logger.dart';

enum WebImageSource { camera, gallery }

/// Sélecteur de photo web direct via FileReader HTML5 natif.
///
/// Résout définitivement la sélection/prise de photo sur iOS Safari et Android Chrome :
/// - Exécution 100% synchrone de `click()` dès le tap utilisateur (conserve la "user activation" Safari/Chrome).
/// - Si `source == WebImageSource.camera`, configure `capture="environment"` pour ouvrir la caméra arrière.
/// - Si `source == WebImageSource.gallery`, ouvre directement la galerie / album de photos.
/// - Inséré dans le DOM avec dimensions réelles et `opacity: 0` (empêche le rejet WebKit lié à `display: none`).
/// - Extraction binaire pure en mémoire vive sans AUCUNE URL blob (immune aux restrictions de Service Worker PWA).
Future<Uint8List?> pickImageBytesWeb({
  WebImageSource source = WebImageSource.gallery,
}) {
  final completer = Completer<Uint8List?>();

  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp,image/gif,image/*';

  if (source == WebImageSource.camera) {
    input.setAttribute('capture', 'environment');
  }

  // Position physique valide mais invisible pour satisfaire le moteur de rendu Safari / Chrome
  input.style.opacity = '0';
  input.style.position = 'fixed';
  input.style.left = '0';
  input.style.top = '0';
  input.style.width = '1px';
  input.style.height = '1px';
  input.style.pointerEvents = 'none';
  input.style.zIndex = '-1';

  void cleanup() {
    try {
      input.remove();
    } catch (_) {}
  }

  // 1. Écouteur de sélection / prise de vue
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
            } catch (err, stack) {
              AppLogger.error('Erreur conversion buffer photo web: $err', error: err, stackTrace: stack, tag: 'media');
              if (!completer.isCompleted) completer.completeError('Impossible de lire cette image.');
            }
          }.toJS,
        );

        reader.addEventListener(
          'error',
          (web.Event e) {
            cleanup();
            AppLogger.error('Erreur FileReader photo web', tag: 'media');
            if (!completer.isCompleted) completer.completeError('Impossible de lire cette image.');
          }.toJS,
        );

        reader.readAsArrayBuffer(file);
      } catch (err, stack) {
        cleanup();
        AppLogger.error('Erreur traitement sélection photo web: $err', error: err, stackTrace: stack, tag: 'media');
        if (!completer.isCompleted) completer.completeError('Échec du chargement de la photo.');
      }
    }.toJS,
  );

  // 2. Écouteur d'annulation (l'utilisateur ferme sans choisir)
  input.addEventListener(
    'cancel',
    (web.Event event) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    }.toJS,
  );

  // 3. Attacher au DOM dans un conteneur persistant
  final body = web.document.body;
  if (body != null) {
    body.append(input);
  } else {
    web.document.documentElement?.append(input);
  }

  // 4. Déclencher le clic immédiatement de façon synchrone dans le cadre du tap
  try {
    input.click();
  } catch (err, stack) {
    cleanup();
    AppLogger.error('Erreur déclenchement click() input photo: $err', error: err, stackTrace: stack, tag: 'media');
    if (!completer.isCompleted) completer.completeError(
      source == WebImageSource.camera ? "Impossible d'accéder à la caméra." : "Impossible d'ouvrir la galerie.",
    );
  }

  return completer.future;
}
