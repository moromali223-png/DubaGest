import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<Uint8List?> pickImageBytesWeb() async {
  final completer = Completer<Uint8List?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp,image/gif';

  input.addEventListener(
    'change',
    (web.Event event) {
      final files = input.files;
      if (files == null || files.length == 0) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final file = files.item(0)!;
      final reader = web.FileReader();
      reader.readAsArrayBuffer(file);

      reader.addEventListener(
        'loadend',
        (web.Event event) {
          try {
            final result = reader.result;
            if (result != null && result.isA<JSArrayBuffer>()) {
              final buffer = (result as JSArrayBuffer).toDart.asUint8List();
              if (!completer.isCompleted) completer.complete(buffer);
            } else {
              if (!completer.isCompleted) completer.complete(null);
            }
          } catch (e) {
            if (!completer.isCompleted) completer.completeError(e);
          }
        }.toJS,
      );

      reader.addEventListener(
        'error',
        (web.Event event) {
          if (!completer.isCompleted) completer.completeError('Erreur de lecture du fichier');
        }.toJS,
      );
    }.toJS,
  );

  input.addEventListener(
    'cancel',
    (web.Event event) {
      if (!completer.isCompleted) completer.complete(null);
    }.toJS,
  );

  input.click();
  return completer.future;
}
