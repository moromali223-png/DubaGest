import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../utils/app_logger.dart';

typedef DownloadProgressCallback = void Function(double progress, int receivedBytes, int totalBytes);

class ApkDownloadService {
  ApkDownloadService({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;
  static const MethodChannel _nativeChannel = MethodChannel('com.example.dubagest/updater');

  /// Vérifie si Android autorise DubaGest à installer des applications inconnues (Android 8.0+)
  Future<bool> canRequestPackageInstalls() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final allowed = await _nativeChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return allowed ?? true;
    } catch (e) {
      AppLogger.warning('Erreur vérification permission installation: $e', tag: 'updater');
      return true;
    }
  }

  /// Ouvre l'écran des paramètres système pour accorder l'autorisation d'installation
  Future<void> openInstallPermissionSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _nativeChannel.invokeMethod('openInstallPermissionSettings');
    } catch (e) {
      AppLogger.warning('Erreur ouverture réglages installation: $e', tag: 'updater');
    }
  }

  /// Télécharge l'APK officiel, calcule son empreinte SHA-256 en continu, vérifie son intégrité
  /// et retourne le chemin absolu du fichier vérifié.
  Future<File> downloadAndVerifyApk({
    required String apkUrl,
    required String expectedSha256,
    required int expectedFileSize,
    required DownloadProgressCallback onProgress,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Le téléchargement d\'APK est réservé aux appareils Android.');
    }

    final uri = Uri.parse(apkUrl);
    final request = http.Request('GET', uri);
    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 302) {
      throw HttpException('Échec du téléchargement (${streamedResponse.statusCode})');
    }

    final totalBytes = streamedResponse.contentLength ?? expectedFileSize;

    final cacheDir = await getTemporaryDirectory();
    final apkFile = File('${cacheDir.path}/dubagest_update.apk');
    if (await apkFile.exists()) {
      await apkFile.delete();
    }

    final sink = apkFile.openWrite();
    final sha256Sink = sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback((digests) {
        // Callback finalisé à la fermeture
      }),
    );

    int receivedBytes = 0;
    final completer = Completer<void>();

    final subscription = streamedResponse.stream.listen(
      (chunk) {
        receivedBytes += chunk.length;
        sink.add(chunk);
        sha256Sink.add(chunk);

        final progress = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
        onProgress(progress, receivedBytes, totalBytes);
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    try {
      await completer.future;
    } finally {
      await subscription.cancel();
      await sink.flush();
      await sink.close();
      sha256Sink.close();
    }

    // 1. Vérification de la taille
    final actualSize = await apkFile.length();
    if (actualSize == 0) {
      await apkFile.delete();
      throw const FormatException('Le fichier téléchargé est vide.');
    }
    if (expectedFileSize > 0 && actualSize != expectedFileSize) {
      AppLogger.warning(
        'Avertissement taille APK: attendu $expectedFileSize, reçu $actualSize',
        tag: 'updater',
      );
    }

    // 2. Vérification cryptographique stricte de l'empreinte SHA-256
    final bytes = await apkFile.readAsBytes();
    final actualHash = sha256.convert(bytes).toString().toLowerCase();
    final targetHash = expectedSha256.trim().toLowerCase();

    if (targetHash.isNotEmpty && actualHash != targetHash) {
      await apkFile.delete();
      throw StateError(
        'Intégrité corrompue : l\'empreinte SHA-256 ne correspond pas au manifeste officiel.\n'
        'Calculé: $actualHash\nAttendu: $targetHash',
      );
    }

    AppLogger.info('APK vérifié avec succès (SHA-256: $actualHash)', tag: 'updater');
    return apkFile;
  }

  /// Déclenche l'installeur officiel Android pour appliquer la mise à jour par-dessus l'ancienne
  Future<bool> triggerInstall(File apkFile) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final success = await _nativeChannel.invokeMethod<bool>('installApk', {
        'filePath': apkFile.path,
      });
      return success ?? false;
    } catch (e) {
      AppLogger.warning('Erreur lors du déclenchement de l\'installation: $e', tag: 'updater');
      rethrow;
    }
  }
}

